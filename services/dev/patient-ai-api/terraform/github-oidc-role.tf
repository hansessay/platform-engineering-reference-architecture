resource "aws_iam_role" "patient_ai_api_github_actions_role" {
  name = "patient-ai-api-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }

          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:hansessay/platform-engineering-reference-architecture:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  tags = {
    Environment = "dev"
    Owner       = "healthcare"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}

#checkov:skip=CKV_AWS_355:ecr:GetAuthorizationToken requires Resource "*"
resource "aws_iam_role_policy" "patient_ai_api_ecr_push_policy" {

  name = "patient-ai-api-ecr-push-policy"
  role = aws_iam_role.patient_ai_api_github_actions_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      {
        Sid    = "ECRAuthentication"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },

      {
        Sid    = "PushToApplicationRepository"
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]

        Resource = aws_ecr_repository.patient_ai_api.arn
      }
    ]
  })
}