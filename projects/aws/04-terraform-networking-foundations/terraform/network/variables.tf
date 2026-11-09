variable "aws_region" {
  description = "AWS region (must match the state bucket's region in backend.hcl)."
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "Value of the Owner tag."
  type        = string
  default     = "lab-learner"
}

variable "vpc_cidr" {
  description = "VPC CIDR."
  type        = string
  default     = "10.40.0.0/16"
}

variable "az_count" {
  description = "Availability zones (2 or 3)."
  type        = number
  default     = 2
}

variable "nat_mode" {
  description = "none (free) | instance (free-tier t3.micro NAT) | gateway (billed NAT Gateway)."
  type        = string
  default     = "none"
}

variable "enable_test_hosts" {
  description = "Create a public bastion and a private host to prove routing (two t3.micro instances)."
  type        = bool
  default     = true
}

variable "ssh_public_key_path" {
  description = "Path to your OpenSSH public key (used by the test hosts)."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "allowed_ssh_cidrs" {
  description = "Your public IP as x.x.x.x/32 (SSH to the bastion)."
  type        = list(string)
}
