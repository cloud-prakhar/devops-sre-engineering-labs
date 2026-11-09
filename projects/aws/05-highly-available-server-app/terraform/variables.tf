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

variable "allowed_http_cidrs" {
  description = "Clients allowed to reach the load balancer, normally your IP as x.x.x.x/32."
  type        = list(string)

  validation {
    condition     = length(var.allowed_http_cidrs) > 0 && alltrue([for c in var.allowed_http_cidrs : can(cidrhost(c, 0))])
    error_message = "Provide at least one valid CIDR."
  }
}

variable "app_version" {
  description = "Version label reported by /api/info. Changing it rolls a new launch template version out with an instance refresh."
  type        = string
  default     = "v1"
}

variable "instance_type" {
  description = "Free-tier eligible type for the app instances."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t2.micro", "t3.micro", "t3.small"], var.instance_type)
    error_message = "Use t2.micro, t3.micro or t3.small (x86_64; the launch template uses an amd64 AMI)."
  }
}

variable "asg_min" {
  description = "Minimum instances (2 = one per AZ, the minimum for high availability)."
  type        = number
  default     = 2

  validation {
    condition     = var.asg_min >= 2
    error_message = "asg_min must be at least 2: one instance is not highly available."
  }
}

variable "asg_max" {
  description = "Maximum instances during scale-out and instance refresh."
  type        = number
  default     = 4

  validation {
    condition     = var.asg_max >= var.asg_min && var.asg_max <= 6
    error_message = "asg_max must be >= asg_min and <= 6 (cost guard)."
  }
}

variable "cpu_target_percent" {
  description = "Target-tracking scaling target for average CPU."
  type        = number
  default     = 50
}

variable "db_engine_version" {
  description = "PostgreSQL major version on RDS. If your region does not offer it yet, use \"17\"."
  type        = string
  default     = "18"
}

variable "db_password_version" {
  description = "Increment to generate and apply a new database password (write-only arguments only change when this does)."
  type        = number
  default     = 1
}
