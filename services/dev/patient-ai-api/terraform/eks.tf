resource "aws_eks_cluster" "dev_platform_cluster" {
  name     = "dev-platform-eks"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    endpoint_private_access = true
    endpoint_public_access  = false
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }

    resources = ["secrets"]
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Environment = "dev"
    Owner       = "healthcare"
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

  update_config {
    max_unavailable = 1
  }

  instance_types = ["t3.medium"]
  capacity_type  = "ON_DEMAND"
  disk_size      = 50

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_readonly_policy
  ]

  tags = {
    Environment = "dev"
    Owner       = "healthcare"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}