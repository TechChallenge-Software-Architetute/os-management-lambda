variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (e.g. homolog, prod). Drives resource names, the stage name and state keys."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
  default     = "os-auth"
}

# =============================================================================
# Lambda
# =============================================================================

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

variable "log_retention_days" {
  description = "CloudWatch log retention for the Lambdas and the API Gateway access log."
  type        = number
  default     = 14
}

# =============================================================================
# Database (managed PostgreSQL)
# =============================================================================
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

# =============================================================================
# Shared os-management state (source of VPC + RDS values)
# =============================================================================

variable "os_management_state_bucket" {
  description = "S3 bucket holding the os-management Terraform state."
  type        = string
}

variable "os_management_state_key" {
  description = "State key for the os-management EKS stack."
  type        = string
  default     = "eks/terraform.tfstate"
}

# =============================================================================
# JWT
# =============================================================================

variable "jwt_secret" {
  description = "Shared HMAC secret used to sign and verify JWTs. Must match the platform value."
  type        = string
  sensitive   = true
}

variable "jwt_expiration_ms" {
  description = "JWT lifetime in milliseconds."
  type        = number
  default     = 3600000 # 1h — CPF is an identifier, not a credential; keep tokens short-lived.
}

variable "jwt_issuer" {
  description = "Value stamped as the JWT `iss` claim and enforced by the authorizer and the main app."
  type        = string
  default     = "os-management-auth"
}

variable "jwt_audience" {
  description = "Value stamped as the JWT `aud` claim and enforced by the authorizer and the main app."
  type        = string
  default     = "os-management-api"
}

# =============================================================================
# VPC (auth issuer needs to reach the database)
# =============================================================================
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

# =============================================================================
# API Gateway (HTTP API v2)
# =============================================================================

variable "origin_url" {
  description = "Base URL of the OS Management backend on Kubernetes (e.g. https://app.example.com). Empty = read from SSM."
  type        = string
  default     = ""

  validation {
    condition     = var.origin_url == "" || can(regex("^https?://[^/]+(:[0-9]+)?(/.*)?$", var.origin_url))
    error_message = "origin_url must be empty or an absolute HTTP/HTTPS URL."
  }
}

variable "origin_url_ssm_parameter" {
  description = "SSM parameter name holding the backend URL. Empty = /os-management/<env>/app/origin_url."
  type        = string
  default     = ""
}

variable "origin_verify_token" {
  description = "Optional shared secret injected as the `x-origin-verify` header so the backend can reject direct traffic. Empty = disabled."
  type        = string
  default     = ""
  sensitive   = true
}

variable "cors_allow_origins" {
  description = "Allowed CORS origins for the API."
  type        = list(string)
  default     = ["*"]
}

variable "authorizer_cache_ttl_seconds" {
  description = "How long API Gateway caches an authorizer result, keyed by the Authorization header."
  type        = number
  default     = 300
}

variable "detailed_metrics_enabled" {
  description = "Per-route CloudWatch metrics. API-level latency/4xx/5xx are free regardless; per-route metrics can incur CloudWatch charges."
  type        = bool
  default     = false
}

variable "throttle_rate_limit" {
  description = "Steady-state requests/second for all routes (stage default)."
  type        = number
  default     = 100
}

variable "throttle_burst_limit" {
  description = "Burst capacity for all routes (stage default)."
  type        = number
  default     = 200
}

variable "auth_throttle_rate_limit" {
  description = "Steady-state requests/second for the unauthenticated POST /auth route."
  type        = number
  default     = 10
}

variable "auth_throttle_burst_limit" {
  description = "Burst capacity for the unauthenticated POST /auth route."
  type        = number
  default     = 20
}

variable "publish_ssm_outputs" {
  description = "Publish api/base_url and the JWT iss/aud to SSM for other repos to consume."
  type        = bool
  default     = true
}
