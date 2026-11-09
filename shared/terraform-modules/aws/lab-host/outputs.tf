output "instance_id" {
  description = "EC2 instance ID (use with aws ssm start-session)."
  value       = aws_instance.host.id
}

output "public_ip" {
  description = "Public IPv4 address. Changes if the instance is stopped and started."
  value       = aws_instance.host.public_ip
}

output "private_ip" {
  description = "Private IPv4 address inside the VPC."
  value       = aws_instance.host.private_ip
}

output "security_group_id" {
  description = "Host security group ID."
  value       = aws_security_group.host.id
}

output "ami_id" {
  description = "Ubuntu 24.04 AMI used at creation time."
  value       = aws_instance.host.ami
}
