resource "aws_acm_certificate" "platform" {
  domain_name       = "patient-ai-api."
  validation_method = "DNS"

  options {
    certificate_transparency_logging_preference = "ENABLED"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "patient-ai-api-dev-certificate"
    Environment = "dev"
    Owner       = "healthcare"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}