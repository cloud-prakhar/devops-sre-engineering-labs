output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "azs" {
  description = "Availability zones used, in subnet order."
  value       = local.azs
}

output "public_subnet_ids" {
  description = "Public subnet IDs, one per AZ."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs, one per AZ."
  value       = aws_subnet.private[*].id
}

output "public_route_table_id" {
  description = "Route table shared by the public subnets."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Private route tables, one per AZ."
  value       = aws_route_table.private[*].id
}

output "web_security_group_id" {
  description = "Web tier SG (load balancers, proxies)."
  value       = aws_security_group.web.id
}

output "app_security_group_id" {
  description = "App tier SG."
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "Data tier SG."
  value       = aws_security_group.db.id
}

output "nat_mode" {
  description = "NAT strategy in use."
  value       = var.nat_mode
}

output "nat_public_ip" {
  description = "Public IP that private-subnet traffic leaves from (null when nat_mode = none)."
  value = (var.nat_mode == "gateway" ? aws_eip.nat[0].public_ip :
  var.nat_mode == "instance" ? aws_instance.nat[0].public_ip : null)
}

output "s3_endpoint_id" {
  description = "S3 gateway endpoint ID (null if disabled)."
  value       = var.enable_s3_gateway_endpoint ? aws_vpc_endpoint.s3[0].id : null
}
