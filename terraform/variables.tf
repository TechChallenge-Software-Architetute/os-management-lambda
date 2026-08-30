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

variable "db_url" {
  description = "JDBC URL for the clients database, e.g. jdbc:postgresql://host:5432/workshop."
  type        = string
}

variable "db_username" {
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
  description = "Private subnet IDs for the auth issuer Lambda (must route to the database)."
  type        = list(string)
}

variable "vpc_security_group_ids" {
  description = "Security group IDs allowing the Lambda to reach the database."
  type        = list(string)
}

# --- Protected backend (target of the authorized routes) ------------------

variable "protected_backend_url" {
  description = "Base HTTP(S) URL of the protected backend API (e.g. the app running on Kubernetes)."
  type        = string
}
