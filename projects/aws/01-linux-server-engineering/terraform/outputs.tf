output "instance_id" {
  description = "EC2 instance ID."
  value       = module.host.instance_id
}

output "public_ip" {
  description = "Public IPv4 address of the host."
  value       = module.host.public_ip
}

output "ssh_command" {
  description = "Log in as the default admin user."
  value       = "ssh ubuntu@${module.host.public_ip}"
}

output "tunnel_command" {
  description = "Forward the localhost-only API to your laptop, then open http://127.0.0.1:8000/api/info."
  value       = "ssh -N -L 8000:127.0.0.1:8000 ubuntu@${module.host.public_ip}"
}

output "ssm_command" {
  description = "Shell without SSH (needs the Session Manager plugin)."
  value       = "aws ssm start-session --region ${var.aws_region} --target ${module.host.instance_id}"
}
