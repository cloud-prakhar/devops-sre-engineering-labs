# Free-tier single Linux host for AWS labs 01-03.
# Safe defaults: IMDSv2 only, encrypted gp3 root volume, no unlimited CPU credits,
# SSH limited to operator CIDRs, egress limited to HTTP/HTTPS, SSM Session Manager as a
# no-open-port fallback.

locals {
  # t4g = Graviton (arm64); everything else in the allowed list is x86_64.
  arch = startswith(var.instance_type, "t4g.") ? "arm64" : "amd64"
  # Canonical publishes the current Ubuntu 24.04 LTS AMI ID as a public SSM parameter,
  # so the AMI is always the latest patched build for the selected region.
  ami_parameter = "/aws/service/canonical/ubuntu/server/24.04/stable/current/${local.arch}/hvm/ebs-gp3/ami-id"
}

data "aws_ssm_parameter" "ubuntu_ami" {
  name = local.ami_parameter
}

resource "aws_key_pair" "this" {
  key_name   = "${var.name}-key"
  public_key = var.ssh_public_key
}

resource "aws_security_group" "host" {
  name        = "${var.name}-host-sg"
  description = "Lab host: SSH and app ports from operator CIDRs only"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-host-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each          = toset(var.allowed_ssh_cidrs)
  security_group_id = aws_security_group.host.id
  description       = "SSH from operator"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "ssh_from_sg" {
  for_each                     = toset(var.ssh_source_security_group_ids)
  security_group_id            = aws_security_group.host.id
  description                  = "SSH from a trusted security group"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = each.value
}

resource "aws_vpc_security_group_ingress_rule" "app" {
  for_each = {
    for rule in flatten([
      for p in var.app_ingress : [for c in p.cidrs : { port = p.port, cidr = c, description = p.description }]
    ]) : "${rule.port}-${rule.cidr}" => rule
  }
  security_group_id = aws_security_group.host.id
  description       = each.value.description
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
  cidr_ipv4         = each.value.cidr
}

# Egress is limited to the ports package managers, container registries and the SSM agent
# need. DNS (VPC resolver) and NTP (169.254.169.123) are link-local services that security
# groups do not filter, so they keep working.
#trivy:ignore:AVD-AWS-0104 Destinations (apt mirrors, registries, SSM endpoints) are not fixed IPs; ports are restricted instead.
resource "aws_vpc_security_group_egress_rule" "web" {
  for_each          = toset(["80", "443"])
  security_group_id = aws_security_group.host.id
  description       = "Outbound HTTP/HTTPS for packages, registries and SSM"
  ip_protocol       = "tcp"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  cidr_ipv4         = "0.0.0.0/0"
}

data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "host" {
  name               = "${var.name}-host-role"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

# Only what Session Manager needs; the instance gets no other AWS API access.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.host.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "host" {
  name = "${var.name}-host-profile"
  role = aws_iam_role.host.name
}

resource "aws_instance" "host" {
  ami                         = data.aws_ssm_parameter.ubuntu_ami.insecure_value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.host.id]
  key_name                    = aws_key_pair.this.key_name
  iam_instance_profile        = aws_iam_instance_profile.host.name
  associate_public_ip_address = var.associate_public_ip
  user_data_base64            = var.user_data_base64
  user_data_replace_on_change = true
  # Detailed (1-minute) monitoring is billed; basic 5-minute metrics are free.
  monitoring = false

  # "unlimited" (the T3 default) can bill surplus CPU credits. "standard" throttles instead,
  # which is the safe choice for free-tier labs.
  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 only: blocks SSRF-style credential theft via IMDSv1
    # Hop limit 1: containers on a bridge network cannot reach instance credentials.
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_gb
    encrypted             = true
    delete_on_termination = true
  }

  lifecycle {
    # A new Canonical AMI must not silently replace a running lab host.
    ignore_changes = [ami]
  }

  tags = { Name = "${var.name}-host" }
}
