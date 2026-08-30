# Reads shared infrastructure (VPC subnets, node security group, RDS URL) from the
# os-management EKS Terraform state, so those values don't have to be re-entered here.
data "terraform_remote_state" "os_management" {
  backend = "s3"
  config = {
    bucket = var.os_management_state_bucket
    key    = var.os_management_state_key
    region = var.aws_region
  }
}

locals {
  # Prefer explicit variables when provided; otherwise fall back to os-management outputs.
  db_url = var.db_url != "" ? var.db_url : data.terraform_remote_state.os_management.outputs.rds_jdbc_url

  subnet_ids = length(var.vpc_subnet_ids) > 0 ? var.vpc_subnet_ids : data.terraform_remote_state.os_management.outputs.private_subnet_ids

  security_group_ids = length(var.vpc_security_group_ids) > 0 ? var.vpc_security_group_ids : [data.terraform_remote_state.os_management.outputs.node_security_group_id]
}
