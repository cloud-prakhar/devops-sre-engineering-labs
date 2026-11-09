# Minimal free-tier network for single-host labs (AWS projects 01-03).
# One VPC, one public subnet, an Internet Gateway and a route table.
# Deliberately NO NAT Gateway: it is billed per hour and per GB and is never free.
# Project 04 replaces this with a full public/private, multi-AZ foundation.

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az = coalesce(var.availability_zone, data.aws_availability_zones.available.names[0])
}

#trivy:ignore:AVD-AWS-0178 Flow logs are billed (CloudWatch ingestion + storage); enabled in project 04 and later.
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.name}-vpc" }
}

# Remove every rule from the default security group so nothing can accidentally use it.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-default-sg-locked" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = local.az
  # Public IPs are requested per instance instead, so nothing launched here gets one by accident.
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.name}-public-${local.az}", Tier = "public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-public-rt" }
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
