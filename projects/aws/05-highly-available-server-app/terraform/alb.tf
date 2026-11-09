#trivy:ignore:AVD-AWS-0053 Internet-facing by design: it is the public entry point (restricted by the web SG).
resource "aws_lb" "this" {
  name                       = "${local.name}-alb"
  load_balancer_type         = "application"
  internal                   = false
  subnets                    = module.vpc.public_subnet_ids
  security_groups            = [module.vpc.web_security_group_id]
  drop_invalid_header_fields = true
  idle_timeout               = 30
  # Lab setting: allow terraform destroy. Production: enable deletion protection.
  enable_deletion_protection = false
}

resource "aws_lb_target_group" "app" {
  name                 = "${local.name}-tg"
  port                 = 8000
  protocol             = "HTTP"
  vpc_id               = module.vpc.vpc_id
  target_type          = "instance"
  deregistration_delay = 30 # in-flight requests get 30 s to finish during scale-in and refresh

  # Readiness, not liveness: an instance that cannot reach the database is taken out of rotation.
  # If ALL targets fail, the ALB "fails open" and routes to all of them (see docs/interview.md Q3).
  health_check {
    path                = "/readyz"
    matcher             = "200"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

#trivy:ignore:AVD-AWS-0054 HTTPS needs a domain for an ACM certificate; documented as the production step in the README.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
