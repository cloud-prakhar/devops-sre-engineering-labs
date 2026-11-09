variable "aws_region" {
  description = "AWS region. us-east-1 has the broadest free-tier coverage and lowest list prices."
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "Value of the Owner tag, so you can find your resources in a shared account."
  type        = string
  default     = "lab-learner"
}

variable "instance_type" {
  description = "Free-tier eligible type. Legacy-free-tier accounts in us-east-1: t2.micro or t3.micro."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_gb" {
  description = "Root volume size in GB (8-30; the EBS free tier is 30 GB total)."
  type        = number
  default     = 20
}

variable "ssh_public_key_path" {
  description = "Path to your OpenSSH public key."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "allowed_ssh_cidrs" {
  description = "Your public IP as x.x.x.x/32 (run shared/scripts/aws-preflight.sh to detect it)."
  type        = list(string)
}
