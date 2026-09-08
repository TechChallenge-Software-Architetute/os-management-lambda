# =============================================================================
# API Gateway
# =============================================================================

output "api_id" {
  description = "ID of the HTTP API."
  value       = aws_apigatewayv2_api.this.id
}

output "api_base_url" {
  description = "Base invoke URL of the deployed API Gateway stage."
  value       = aws_apigatewayv2_stage.this.invoke_url
}

output "auth_endpoint" {
  description = "Full URL of the CPF authentication endpoint (POST)."
  value       = "${aws_apigatewayv2_stage.this.invoke_url}/auth"
}

# =============================================================================
# Lambda (kept for debugging / manual wiring)
# =============================================================================

output "issuer_function_name" {
  description = "Name of the auth issuer Lambda."
  value       = aws_lambda_function.issuer.function_name
}

output "authorizer_function_name" {
  description = "Name of the token authorizer Lambda."
  value       = aws_lambda_function.authorizer.function_name
}
