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

  # Container Insights setting driven by environment config.
  # prod = "enabled", dev/staging = "disabled" — controls cost vs. observability.
  setting {
    name  = "containerInsights"
    value = local.current_env.container_insights ? "enabled" : "disabled"
  }

  tags = local.common_tags

  lifecycle {
    # Prevent accidental terraform destroy on this cluster.
    # Comment out temporarily only when intentionally decommissioning.
    prevent_destroy = true
  }
}

# ---------------------------------------------------------------------------
# ECS Services — one per entry in var.ecs_services
# ---------------------------------------------------------------------------

resource "aws_ecs_service" "services" {
  # for_each keyed by service name — state addresses are stable (name-based, not index-based)
  for_each = var.ecs_services

  name          = each.key
  cluster       = aws_ecs_cluster.main.id
  desired_count = each.value.desired_count

  lifecycle {
    # Application Auto Scaling adjusts desired_count at runtime.
    # Without this, every terraform apply resets it to the tfvars value,
    # fighting the autoscaler and potentially causing task churn mid-incident.
    ignore_changes = [desired_count]
  }
}

# ---------------------------------------------------------------------------
# CloudWatch Log Groups — only for services with enable_logs = true
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "service_logs" {
  # Filter for_each: only create a log group if the service has logging enabled.
  # The scheduler service has enable_logs = false — no log group, no cost.
  for_each = { for k, v in var.ecs_services : k => v if v.enable_logs }

  name              = "/ecs/${local.name_prefix}/${each.key}"
  retention_in_days = local.current_env.log_retention_days

  tags = merge(local.common_tags, {
    Service = each.key
  })
}

# ---------------------------------------------------------------------------
# Security Group for ECS Tasks
# ---------------------------------------------------------------------------

resource "aws_security_group" "ecs_tasks" {
  name        = "${local.name_prefix}-ecs-tasks-sg"
  description = "Controls inbound access to ECS tasks"
  vpc_id      = var.vpc_id

  # Dynamic ingress block — driven entirely by local.sg_ingress_rules.
  # Adding a new rule = adding a new object to the list in locals.tf.
  # No changes needed to this resource block.
  dynamic "ingress" {
    for_each = local.sg_ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = local.common_tags
}
