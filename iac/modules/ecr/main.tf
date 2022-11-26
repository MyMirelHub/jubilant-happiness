variable "name" {
  type        = string
  description = "base name of the resources"
}

# ECS Fargate Resources
resource "aws_ecr_repository" "repo" {
  name                 = var.name
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}