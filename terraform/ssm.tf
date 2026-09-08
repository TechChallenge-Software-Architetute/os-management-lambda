# =============================================================================
# Cross-repo contract — values other repos (app, docs, Bruno) consume.
#
# Published under /os-management/<env>/... so the app team can wire the main
# application against the same JWT contract and gateway URL without a shared
# Terraform state.
# =============================================================================

resource "aws_ssm_parameter" "api_base_url" {
  count = var.publish_ssm_outputs ? 1 : 0
  name  = "/os-management/${var.environment}/api/base_url"
  type  = "String"
  value = aws_apigatewayv2_stage.this.invoke_url
}

resource "aws_ssm_parameter" "jwt_issuer" {
  count = var.publish_ssm_outputs ? 1 : 0
  name  = "/os-management/${var.environment}/auth/jwt_issuer"
  type  = "String"
  value = var.jwt_issuer
}

resource "aws_ssm_parameter" "jwt_audience" {
  count = var.publish_ssm_outputs ? 1 : 0
  name  = "/os-management/${var.environment}/auth/jwt_audience"
  type  = "String"
  value = var.jwt_audience
}
