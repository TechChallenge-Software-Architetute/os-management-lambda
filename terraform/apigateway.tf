locals {
  api_name = "${var.name_prefix}-api-${var.environment}"
}

resource "aws_api_gateway_rest_api" "this" {
  name        = local.api_name
  description = "Auth + protected routing for os-management (${var.environment})."

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# =============================================================================
# Public route: POST /auth -> auth issuer Lambda (no authorization)
# =============================================================================

resource "aws_api_gateway_resource" "auth" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "auth"
}

resource "aws_api_gateway_method" "auth_post" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.auth.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_post" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.auth.id
  http_method             = aws_api_gateway_method.auth_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.issuer.invoke_arn
}

resource "aws_lambda_permission" "apigw_invoke_issuer" {
  statement_id  = "AllowAPIGatewayInvokeIssuer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.issuer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/POST/auth"
}

# =============================================================================
# TOKEN authorizer (validates the JWT on protected routes)
# =============================================================================

resource "aws_api_gateway_authorizer" "jwt" {
  name                             = "${var.name_prefix}-jwt-authorizer"
  rest_api_id                      = aws_api_gateway_rest_api.this.id
  type                             = "TOKEN"
  identity_source                  = "method.request.header.Authorization"
  authorizer_uri                   = aws_lambda_function.authorizer.invoke_arn
  authorizer_result_ttl_in_seconds = 300
}

resource "aws_lambda_permission" "apigw_invoke_authorizer" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/authorizers/${aws_api_gateway_authorizer.jwt.id}"
}

# =============================================================================
# Protected routes: ANY /{proxy+} -> backend API, guarded by the authorizer
# =============================================================================

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "proxy_any" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy_any.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "${var.protected_backend_url}/{proxy}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# =============================================================================
# Deployment + stage
# =============================================================================

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  # Redeploy when any of the routing pieces change.
  triggers = {
    redeploy = sha1(jsonencode([
      aws_api_gateway_resource.auth.id,
      aws_api_gateway_method.auth_post.id,
      aws_api_gateway_integration.auth_post.id,
      aws_api_gateway_authorizer.jwt.id,
      aws_api_gateway_resource.proxy.id,
      aws_api_gateway_method.proxy_any.id,
      aws_api_gateway_integration.proxy_any.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.environment
}
