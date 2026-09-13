locals {
  # Infrastructure connection details are explicit inputs. This keeps the Lambda
  # deployment independent from any other Terraform state or deployment order.
  db_url             = var.db_url
  subnet_ids         = var.vpc_subnet_ids
  security_group_ids = var.vpc_security_group_ids
}
