variable "name" {
  description = "Name prefix for all resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC for the security group."
  type        = string
}

variable "subnet_id" {
  description = "Public subnet for the instance."
  type        = string
}

variable "instance_type" {
  description = "EC2 type. Restricted to types AWS lists as free-tier eligible (check your account's plan)."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t2.micro", "t3.micro", "t3.small", "t4g.micro", "t4g.small"], var.instance_type)
    error_message = "Use a free-tier eligible type: t2.micro, t3.micro, t3.small, t4g.micro or t4g.small."
  }
}

variable "root_volume_gb" {
  description = "Root gp3 volume size. The EBS free tier covers 30 GB in total across all volumes."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_gb >= 8 && var.root_volume_gb <= 30
    error_message = "root_volume_gb must be between 8 and 30 to stay inside the EBS free tier."
  }
}

variable "ssh_public_key" {
  description = "OpenSSH public key (contents, not a path)."
  type        = string

  validation {
    condition     = can(regex("^(ssh-ed25519|ecdsa-sha2-nistp256|ssh-rsa) ", var.ssh_public_key))
    error_message = "ssh_public_key must be an OpenSSH public key line (ssh-ed25519 recommended). Check that ssh_public_key_path points to an existing .pub file."
  }
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs allowed to SSH, normally your public IP as x.x.x.x/32."
  type        = list(string)

  validation {
    condition     = length(var.allowed_ssh_cidrs) > 0 && alltrue([for c in var.allowed_ssh_cidrs : can(cidrhost(c, 0)) && c != "0.0.0.0/0"])
    error_message = "Provide at least one valid CIDR. 0.0.0.0/0 is refused: scanners find open SSH within minutes."
  }
}

variable "app_ingress" {
  description = "Extra TCP ports to open, each with its own CIDR list."
  type = list(object({
    port        = number
    cidrs       = list(string)
    description = string
  }))
  default = []
}

variable "user_data_base64" {
  description = "Base64-encoded cloud-init user data."
  type        = string
}
