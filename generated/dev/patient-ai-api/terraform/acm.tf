resource "aws_acm_certificate" "platform" {
  domain_name       = "*.dev.platform.example.com"
  validation_method = "DNS"

  tags = {
    Environment = "dev"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}