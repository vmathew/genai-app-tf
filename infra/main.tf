provider "aws" {
  region = "us-east-1"
}

resource "aws_ecr_repository" "app" {
  name = "gen-ai-app"
}

resource "aws_ecs_cluster" "main" {
  name = "gen-ai-cluster"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "streamlit-langchain-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "gen-ai-app"
      image = "${aws_ecr_repository.app.repository_url}:latest"
      portMappings = [
        {
          containerPort = 8501
          hostPort      = 8501
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "app" {
  name            = "streamlit-langchain-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets         = [data.aws_subnet.private.id]
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "gen-ai-app"
    container_port   = 8501
  }
}

resource "aws_lb" "app" {
  name               = "streamlit-langchain-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [data.aws_subnet.public.id, data.aws_subnet.public_2.id]
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_target_group" "app" {
  name        = "streamlit-langchain-tg"
  port        = 8501
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.existing.id
  target_type = "ip"

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 60
    interval            = 300
    matcher             = "200"
  }
}

resource "aws_security_group" "alb" {
  name        = "streamlit-langchain-alb-sg"
  description = "Controls access to the ALB"
  vpc_id      = data.aws_vpc.existing.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "streamlit-langchain-ecs-tasks-sg"
  description = "Allow inbound access from the ALB only"
  vpc_id      = data.aws_vpc.existing.id

  ingress {
    from_port       = 8501
    to_port         = 8501
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "internal_sg" {
  name        = "internal-sg"
  vpc_id      = data.aws_vpc.existing.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Allow inbound HTTP traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id       = data.aws_vpc.existing.id
  service_name = "com.amazonaws.us-east-1.ecr.dkr"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids  = [data.aws_subnet.private.id]
  security_group_ids = [aws_security_group.internal_sg.id]
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id       = data.aws_vpc.existing.id
  service_name = "com.amazonaws.us-east-1.ecr.api"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids  = [data.aws_subnet.private.id]
  security_group_ids = [aws_security_group.internal_sg.id]
}

resource "aws_vpc_endpoint" "ecs" {
  vpc_id       = data.aws_vpc.existing.id
  service_name = "com.amazonaws.us-east-1.ecs"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids  = [data.aws_subnet.private.id]
  security_group_ids = [aws_security_group.ecs_tasks.id]
}

resource "aws_vpc_endpoint" "ecs_agent" {
  vpc_id       = data.aws_vpc.existing.id
  service_name = "com.amazonaws.us-east-1.ecs-agent"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids  = [data.aws_subnet.private.id]
  security_group_ids = [aws_security_group.ecs_tasks.id]
}

resource "aws_vpc_endpoint" "ecs_telemetry" {
  vpc_id       = data.aws_vpc.existing.id
  service_name = "com.amazonaws.us-east-1.ecs-telemetry"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids  = [data.aws_subnet.private.id]
  security_group_ids = [aws_security_group.ecs_tasks.id]
}

resource "aws_vpc_endpoint" "bedrock" {
  vpc_id       = data.aws_vpc.existing.id
  service_name = "com.amazonaws.us-east-1.bedrock"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids  = [data.aws_subnet.private.id]
  security_group_ids = [aws_security_group.ecs_tasks.id]
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "streamlit-langchain-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "streamlit-langchain-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "bedrock_access" {
  name        = "streamlit-langchain-bedrock-access"
  description = "IAM policy for accessing Amazon Bedrock"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:ListFoundationModels"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_bedrock_access" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.bedrock_access.arn
}