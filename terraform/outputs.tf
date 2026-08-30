output "api_base_url" {
  description = "Base invoke URL for the API stage."
  value       = aws_api_gateway_stage.this.invoke_url
}

output "auth_endpoint" {
  description = "Full URL of the CPF authentication endpoint."
  value       = "${aws_api_gateway_stage.this.invoke_url}/auth"
}

output "issuer_function_name" {
  value = aws_lambda_function.issuer.function_name
}

output "authorizer_function_name" {
  value = aws_lambda_function.authorizer.function_name
}
