locals {
  # Empty when the file is missing; the lab-host module's validation then explains the problem.
  ssh_public_key = fileexists(pathexpand(var.ssh_public_key_path)) ? trimspace(file(pathexpand(var.ssh_public_key_path))) : ""
  name           = "lab01-linux"

  # Files are shipped base64-encoded so their exact bytes (permissions-sensitive configs,
  # scripts) survive YAML templating untouched.
  host_files = {
    sshd_hardening    = filebase64("${path.module}/../files/10-lab-hardening.conf")
    journald          = filebase64("${path.module}/../files/journald-lab.conf")
    unattended        = filebase64("${path.module}/../files/52-lab-unattended-upgrades")
    taskboard_service = filebase64("${path.module}/../../../../shared/linux-service/taskboard.service")
    host_audit        = filebase64("${path.module}/../files/host-audit.sh")
    lab_fault         = filebase64("${path.module}/../files/lab-fault.sh")
    install_taskboard = filebase64("${path.module}/../../../../shared/linux-service/install-taskboard.sh")
  }
}

locals {
  # Rendered cloud-init document. scripts/validate.sh cloudinit renders this local and checks it
  # against cloud-init's schema, so keep the name.
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", local.host_files)
}

module "network" {
  source = "../../../../shared/terraform-modules/aws/lab-network"
  name   = local.name
}

module "host" {
  source            = "../../../../shared/terraform-modules/aws/lab-host"
  name              = local.name
  vpc_id            = module.network.vpc_id
  subnet_id         = module.network.public_subnet_id
  instance_type     = var.instance_type
  root_volume_gb    = var.root_volume_gb
  ssh_public_key    = local.ssh_public_key
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
  # No app ports: the API listens on 127.0.0.1 and is reached through an SSH tunnel.
  app_ingress      = []
  user_data_base64 = base64gzip(local.user_data)
}
