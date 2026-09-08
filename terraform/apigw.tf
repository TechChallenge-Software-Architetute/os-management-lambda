# =============================================================================
# API Gateway (HTTP API v2) — public entry point for the platform
#
# Merged in from the former `os-management-gateway` repo. HTTP API (v2) is used
# instead of REST API (v1) because:
#   * VPC Link is free (REST needs a paid NLB for private integration);
#   * it is ~70% cheaper per request and lower latency;
#   * CORS is a single block;
#   * a REQUEST authorizer with `enable_simple_responses` is not scoped to a
#     method ARN, which removes the REST TOKEN-authorizer caching bug where the
#     first route's policy is cached and every other route is then denied.
#
# Routes:
#   POST /auth        -> issuer Lambda (public, throttled tighter)
#   ANY  /{proxy+}     -> backend on Kubernetes, guarded by the JWT authorizer
# =============================================================================

resource "aws_apigatewayv2_api" "this" {
  name          = "${var.name_prefix}-gateway-${var.environment}"
  protocol_type = "HTTP"
  description   = "Public entry point for the OS Management platform (auth + protected proxy)."

  cors_configuration {
    allow_origins = var.cors_allow_origins
    allow_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_headers = ["authorization", "content-type"]
    max_age       = 3600
  }
}

# -----------------------------------------------------------------------------
# Public route: POST /auth -> issuer Lambda (no authorizer)
# -----------------------------------------------------------------------------

resource "aws_apigatewayv2_integration" "issuer" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.issuer.invoke_arn
  integration_method     = "POST"
  payload_format_version = "1.0" # AuthHandler uses the v1 APIGatewayProxyRequest/Response model
}

resource "aws_apigatewayv2_route" "auth" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /auth"
  target    = "integrations/${aws_apigatewayv2_integration.issuer.id}"
}

resource "aws_lambda_permission" "apigw_issuer" {
  statement_id  = "AllowAPIGatewayInvokeIssuer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.issuer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*/auth"
}

# -----------------------------------------------------------------------------
# REQUEST authorizer (validates the JWT; simple {isAuthorized} response)
# -----------------------------------------------------------------------------

resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id                            = aws_apigatewayv2_api.this.id
  authorizer_type                   = "REQUEST"
  authorizer_uri                    = aws_lambda_function.authorizer.invoke_arn
  identity_sources                  = ["$request.header.Authorization"]
  name                              = "${var.name_prefix}-jwt-authorizer-${var.environment}"
  authorizer_payload_format_version = "2.0"
  enable_simple_responses           = true
  authorizer_result_ttl_in_seconds  = var.authorizer_cache_ttl_seconds
}

resource "aws_lambda_permission" "apigw_authorizer" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/authorizers/${aws_apigatewayv2_authorizer.jwt.id}"
}

# -----------------------------------------------------------------------------
# Protected catch-all: ANY /{proxy+} -> backend on Kubernetes, guarded by JWT
# -----------------------------------------------------------------------------

resource "aws_apigatewayv2_integration" "backend" {
  api_id             = aws_apigatewayv2_api.this.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = "${local.origin_url}/{proxy}"
  integration_method = "ANY"

  # Optional shared secret so the backend can reject traffic that bypasses the
  # gateway and hits its load balancer directly. The app must check this header.
  request_parameters = var.origin_verify_token != "" ? {
    "overwrite:header.x-origin-verify" = var.origin_verify_token
  } : null
}

resource "aws_apigatewayv2_route" "proxy" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "ANY /{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.backend.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}

# -----------------------------------------------------------------------------
# Stage — auto-deploy, throttling, structured JSON access logs
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "apigw_access" {
  name              = "/aws/apigateway/${aws_apigatewayv2_api.this.name}/access"
  retention_in_days = var.log_retention_days
}

# API Gateway needs permission to write the access log stream.
data "aws_iam_policy_document" "apigw_logs" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.apigw_access.arn}:*"]
    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "apigw" {
  policy_name     = "${var.name_prefix}-apigw-access-logs-${var.environment}"
  policy_document = data.aws_iam_policy_document.apigw_logs.json
}

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = var.environment
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit    = var.throttle_rate_limit
    throttling_burst_limit   = var.throttle_burst_limit
    detailed_metrics_enabled = var.detailed_metrics_enabled
  }

  # Tighter limit for the unauthenticated auth endpoint (CPF enumeration guard).
  route_settings {
    route_key                = aws_apigatewayv2_route.auth.route_key
    throttling_rate_limit    = var.auth_throttle_rate_limit
    throttling_burst_limit   = var.auth_throttle_burst_limit
    detailed_metrics_enabled = var.detailed_metrics_enabled
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw_access.arn
    format = jsonencode({
      requestId          = "$context.requestId"
      requestTime        = "$context.requestTime"
      method             = "$context.http.method"
      path               = "$context.http.path"
      routeKey           = "$context.routeKey"
      protocol           = "$context.http.protocol"
      status             = "$context.status"
      responseLatency    = "$context.responseLatency"
      integrationLatency = "$context.integrationLatency"
      integrationStatus  = "$context.integrationStatus"
      authorizerError    = "$context.authorizer.error"
      errorMessage       = "$context.error.message"
      sourceIp           = "$context.http.sourceIp"
      userAgent          = "$context.http.userAgent"
      clientId           = "$context.authorizer.clientId"
    })
  }

  depends_on = [aws_cloudwatch_log_resource_policy.apigw]
}
