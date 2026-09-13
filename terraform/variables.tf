variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "Expected AWS account ID. Guards the provider against deploying to the wrong account. Empty = no restriction (local validation)."
  type        = string
  default     = ""
}

variable "environment" {
  description = "Deployment environment. Matches the branch name: develop or main."
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

variable "db_url" {
  description = "JDBC URL for the clients database."
  type        = string
  sensitive   = true
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

variable "vpc_subnet_ids" {
  description = "Private subnet IDs for the auth issuer Lambda."
  type        = list(string)
}

variable "vpc_security_group_ids" {
  description = "Security group IDs for the Lambda (must reach the DB)."
  type        = list(string)
}

# --- Protected backend (target of the authorized routes) ------------------
# (Removed: the API Gateway and its backend proxy now live in os-management-gateway.)
