
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.platform.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-north-1a"

  tags = {
    Name = "dev-private-a"
    Type = "private"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.platform.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-north-1b"

  tags = {
    Name = "dev-private-b"
    Type = "private"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.platform.id
  cidr_block              = "10.0.101.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "dev-public-a"
    Type = "public"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.platform.id
  cidr_block              = "10.0.102.0/24"
  availability_zone       = "eu-north-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "dev-public-b"
    Type = "public"
  }
}
