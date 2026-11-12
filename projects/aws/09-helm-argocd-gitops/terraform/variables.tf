variable "aws_region" {
  description = "AWS region of the AWS 07 cluster."
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

variable "repo_url" {
  description = "HTTPS URL of YOUR fork, which Argo CD watches (public, or add repository credentials)."
  type        = string

  validation {
    condition     = can(regex("^https://", var.repo_url))
    error_message = "Use the https:// clone URL of your fork."
  }
}

variable "target_revision" {
  description = "Branch, tag or commit Argo CD tracks."
  type        = string
  default     = "main"
}

variable "argocd_chart_version" {
  description = "argo-cd Helm chart version (10.18.0 = Argo CD v3.6.1)."
  type        = string
  default     = "10.18.0"
}

variable "argocd_apps_chart_version" {
  description = "argocd-apps Helm chart version used for the root Application."
  type        = string
  default     = "2.0.8"
}
