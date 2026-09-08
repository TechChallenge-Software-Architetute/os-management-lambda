locals {
  auth_function_name       = "${var.name_prefix}-issuer-${var.environment}"
  authorizer_function_name = "${var.name_prefix}-authorizer-${var.environment}"

  # Claims stamped by the issuer and enforced by the authorizer / main app.
  jwt_env = {
    JWT_SECRET   = var.jwt_secret
    JWT_ISSUER   = var.jwt_issuer
    JWT_AUDIENCE = var.jwt_audience
  }
}

# =============================================================================
# Secrets
# =============================================================================
# DB credentials and the JWT secret are passed as Lambda environment variables.
# AWS encrypts them at rest with an AWS-managed KMS key at no cost. A dedicated
# Secrets Manager store with rotation is deliberately out of scope for the free
# tier (~US$0.40/secret/month) and is tracked as future hardening — see README.

# =============================================================================
# IAM
# =============================================================================

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# --- Auth issuer role (needs VPC access to reach the database) ---
resource "aws_iam_role" "issuer" {
  name               = "${local.auth_function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "issuer_basic" {
  role       = aws_iam_role.issuer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "issuer_vpc" {
  role       = aws_iam_role.issuer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "issuer_xray" {
  role       = aws_iam_role.issuer.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# --- Authorizer role (validates JWT only; no VPC, no DB) ---
resource "aws_iam_role" "authorizer" {
  name               = "${local.authorizer_function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "authorizer_basic" {
  role       = aws_iam_role.authorizer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "authorizer_xray" {
  role       = aws_iam_role.authorizer.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# =============================================================================
# CloudWatch log groups (declared so retention is bounded, not "never expire")
# =============================================================================

resource "aws_cloudwatch_log_group" "issuer" {
  name              = "/aws/lambda/${local.auth_function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "authorizer" {
  name              = "/aws/lambda/${local.authorizer_function_name}"
  retention_in_days = var.log_retention_days
}

# =============================================================================
# Lambda functions
# =============================================================================

resource "aws_lambda_function" "issuer" {
  function_name    = local.auth_function_name
  role             = aws_iam_role.issuer.arn
  runtime          = var.lambda_runtime
  handler          = "com.os.workshop.auth.AuthHandler::handleRequest"
  filename         = var.lambda_jar_path
  source_code_hash = filebase64sha256(var.lambda_jar_path)
  memory_size      = var.lambda_memory_mb
  timeout          = var.lambda_timeout_seconds

  vpc_config {
    subnet_ids         = local.subnet_ids
    security_group_ids = local.security_group_ids
  }

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = merge(local.jwt_env, {
      DB_URL         = local.db_url
      DB_USERNAME    = var.db_user
      DB_PASSWORD    = var.db_password
      JWT_EXPIRATION = tostring(var.jwt_expiration_ms)
    })
  }

  depends_on = [aws_cloudwatch_log_group.issuer]
}

resource "aws_lambda_function" "authorizer" {
  function_name    = local.authorizer_function_name
  role             = aws_iam_role.authorizer.arn
  runtime          = var.lambda_runtime
  handler          = "com.os.workshop.auth.TokenAuthorizerHandler::handleRequest"
  filename         = var.lambda_jar_path
  source_code_hash = filebase64sha256(var.lambda_jar_path)
  memory_size      = 256
  timeout          = var.lambda_timeout_seconds

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = local.jwt_env
  }

  depends_on = [aws_cloudwatch_log_group.authorizer]
}
