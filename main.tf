provider "aws" {
}

terraform {
  required_version = ">= 1.3.5"
}

locals {
  config = yamldecode(file("./iac/config.yaml"))
}

data "aws_vpc" "default_vpc" {
  default = true
}

data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
}

data "aws_iam_role" "task_ecs" {
  name = "ecsTaskExecutionRole"
}

module "ecr" {
  source = "./iac/modules/ecr"
  name   = local.config.common.name
}

module "ecs" {
  source             = "./iac/modules/ecs"
  name               = local.config.common.name
  image              = local.config.ecs.image
  container_port     = local.config.common.container_port
  execution_role_arn = data.aws_iam_role.task_ecs.arn
  subnets            = data.aws_subnets.subnets.ids
  security_groups    = [module.security.ecs_tasks_security_group_id]
  target_group_arn   = module.load_balancer.target_group_arn
}

module "security" {
  source         = "./iac/modules/security"
  name           = local.config.common.name
  container_port = local.config.common.container_port
  vpc_id         = data.aws_vpc.default_vpc.id
}

module "load_balancer" {
  source          = "./iac/modules/loadbalancer"
  name            = local.config.common.name
  security_groups = [module.security.alb_security_group_id]
  subnets         = data.aws_subnets.subnets.ids
  vpc_id          = data.aws_vpc.default_vpc.id
}

