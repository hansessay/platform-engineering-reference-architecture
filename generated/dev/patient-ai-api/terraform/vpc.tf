
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

data "aws_caller_identity" "vpc_flow_logs_current" {}

data "aws_region" "vpc_flow_logs_current" {}

data "aws_iam_policy_document" "vpc_flow_logs_kms" {
  # checkov:skip=CKV_AWS_109:KMS key policies require broad permissions for the account root principal
  # checkov:skip=CKV_AWS_111:KMS key policies require write permissions for key administration and CloudWatch Logs encryption
  # checkov:skip=CKV_AWS_356:AWS KMS key policies require Resource wildcard because the policy applies directly to the key

  statement {
    sid    = "EnableRootAccountPermissions"
    effect = "Allow"

    principals {
      type = "AWS"

      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.vpc_flow_logs_current.account_id}:root"
      ]
    }

    actions = [
      "kms:*"
    ]

    resources = [
      "*"
    ]
  }

  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "logs.${data.aws_region.vpc_flow_logs_current.region}.amazonaws.com"
      ]
    }

    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]

    resources = [
      "*"
    ]

    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"

      values = [
        "arn:aws:logs:${data.aws_region.vpc_flow_logs_current.region}:${data.aws_caller_identity.vpc_flow_logs_current.account_id}:log-group:/aws/vpc/dev-platform-flow-logs"
      ]
    }
  }
}

resource "aws_kms_key" "vpc_flow_logs" {
  description             = "KMS key for dev VPC flow logs"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.vpc_flow_logs_kms.json

  tags = {
    Name        = "dev-platform-vpc-flow-logs-kms"
    Environment = "dev"
    Owner       = "healthcare"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}

resource "aws_kms_alias" "vpc_flow_logs" {
  name          = "alias/dev-platform-vpc-flow-logs"
  target_key_id = aws_kms_key.vpc_flow_logs.key_id
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/dev-platform-flow-logs"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.vpc_flow_logs.arn

  tags = {
    Name        = "dev-platform-vpc-flow-logs"
    Environment = "dev"
    Owner       = "healthcare"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}

data "aws_iam_policy_document" "vpc_flow_logs_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "vpc-flow-logs.amazonaws.com"
      ]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "dev-platform-vpc-flow-logs-role"

  assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume_role.json

  tags = {
    Name        = "dev-platform-vpc-flow-logs-role"
    Environment = "dev"
    Owner       = "healthcare"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}

data "aws_iam_policy_document" "vpc_flow_logs" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]

    resources = [
      "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
    ]
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name   = "dev-platform-vpc-flow-logs-policy"
  role   = aws_iam_role.vpc_flow_logs.id
  policy = data.aws_iam_policy_document.vpc_flow_logs.json
}

resource "aws_flow_log" "platform" {
  vpc_id               = aws_vpc.platform.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn

  max_aggregation_interval = 60

  depends_on = [
    aws_iam_role_policy.vpc_flow_logs
  ]

  tags = {
    Name        = "dev-platform-vpc-flow-log"
    Environment = "dev"
    Owner       = "healthcare"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}

