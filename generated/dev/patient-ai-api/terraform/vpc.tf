resource "aws_vpc" "platform" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "dev-platform-vpc"
    Environment = "dev"
    Owner       = "healthcare-platform"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}