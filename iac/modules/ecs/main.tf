variable "name" {
  type        = string
  description = "base name of the resources"
}

variable "execution_role_arn" {
  type        = string
  description = "ARN of the ecs task execution role"
}

variable "image" {
  type        = string
  description = "image to run in the task"
}

variable "container_port" {
  type        = number
  description = "port of the ecs container"
}

variable "subnets" {
  type        = list(string)
  description = "list of subnets to run the task"
}

variable "security_groups" {
  type        = list(string)
  description = "list of security groups to run the task"
}

variable "target_group_arn" {
  type        = string
  description = "ARN of the target group to register the task to"
}

resource "aws_ecs_cluster" "main" {
  name = "${var.name}-cluster"
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
  }
}

# Random id to keep ecs task definition unique
resource "random_id" "main" {
  byte_length = 2
}

resource "aws_ecs_task_definition" "main" {
  family                   = "${var.name}-${random_id.main.id}"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = var.execution_role_arn
  cpu                      = 256
  memory                   = 512
  network_mode             = "awsvpc"

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = var.name
      image     = var.image
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
        },
      ]
    },
  ])
}

resource "aws_ecs_service" "main" {
  name                = var.name
  cluster             = aws_ecs_cluster.main.id
  task_definition     = aws_ecs_task_definition.main.arn
  desired_count       = 2
  launch_type         = "FARGATE"
  scheduling_strategy = "REPLICA"

  network_configuration {
    security_groups  = var.security_groups
    subnets          = var.subnets
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.name
    container_port   = var.container_port
  }
}