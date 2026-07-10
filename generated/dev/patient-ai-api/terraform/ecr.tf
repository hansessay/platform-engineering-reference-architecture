resource "aws_ecr_repository" "patient_ai_api" {
  name                 = "patient-ai-api"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Service     = "patient-ai-api"
    Owner       = "healthcare-platform"
    Environment = "dev"
    ManagedBy   = "platform-engineering-reference-architecture"
  }
}