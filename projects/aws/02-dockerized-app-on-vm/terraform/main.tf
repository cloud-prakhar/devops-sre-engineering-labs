locals {
  # Empty when the file is missing; the lab-host module's validation then explains the problem.
  ssh_public_key = fileexists(pathexpand(var.ssh_public_key_path)) ? trimspace(file(pathexpand(var.ssh_public_key_path))) : ""
  name           = "lab02-docker"
  http_cidrs     = length(var.allowed_http_cidrs) > 0 ? var.allowed_http_cidrs : var.allowed_ssh_cidrs
}

locals {
  # Rendered cloud-init document (checked by scripts/validate.sh cloudinit).
  user_data = templatefile("${path.module}/../../../../shared/cloud-init/ubuntu-docker-host.yaml.tftpl", {
    daemon_json = filebase64("${path.module}/../../../../shared/cloud-init/docker-daemon.json")
    lab_name    = local.name
  })
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
  app_ingress = [{
    port        = 80
    cidrs       = local.http_cidrs
    description = "Taskboard HTTP (container published on host port 80)"
  }]
  user_data_base64 = base64gzip(local.user_data)
}
