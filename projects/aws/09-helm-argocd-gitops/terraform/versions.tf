terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0, < 7.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.3.0, < 4.0.0"
    }
  }
  # State in the AWS 04 bootstrap bucket:  ../../../shared/scripts/tf-init-backend.sh terraform
  backend "s3" {
    key = "aws-09/argocd/terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Repository = "devops-sre-engineering-labs"
      Project    = "aws-09-helm-argocd-gitops"
      ManagedBy  = "terraform"
      Owner      = var.owner
      CostCenter = "eks-lab-billed"
    }
  }
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

# Short-lived token from "aws eks get-token" (same identity and access entry as kubectl).
provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
    }
  }
}
