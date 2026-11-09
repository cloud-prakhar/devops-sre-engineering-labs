variable "aws_region" {
  description = "Region for the state bucket. Use the same region as the stacks that store state in it."
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "Value of the Owner tag."
  type        = string
  default     = "lab-learner"
}

variable "bucket_prefix" {
  description = "Prefix of the bucket name. Account ID and region are appended to make it globally unique."
  type        = string
  default     = "dsel-tfstate"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{2,30}$", var.bucket_prefix))
    error_message = "bucket_prefix: 3-31 characters, lowercase letters, digits and hyphens."
  }
}

variable "noncurrent_version_days" {
  description = "Days to keep previous state versions (your undo history)."
  type        = number
  default     = 30
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete the bucket together with every state version. Keep false except during final cleanup."
  type        = bool
  default     = false
}
