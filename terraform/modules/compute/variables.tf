variable "env" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the Target group and ALB will be deployed"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs where ALB will sit"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs where Auto Scaling Group will launch instances"
  type        = list(string)
}

variable "ec2_security_group_id" {
  description = "The security group ID to attach to the EC2 instances"
  type        = string
}

variable "alb_security_group_id" {
  description = "The security group ID to attach to the Application Load Balancer"
  type        = string
}

variable "instance_type" {
  description = "The EC2 instance type for the launch template"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "The AMI ID to use for the EC2 instances (e.g., Ubuntu or Amazon Linux 2023)"
  type        = string
}

variable "iam_instance_profile" {
  description = "The name of the IAM instance profile for SSM managed instances"
  type        = string
}

variable "asg_min_size" {
  description = "The minimum number of instances in the ASG"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "The maximum number of instances in the ASG"
  type        = number
  default     = 3
}

variable "asg_desired_capacity" {
  description = "The desired number of instances in the ASG"
  type        = number
  default     = 2
}