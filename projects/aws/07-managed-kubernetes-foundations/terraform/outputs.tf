output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_version" {
  description = "Kubernetes version."
  value       = aws_eks_cluster.this.version
}

output "kubeconfig_command" {
  description = "Write a kubeconfig context for the admin principal."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.this.name} --alias lab07-admin"
}

output "developer_kubeconfig_command" {
  description = "Write a separate kubeconfig that authenticates as the developer role."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.this.name} --role-arn ${aws_iam_role.developer.arn} --alias lab07-developer --kubeconfig $HOME/.kube/lab07-developer"
}

output "developer_role_arn" {
  description = "IAM role mapped to Kubernetes group lab07-developers."
  value       = aws_iam_role.developer.arn
}

output "admin_principal_arn" {
  description = "Principal with the cluster-admin access entry."
  value       = local.admin_principal_arn
}

output "demo_parameter" {
  description = "SSM parameter the Pod Identity demo reads."
  value       = aws_ssm_parameter.demo.name
}

output "addon_versions" {
  description = "Managed add-on versions installed."
  value       = { for k, v in data.aws_eks_addon_version.this : k => v.version }
}

output "nat_public_ip" {
  description = "Egress IP of the nodes."
  value       = module.vpc.nat_public_ip
}
