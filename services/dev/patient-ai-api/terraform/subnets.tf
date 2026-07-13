resource "aws_subnet" "public_a" {
  # checkov:skip=CKV_AWS_130:Public subnet for Internet-facing ALB

  vpc_id                  = aws_vpc.platform.id
  cidr_block              = "10.0.101.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = false

  tags = {
    Name        = "patient-ai-api-dev-public-a"
    Environment = "dev"
    Owner       = "healthcare"
    ManagedBy   = "platform-engineering-reference-architecture"
    Tier        = "public"
  }
}

resource "aws_subnet" "public_b" {
  # checkov:skip=CKV_AWS_130:Public subnet for Internet-facing ALB

  vpc_id                  = aws_vpc.platform.id
  cidr_block              = "10.0.102.0/24"
  availability_zone       = "eu-north-1b"
  map_public_ip_on_launch = false

  tags = {
    Name        = "patient-ai-api-dev-public-b"
    Environment = "dev"
    Owner       = "healthcare"
    ManagedBy   = "platform-engineering-reference-architecture"
    Tier        = "public"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.platform.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = false

  tags = {
    Name        = "patient-ai-api-dev-private-a"
    Environment = "dev"
    Owner       = "healthcare"
    ManagedBy   = "platform-engineering-reference-architecture"
    Tier        = "private"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.platform.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-north-1b"
  map_public_ip_on_launch = false

  tags = {
    Name        = "patient-ai-api-dev-private-b"
    Environment = "dev"
    Owner       = "healthcare"
    ManagedBy   = "platform-engineering-reference-architecture"
    Tier        = "private"
  }
}