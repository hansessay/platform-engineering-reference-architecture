resource "aws_kms_key" "eks" {
  description             = "dev EKS secrets encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Environment = "dev"
    Owner       = "healthcare"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/dev-eks-secrets"
  target_key_id = aws_kms_key.eks.key_id
}