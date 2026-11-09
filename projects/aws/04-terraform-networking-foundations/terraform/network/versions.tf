terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0, < 7.0.0"
    }
  }
  # Partial configuration: bucket, region, encrypt and use_lockfile come from backend.hcl, written by
  # shared/scripts/tf-init-backend.sh from the bootstrap stack's outputs. Only the key is fixed here.
  backend "s3" {
    key = "aws-04/network/terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Repository = "devops-sre-engineering-labs"
      Project    = "aws-04-terraform-networking-foundations"
      Stack      = "network"
      ManagedBy  = "terraform"
      Owner      = var.owner
      CostCenter = "free-tier-lab"
    }
  }
}
