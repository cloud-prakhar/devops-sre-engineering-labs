variable "aws_region" {
  description = "AWS region (same as the AWS 07 cluster)."
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "Value of the Owner tag."
  type        = string
  default     = "lab-learner"
}

variable "cluster_name" {
  description = "Existing EKS cluster from AWS 07."
  type        = string
  default     = "lab07-eks"
}
