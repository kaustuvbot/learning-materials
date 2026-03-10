# 05 — Custom Validation Rules for Variables

> **Module**: 1 — Advanced HCL Patterns & Code Design  
> **Time**: ~10 minutes

---

## What & Why

Type constraints (`string`, `number`, `list(string)`) catch the wrong shape of input. Validation rules catch the wrong *value* — and they surface the problem at `terraform plan` with a human-readable message, before any infrastructure is touched.

---

## Real-World Use Case

> **Scenario**: A junior engineer on your platform team passed `env = "production"` instead of `"prod"` to a module. The module silently used the wrong IAM policy, the wrong S3 bucket, and the wrong RDS instance class. The mistake wasn't caught until a post-deploy audit. Custom validation would have caught it at plan time with a clear error.

---

## Syntax

```hcl
variable "env" {
  type        = string
  description = "Deployment environment"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "env must be one of: dev, staging, prod. Got: '${var.env}'."
  }
}
```

---

## Production Validation Patterns

### Enum-style Constraints

```hcl
variable "instance_tier" {
  type = string

  validation {
    condition     = contains(["small", "medium", "large", "xlarge"], var.instance_tier)
    error_message = "instance_tier must be small, medium, large, or xlarge."
  }
}
```

### CIDR Format Validation

```hcl
variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"

  validation {
    # can() returns true if the expression doesn't throw an error
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block (e.g. 10.0.0.0/16)."
  }
}
```

### Length and Format Constraints

```hcl
variable "project" {
  type        = string
  description = "Project name — used as prefix in all resource names"

  validation {
    condition     = length(var.project) >= 2 && length(var.project) <= 20
    error_message = "project must be between 2 and 20 characters."
  }

  validation {
    # regex returns the match or throws — can() wraps the error
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project))
    error_message = "project must start with a letter and contain only lowercase letters, numbers, and hyphens."
  }
}
```

### Cross-Field Validation (Terraform 1.9+)

```hcl
# In Terraform 1.9+, validation blocks can reference other variables
variable "min_capacity" {
  type = number
}

variable "max_capacity" {
  type = number

  validation {
    condition     = var.max_capacity >= var.min_capacity
    error_message = "max_capacity (${var.max_capacity}) must be >= min_capacity (${var.min_capacity})."
  }
}
```

> 💡 **Pro Tip**: Add `error_message` values that include the actual invalid value using `${var.name}`. "Invalid value" is useless. `"env must be dev, staging, or prod. Got: 'production'."` tells the user exactly what to fix.

### Validating Object Fields

```hcl
variable "rds_config" {
  type = object({
    instance_class        = string
    backup_retention_days = number
  })

  validation {
    condition     = var.rds_config.backup_retention_days >= 1 && var.rds_config.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 1 and 35 (AWS RDS limit)."
  }

  validation {
    condition     = can(regex("^db\\.", var.rds_config.instance_class))
    error_message = "instance_class must start with 'db.' (e.g. db.t4g.micro, db.r7g.xlarge)."
  }
}
```

---

## Gotchas & Production Notes

- **Multiple `validation` blocks are allowed** — and preferred over combining conditions with `&&`. One validation = one clear error message.
- **Validation runs at plan time, not at `variable` definition time** — so `can()` and `try()` are safe to use (they won't panic on bad input, they just return false/default).
- **Cross-variable validation has limits** — you can't reference `var.other_variable` in a validation block before Terraform 1.9. Use `precondition` in resource `lifecycle` blocks as a workaround for earlier versions.

> ⚠️ **Warning**: Don't use validation to enforce cloud-specific limits you're not sure about (e.g. "max 5 security groups per ENI"). These limits change and vary by account. Validate business rules, not AWS internals.

---

## Summary

| Pattern | Function Used | Good For |
|---------|--------------|----------|
| Enum check | `contains()` | Allowed value sets |
| Format check | `can(regex(...))` | Names, CIDRs, ARNs |
| Range check | `>= && <=` | Numeric bounds |
| Existence check | `can(...)` | Valid CIDR, valid JSON |
| Cross-field | `var.other >= var.this` | Capacity, date ranges (Terraform 1.9+) |

---

**Next → [06 — Moved Blocks](./06-moved-blocks.md)**
