variable "name" {
  description = "Name prefix for all resources."
  type        = string
}

variable "cidr" {
  description = "VPC CIDR. A /16 gives room for 256 /24 subnets."
  type        = string
  default     = "10.40.0.0/16"

  validation {
    condition     = can(cidrhost(var.cidr, 0)) && tonumber(split("/", var.cidr)[1]) <= 20
    error_message = "cidr must be a valid IPv4 CIDR of /20 or larger (subnets are carved as /24s)."
  }
}

variable "az_count" {
  description = "Number of availability zones (one public and one private subnet in each)."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3: high availability needs at least two AZs."
  }
}

variable "nat_mode" {
  description = <<-EOT
    Outbound internet for private subnets:
      none     - no route to the internet (free; S3 still reachable via the gateway endpoint)
      instance - one t3.micro NAT instance (free-tier instance hours; single point of failure)
      gateway  - one managed NAT Gateway (billed hourly + per GB, never free)
  EOT
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "instance", "gateway"], var.nat_mode)
    error_message = "nat_mode must be none, instance or gateway."
  }
}

variable "enable_s3_gateway_endpoint" {
  description = "Route S3 traffic from private subnets through a gateway endpoint (no charge)."
  type        = bool
  default     = true
}

variable "web_ingress_cidrs" {
  description = "CIDRs allowed to reach the web tier on 80/443."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.web_ingress_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry must be a valid CIDR."
  }
}

variable "app_port" {
  description = "Port the app tier listens on (reachable only from the web tier)."
  type        = number
  default     = 8000
}

variable "db_port" {
  description = "Port the data tier listens on (reachable only from the app tier)."
  type        = number
  default     = 5432
}

variable "public_subnet_tags" {
  description = "Extra tags for public subnets (e.g. kubernetes.io/role/elb = 1 for EKS load balancers)."
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Extra tags for private subnets (e.g. kubernetes.io/role/internal-elb = 1)."
  type        = map(string)
  default     = {}
}
