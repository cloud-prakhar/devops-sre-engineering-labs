output "instance_id" {
  description = "EC2 instance ID."
  value       = module.host.instance_id
}

output "public_ip" {
  description = "Public IPv4 address."
  value       = module.host.public_ip
}

output "app_url" {
  description = "Taskboard through the TLS proxy (self-signed certificate: expect a browser warning)."
  value       = "https://${module.host.public_ip}/"
}

output "ssh_command" {
  description = "Log in to the host; the stack lives in /opt/lab03."
  value       = "ssh ubuntu@${module.host.public_ip}"
}

output "ssm_command" {
  description = "Shell without SSH."
  value       = "aws ssm start-session --region ${var.aws_region} --target ${module.host.instance_id}"
}
