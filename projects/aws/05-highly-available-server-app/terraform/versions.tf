terraform {
  # 1.11+: write-only arguments (password_wo, value_wo) keep the database password out of state.
  required_version = ">= 1.11.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0, < 7.0.0"
    }
  }
  # State in the bucket created by AWS 04's bootstrap stack:
  #   ../../../shared/scripts/tf-init-backend.sh terraform
  backend "s3" {
    key = "aws-05/app/terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Repository = "devops-sre-engineering-labs"
      Project    = "aws-05-highly-available-server-app"
      ManagedBy  = "terraform"
      Owner      = var.owner
      CostCenter = "free-tier-lab"
    }
  }
}
