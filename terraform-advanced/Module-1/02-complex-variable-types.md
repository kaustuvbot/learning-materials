# 02 — Complex Variable Types: objects, tuples, any

> **Module**: 1 — Advanced HCL Patterns & Code Design  
> **Time**: ~15 minutes

---

## What & Why

Terraform's type system is more powerful than most engineers use. Moving beyond `string` and `list(string)` lets you model real infrastructure inputs — multi-field configurations, optional attributes, mixed-type collections — with compile-time validation instead of runtime surprises.

---

## Real-World Use Case

> **Scenario**: Your platform team manages 15 microservices on ECS Fargate. Each service has different CPU/memory, port, health check path, and autoscaling config. You have 15 nearly-identical variable blocks and 15 nearly-identical resource blocks. One mis-copy caused a production outage last month.

The fix: model each service as a typed object and drive all resources from a single `map(object(...))`.

---

## Type Definitions

### `object` — Structured, Named Fields

```hcl
# variables.tf

variable "ecs_services" {
  description = "Map of ECS service configurations"
  type = map(object({
    cpu           = number
    memory        = number
    port          = number
    health_check  = string
    desired_count = number
    min_capacity  = number
    max_capacity  = number
  }))
}
```

```hcl
# terraform.tfvars

ecs_services = {
  api-gateway = {
    cpu           = 512
    memory        = 1024
    port          = 8080
    health_check  = "/health"
    desired_count = 3
    min_capacity  = 2
    max_capacity  = 10
  }
  worker-service = {
    cpu           = 1024
    memory        = 2048
    port          = 9000
    health_check  = "/ready"
    desired_count = 2
    min_capacity  = 1
    max_capacity  = 5
  }
}
```

```hcl
# compute.tf — one resource block drives all 15 services

resource "aws_ecs_service" "services" {
  for_each = var.ecs_services

  name            = each.key
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  desired_count   = each.value.desired_count

  load_balancer {
    target_group_arn = aws_lb_target_group.services[each.key].arn
    container_name   = each.key
    container_port   = each.value.port
  }
}
```

### Optional Object Attributes (Terraform 1.3+)

```hcl
variable "rds_config" {
  type = object({
    instance_class    = string
    allocated_storage = number
    multi_az          = bool
    # optional() means callers can omit this field — it defaults to null
    snapshot_id       = optional(string)
    deletion_protection = optional(bool, true)   # default = true if omitted
  })
}
```

> 💡 **Pro Tip**: Use `optional(type, default)` to give your objects sensible defaults without forcing every caller to specify every field. This is how you build flexible, backward-compatible variable schemas.

### `tuple` — Fixed-Length, Mixed-Type Lists

```hcl
# Tuples are ordered, fixed-length, and each position has a specific type.
# Use them for config pairs where position has meaning.

variable "health_check_thresholds" {
  description = "[healthy_threshold, unhealthy_threshold, interval_seconds]"
  type        = tuple([number, number, number])
  default     = [3, 2, 30]
}

# Access by index — not iterable like a list
locals {
  healthy_threshold   = var.health_check_thresholds[0]
  unhealthy_threshold = var.health_check_thresholds[1]
  interval_seconds    = var.health_check_thresholds[2]
}
```

> ⚠️ **Warning**: Prefer `object` over `tuple` for anything that might gain a new field. Adding a position to a tuple is a breaking change for all callers. Objects can add `optional()` fields without breaking existing usage.

### `any` — Escape Hatch (Use Sparingly)

```hcl
# any accepts any type — Terraform infers the actual type at runtime.
# Useful for wrapper modules that must accept heterogeneous values.

variable "tags" {
  description = "Resource tags — accepts map(string) or map(any)"
  type        = map(any)
  default     = {}
}

# ❌ Don't use any for core business config — you lose compile-time validation
variable "service_config" {
  type = any   # Now Terraform can't tell you when you pass the wrong shape
}
```

---

## Lab Exercise

### Objective

Model an Aurora PostgreSQL cluster configuration as a typed object variable with optional fields. Drive an `aws_rds_cluster` resource from it.

### Starter Code

```hcl
# variables.tf

variable "aurora_config" {
  description = "Aurora PostgreSQL cluster configuration"
  type = object({
    # TODO: add fields for:
    # - cluster_identifier (string)
    # - engine_version (string)
    # - instance_count (number)
    # - instance_class (string)
    # - database_name (string)
    # - backup_retention_days (number)
    # - deletion_protection (bool, optional, default true)
    # - skip_final_snapshot (bool, optional, default false)
  })
}

# main.tf

resource "aws_rds_cluster" "aurora" {
  # TODO: wire up all fields from var.aurora_config
}
```

### Expected Output

```
$ terraform validate
Success! The configuration is valid.

$ terraform plan
  + resource "aws_rds_cluster" "aurora" {
      + cluster_identifier  = "prod-aurora-pg"
      + engine              = "aurora-postgresql"
      + engine_version      = "15.4"
      + database_name       = "appdb"
      + deletion_protection = true
      ...
    }
```

### Solution

<details>
<summary>Click to reveal solution</summary>

```hcl
# variables.tf

variable "aurora_config" {
  description = "Aurora PostgreSQL cluster configuration"
  type = object({
    cluster_identifier    = string
    engine_version        = string
    instance_count        = number
    instance_class        = string
    database_name         = string
    backup_retention_days = number
    deletion_protection   = optional(bool, true)
    skip_final_snapshot   = optional(bool, false)
  })
}

# terraform.tfvars

aurora_config = {
  cluster_identifier    = "prod-aurora-pg"
  engine_version        = "15.4"
  instance_count        = 2
  instance_class        = "db.r7g.large"
  database_name         = "appdb"
  backup_retention_days = 7
  # deletion_protection and skip_final_snapshot use defaults
}

# main.tf

resource "aws_rds_cluster" "aurora" {
  cluster_identifier      = var.aurora_config.cluster_identifier
  engine                  = "aurora-postgresql"
  engine_version          = var.aurora_config.engine_version
  database_name           = var.aurora_config.database_name
  backup_retention_period = var.aurora_config.backup_retention_days
  deletion_protection     = var.aurora_config.deletion_protection
  skip_final_snapshot     = var.aurora_config.skip_final_snapshot
}

resource "aws_rds_cluster_instance" "aurora" {
  count               = var.aurora_config.instance_count
  cluster_identifier  = aws_rds_cluster.aurora.id
  instance_class      = var.aurora_config.instance_class
  engine              = aws_rds_cluster.aurora.engine
}
```

</details>

---

## Summary

| Type | Best For | Avoid When |
|------|----------|------------|
| `object({})` | Multi-field config blocks | Config has no structure — just use `string` |
| `optional(type, default)` | Backward-compatible extensions | Hiding required config from callers |
| `tuple([])` | Fixed positional config | Field count might grow |
| `map(object({}))` | Multiple instances of same config shape | Instances have wildly different schemas |
| `any` | Generic wrapper modules | Core infrastructure config |

---

**Next → [03 — Advanced for_each and Dynamic Blocks](./03-advanced-for-each-dynamic-blocks.md)**
