variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "Value of the Owner tag."
  type        = string
  default     = "lab-learner"
}

variable "instance_type" {
  description = "Free-tier eligible type (validated by the lab-host module)."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_gb" {
  description = "Root volume in GB (8-30). Images, build cache, the PostgreSQL volume, backups and the 1 GB swap file live here."
  type        = number
  default     = 20
}

variable "ssh_public_key_path" {
  description = "Path to your OpenSSH public key."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "allowed_ssh_cidrs" {
  description = "Your public IP as x.x.x.x/32."
  type        = list(string)
}

variable "allowed_http_cidrs" {
  description = "CIDRs allowed to reach ports 80 and 443. Empty = same as allowed_ssh_cidrs."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.allowed_http_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry must be a valid CIDR."
  }
}
