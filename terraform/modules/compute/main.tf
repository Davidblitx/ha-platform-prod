# Launch Template
resource "aws_launch_template" "app" {
  name_prefix   = "${var.env}-app-template-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  # Network and security association
  vpc_security_group_ids = [var.ec2_security_group_id]

  # IAM Instances Profile required for SSM access (No SSH)
  iam_instance_profile {
    name = var.iam_instance_profile
  }

  # Troubleshooting and Optimization flags
  monitoring {
    enabled = true
  }

  # Bootstrap script to handle application start (Docker, Flask, Nginx, etc.)
  # firebase64 reads a script file, encodes it, and feeds it to AWS User Data
  user_data = filebase64("${path.root}/../scripts/bootstrap.sh")

  # Dynamic configuration lifecycle rule to prevent updates from breaking existing ASG deployments
  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
        Name = "${var.env}-asg-instance"
        Env  = var.env
    }
  }

  tags = {
    Name = "${var.env}-launch-template"
    Env  = var.env
  }
}

# Target Groups
resource "aws_lb_target_group" "app" {
  name        = "${var.env}-app-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/"
    port                = "80" #Hits Nginx reverse proxy inside the system
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2 # 2 consecutive successes = instance is healthy
    unhealthy_threshold = 3 # 3 consecutive failures = boot the instance out of rotation
    matcher             = "200" # Must return a 200 OK status
  }

  tags = {
    Name = "${var.env}-app-tg"
    Env  = var.env
  }
}

# ALB (Application Load Balancer)
resource "aws_lb" "main" {
  name               = "${var.env}-app-alb"
  internal           = false # false means it faces the public internet
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  # Prevent accidental deletion in production ebvironments
  enable_deletion_protection = false

  tags = {
    Name = "${var.env}-app-tag"
    Env  = var.env
  }
}

# ASG (Auto Scaling Group)
resource "aws_autoscaling_group" "app" {
  name_prefix         = "${var.env}-app-asg-"
  vpc_zone_identifier = var.private_subnet_ids

  # Capcity configuration from variables
  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  # Launch Template configuration
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Link to the load balancer target group
  target_group_arns = [aws_lb_target_group.app.arn]

  # Link to the load balancer target group
  health_check_type         = "ELB"
  health_check_grace_period = 300 # 5 minutes for instance boot and Docker start

  # Force instances to roll cleanly during updates
  lifecycle {
    create_before_destroy = true
  }

  dynamic "tag" {
    for_each = {
       Name = "${var.env}-asg-instance"
       Env  = var.env
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # What to do when traffic hits port 80
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}