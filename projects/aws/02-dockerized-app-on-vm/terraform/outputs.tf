output "instance_id" {
  description = "EC2 instance ID."
  value       = module.host.instance_id
}

output "public_ip" {
  description = "Public IPv4 address."
  value       = module.host.public_ip
}

output "app_url" {
  description = "Taskboard API through the published container port."
  value       = "http://${module.host.public_ip}/api/info"
}

output "docker_host" {
  description = "export DOCKER_HOST=<this> to run docker commands against the VM over SSH."
  value       = "ssh://ubuntu@${module.host.public_ip}"
}

output "ssm_command" {
  description = "Shell without SSH."
  value       = "aws ssm start-session --region ${var.aws_region} --target ${module.host.instance_id}"
}
