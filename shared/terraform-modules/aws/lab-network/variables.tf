variable "name" {
  description = "Name prefix for all resources."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR of the single public subnet. Must sit inside vpc_cidr."
  type        = string
  default     = "10.20.1.0/24"
}

variable "availability_zone" {
  description = "AZ for the subnet. Null picks the first available AZ in the region."
  type        = string
  default     = null
}
