variable "aws_region" {
  description = "AWS region (same as the AWS 04 state bucket)."
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "Value of the Owner tag."
  type        = string
  default     = "lab-learner"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "lab07-eks"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version. 1.37 was the default and newest in standard support on 2026-11-09 (aws eks describe-cluster-versions)."
  type        = string
  default     = "1.37"
}

variable "allowed_api_cidrs" {
  description = "CIDRs allowed to reach the public Kubernetes API endpoint (your IP as x.x.x.x/32)."
  type        = list(string)

  validation {
    condition     = length(var.allowed_api_cidrs) > 0 && alltrue([for c in var.allowed_api_cidrs : can(cidrhost(c, 0)) && c != "0.0.0.0/0"])
    error_message = "Provide your /32. 0.0.0.0/0 would expose the API server endpoint to the internet."
  }
}

variable "admin_principal_arn" {
  description = "IAM role or user that gets cluster admin through an access entry. Empty = the identity running Terraform (role ARN for assumed-role sessions)."
  type        = string
  default     = ""
}

variable "nat_mode" {
  description = "Egress for the private node subnets: instance (free-tier t3.micro NAT, default) or gateway (billed). Nodes need egress to pull images."
  type        = string
  default     = "instance"

  validation {
    condition     = contains(["instance", "gateway"], var.nat_mode)
    error_message = "nat_mode must be instance or gateway: nodes in private subnets need egress."
  }
}

variable "node_instance_type" {
  description = "Worker node type. t3.small is free-tier eligible on current AWS accounts (shared/scripts/aws-preflight.sh lists yours); t3.micro allows only 4 pods per node."
  type        = string
  default     = "t3.small"

  validation {
    condition     = contains(["t3.small", "t3.medium", "t4g.small", "c7i-flex.large", "m7i-flex.large"], var.node_instance_type)
    error_message = "Use t3.small, t3.medium, t4g.small, c7i-flex.large or m7i-flex.large."
  }
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT. SPOT is cheaper but nodes can be reclaimed with two minutes' notice."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_count" {
  description = "Desired (and minimum) worker nodes: 2 spreads them over both AZs."
  type        = number
  default     = 2

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 3
    error_message = "node_count must be between 1 and 3 (cost guard)."
  }
}

variable "control_plane_log_types" {
  description = "Control-plane log types sent to CloudWatch (billed per GB). Empty by default; try [\"audit\", \"authenticator\"] in the exercises."
  type        = list(string)
  default     = []
}
