locals {
  name = "lab05-ha"
}

# Same reusable network as AWS 04, in its own VPC so the labs can be deployed independently.
# nat_mode = none: the app tier sits in public subnets with inbound allowed only from the load
# balancer (see docs/adr/0001-public-app-subnets-without-nat.md); the database is in private subnets.
module "vpc" {
  source            = "../../../../shared/terraform-modules/aws/vpc"
  name              = local.name
  cidr              = "10.50.0.0/16"
  az_count          = 2
  nat_mode          = "none"
  web_ingress_cidrs = var.allowed_http_cidrs
  app_port          = 8000
  db_port           = 5432
}
