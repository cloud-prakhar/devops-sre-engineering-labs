output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "azs" {
  description = "AZs in use."
  value       = module.vpc.azs
}

output "public_subnet_ids" {
  description = "Public subnets."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnets."
  value       = module.vpc.private_subnet_ids
}

output "private_route_table_ids" {
  description = "Private route tables."
  value       = module.vpc.private_route_table_ids
}

output "security_groups" {
  description = "Tiered security group IDs."
  value = {
    web = module.vpc.web_security_group_id
    app = module.vpc.app_security_group_id
    db  = module.vpc.db_security_group_id
  }
}

output "nat_mode" {
  description = "NAT strategy in use."
  value       = module.vpc.nat_mode
}

output "nat_public_ip" {
  description = "Egress IP for private subnets (null when nat_mode = none)."
  value       = module.vpc.nat_public_ip
}

output "bastion_public_ip" {
  description = "Bastion public IP (null without test hosts)."
  value       = var.enable_test_hosts ? module.bastion[0].public_ip : null
}

output "private_host_ip" {
  description = "Private host IP (null without test hosts)."
  value       = var.enable_test_hosts ? module.private_host[0].private_ip : null
}

output "ssh_private_host_command" {
  description = "SSH to the private host through the bastion."
  value       = var.enable_test_hosts ? "ssh -J ubuntu@${module.bastion[0].public_ip} ubuntu@${module.private_host[0].private_ip}" : null
}
