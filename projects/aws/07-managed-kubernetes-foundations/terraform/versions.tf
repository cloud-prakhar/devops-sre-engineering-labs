terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0, < 7.0.0"
    }
  }
  # State in the AWS 04 bootstrap bucket:  ../../../shared/scripts/tf-init-backend.sh terraform
  backend "s3" {
    key = "aws-07/eks/terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Repository = "devops-sre-engineering-labs"
      Project    = "aws-07-managed-kubernetes-foundations"
      ManagedBy  = "terraform"
      Owner      = var.owner
      CostCenter = "eks-lab-billed"
    }
  }
}
