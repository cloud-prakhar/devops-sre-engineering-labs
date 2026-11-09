output "alb_dns_name" {
  description = "Load balancer DNS name."
  value       = aws_lb.this.dns_name
}

output "app_url" {
  description = "Taskboard API through the load balancer."
  value       = "http://${aws_lb.this.dns_name}/api/info"
}

output "asg_name" {
  description = "Auto Scaling group name."
  value       = aws_autoscaling_group.app.name
}

output "target_group_arn" {
  description = "Target group ARN (for health checks)."
  value       = aws_lb_target_group.app.arn
}

output "db_address" {
  description = "RDS endpoint (private; reachable only from the app SG)."
  value       = aws_db_instance.this.address
}

output "db_identifier" {
  description = "RDS instance identifier."
  value       = aws_db_instance.this.identifier
}

output "db_password_parameter" {
  description = "SSM parameter holding the DB password (value never in Terraform state)."
  value       = aws_ssm_parameter.db_password.name
}

output "azs" {
  description = "AZs used."
  value       = module.vpc.azs
}
