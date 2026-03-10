# Example: Production-Grade HCL Patterns
#
# Demonstrates:
#   - Naming conventions via locals (change once, flows everywhere)
#   - Required tags defined once, merged into every resource
#   - Explicit over implicit configuration
#
# Run: terraform init && terraform plan

terraform {
  required_version = ">= 1.9"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

variable "project" {
  type        = string
  description = "Project name used in all resource names"
  default     = "myapp"
}

variable "env" {
  type        = string
  description = "Deployment environment"
  default     = "prod"
}

variable "team" {
  type        = string
  description = "Owning team name"
  default     = "platform"
}

variable "cost_center" {
  type        = string
  description = "Cost center for billing allocation"
  default     = "cc-1234"
}

# ✅ Pattern 1: All naming derived from a single local — rename once, updates everywhere
locals {
  name_prefix = "${var.project}-${var.env}"

  # ✅ Pattern 2: Required tags defined once — every resource gets them via merge()
  common_tags = {
    Project     = var.project
    Environment = var.env
    ManagedBy   = "terraform"
    Team        = var.team
    CostCenter  = var.cost_center
  }
}

# In a real project these would be aws_ecs_cluster, aws_rds_cluster, etc.
# null_resource is used here so the example runs without AWS credentials.

resource "null_resource" "app_server" {
  triggers = {
    # ✅ Every resource name follows the same convention
    name = "${local.name_prefix}-app-server"
    tags = jsonencode(merge(local.common_tags, {
      Name = "${local.name_prefix}-app-server"
      Role = "app"
    }))
  }
}

resource "null_resource" "worker" {
  triggers = {
    name = "${local.name_prefix}-worker"
    tags = jsonencode(merge(local.common_tags, {
      Name = "${local.name_prefix}-worker"
      Role = "worker"
    }))
  }
}

resource "null_resource" "database" {
  triggers = {
    name = "${local.name_prefix}-db"
    tags = jsonencode(merge(local.common_tags, {
      Name = "${local.name_prefix}-db"
      Role = "database"
    }))
  }
}

output "name_prefix" {
  description = "Naming prefix applied to all resources"
  value       = local.name_prefix
}

output "common_tags" {
  description = "Tags merged into every resource"
  value       = local.common_tags
}

output "resource_names" {
  description = "All resource names derived from name_prefix"
  value = {
    app_server = "${local.name_prefix}-app-server"
    worker     = "${local.name_prefix}-worker"
    database   = "${local.name_prefix}-db"
  }
}
