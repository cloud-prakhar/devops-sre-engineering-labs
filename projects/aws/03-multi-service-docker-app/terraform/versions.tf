terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0, < 7.0.0"
    }
  }
  # Local state on purpose: one learner, one short-lived lab. Remote state with locking
  # is introduced in project 04.
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Repository = "devops-sre-engineering-labs"
      Project    = "aws-03-multi-service-docker-app"
      ManagedBy  = "terraform"
      Owner      = var.owner
      CostCenter = "free-tier-lab"
    }
  }
}
