variable "name" {
  type        = string
  description = "base name of the resources"
}

variable "security_groups" {
  type        = list(string)
  description = "security groups to attach to the load balancer"
}

variable "subnets" {
  type        = list(string)
  description = "subnets to attach to the load balancer"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

resource "aws_lb" "main" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.security_groups
  subnets            = var.subnets

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "main" {
  name        = var.name
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
}

resource "aws_lb_listener" "alb_listener_http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

output "target_group_arn" {
  value = aws_lb_target_group.main.arn
}