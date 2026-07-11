resource "aws_security_group" "eks_cluster" {
  name        = "dev-eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.platform.id

  tags = {
    Environment = "dev"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}