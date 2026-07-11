resource "aws_route53_zone" "platform" {
  name = "dev.platform.example.com"

  tags = {
    Environment = "dev"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}