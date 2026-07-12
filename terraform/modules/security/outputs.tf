output "alb_security_group_id" {
  description = "The ID of the security group for the ALB"
  value       = aws_security_group.alb.id
}

output "ec2_security_group_id" {
  description = "The ID of the security group for the EC2 instances"
  value       = aws_security_group.ec2.id
}

output "ssm_security_group_id" {
  description = "The ID of the security group for SSM endpoints"
  value       = aws_security_group.ssm.id
}

