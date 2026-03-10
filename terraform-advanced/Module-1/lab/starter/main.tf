terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# ECS Cluster
# ---------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  # TODO (Exercise 4B + Exercise 7 bonus): Add a setting block for Container Insights.
  # Use local.current_env.container_insights — set value to "enabled" if true, "disabled" if false.
  #
  # setting {
  #   name  = "containerInsights"
  #   value = ??? ? "enabled" : "disabled"
  # }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# ECS Services
# ---------------------------------------------------------------------------

resource "aws_ecs_service" "services" {
  # TODO (Exercise 3A / Exercise 7): Complete this resource block.
  # for_each  — drive from var.ecs_services
  # name      — use each.key
  # cluster   — reference aws_ecs_cluster.main.id
  # desired_count — use each.value.desired_count
  # lifecycle — ignore_changes on desired_count (managed by Auto Scaling at runtime)

  name    = "" # ← replace with each.key
  cluster = aws_ecs_cluster.main.id

  # TODO: Set desired_count from each.value
  desired_count = 0

  lifecycle {
    # TODO (Exercise 7): Ignore changes to desired_count
  }
}

# ---------------------------------------------------------------------------
# CloudWatch Log Groups (one per service, only when enable_logs = true)
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "service_logs" {
  # TODO (Exercise 3A): Add for_each — only include services where enable_logs = true.
  # Pattern: { for k, v in var.ecs_services : k => v if v.??? }

  name              = "/ecs/${local.name_prefix}/${each.key}"
  retention_in_days = local.current_env.log_retention_days

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Security Group for ECS Tasks
# ---------------------------------------------------------------------------

resource "aws_security_group" "ecs_tasks" {
  name        = "${local.name_prefix}-ecs-tasks-sg"
  description = "Controls inbound access to ECS tasks"
  vpc_id      = var.vpc_id

  # TODO (Exercise 3B): Add a dynamic "ingress" block driven by local.sg_ingress_rules.
  # The content block must set: from_port, to_port, protocol, cidr_blocks, description
  #
  # dynamic "ingress" {
  #   for_each = ???
  #   content {
  #     from_port   = ingress.value.???
  #     ...
  #   }
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = local.common_tags
}
