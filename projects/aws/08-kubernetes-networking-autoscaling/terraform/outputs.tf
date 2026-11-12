output "cluster_name" {
  description = "EKS cluster the controller runs in."
  value       = data.aws_eks_cluster.this.name
}

output "vpc_id" {
  description = "Cluster VPC (passed to the controller's Helm values)."
  value       = data.aws_eks_cluster.this.vpc_config[0].vpc_id
}

output "region" {
  description = "AWS region."
  value       = var.aws_region
}

output "controller_role_arn" {
  description = "IAM role the controller receives through Pod Identity."
  value       = aws_iam_role.lbc.arn
}
