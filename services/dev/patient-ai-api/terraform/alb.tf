
data "aws_caller_identity" "alb_current" {}

resource "aws_security_group" "alb" {
  name        = "dev-platform-alb-sg"
  description = "Security group for the platform Application Load Balancer"
  vpc_id      = aws_vpc.platform.id

  ingress {
    description = "Allow HTTPS inbound traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow HTTPS outbound traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "dev-platform-alb-sg"
    Environment = "dev"
    Owner       = "healthcare"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}

###############################################################################
# ALB access-log S3 bucket
###############################################################################

resource "aws_s3_bucket" "alb_logs" {
  # checkov:skip=CKV_AWS_145:ALB access logs use AWS-supported SSE-S3 encryption
  # checkov:skip=CKV2_AWS_62:Event notifications are not required for this dedicated ALB access-log archive bucket
  # checkov:skip=CKV_AWS_18:Enabling server access logging on the ALB log bucket would create recursive log delivery
  # checkov:skip=CKV_AWS_144:Cross-region replication is intentionally excluded from the single-region reference architecture

  bucket_prefix = "dev-platform-alb-logs-"
  force_destroy = false

  tags = {
    Name        = "dev-platform-alb-logs"
    Environment = "dev"
    Owner       = "healthcare"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "alb-log-retention"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

data "aws_iam_policy_document" "alb_logs" {
  statement {
    sid    = "AllowELBLogDelivery"
    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "logdelivery.elasticloadbalancing.amazonaws.com"
      ]
    }

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.alb_logs.arn}/AWSLogs/${data.aws_caller_identity.alb_current.account_id}/*"
    ]
  }

  statement {
    sid    = "AllowELBLogDeliveryAclCheck"
    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "logdelivery.elasticloadbalancing.amazonaws.com"
      ]
    }

    actions = [
      "s3:GetBucketAcl"
    ]

    resources = [
      aws_s3_bucket.alb_logs.arn
    ]
  }

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type = "*"

      identifiers = [
        "*"
      ]
    }

    actions = [
      "s3:*"
    ]

    resources = [
      aws_s3_bucket.alb_logs.arn,
      "${aws_s3_bucket.alb_logs.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"

      values = [
        "false"
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = data.aws_iam_policy_document.alb_logs.json

  depends_on = [
    aws_s3_bucket_public_access_block.alb_logs,
    aws_s3_bucket_ownership_controls.alb_logs
  ]
}

###############################################################################
# Application Load Balancer
###############################################################################

resource "aws_lb" "platform" {
  # checkov:skip=CKV2_AWS_76:AWSManagedRulesKnownBadInputsRuleSet is attached through the associated WAFv2 WebACL for Log4j protection

  name               = "dev-platform-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  enable_deletion_protection = true
  drop_invalid_header_fields = true

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "dev-platform-alb"
    enabled = true
  }

  depends_on = [
    aws_s3_bucket_policy.alb_logs
  ]

  tags = {
    Name        = "dev-platform-alb"
    Environment = "dev"
    Owner       = "healthcare"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}

###############################################################################
# AWS WAF
###############################################################################

resource "aws_wafv2_web_acl" "platform" {
  name        = "dev-platform-waf"
  description = "Web ACL protecting the platform Application Load Balancer"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "dev-platform-common-rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "dev-platform-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "dev-platform-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "dev-platform-waf"
    Environment = "dev"
    Owner       = "healthcare"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}

resource "aws_wafv2_web_acl_association" "platform" {
  resource_arn = aws_lb.platform.arn
  web_acl_arn  = aws_wafv2_web_acl.platform.arn
}

###############################################################################
# AWS WAF logging
###############################################################################

resource "aws_cloudwatch_log_group" "waf" {
  # checkov:skip=CKV_AWS_158:WAF logging is enabled and the reference architecture uses service-managed encryption

  name              = "aws-waf-logs-dev-platform"
  retention_in_days = 365

  tags = {
    Name        = "dev-platform-waf-logs"
    Environment = "dev"
    Owner       = "healthcare"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "platform" {
  resource_arn = aws_wafv2_web_acl.platform.arn

  log_destination_configs = [
    aws_cloudwatch_log_group.waf.arn
  ]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.waf
  ]
}
