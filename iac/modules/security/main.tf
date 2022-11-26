variable "name" {
  type        = string
  description = "base name of the resources"
}

variable "container_port" {
  type        = number
  description = "port of the ecs container"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

resource "aws_security_group" "alb" {
  description = "ALB traffic rules"
  name        = "${var.name}-sg-alb"
  vpc_id      = var.vpc_id

  ingress {
    description      = "Allow HTTP traffic from the internet"
    protocol         = "tcp"
    from_port        = 80
    to_port          = 80
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    description      = "Allow all outbound traffic"
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "ecs_tasks" {
  description = "ECS task traffic rules"
  name        = "${var.name}-sg-task"
  vpc_id      = var.vpc_id

  ingress {
    description      = "Allow inbound traffic from the ALB to container port exposed by the task"
    protocol         = "tcp"
    from_port        = var.container_port
    to_port          = var.container_port
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    description      = "Allow all outbound traffic"
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "ecs_tasks_security_group_id" {
  value = aws_security_group.ecs_tasks.id
}