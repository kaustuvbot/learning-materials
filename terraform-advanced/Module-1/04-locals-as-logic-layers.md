# 04 — Locals as Logic Layers (Reducing Duplication)

> **Module**: 1 — Advanced HCL Patterns & Code Design  
> **Time**: ~15 minutes

---

## What & Why

`locals` are Terraform's in-module computation layer. Beyond simple string interpolation, they let you express conditional logic, data transformations, and derived configuration — keeping resource blocks clean and your variables as close to raw business intent as possible.

---

## Real-World Use Case

> **Scenario**: You manage three environments: dev, staging, prod. Dozens of settings differ per environment — instance sizes, retention periods, replica counts, feature flags. Currently this logic is scattered across resource blocks using `var.env == "prod" ? ... : ...` conditionals. The code is unreadable and error-prone.

Refactoring to a locals-as-config-layer pattern cleans this up completely.

---

## Pattern 1: Environment Configuration Map

```hcl
# locals.tf

locals {
  # All environment-specific configuration in one place
  # Change one value here — it propagates everywhere
  env_config = {
    dev = {
      instance_class        = "db.t4g.micro"
      multi_az              = false
      backup_retention_days = 1
      deletion_protection   = false
      replica_count         = 0
    }
    staging = {
      instance_class        = "db.t4g.medium"
      multi_az              = false
      backup_retention_days = 3
      deletion_protection   = false
      replica_count         = 1
    }
    prod = {
      instance_class        = "db.r7g.xlarge"
      multi_az              = true
      backup_retention_days = 30
      deletion_protection   = true
      replica_count         = 2
    }
  }

  # Derived config for this specific environment
  db = local.env_config[var.env]
}

# database.tf — clean, no conditional clutter
resource "aws_db_instance" "main" {
  instance_class      = local.db.instance_class
  multi_az            = local.db.multi_az
  backup_retention_period = local.db.backup_retention_days
  deletion_protection = local.db.deletion_protection
}
```

> 💡 **Pro Tip**: This "lookup table" pattern scales to any number of environments without adding new `if/else` branches. Adding a new environment is just adding a new map key — no resource logic changes.

---

## Pattern 2: Derived Naming and Tagging

```hcl
locals {
  # Single source of truth for naming — changes flow everywhere
  name_prefix  = "${var.project}-${var.env}"
  region_short = substr(var.aws_region, 0, 6)   # "us-eas" from "us-east-1"

  # Unique bucket names require region to avoid global collision
  bucket_prefix = "${local.name_prefix}-${local.region_short}"

  common_tags = {
    Project     = var.project
    Environment = var.env
    Region      = var.aws_region
    ManagedBy   = "terraform"
    GitRepo     = var.git_repo
  }
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "${local.bucket_prefix}-artifacts"
  tags   = merge(local.common_tags, { Purpose = "build-artifacts" })
}

resource "aws_s3_bucket" "logs" {
  bucket = "${local.bucket_prefix}-logs"
  tags   = merge(local.common_tags, { Purpose = "access-logs" })
}
```

---

## Pattern 3: Conditional Feature Flags

```hcl
locals {
  # Feature flags computed from environment + explicit overrides
  features = {
    enable_waf         = var.env == "prod" || var.force_waf
    enable_cloudtrail  = var.env != "dev"
    enable_guardduty   = var.env == "prod"
    nat_gateway_count  = var.env == "prod" ? length(var.availability_zones) : 1
  }
}

resource "aws_wafv2_web_acl_association" "main" {
  count        = local.features.enable_waf ? 1 : 0
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main[0].arn
}

resource "aws_nat_gateway" "main" {
  count         = local.features.nat_gateway_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
}
```

---

## Pattern 4: Data Transformation

```hcl
variable "allowed_cidr_blocks" {
  type = list(string)
  # Input: ["10.0.0.0/8", "172.16.0.0/12"]
}

locals {
  # Transform list into security group rule objects
  # Output drives a dynamic block — see Module 1-03
  ingress_rules = [
    for cidr in var.allowed_cidr_blocks : {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [cidr]
      description = "HTTPS from ${cidr}"
    }
  ]

  # Flatten a map of lists into a single list for for_each
  # Input: { "team-a" = ["10.0.1.0/24", "10.0.2.0/24"], "team-b" = ["10.1.0.0/24"] }
  all_team_cidrs = flatten([
    for team, cidrs in var.team_cidrs : [
      for cidr in cidrs : { team = team, cidr = cidr }
    ]
  ])
}
```

---

## Gotchas & Production Notes

- **Locals can't reference each other circularly** — `local.a` referencing `local.b` which references `local.a` is a hard error. Order your locals so dependencies flow one way.
- **Don't put secrets in locals** — they appear in state and in plan output. Use `sensitive = true` variables or external secret managers.
- **Locals don't create module outputs** — if a downstream module needs a computed value, expose it via `output`, not by expecting callers to re-derive it.

> ⚠️ **Warning**: Large locals blocks with complex `for` expressions become hard to debug. Extract the logic into a clearly named `local` at each step rather than one giant nested expression. Terraform Console (see Module 1-08) is your friend when debugging locals.

---

## Summary

| Pattern | When to Use | Watch Out For |
|---------|-------------|---------------|
| Environment config map | Per-env settings | Map keys must exactly match `var.env` values |
| Naming locals | Any project | Can't be used before they're defined |
| Feature flag locals | Conditional resources | Complex boolean expressions — test in console |
| Data transformation locals | Reshaping input for `for_each` | Deeply nested `for` expressions — split into steps |

---

**Next → [05 — Custom Validation Rules](./05-custom-validation-rules.md)**
