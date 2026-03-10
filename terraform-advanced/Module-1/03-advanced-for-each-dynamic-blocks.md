# 03 — Advanced `for_each` and Dynamic Blocks

> **Module**: 1 — Advanced HCL Patterns & Code Design  
> **Time**: ~20 minutes

---

## What & Why

`for_each` and dynamic blocks are Terraform's primary tools for eliminating repetition. Used well, they let one resource block manage 50 resources cleanly. Used poorly, they produce unreadable code that breaks on simple refactors. This section covers the advanced patterns: nested `for_each`, computed keys, and dynamic blocks with conditional logic.

---

## Real-World Use Case

> **Scenario**: You're managing a multi-tenant SaaS platform on AWS. Each tenant gets their own S3 bucket, IAM role, and CloudWatch log group. There are currently 12 tenants and new ones onboard weekly. You need to add each new tenant without touching resource blocks — only `terraform.tfvars`.

---

## Advanced `for_each` Patterns

### Pattern 1: `for_each` Over `map(object(...))`

```hcl
# variables.tf
variable "tenants" {
  type = map(object({
    tier         = string   # "starter" | "pro" | "enterprise"
    region       = string
    enable_logs  = bool
  }))
}

# terraform.tfvars
tenants = {
  acme-corp = {
    tier        = "enterprise"
    region      = "us-east-1"
    enable_logs = true
  }
  initech = {
    tier        = "pro"
    region      = "eu-west-1"
    enable_logs = false
  }
}

# main.tf — one block, all tenants
resource "aws_s3_bucket" "tenant_data" {
  for_each = var.tenants
  bucket   = "tenant-${each.key}-data-${each.value.region}"

  tags = {
    Tenant = each.key
    Tier   = each.value.tier
  }
}

resource "aws_iam_role" "tenant_role" {
  for_each = var.tenants
  name     = "tenant-${each.key}-role"
  # ... assume_role_policy
}
```

### Pattern 2: Computing `for_each` Keys with `for` Expressions

```hcl
# Sometimes your input is a list but for_each needs a map.
# Convert using a for expression — key must be unique.

variable "subnet_configs" {
  type = list(object({
    cidr = string
    az   = string
    name = string
  }))
}

# Convert list → map keyed by subnet name for stable state addresses
resource "aws_subnet" "app" {
  for_each = { for s in var.subnet_configs : s.name => s }

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = { Name = each.key }
}
```

> 💡 **Pro Tip**: When converting a list to a map for `for_each`, always key on a **stable, unique business identifier** (like `name` or `id`) — never on list index. Index-based keys break when items are inserted or removed.

### Pattern 3: Filtering with `for_each` + `if`

```hcl
# Only create CloudWatch log groups for tenants with enable_logs = true
resource "aws_cloudwatch_log_group" "tenant_logs" {
  for_each = { for k, v in var.tenants : k => v if v.enable_logs }

  name              = "/tenant/${each.key}/app"
  retention_in_days = 30
}
```

---

## Dynamic Blocks

Dynamic blocks generate repeated nested blocks within a resource — things like `ingress` rules, `lifecycle_rule`, or `logging` configurations.

### Basic Dynamic Block

```hcl
variable "sg_ingress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
}

resource "aws_security_group" "app" {
  name   = "${local.name_prefix}-app-sg"
  vpc_id = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.sg_ingress_rules
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
  }
}
```

### Conditional Dynamic Block (Feature Flags)

```hcl
variable "enable_s3_logging" {
  type    = bool
  default = false
}

variable "log_bucket_id" {
  type    = string
  default = ""
}

resource "aws_s3_bucket" "app_assets" {
  bucket = "${local.name_prefix}-assets"

  # Logging block only appears when feature is enabled
  dynamic "logging" {
    for_each = var.enable_s3_logging ? [1] : []
    content {
      target_bucket = var.log_bucket_id
      target_prefix = "s3-access-logs/${local.name_prefix}/"
    }
  }
}
```

> ⚠️ **Warning**: The `[1] : []` pattern for conditional dynamic blocks is idiomatic but confusing to newcomers. Comment it clearly — `# Include this block only when logging is enabled`. Better yet, move to a `locals` variable named `logging_enabled_list` for readability.

### Nested Dynamic Blocks

```hcl
# CodeBuild project with environment variables driven entirely by variables
variable "build_projects" {
  type = map(object({
    buildspec    = string
    compute_type = string
    env_vars     = map(string)
  }))
}

resource "aws_codebuild_project" "builds" {
  for_each = var.build_projects
  name     = each.key

  environment {
    compute_type = each.value.compute_type
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"

    dynamic "environment_variable" {
      for_each = each.value.env_vars
      content {
        name  = environment_variable.key
        value = environment_variable.value
        type  = "PLAINTEXT"
      }
    }
  }

  source {
    type      = "GITHUB"
    buildspec = each.value.buildspec
  }

  artifacts { type = "NO_ARTIFACTS" }

  service_role = aws_iam_role.codebuild.arn
}
```

---

## Gotchas & Production Notes

- **State address stability**: `for_each` uses map keys as state addresses — `aws_s3_bucket.tenant_data["acme-corp"]`. If you rename a key, Terraform sees destroy+create, not a rename. Use `moved` blocks (see Module 1-06).
- **`for_each` can't use unknown values at plan time** — if your key comes from a resource that doesn't exist yet, you'll get `Error: Invalid for_each argument`. Use a static map or `depends_on` carefully.
- **Avoid deeply nested dynamic blocks** — more than 2 levels makes the code unreadable. Refactor into sub-modules.

---

## Summary

| Pattern | When to Use | Watch Out For |
|---------|-------------|---------------|
| `for_each` on `map(object)` | Multiple similar resources | Key changes cause destroy/recreate |
| `for` expression to build map | Input is a list | Keys must be unique and stable |
| `if` filter in `for_each` | Conditional resource creation | Can't use unknown values as filter |
| Dynamic blocks | Repeated nested blocks | >2 nesting levels — extract to module |
| `[1] : []` conditional | Optional nested blocks | Comment intent clearly |

---

**Next → [04 — Locals as Logic Layers](./04-locals-as-logic-layers.md)**
