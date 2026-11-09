# Multi-AZ VPC foundation: public + private subnet per AZ, tiered security groups, a stateless NACL
# for the private tier, an S3 gateway endpoint, and a selectable NAT strategy.

data "aws_availability_zones" "available" {
  state = "available"
  # Exclude Local Zones / Wavelength: they have different service availability and pricing.
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_region" "current" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  # 10.40.0.0/24, 10.40.1.0/24, ... public ; 10.40.10.0/24, 10.40.11.0/24, ... private
  public_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.cidr, 24 - tonumber(split("/", var.cidr)[1]), i)]
  private_cidrs = [for i in range(var.az_count) : cidrsubnet(var.cidr, 24 - tonumber(split("/", var.cidr)[1]), 10 + i)]
}

#trivy:ignore:AVD-AWS-0178 Flow logs are billed per GB ingested; covered by the observability labs.
resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.name}-vpc" }
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-default-sg-locked" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-igw" }
}

# ---------------------------------------------------------------- subnets and routing

resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false
  tags                    = merge({ Name = "${var.name}-public-${local.azs[count.index]}", Tier = "public" }, var.public_subnet_tags)
}

resource "aws_subnet" "private" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_cidrs[count.index]
  availability_zone = local.azs[count.index]
  tags              = merge({ Name = "${var.name}-private-${local.azs[count.index]}", Tier = "private" }, var.private_subnet_tags)
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-public-rt" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# One private route table per AZ: with a NAT per AZ (production) each table points at its own
# AZ's NAT. This lab uses at most one NAT, so all tables share it — see the ADR for the tradeoff.
resource "aws_route_table" "private" {
  count  = var.az_count
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-private-rt-${local.azs[count.index]}" }
}

resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_vpc_endpoint" "s3" {
  count             = var.enable_s3_gateway_endpoint ? 1 : 0
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id
  tags              = { Name = "${var.name}-s3-gateway" }
}

# ---------------------------------------------------------------- NAT

resource "aws_eip" "nat" {
  count  = var.nat_mode == "gateway" ? 1 : 0
  domain = "vpc"
  tags   = { Name = "${var.name}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  count         = var.nat_mode == "gateway" ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${var.name}-natgw" }
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_route" "private_nat_gateway" {
  count                  = var.nat_mode == "gateway" ? var.az_count : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

data "aws_ssm_parameter" "ubuntu_ami" {
  count = var.nat_mode == "instance" ? 1 : 0
  name  = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_security_group" "nat" {
  count       = var.nat_mode == "instance" ? 1 : 0
  name        = "${var.name}-nat-sg"
  description = "NAT instance: forward traffic from private subnets"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.name}-nat-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "nat_from_private" {
  count             = var.nat_mode == "instance" ? var.az_count : 0
  security_group_id = aws_security_group.nat[0].id
  description       = "All traffic from private subnet ${local.private_cidrs[count.index]}"
  ip_protocol       = "-1"
  cidr_ipv4         = local.private_cidrs[count.index]
}

#trivy:ignore:AVD-AWS-0104 A NAT forwards traffic to arbitrary internet destinations by design.
resource "aws_vpc_security_group_egress_rule" "nat_out" {
  count             = var.nat_mode == "instance" ? 1 : 0
  security_group_id = aws_security_group.nat[0].id
  description       = "Forwarded traffic to the internet"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_instance" "nat" {
  count                       = var.nat_mode == "instance" ? 1 : 0
  ami                         = data.aws_ssm_parameter.ubuntu_ami[0].insecure_value
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.nat[0].id]
  associate_public_ip_address = true
  # A NAT receives packets addressed to other hosts; EC2 drops those unless this is off.
  source_dest_check           = false
  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/nat-instance.yaml.tftpl", {
    vpc_cidr = var.cidr
  })
  monitoring = false

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  lifecycle {
    ignore_changes = [ami]
  }

  tags = { Name = "${var.name}-nat-instance" }
}

resource "aws_route" "private_nat_instance" {
  count                  = var.nat_mode == "instance" ? var.az_count : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat[0].primary_network_interface_id
}

# ---------------------------------------------------------------- NACL for the private tier
# Stateless: return traffic must be allowed explicitly (ephemeral ports), unlike security groups.

resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = aws_subnet.private[*].id
  tags       = { Name = "${var.name}-private-nacl" }
}

#trivy:ignore:AWS-0102 Coarse backstop by design: any protocol, but only from inside the VPC; security groups are the primary control (AWS 04 ADR-0003).
resource "aws_network_acl_rule" "private_in_vpc" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.cidr
}

#trivy:ignore:AVD-AWS-0105 Return traffic for outbound connections (NAT, S3 endpoint) arrives from public IPs on ephemeral ports.
resource "aws_network_acl_rule" "private_in_ephemeral" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 200
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

#trivy:ignore:AWS-0102 Outbound is filtered statefully by security groups; a stateless egress filter here would break replies (AWS 04 ADR-0003).
resource "aws_network_acl_rule" "private_out_all" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

# ---------------------------------------------------------------- tiered security groups
# web <- internet (web_ingress_cidrs) ; app <- web only ; db <- app only.
# Rules reference security groups, not IP ranges, so they stay correct as instances come and go.

resource "aws_security_group" "web" {
  name        = "${var.name}-web-sg"
  description = "Web tier (load balancer / proxy)"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.name}-web-sg", Tier = "web" }
}

resource "aws_security_group" "app" {
  name        = "${var.name}-app-sg"
  description = "App tier: only from the web tier"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.name}-app-sg", Tier = "app" }
}

resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "Data tier: only from the app tier"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.name}-db-sg", Tier = "db" }
}

resource "aws_vpc_security_group_ingress_rule" "web_in" {
  for_each = { for pair in setproduct(var.web_ingress_cidrs, [80, 443]) : "${pair[0]}-${pair[1]}" => pair }

  security_group_id = aws_security_group.web.id
  description       = "HTTP(S) from allowed clients"
  ip_protocol       = "tcp"
  from_port         = each.value[1]
  to_port           = each.value[1]
  cidr_ipv4         = each.value[0]
}

resource "aws_vpc_security_group_egress_rule" "web_to_app" {
  security_group_id            = aws_security_group.web.id
  description                  = "To app tier"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_ingress_rule" "app_from_web" {
  security_group_id            = aws_security_group.app.id
  description                  = "From web tier"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.web.id
}

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id            = aws_security_group.app.id
  description                  = "To data tier"
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
  referenced_security_group_id = aws_security_group.db.id
}

#trivy:ignore:AVD-AWS-0104 App hosts fetch packages and call AWS APIs over HTTPS; destinations are not fixed IPs.
resource "aws_vpc_security_group_egress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS for packages and AWS APIs"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

#trivy:ignore:AVD-AWS-0104 Ubuntu package mirrors are served over HTTP (packages are GPG-signed).
resource "aws_vpc_security_group_egress_rule" "app_http" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP for signed apt packages"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "From app tier"
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
  referenced_security_group_id = aws_security_group.app.id
}
