terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state (recommended for develop/main). Configured by CI via -backend-config,
  # so local `terraform init -backend=false` still works for validation.
  #
  # backend "s3" {
  #   bucket = "os-management-tfstate"
  #   key    = "lambda/terraform.tfstate"
  #   region = "us-east-1"
  # }
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  # Guardrail: fail fast if the active credentials point at an unexpected account.
  # Empty (local validation) = no restriction; CI sets TF_VAR_aws_account_id.
  allowed_account_ids = var.aws_account_id != "" ? [var.aws_account_id] : []

  default_tags {
    tags = {
      Project     = "os-management"
      Component   = "auth-lambda"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}
