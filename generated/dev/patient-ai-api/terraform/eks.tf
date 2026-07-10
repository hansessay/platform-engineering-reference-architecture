resource "aws_eks_cluster" "dev_platform_cluster" {
  name     = "dev-platform-eks"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }

    resources = ["secrets"]
  }

  tags = {
    Environment = "dev"
    Owner       = "healthcare-platform"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}

resource "aws_eks_node_group" "dev_platform_nodes" {
  cluster_name    = aws_eks_cluster.dev_platform_cluster.name
  node_group_name = "dev-platform-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 5
  }

  instance_types = ["t3.medium"]

  tags = {
    Environment = "dev"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}
