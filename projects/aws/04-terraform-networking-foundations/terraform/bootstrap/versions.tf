terraform {
  # 1.10+ is required by the S3 backend's native lock file (use_lockfile) used by the network stack.
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0, < 7.0.0"
    }
  }
  # The bootstrap stack creates the state bucket, so its own state is necessarily local
  # (see docs/adr/0001-remote-state-s3-native-locking.md). It holds no secrets.
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Repository = "devops-sre-engineering-labs"
      Project    = "aws-04-terraform-networking-foundations"
      Stack      = "bootstrap"
      ManagedBy  = "terraform"
      Owner      = var.owner
      CostCenter = "free-tier-lab"
    }
  }
}
