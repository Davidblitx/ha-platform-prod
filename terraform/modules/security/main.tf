# ALB Security group
resource "aws_security_group" "alb" {
  name        = "${var.env}-alb-sg"
  description = "Security group for user-facing Application Load Balancer"
  vpc_id      = var.vpc_id

  # Inbound HTTP traffic from the outside world
  ingress {
    description = "Allow HTTP traffic from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_inbound_cidr]
  }

  # Inbound HTTPS traffic from the outside world
  ingress {
    description = "Allow HTTPS traffic from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_inbound_cidr]
  }

  # Outbound traffic to anywhere
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env}-alb-sg"
    Env  = var.env
  }
}

# EC2 Security Group
resource "aws_security_group" "ec2" {
  name        = "${var.env}-ec2-sg"
  description = "Security group for backend EC2 instances running application containers"
  vpc_id      = var.vpc_id

  # Inbound app traffic from ALB only
  ingress {
    description     = "Allow container application traffic from ALB"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Inbound Nginx proxy traffic from the ALB only
  ingress {
    description     = "Allow reverse proxy traffic from ALB"
    from_port       = 80
    to_port         = 80    
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Outbound traffic to anywhere via NAT Gateway
  egress {
    description = "Allow all outbound traffic for package updates and Docker pulls"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env}-ec2-sg"
    Env  = var.env
  }
}

resource "aws_security_group" "ssm" {
  name        = "${var.env}-ssm-sg"
  description = "Security group for SSM VPC Endpoints"
  vpc_id      = var.vpc_id

  # No inbound rules required for SSM Session Manager to function
  # Inbound rules = empty

  # Outbound HTTPS traffic to AWS Systems Manager endpoints
  egress {
    description = "Allow outbound HTTPS traffic to AWS SSM services"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env}-ssm-sg"
    Env  = var.env
  }
}



