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

variable "github_repository" {
  description = "GitHub repository allowed to assume the pipeline roles, as owner/name."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Use the form owner/repository, e.g. cloud-prakhar/devops-sre-engineering-labs."
  }
}

variable "github_environment" {
  description = "GitHub Environment the release and deploy jobs run in. Only workflows in this environment can assume the roles."
  type        = string
  default     = "aws-06-lab"
}

variable "create_github_oidc_provider" {
  description = "Create the account's GitHub OIDC provider. Set false if the account already has one (only one per URL is allowed)."
  type        = bool
  default     = true
}

variable "allowed_ssh_cidrs" {
  description = "Your public IP as x.x.x.x/32 (SSH to the deploy host for debugging)."
  type        = list(string)
}

variable "allowed_http_cidrs" {
  description = "Who may reach the app on port 80 (your IP). The pipeline verifies from inside the host via SSM, so runner IPs are never allowed in."
  type        = list(string)
}

variable "ssh_public_key_path" {
  description = "Path to your OpenSSH public key."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "instance_type" {
  description = "Free-tier eligible type for the deploy host."
  type        = string
  default     = "t3.micro"
}

variable "image_retention_count" {
  description = "Tagged images kept in ECR (older ones expire; keeps storage inside the free allowance)."
  type        = number
  default     = 10
}

variable "force_delete_repository" {
  description = "Let terraform destroy delete the ECR repository even if it still contains images."
  type        = bool
  default     = true
}
