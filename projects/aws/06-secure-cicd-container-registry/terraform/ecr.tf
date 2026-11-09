# Private registry for the Taskboard API image.
resource "aws_ecr_repository" "app" {
  name = "lab06/taskboard-api"
  # Immutable tags: once :<git-sha> is pushed it can never point at different content.
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.force_delete_repository

  # Basic scanning on push (no charge). The pipeline also scans before pushing; this catches
  # vulnerabilities in images that reach the registry by other means.
  image_scanning_configuration {
    scan_on_push = true
  }

  #trivy:ignore:AWS-0033 AES256 (SSE-S3 equivalent) instead of a customer-managed KMS key to avoid KMS charges.
  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Untagged images (e.g. attestation leftovers) expire after 1 day"
        selection    = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 1 }
        action       = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep the newest ${var.image_retention_count} tagged images"
        selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = var.image_retention_count }
        action       = { type = "expire" }
      }
    ]
  })
}
