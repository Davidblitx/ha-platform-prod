variable "env" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where security groups will be created"
  type        = string
}

variable "allowed_inbound_cidr" {
  description = "Allowed CIDR block for external web traffic (e.g., your ALB or public internet)"
  type        = string
  default     = "0.0.0.0/0"
}