output "alb_dns_name" {
  description = "The public DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "The canonical Hosted Zone ID of the load balancer (useful for Route 53 DNS records)"
  value       = aws_lb.main.zone_id
}

output "asg_name" {
  description = "The name of the Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}