# Copyright (C) The Arvados Authors. All rights reserved.
#
# SPDX-License-Identifier: CC-BY-SA-3.0

locals {
  region_name = data.terraform_remote_state.vpc.outputs.region_name
  cluster_name = data.terraform_remote_state.vpc.outputs.cluster_name
  use_external_db = data.terraform_remote_state.data-storage.outputs.use_external_db
  private_only = data.terraform_remote_state.vpc.outputs.private_only
  public_ip = data.terraform_remote_state.vpc.outputs.public_ip
  private_ip = data.terraform_remote_state.vpc.outputs.private_ip
  pubkey_path = pathexpand(var.pubkey_path)
  pubkey_name = "${local.cluster_name}-arvados-deployer-key"
  public_hosts = data.terraform_remote_state.vpc.outputs.public_hosts
  private_hosts = data.terraform_remote_state.vpc.outputs.private_hosts
  user_facing_hosts = data.terraform_remote_state.vpc.outputs.user_facing_hosts
  internal_service_hosts = data.terraform_remote_state.vpc.outputs.internal_service_hosts
  ssl_password_secret_name = "${local.cluster_name}-${var.ssl_password_secret_name_suffix}"
}
