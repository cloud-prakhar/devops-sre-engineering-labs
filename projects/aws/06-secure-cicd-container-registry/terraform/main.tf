locals {
  name = "lab06-cicd"
  # Empty when the file is missing; the lab-host module's validation then explains the problem.
  ssh_public_key = fileexists(pathexpand(var.ssh_public_key_path)) ? trimspace(file(pathexpand(var.ssh_public_key_path))) : ""
  # Rendered cloud-init document (schema-checked by scripts/validate.sh cloudinit).
  user_data = templatefile("${path.module}/../../../../shared/cloud-init/ubuntu-docker-host.yaml.tftpl", {
    daemon_json = filebase64("${path.module}/../../../../shared/cloud-init/docker-daemon.json")
    lab_name    = local.name
    extra_files = {
      "/usr/local/sbin/taskboard-deploy" = filebase64("${path.module}/../files/taskboard-deploy.sh")
    }
    # The AWS CLI is needed on the host for "aws ecr get-login-password".
    extra_runcmd = [["snap", "install", "aws-cli", "--classic"]]
  })
}

module "network" {
  source = "../../../../shared/terraform-modules/aws/lab-network"
  name   = local.name
}

data "aws_iam_policy_document" "pull" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid       = "PullFromOneRepository"
    actions   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"]
    resources = [aws_ecr_repository.app.arn]
  }
}

# Deploy target: one free-tier Docker host. Same module as AWS 01-03, plus an ECR pull policy.
module "host" {
  source            = "../../../../shared/terraform-modules/aws/lab-host"
  name              = local.name
  vpc_id            = module.network.vpc_id
  subnet_id         = module.network.public_subnet_id
  instance_type     = var.instance_type
  ssh_public_key    = local.ssh_public_key
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
  app_ingress = [{
    port        = 80
    cidrs       = var.allowed_http_cidrs
    description = "Taskboard HTTP"
  }]
  extra_policy_json = data.aws_iam_policy_document.pull.json
  user_data_base64  = base64gzip(local.user_data)
}
