# Network: the shared vpc module (AWS 04). Nodes live in private subnets and need egress for image
# pulls, so NAT is required here; the default is the free-tier NAT instance (see ADR-0002).
module "vpc" {
  source   = "../../../../shared/terraform-modules/aws/vpc"
  name     = var.cluster_name
  cidr     = "10.70.0.0/16"
  az_count = 2
  nat_mode = var.nat_mode
  # Tags the AWS Load Balancer Controller uses to pick subnets (used from AWS 08 on).
  public_subnet_tags  = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }
}

data "aws_caller_identity" "current" {}

# For assumed-role sessions the caller ARN is a session; access entries need the role ARN.
data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

locals {
  admin_principal_arn = var.admin_principal_arn != "" ? var.admin_principal_arn : data.aws_iam_session_context.current.issuer_arn
}
