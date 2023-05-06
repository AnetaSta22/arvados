# Copyright (C) The Arvados Authors. All rights reserved.
#
# SPDX-License-Identifier: CC-BY-SA-3.0

locals {
  allowed_ports = {
    http: "80",
    https: "443",
    ssh: "22",
  }
  availability_zone = data.aws_availability_zones.available.names[0]
  route53_public_zone = one(aws_route53_zone.public_zone[*])
  iam_user_letsencrypt = one(aws_iam_user.letsencrypt[*])
  iam_access_key_letsencrypt = one(aws_iam_access_key.letsencrypt[*])
  public_hosts = var.private_only ? [] : var.user_facing_hosts
  private_hosts = concat(
    var.internal_service_hosts,
    var.private_only ? var.user_facing_hosts : []
  )
  arvados_dns_zone = "${var.cluster_name}.${var.domain_name}"
  public_ip = {
    for k, v in aws_eip.arvados_eip: k => v.public_ip
  }
  private_ip = {
    "controller": "10.1.1.11",
    "workbench": "10.1.1.15",
    "shell": "10.1.2.17",
    "keep0": "10.1.2.13",
  }
  aliases = {
    controller: ["ws"]
    workbench: ["workbench2", "webshell", "keep", "download", "prometheus", "grafana", "*.collections"]
  }
  cname_by_host = flatten([
    for host, aliases in local.aliases : [
      for alias in aliases : {
        record = alias
        cname = host
      }
    ]
  ])
}
