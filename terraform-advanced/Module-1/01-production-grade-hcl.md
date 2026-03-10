# 01 — Writing Production-Grade HCL (Beyond Basics)

> **Module**: 1 — Advanced HCL Patterns & Code Design  
> **Time**: ~15 minutes

---

## What & Why

Production HCL isn't just working HCL — it's HCL that survives team handoffs, environment proliferation, and 3am incidents. The patterns here eliminate the most common sources of drift, duplication, and confusion in real Terraform codebases.

---

## Real-World Use Case

> **Scenario**: You're joining a 12-person platform team at a fintech. They have 3 environments (dev/staging/prod) on AWS. The existing Terraform is a copy-paste mess — `main.tf` is 1,200 lines, variable names are inconsistent, and nobody knows if `ignore_changes` is there intentionally or by accident.

Your job: establish patterns that the whole team can follow and that Terraform itself can enforce.

---

## Core Principles

### 1. One Resource, One Responsibility

Split large `main.tf` files by resource concern — not arbitrary line counts.

```hcl
# ❌ Anti-pattern: everything in one file
# main.tf (1,200 lines of VPC, ECS, RDS, IAM mixed together)

# ✅ Production pattern: split by domain
# network.tf     — VPCs, subnets, route tables, NACLs
# compute.tf     — ECS clusters, task definitions, services
# database.tf    — RDS, parameter groups, subnet groups
# iam.tf         — roles, policies, instance profiles
# outputs.tf     — all outputs, nothing else
# variables.tf   — all input variables, nothing else
```

### 2. Explicit Over Implicit

```hcl
# ❌ Relies on default region from provider config — invisible to the reader
resource "aws_s3_bucket" "audit_logs" {
  bucket = "audit-logs-${var.env}"
}

# ✅ Explicit — intent is clear and portable
resource "aws_s3_bucket" "audit_logs" {
  bucket = "audit-logs-${var.env}-${data.aws_region.current.name}"
}

data "aws_region" "current" {}
```

### 3. Consistent Naming Conventions

```hcl
# Establish a naming convention and use locals to enforce it
locals {
  # name_prefix is used in every resource name — change once, updates everywhere
  name_prefix = "${var.project}-${var.env}-${var.region_short}"
}

resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-ecs"
}

resource "aws_rds_cluster" "main" {
  cluster_identifier = "${local.name_prefix}-aurora"
}
```

### 4. Required Tags Enforced in Code

```hcl
# Define required tags once in locals — never forget them on a resource
locals {
  common_tags = {
    Project     = var.project
    Environment = var.env
    ManagedBy   = "terraform"
    Team        = var.team
    CostCenter  = var.cost_center
  }
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags       = merge(local.common_tags, { Name = "${local.name_prefix}-vpc" })
}
```

> 💡 **Pro Tip**: Put `common_tags` in a shared `locals.tf` file. Every engineer on the team adds `merge(local.common_tags, {...})` to their resources. Cloud cost allocation reports become useful overnight.

---

## File Layout (Production Standard)

```
environments/
└── prod/
    ├── main.tf          # Provider config + terraform block
    ├── network.tf       # VPC, subnets, routing
    ├── compute.tf       # ECS/EC2/Lambda
    ├── database.tf      # RDS, ElastiCache
    ├── iam.tf           # Roles, policies
    ├── monitoring.tf    # CloudWatch, alarms, dashboards
    ├── locals.tf        # ALL locals — naming, tags, computed values
    ├── variables.tf     # ALL input variables with types + validation
    ├── outputs.tf       # ALL outputs
    └── terraform.tfvars # Environment-specific values (never secrets)
```

---

## Gotchas & Production Notes

- **Avoid `terraform.tfvars` in version control for secrets** — use `TF_VAR_*` environment variables or AWS Secrets Manager + `data` blocks instead
- **Never use `count` and `for_each` on the same resource** — pick one strategy and be consistent across the codebase
- **`depends_on` is a code smell** — if you need it often, your module boundaries are wrong; explicit references create implicit dependencies cleanly

> ⚠️ **Warning**: Mixing `count` and `for_each` on similar resources in the same module leads to state address conflicts when you refactor. Decide on `for_each` for anything that might grow beyond 1 instance, and use it from day one.

---

## Summary

| Pattern | When to Use | Watch Out For |
|---------|-------------|---------------|
| Split files by domain | Always — even small projects | Over-splitting creates navigation overhead |
| `locals` for naming | Any project with >1 resource | Locals can't reference each other circularly |
| `merge()` for tags | Every resource | Some resources don't support tags — check the docs |
| Explicit data sources | Cross-resource references | Can slow plan if data sources hit slow APIs |

---

**Next → [02 — Complex Variable Types](./02-complex-variable-types.md)**
