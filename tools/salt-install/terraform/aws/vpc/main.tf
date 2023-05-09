# Copyright (C) The Arvados Authors. All rights reserved.
#
# SPDX-License-Identifier: CC-BY-SA-3.0

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = var.region_name
  default_tags {
    tags = {
      Arvados = var.cluster_name
    }
  }
}

resource "aws_vpc" "arvados_vpc" {
  cidr_block = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
}
resource "aws_subnet" "public_subnet" {
  vpc_id = aws_vpc.arvados_vpc.id
  availability_zone = local.availability_zone
  cidr_block = "10.1.1.0/24"
}
resource "aws_subnet" "private_subnet" {
  vpc_id = aws_vpc.arvados_vpc.id
  availability_zone = local.availability_zone
  cidr_block = "10.1.2.0/24"
}

#
# VPC S3 access
#
resource "aws_vpc_endpoint" "s3" {
  vpc_id = aws_vpc.arvados_vpc.id
  service_name = "com.amazonaws.${var.region_name}.s3"
}
resource "aws_vpc_endpoint_route_table_association" "compute_s3_route" {
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
  route_table_id = aws_route_table.private_subnet_rt.id
}

#
# Internet access for Public IP instances
#
resource "aws_internet_gateway" "internet_gw" {
  vpc_id = aws_vpc.arvados_vpc.id
}
resource "aws_eip" "arvados_eip" {
  for_each = toset(local.public_hosts)
  depends_on = [
    aws_internet_gateway.internet_gw
  ]
}
resource "aws_route_table" "public_subnet_rt" {
  vpc_id = aws_vpc.arvados_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gw.id
  }
}
resource "aws_route_table_association" "public_subnet_assoc" {
  subnet_id = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_subnet_rt.id
}

#
# Internet access for Private IP instances
#
resource "aws_eip" "nat_gw_eip" {
  depends_on = [
    aws_internet_gateway.internet_gw
  ]
}
resource "aws_nat_gateway" "nat_gw" {
  # A NAT gateway should be placed on a subnet with an internet gateway
  subnet_id = aws_subnet.public_subnet.id
  allocation_id = aws_eip.nat_gw_eip.id
}
resource "aws_route_table" "private_subnet_rt" {
  vpc_id = aws_vpc.arvados_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
}
resource "aws_route_table_association" "private_subnet_assoc" {
  subnet_id = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_subnet_rt.id
}

resource "aws_security_group" "arvados_sg" {
  name = "arvados_sg"
  vpc_id = aws_vpc.arvados_vpc.id

  dynamic "ingress" {
    for_each = local.allowed_ports
    content {
      description = "Ingress rule for ${ingress.key}"
      from_port = "${ingress.value}"
      to_port = "${ingress.value}"
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }
  # Allows communication between nodes in the VPC
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ aws_vpc.arvados_vpc.cidr_block ]
  }
  # Even though AWS auto-creates an "allow all" egress rule,
  # Terraform deletes it, so we add it explicitly.
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

#
# Route53 split-horizon DNS zones
#

# PUBLIC DNS
resource "aws_route53_zone" "public_zone" {
  count = var.private_only ? 0 : 1
  name = local.arvados_dns_zone
}
resource "aws_route53_record" "public_a_record" {
  zone_id = try(local.route53_public_zone.id, "")
  for_each = local.public_ip
  name = each.key
  type = "A"
  ttl = 300
  records = [ each.value ]
}
resource "aws_route53_record" "main_a_record" {
  count = var.private_only ? 0 : 1
  zone_id = try(local.route53_public_zone.id, "")
  name = ""
  type = "A"
  ttl = 300
  records = [ local.public_ip["controller"] ]
}
resource "aws_route53_record" "public_cname_record" {
  zone_id = try(local.route53_public_zone.id, "")
  for_each = {
    for i in local.cname_by_host: i.record =>
      "${i.cname}.${local.arvados_dns_zone}"
    if var.private_only == false
  }
  name = each.key
  type = "CNAME"
  ttl = 300
  records = [ each.value ]
}

# PRIVATE DNS
resource "aws_route53_zone" "private_zone" {
  name = local.arvados_dns_zone
  vpc {
    vpc_id = aws_vpc.arvados_vpc.id
  }
}
resource "aws_route53_record" "private_a_record" {
  zone_id = aws_route53_zone.private_zone.id
  for_each = local.private_ip
  name = each.key
  type = "A"
  ttl = 300
  records = [ each.value ]
}
resource "aws_route53_record" "private_main_a_record" {
  zone_id = aws_route53_zone.private_zone.id
  name = ""
  type = "A"
  ttl = 300
  records = [ local.private_ip["controller"] ]
}
resource "aws_route53_record" "private_cname_record" {
  zone_id = aws_route53_zone.private_zone.id
  for_each = {for i in local.cname_by_host: i.record => "${i.cname}.${local.arvados_dns_zone}" }
  name = each.key
  type = "CNAME"
  ttl = 300
  records = [ each.value ]
}

#
# Route53's credentials for Let's Encrypt
#
resource "aws_iam_user" "letsencrypt" {
  count = var.private_only ? 0 : 1
  name = "${var.cluster_name}-letsencrypt"
  path = "/"
}

resource "aws_iam_access_key" "letsencrypt" {
  count = var.private_only ? 0 : 1
  user = local.iam_user_letsencrypt.name
}
resource "aws_iam_user_policy" "letsencrypt_iam_policy" {
  count = var.private_only ? 0 : 1
  name = "${var.cluster_name}-letsencrypt_iam_policy"
  user = local.iam_user_letsencrypt.name
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:GetChange"
      ],
      "Resource": [
          "*"
      ]
    },{
      "Effect" : "Allow",
      "Action" : [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource" : [
        "arn:aws:route53:::hostedzone/${local.route53_public_zone.id}"
      ]
    }]
  })
}

