locals {
  name = "lab04-net"
  # Empty when the file is missing; the lab-host module's validation then explains the problem.
  ssh_public_key = fileexists(pathexpand(var.ssh_public_key_path)) ? trimspace(file(pathexpand(var.ssh_public_key_path))) : ""
  # Test hosts need nothing installed. Keeping user data package-free matters for the private
  # host: with nat_mode = "none" it has no route to package mirrors.
  # Rendered and schema-checked by scripts/validate.sh cloudinit.
  user_data = <<-EOT
    #cloud-config
    package_update: false
    package_upgrade: false
    final_message: "lab04 test host ready after $UPTIME seconds"
  EOT
}

module "vpc" {
  source            = "../../../../../shared/terraform-modules/aws/vpc"
  name              = local.name
  cidr              = var.vpc_cidr
  az_count          = var.az_count
  nat_mode          = var.nat_mode
  web_ingress_cidrs = var.allowed_ssh_cidrs
}

# Public bastion in AZ 1: the only host reachable from the internet (SSH from your IP).
module "bastion" {
  count             = var.enable_test_hosts ? 1 : 0
  source            = "../../../../../shared/terraform-modules/aws/lab-host"
  name              = "${local.name}-bastion"
  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.public_subnet_ids[0]
  ssh_public_key    = local.ssh_public_key
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
  root_volume_gb    = 8
  user_data_base64  = base64encode(local.user_data)
}

# Private host in the LAST AZ, so the bastion -> private path crosses AZs inside the VPC.
module "private_host" {
  count                         = var.enable_test_hosts ? 1 : 0
  source                        = "../../../../../shared/terraform-modules/aws/lab-host"
  name                          = "${local.name}-private"
  vpc_id                        = module.vpc.vpc_id
  subnet_id                     = module.vpc.private_subnet_ids[var.az_count - 1]
  associate_public_ip           = false
  ssh_public_key                = local.ssh_public_key
  allowed_ssh_cidrs             = []
  ssh_source_security_group_ids = [module.bastion[0].security_group_id]
  root_volume_gb                = 8
  user_data_base64              = base64encode(local.user_data)
}
