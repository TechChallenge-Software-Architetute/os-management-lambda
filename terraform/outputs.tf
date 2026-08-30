# Consumed by the os-management-gateway repo via terraform_remote_state.

output "issuer_function_name" {
  description = "Name of the auth issuer Lambda."
  value       = aws_lambda_function.issuer.function_name
}

output "issuer_invoke_arn" {
  description = "Invoke ARN of the auth issuer Lambda (for API Gateway integration)."
  value       = aws_lambda_function.issuer.invoke_arn
}

output "authorizer_function_name" {
  description = "Name of the token authorizer Lambda."
  value       = aws_lambda_function.authorizer.function_name
}

output "authorizer_invoke_arn" {
  description = "Invoke ARN of the token authorizer Lambda (for API Gateway authorizer)."
  value       = aws_lambda_function.authorizer.invoke_arn
}
