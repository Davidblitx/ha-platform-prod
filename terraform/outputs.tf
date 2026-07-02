output "vpc_id" {
    description = "The ID of the VPC"
    value = module.network.vpc_id
}

output "public_subnet_ids" {
    description = "Public subnet IDs"
    value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
    description = "Private subnet IDs"
    value = module.network.private_subnet_ids
}

output "alb_dns_name" {
  description = "The public DNS name of the Application Load Balancer"
  value       = module.compute.alb_dns_name
}