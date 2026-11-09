output "ecr_repository_url" {
  description = "ECR repository URL (images are pushed as <url>:<git-sha> and deployed by digest)."
  value       = aws_ecr_repository.app.repository_url
}

output "push_role_arn" {
  description = "Role the release job assumes via OIDC."
  value       = aws_iam_role.push.arn
}

output "deploy_role_arn" {
  description = "Role the deploy job assumes via OIDC."
  value       = aws_iam_role.deploy.arn
}

output "instance_id" {
  description = "Deploy host instance ID (SSM target)."
  value       = module.host.instance_id
}

output "app_url" {
  description = "Taskboard on the deploy host (reachable from allowed_http_cidrs)."
  value       = "http://${module.host.public_ip}/api/info"
}

output "github_variables" {
  description = "Repository variables the workflow reads (scripts/configure-github.sh sets them)."
  value = {
    AWS06_ENABLED            = "true"
    AWS06_REGION             = var.aws_region
    AWS06_ECR_REPOSITORY_URL = aws_ecr_repository.app.repository_url
    AWS06_PUSH_ROLE_ARN      = aws_iam_role.push.arn
    AWS06_DEPLOY_ROLE_ARN    = aws_iam_role.deploy.arn
    AWS06_INSTANCE_ID        = module.host.instance_id
  }
}
