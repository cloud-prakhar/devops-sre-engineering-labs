data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

locals {
  app_src            = "${path.module}/../../../../shared/sample-apps/taskboard/api"
  user_data_template = "${path.module}/user-data.yaml.tftpl"
  # Values only known after apply. scripts/validate.sh renders the template offline by merging
  # user_data_placeholders over user_data_vars.
  user_data_runtime_vars = {
    db_host = aws_db_instance.this.address
  }
  # tflint-ignore: terraform_unused_declarations
  user_data_placeholders = {
    db_host = "lab05-ha-db.example.us-east-1.rds.amazonaws.com"
  }
  user_data_vars = {
    region            = var.aws_region
    app_version       = var.app_version
    db_password_param = "/${local.name}/db/password"
    files = {
      "/opt/taskboard-src/requirements.txt" = filebase64("${local.app_src}/requirements.txt")
      "/opt/taskboard-src/app/__init__.py"  = filebase64("${local.app_src}/app/__init__.py")
      "/opt/taskboard-src/app/main.py"      = filebase64("${local.app_src}/app/main.py")
      "/opt/taskboard-src/app/storage.py"   = filebase64("${local.app_src}/app/storage.py")
    }
    taskboard_service = filebase64("${path.module}/../../../../shared/linux-service/taskboard.service")
    install_taskboard = filebase64("${path.module}/../../../../shared/linux-service/install-taskboard.sh")
  }
  user_data = templatefile(local.user_data_template, merge(local.user_data_vars, local.user_data_runtime_vars))
}

resource "aws_launch_template" "app" {
  name_prefix   = "${local.name}-app-"
  image_id      = data.aws_ssm_parameter.ubuntu_ami.insecure_value
  instance_type = var.instance_type
  user_data     = base64gzip(local.user_data)

  iam_instance_profile {
    arn = aws_iam_instance_profile.app.arn
  }

  network_interfaces {
    # Public IP for package downloads (no NAT, see ADR-0001). Inbound is limited by the app SG to
    # the load balancer's SG on port 8000.
    associate_public_ip_address = true
    security_groups             = [module.vpc.app_security_group_id]
    delete_on_termination       = true
  }

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_type           = "gp3"
      volume_size           = 10
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = false
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.name}-app", AppVersion = var.app_version }
  }
  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "${local.name}-app" }
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${local.name}-asg"
  min_size            = var.asg_min
  max_size            = var.asg_max
  desired_capacity    = var.asg_min
  vpc_zone_identifier = module.vpc.public_subnet_ids
  target_group_arns   = [aws_lb_target_group.app.arn]

  # ELB health checks: an instance whose /readyz keeps failing is replaced, not just ignored.
  health_check_type         = "ELB"
  health_check_grace_period = 300 # first boot installs Python 3.14 and dependencies
  default_instance_warmup   = 120

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  # A new launch template version (e.g. app_version change) replaces instances in waves while
  # keeping at least half of the capacity healthy behind the load balancer.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 120
      auto_rollback          = true
    }
  }

  tag {
    key                 = "Name"
    value               = "${local.name}-app"
    propagate_at_launch = true
  }

  # Desired capacity is owned by the scaling policy after creation.
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "${local.name}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_percent
  }
}
