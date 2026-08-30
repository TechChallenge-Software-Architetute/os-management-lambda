locals {
  auth_function_name       = "${var.name_prefix}-issuer-${var.environment}"
  authorizer_function_name = "${var.name_prefix}-authorizer-${var.environment}"
}

# =============================================================================
# Secrets Manager (managed source of truth for sensitive values)
# =============================================================================
# Values are also injected as Lambda environment variables so the function code
# (which reads plain env vars) works unchanged. Fetching these at runtime via the
# AWS SDK is a future hardening step.

resource "aws_secretsmanager_secret" "jwt" {
  name        = "${var.name_prefix}/jwt-secret/${var.environment}"
  description = "Shared HMAC secret for JWT signing/verification."
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id     = aws_secretsmanager_secret.jwt.id
  secret_string = var.jwt_secret
}

resource "aws_secretsmanager_secret" "db" {
  name        = "${var.name_prefix}/db-credentials/${var.environment}"
  description = "Database credentials for the clients lookup."
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    url      = local.db_url
    username = var.db_user
    password = var.db_password
  })
}

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

data "aws_iam_policy_document" "issuer_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.jwt.arn, aws_secretsmanager_secret.db.arn]
  }
}

resource "aws_iam_role_policy" "issuer_secrets" {
  name   = "read-secrets"
  role   = aws_iam_role.issuer.id
  policy = data.aws_iam_policy_document.issuer_secrets.json
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

data "aws_iam_policy_document" "authorizer_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.jwt.arn]
  }
}

resource "aws_iam_role_policy" "authorizer_secrets" {
  name   = "read-jwt-secret"
  role   = aws_iam_role.authorizer.id
  policy = data.aws_iam_policy_document.authorizer_secrets.json
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

  environment {
    variables = {
      DB_URL         = local.db_url
      DB_USERNAME    = var.db_user
      DB_PASSWORD    = var.db_password
      JWT_SECRET     = var.jwt_secret
      JWT_EXPIRATION = tostring(var.jwt_expiration_ms)
    }
  }
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

  environment {
    variables = {
      JWT_SECRET = var.jwt_secret
    }
  }
}
