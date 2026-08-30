terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state (recommended for homolog/prod). Configured by CI via -backend-config,
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

  default_tags {
    tags = {
      Project     = "os-management"
      Component   = "auth-lambda"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}
