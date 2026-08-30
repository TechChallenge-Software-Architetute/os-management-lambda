variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (e.g. homolog, prod)."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
  default     = "os-auth"
}

variable "lambda_jar_path" {
  description = "Path to the built Lambda fat jar."
  type        = string
  default     = "../target/os-management-lambda.jar"
}

variable "lambda_runtime" {
  description = "Lambda Java runtime."
  type        = string
  default     = "java21"
}

variable "lambda_memory_mb" {
  description = "Memory (MB) for the auth issuer Lambda."
  type        = number
  default     = 512
}

variable "lambda_timeout_seconds" {
  description = "Timeout (seconds) for the Lambda functions."
  type        = number
  default     = 15
}

# --- Database (managed PostgreSQL) ---------------------------------------
# db_url is optional: when empty it is read from the os-management remote state.

variable "db_url" {
  description = "JDBC URL for the clients database. Leave empty to source it from os-management state."
  type        = string
  default     = ""
}

variable "db_user" {
  description = "Database username."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database password."
  type        = string
  sensitive   = true
}

# --- Shared os-management state (source of VPC + RDS values) --------------

variable "os_management_state_bucket" {
  description = "S3 bucket holding the os-management Terraform state."
  type        = string
}

variable "os_management_state_key" {
  description = "State key for the os-management EKS stack."
  type        = string
  default     = "eks/terraform.tfstate"
}

# --- JWT ------------------------------------------------------------------

variable "jwt_secret" {
  description = "Shared HMAC secret used to sign and verify JWTs. Must match the platform value."
  type        = string
  sensitive   = true
}

variable "jwt_expiration_ms" {
  description = "JWT lifetime in milliseconds."
  type        = number
  default     = 86400000
}

# --- VPC (auth issuer needs to reach the database) ------------------------
# Both optional: when empty they are read from the os-management remote state.

variable "vpc_subnet_ids" {
  description = "Private subnet IDs for the auth issuer Lambda. Empty = use os-management state."
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "Security group IDs for the Lambda (must reach the DB). Empty = use os-management node SG."
  type        = list(string)
  default     = []
}

# --- Protected backend (target of the authorized routes) ------------------
# (Removed: the API Gateway and its backend proxy now live in os-management-gateway.)
