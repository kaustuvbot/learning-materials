# Example: Lifecycle Hooks
#
# Demonstrates:
#   - ignore_changes     — let external systems own specific attributes
#   - replace_triggered_by — force replacement when a dependency changes
#   - create_before_destroy — zero-downtime replacement for resources with dependents
#   - prevent_destroy    — guardrail for stateful production resources
#   - precondition       — validate assumptions before a resource is touched
#   - postcondition      — validate outcomes after a resource is created/updated
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

variable "app_version" {
  type        = string
  description = "Application image version — changing this triggers a redeployment"
  default     = "v1.2.0"
}

variable "autoscaler_desired_count" {
  type        = number
  description = "Initial desired count — will be managed by autoscaler at runtime"
  default     = 3
}

variable "environment" {
  type    = string
  default = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

# -----------------------------------------------------------------------
# Pattern 1: ignore_changes
#
# Problem: Application Auto Scaling adjusts desired_count at runtime.
# Without ignore_changes: every terraform apply resets it — fighting the autoscaler.
# With ignore_changes: Terraform ignores runtime drift on that attribute only.
# -----------------------------------------------------------------------

resource "null_resource" "ecs_service" {
  triggers = {
    name          = "api-service"
    desired_count = tostring(var.autoscaler_desired_count)
    launch_type   = "FARGATE"
  }

  lifecycle {
    ignore_changes = [
      # desired_count is owned by Application Auto Scaling after initial deploy.
      # Terraform only sets it on first creation; auto scaling manages it after.
      triggers["desired_count"],
    ]
  }
}

# -----------------------------------------------------------------------
# Pattern 2: replace_triggered_by
#
# Problem: ECS service holds a reference to its task definition.
# When image version changes, the task definition is replaced, but the
# service resource block hasn't changed — Terraform won't replace it.
# With replace_triggered_by: service is replaced whenever task_definition is.
# -----------------------------------------------------------------------

resource "null_resource" "task_definition" {
  triggers = {
    image_tag = var.app_version
  }
}

resource "null_resource" "ecs_service_rolling_deploy" {
  triggers = {
    name = "api-service-v2"
  }

  lifecycle {
    # When task_definition is replaced (new image), replace this service too.
    # This ensures the service always runs the latest task definition.
    replace_triggered_by = [null_resource.task_definition]
  }
}

# -----------------------------------------------------------------------
# Pattern 3: create_before_destroy
#
# Problem: TLS certificates are referenced by load balancer listeners.
# Default destroy-then-create: old cert deleted → listener broken → new cert created.
# With create_before_destroy: new cert created → listener switches → old cert deleted.
# -----------------------------------------------------------------------

resource "null_resource" "tls_certificate" {
  triggers = {
    domain = "api.example.com"
    expiry = "2027-01-01"
  }

  lifecycle {
    # New certificate is provisioned before the old one is destroyed.
    # Any resource referencing this cert maintains a valid reference throughout.
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------
# Pattern 4: prevent_destroy
#
# Problem: A mis-typed terraform destroy or plan -destroy destroys the DB.
# With prevent_destroy: terraform plan fails with a clear error before any change.
# Remove temporarily ONLY when intentionally decommissioning.
# -----------------------------------------------------------------------

resource "null_resource" "production_database" {
  triggers = {
    cluster_id = "prod-aurora-pg"
    engine     = "aurora-postgresql"
  }

  lifecycle {
    # Terraform plan fails if this resource would be destroyed.
    # This is a last-resort guardrail — not a substitute for backups.
    prevent_destroy = true
  }
}

# -----------------------------------------------------------------------
# Pattern 5: precondition and postcondition (Terraform 1.2+)
#
# precondition: validated before the resource is created/updated
# postcondition: validated after the resource is created/updated
#
# These complement variable validation — use for resource-level assumptions
# that can't be checked at variable parse time.
# -----------------------------------------------------------------------

resource "null_resource" "app_deployment" {
  triggers = {
    version     = var.app_version
    environment = var.environment
  }

  lifecycle {
    precondition {
      # Enforce that production deployments only use stable version tags
      # v1.0.0 format is allowed; "latest" or "dev" are not
      condition     = var.environment != "prod" || can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.app_version))
      error_message = "Production deployments require a pinned version tag (e.g. v1.2.0). Got: '${var.app_version}'."
    }

    postcondition {
      # After creation, validate that the resource has the expected triggers set
      condition     = self.triggers["version"] != ""
      error_message = "app_version must not be empty after deployment."
    }
  }
}

output "lifecycle_summary" {
  value = {
    ecs_service_name      = null_resource.ecs_service.triggers["name"]
    task_definition_image = null_resource.task_definition.triggers["image_tag"]
    app_version           = var.app_version
    environment           = var.environment
  }
}
