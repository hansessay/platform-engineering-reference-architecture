resource "aws_vpc" "platform" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "dev-platform-vpc"
    Environment = "dev"
    Owner       = "healthcare"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}

resource "aws_default_security_group" "platform_default" {
  vpc_id = aws_vpc.platform.id

  ingress = []
  egress  = []

  tags = {
    Name        = "dev-platform-default-deny"
    Environment = "dev"
    Owner       = "healthcare"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}