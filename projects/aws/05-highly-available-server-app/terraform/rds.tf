resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-db"
  subnet_ids = module.vpc.private_subnet_ids
  tags       = { Name = "${local.name}-db" }
}

# Single-AZ db.t4g.micro: covered by the RDS free tier on legacy accounts. Multi-AZ doubles the
# cost and is not free — see docs/adr/0002-single-az-rds-free-tier.md.
#trivy:ignore:AVD-AWS-0176 IAM database authentication adds token handling to the app; password auth over TLS is used.
#trivy:ignore:AVD-AWS-0133 Performance Insights is disabled to stay within free-tier limits.
resource "aws_db_instance" "this" {
  identifier     = "${local.name}-db"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 20 # no storage autoscaling beyond the free-tier allowance
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name             = "taskboard"
  username            = "taskboard"
  password_wo         = ephemeral.aws_secretsmanager_random_password.db.random_password
  password_wo_version = var.db_password_version

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [module.vpc.db_security_group_id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period    = 1
  copy_tags_to_snapshot      = true
  auto_minor_version_upgrade = true
  apply_immediately          = true

  performance_insights_enabled = false
  monitoring_interval          = 0

  # Lab settings: allow terraform destroy without a final snapshot. Production: deletion_protection
  # = true and a final snapshot.
  deletion_protection = false
  skip_final_snapshot = true

  tags = { Name = "${local.name}-db" }
}
