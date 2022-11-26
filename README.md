# jubilant-happiness

This is the code to deploy 2 instances of a flask app on an ecs fargate instance

## CI/CD 

**What I Wanted to do**

![cicd](https://github.com/MyMirelHub/jubilant-happiness/blob/main/images/cicd.jpg?raw=true)

Promote image artifacts - The pipeline code is handled by github actions with the manifests localted in `.github/workflows` folder. I wanted to set up a pipeline where the container artifact is only built once and promoted through the steps. This was not possible due to: 
- Github actions not persisting artifacts through workflows 
- Not being able to do it with ECR due to missing permissions `mirisa is not authorized to perform: ecr:BatchGetImage` 

This is how I would have done it otherwise https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-retag.html
  
Force new deployment on ecs cluster - I didn't get to this stage but with more time I would have liked to investigate if I can 
1. Force new deployments of the ecs service `aws ecs update-service --cluster <my_cluster> --service <my_service> --force-new-deployment` 
2.  Automatically exporting the image tag and have it pulled by terraform, so it could redeploy. New image tags would have to be unique for this to work
3. Create a new task definition and clean up the old one
4. There are more options discussed here. https://stackoverflow.com/questions/34840137/how-do-i-deploy-updated-docker-images-to-amazon-ecs-tasks

**End Result**
- An image which builds the container
- The tests are run inside the docker container itsef by overriding entrypoints to keep the test environment consistent regardless of the CI runner VM
- pytest - `docker run --entrypoint "pytest" helloapp:test` 
- linting - `docker run --entrypoint "flake8" helloapp:test` 
- After merging the main pipeline then rebuilds the image, adds the image tag `main` and pushes it to ECR

---
## IAC
The terraform code here is set up in a modular format with the modules declared in the 
`./iac/modules folder` 

```
.
├── config.yaml
└── modules
    ├── ecr
    ├── ecs
    ├── loadbalancer
    └── security
```

Harcoded variables are fed in via the `./iac/config.yaml` file and initialised by the root module `.main.tf`


ECR - Contains the ecr repo, the tags are mutable to allow for image rettaging/promotion
```hcl
# ECS Fargate Resources
resource "aws_ecr_repository" "repo" {
  name                 = var.name
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}
```

ECS - contains the task definition of the container, the container defintions are fed into it with inline json, and the ecs service is launched providing instructions for the scheduling, networking and load balancing config the the container.
  
```hcl
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
```

LB - this spins up an application load balancer, with only one listener used for HTTP, and this forwards the traffic to the target group which the instances are linked to.

```hcl
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
```

Security - this contains 2 security groups, one allowing http traffic to the ALB, and another allowing inbound traffic to our ecs container on port `5000`

```hcl
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
```
**End-result**
Unfortunately I was not able to deploy this end-to-end due to a permissions issue of not being able to assign the executor role. This is possibly due to having mistankenly commited my AWS credentials to git and getting caught and locked out by the account police bots. 
---

## Production Considerations
**CI/CD**
- Tagging here was static with only a `:main`, in production we would have a unique tag/id for each commit and this would be fed into the task definition
- Tests would be run during the container build stage - here I just split them up for the task
- Rething branching model, and other progressive delivery considerations (GitOps, Canarying, Automated performance testing, use of dedicated CD tools, feature flagging)
- Docker compose file or similar for local testing

**Terraform**
- Remote state management
- Versioned modules 
- Terraform in a CI/CD workflows
- Testing modules e2e with frameworks like terratest
- A combination of a public private subnets and following best practices from AWS https://aws.amazon.com/de/blogs/compute/task-networking-in-aws-fargate/


![AWS](https://d2908q01vomqb2.cloudfront.net/1b6453892473a467d07372d45eb05abc2031647a/2018/01/26/Slide5-1024x647.png)

