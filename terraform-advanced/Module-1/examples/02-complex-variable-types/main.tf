# Example: Complex Variable Types
#
# Demonstrates:
#   - object() with named fields for structured config
#   - optional() with defaults (Terraform 1.3+)
#   - map(object()) for multiple instances of the same shape
#   - tuple() for fixed-length, positional config
#   - any as an escape hatch (use sparingly)
#
# Run: terraform init && terraform plan

terraform {
  required_version = ">= 1.9"
}

# ✅ Pattern 1: object() with optional() fields
# Models a database config — callers only need to specify what differs from defaults
variable "db_config" {
  description = "Database cluster configuration"
  type = object({
    instance_class        = string
    allocated_storage     = number
    multi_az              = bool
    deletion_protection   = optional(bool, true)   # defaults to true if omitted
    snapshot_identifier   = optional(string)        # defaults to null if omitted
    backup_retention_days = optional(number, 7)    # defaults to 7 if omitted
  })
  default = {
    instance_class    = "db.t4g.micro"
    allocated_storage = 20
    multi_az          = false
    # deletion_protection  → true  (from optional default)
    # snapshot_identifier  → null  (from optional default)
    # backup_retention_days → 7    (from optional default)
  }
}

# ✅ Pattern 2: map(object()) — multiple instances of the same config shape
# One variable drives all services; adding a new service is just a new map entry
variable "ecs_services" {
  description = "ECS service configurations — key is the service name"
  type = map(object({
    cpu           = number
    memory        = number
    port          = number
    desired_count = number
    min_capacity  = number
    max_capacity  = number
  }))
  default = {
    api-gateway = {
      cpu           = 512
      memory        = 1024
      port          = 8080
      desired_count = 3
      min_capacity  = 2
      max_capacity  = 10
    }
    worker-service = {
      cpu           = 1024
      memory        = 2048
      port          = 9000
      desired_count = 2
      min_capacity  = 1
      max_capacity  = 5
    }
  }
}

# ✅ Pattern 3: tuple() — fixed-length, positional config
# Use when position has meaning and the length is fixed
# Prefer object() if the field count might grow
variable "health_check_thresholds" {
  description = "[healthy_threshold, unhealthy_threshold, interval_seconds]"
  type        = tuple([number, number, number])
  default     = [3, 2, 30]
}

# ✅ Pattern 4: map(any) as escape hatch for heterogeneous values
# Only use for generic wrapper scenarios — not core infrastructure config
variable "extra_tags" {
  description = "Additional tags — accepts any map"
  type        = map(any)
  default     = {}
}

locals {
  # Access tuple by index — position has the meaning, not a key
  healthy_threshold   = var.health_check_thresholds[0]
  unhealthy_threshold = var.health_check_thresholds[1]
  interval_seconds    = var.health_check_thresholds[2]
}

output "db_deletion_protection" {
  description = "Shows optional() default: true even though caller didn't set it"
  value       = var.db_config.deletion_protection
}

output "db_backup_retention" {
  description = "Shows optional() default with value: 7 days"
  value       = var.db_config.backup_retention_days
}

output "service_names" {
  description = "All services defined in the map"
  value       = keys(var.ecs_services)
}

output "service_ports" {
  description = "Port for each service — derived from map(object)"
  value       = { for name, svc in var.ecs_services : name => svc.port }
}

output "health_check" {
  description = "Tuple values accessed by index"
  value = {
    healthy   = local.healthy_threshold
    unhealthy = local.unhealthy_threshold
    interval  = local.interval_seconds
  }
}
