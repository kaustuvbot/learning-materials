# Module 1 Lab Runbook — Advanced HCL Patterns & Code Design

> **Scenario**: You're a platform engineer at a fintech startup. You're refactoring a messy Terraform config that manages ECS services across three environments. By the end of this lab, you'll have a production-grade configuration demonstrating all eight patterns from Module 1.
>
> **What you'll build**: ECS Cluster + 3 services, CloudWatch Log Groups (filtered), Security Group (dynamic ingress rules) — all driven from typed variables with validation, locals-as-logic, lifecycle hooks, and a moved block.
>
> **Primary verification**: `terraform validate` + `terraform plan` (no AWS account required for exercises 1–7)
>
> **Full apply**: Requires a real AWS VPC ID. Costs ~$0 at plan time; ECS/CloudWatch resources are created on apply.
>
> **Time**: ~60–90 minutes

---

## Prerequisites

- Terraform v1.9+ installed (`terraform version`)
- AWS CLI configured — `aws sts get-caller-identity` returns your account
- Git (optional — useful for tracking your changes per exercise)

---

## Setup

```bash
# Navigate to the starter directory
cd Module-1/lab/starter/

# Copy the example vars file
cp terraform.tfvars.example terraform.tfvars

# Open terraform.tfvars and set vpc_id to a real VPC in your AWS account
# Leave all other values as-is for now

# Initialise — downloads the AWS provider
terraform init
```

> ⚠️ **Expected on first run**: `terraform validate` will report errors. The starter code has intentional `# TODO` gaps. You'll fix them one exercise at a time.

---

## How to Use This Runbook

Each exercise below maps directly to a subtopic file. The workflow for each:

1. **Read** the linked subtopic file first
2. **Open** the relevant starter `.tf` file
3. **Complete** the `# TODO` blocks described in the exercise
4. **Verify** with the command shown — `terraform validate` or `terraform console`
5. **Reveal** the answer only after attempting it yourself

Work through exercises **in order** — each one builds on the previous.

---

## Exercise 1 — Production-Grade HCL Structure

> **Read first**: [`01-production-grade-hcl.md`](../01-production-grade-hcl.md)

**Objective**: Understand why the starter code is structured the way it is and identify the patterns in action.

### Task

Examine the starter file layout:

```
lab/starter/
├── variables.tf      ← all input variables in one file
├── locals.tf         ← all locals in one file
├── main.tf           ← resource blocks, split by concern
├── moved.tf          ← refactoring declarations, isolated
└── terraform.tfvars.example
```

Answer these questions (no code changes required):

1. Why is `locals.tf` a separate file instead of putting locals directly in `main.tf`?
2. The starter has `vpc_id` as a variable rather than hard-coding it. What naming convention principle does this follow?
3. Look at `main.tf`. Every resource uses `local.name_prefix` for naming. Where should that local be defined, and why does centralising it matter?

### What to notice

Open `main.tf` — every resource name follows the pattern `${local.name_prefix}-<resource-type>`. When `var.project` or `var.env` changes, every resource name updates automatically. This is the single source of truth principle in action.

---

## Exercise 2 — Complex Variable Types

> **Read first**: [`02-complex-variable-types.md`](../02-complex-variable-types.md)

**Objective**: Replace `type = any` with a proper `map(object(...))` type definition for the `ecs_services` variable.

### Task

Open `variables.tf`. Find the `ecs_services` variable — it currently has `type = any`. Replace it with a typed definition:

```hcl
variable "ecs_services" {
  description = "Map of ECS service configurations"

  # TODO: Replace 'type = any' with map(object({...}))
  # Fields needed:
  # - cpu (number)
  # - memory (number)
  # - port (number)
  # - health_check_path (string)
  # - desired_count (number)
  # - enable_logs   (bool, optional, default true)
  # - enable_autoscaling (bool, optional, default false)
  type = any  # ← replace this
}
```

### Verify

```bash
terraform validate
# Expected: Success! The configuration is valid.
```

### Why this matters

With `type = any`, Terraform accepts `ecs_services = "oops"` without complaint. With `map(object(...))`, a misconfigured service entry fails at plan time with a clear type error — before any API call is made.

<details>
<summary>Reveal answer</summary>

```hcl
variable "ecs_services" {
  description = "Map of ECS service configurations"
  type = map(object({
    cpu                = number
    memory             = number
    port               = number
    health_check_path  = string
    desired_count      = number
    enable_logs        = optional(bool, true)
    enable_autoscaling = optional(bool, false)
  }))
}
```

</details>

---

## Exercise 3 — for_each and Dynamic Blocks

> **Read first**: [`03-advanced-for-each-dynamic-blocks.md`](../03-advanced-for-each-dynamic-blocks.md)

**Objective**: Wire up the two incomplete resource blocks in `main.tf` using `for_each` and a `dynamic` block.

### Task A — Filtered for_each on log groups

Find `aws_cloudwatch_log_group.service_logs` in `main.tf`. It has a `# TODO` where `for_each` should be. Add a filtered expression that only creates a log group for services where `enable_logs = true`:

```hcl
resource "aws_cloudwatch_log_group" "service_logs" {
  # TODO: for_each — only services with enable_logs = true
  # Hint: { for k, v in var.ecs_services : k => v if ??? }

  name              = "/ecs/${local.name_prefix}/${each.key}"
  retention_in_days = local.current_env.log_retention_days
  tags              = local.common_tags
}
```

### Task B — Dynamic ingress block on security group

Find `aws_security_group.ecs_tasks`. Add a `dynamic "ingress"` block driven by `local.sg_ingress_rules`:

```hcl
resource "aws_security_group" "ecs_tasks" {
  # ...
  # TODO: dynamic "ingress" block
  # for_each = local.sg_ingress_rules
  # content block needs: from_port, to_port, protocol, cidr_blocks, description
}
```

### Verify

```bash
terraform validate
# Expected: Success! The configuration is valid.

terraform plan
# You should see one log group per service that has enable_logs = true
# Check: the scheduler service has enable_logs = false — no log group should appear for it
```

<details>
<summary>Reveal answer</summary>

```hcl
# Log groups — filtered
resource "aws_cloudwatch_log_group" "service_logs" {
  for_each = { for k, v in var.ecs_services : k => v if v.enable_logs }

  name              = "/ecs/${local.name_prefix}/${each.key}"
  retention_in_days = local.current_env.log_retention_days
  tags              = local.common_tags
}

# Security group — dynamic ingress
resource "aws_security_group" "ecs_tasks" {
  name   = "${local.name_prefix}-ecs-tasks-sg"
  vpc_id = var.vpc_id

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
    description = "Allow all outbound"
  }

  tags = local.common_tags
}
```

</details>

---

## Exercise 4 — Locals as Logic Layers

> **Read first**: [`04-locals-as-logic-layers.md`](../04-locals-as-logic-layers.md)

**Objective**: Complete `locals.tf` — the naming locals, the environment config map, and the ingress rules transformation.

### Task A — Naming and tags

Fill in `name_prefix` and `common_tags`:

```hcl
locals {
  # TODO: "${var.project}-${var.env}"
  name_prefix = ""

  # TODO: map with Project, Environment, ManagedBy = "terraform"
  common_tags = {}
}
```

### Task B — Environment config map

Complete the `env_config` lookup table and the `current_env` reference:

```hcl
locals {
  env_config = {
    dev = {
      # TODO: log_retention_days = 7, container_insights = false, enable_deletion_protection = false
    }
    staging = {
      # TODO: log_retention_days = 14, container_insights = false, enable_deletion_protection = false
    }
    prod = {
      # TODO: log_retention_days = 90, container_insights = true, enable_deletion_protection = true
    }
  }

  # TODO: Look up the current environment's config
  current_env = {}  # ← replace
}
```

### Task C — Ingress rules transformation

Complete `sg_ingress_rules` as a list of two objects (HTTP on 80, HTTPS on 443):

```hcl
locals {
  # TODO: list of ingress rule objects for ports 80 and 443
  # Each object: from_port, to_port, protocol, cidr_blocks, description
  sg_ingress_rules = []
}
```

### Verify

```bash
terraform validate
terraform plan
# You should now see the ECS cluster setting block using container_insights from the env config
```

<details>
<summary>Reveal answer</summary>

```hcl
locals {
  name_prefix = "${var.project}-${var.env}"

  common_tags = {
    Project     = var.project
    Environment = var.env
    ManagedBy   = "terraform"
  }

  env_config = {
    dev = {
      log_retention_days         = 7
      container_insights         = false
      enable_deletion_protection = false
    }
    staging = {
      log_retention_days         = 14
      container_insights         = false
      enable_deletion_protection = false
    }
    prod = {
      log_retention_days         = 90
      container_insights         = true
      enable_deletion_protection = true
    }
  }

  current_env = local.env_config[var.env]

  sg_ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP inbound"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS inbound"
    }
  ]
}
```

</details>

---

## Exercise 5 — Custom Validation Rules

> **Read first**: [`05-custom-validation-rules.md`](../05-custom-validation-rules.md)

**Objective**: Add validation blocks to `project` and `env` in `variables.tf` so bad values fail at plan time with clear errors.

### Task A — Validate `project`

Add two validation blocks:

```hcl
variable "project" {
  type        = string
  description = "Project name — used as prefix in all resource names"

  # TODO: Validation 1 — length between 2 and 20 characters
  # TODO: Validation 2 — must match ^[a-z][a-z0-9-]*$ (lowercase, starts with letter)
}
```

### Task B — Validate `env`

```hcl
variable "env" {
  type        = string
  description = "Deployment environment"

  # TODO: Validation — must be one of: dev, staging, prod
  # Include the invalid value in the error message: "Got: '${var.env}'"
}
```

### Test the validation

```bash
# Test with an invalid env value — plan should fail with a clear error
terraform plan -var="env=production"

# Expected error:
# │ Error: Invalid value for variable
# │   env must be one of: dev, staging, prod. Got: 'production'.
```

<details>
<summary>Reveal answer</summary>

```hcl
variable "project" {
  type        = string
  description = "Project name — used as prefix in all resource names"

  validation {
    condition     = length(var.project) >= 2 && length(var.project) <= 20
    error_message = "project must be between 2 and 20 characters."
  }

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project))
    error_message = "project must start with a letter and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "env" {
  type        = string
  description = "Deployment environment"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "env must be one of: dev, staging, prod. Got: '${var.env}'."
  }
}
```

</details>

---

## Exercise 6 — Moved Blocks

> **Read first**: [`06-moved-blocks.md`](../06-moved-blocks.md)

**Objective**: Write a `moved` block in `moved.tf` that renames a resource without destroying it.

### The scenario

When this project was first applied, the security group was named `aws_security_group.app`. It was later renamed to `aws_security_group.ecs_tasks` to better reflect its purpose. Without a `moved` block, Terraform would destroy the old security group and create a new one — taking down all ECS tasks in the process.

### Task

Open `moved.tf`. Write the `moved` block:

```hcl
# moved.tf

# TODO: Declare the rename so Terraform updates the state address
# rather than destroying and recreating the security group.
#
# moved {
#   from = ???
#   to   = ???
# }
```

### Verify (conceptual)

If this configuration had previously been applied with `aws_security_group.app`, running `terraform plan` after adding this `moved` block would show:

```
# aws_security_group.app has moved to aws_security_group.ecs_tasks
```

No destroy. No recreate.

> 💡 Since this is a fresh configuration (never applied as `aws_security_group.app`), Terraform won't show a move in the plan output — but the block is correct and would function on a real migration.

<details>
<summary>Reveal answer</summary>

```hcl
moved {
  from = aws_security_group.app
  to   = aws_security_group.ecs_tasks
}
```

</details>

---

## Exercise 7 — Lifecycle Hooks

> **Read first**: [`07-lifecycle-hooks.md`](../07-lifecycle-hooks.md)

**Objective**: Add a `lifecycle` block to the ECS service resource so that `desired_count` changes made by Application Auto Scaling aren't overwritten on every apply.

### Task

Find `aws_ecs_service.services` in `main.tf`. It has an empty `lifecycle {}` block. Complete it:

```hcl
resource "aws_ecs_service" "services" {
  for_each      = var.ecs_services
  name          = each.key
  cluster       = aws_ecs_cluster.main.id
  desired_count = each.value.desired_count

  lifecycle {
    # TODO: Ignore changes to desired_count
    # Reason: Application Auto Scaling adjusts this at runtime.
    # Without ignore_changes, every terraform apply resets the count,
    # fighting the autoscaler mid-incident.
  }
}
```

### Bonus

Add a second lifecycle block argument to `aws_ecs_cluster.main` that prevents accidental deletion in production:

```hcl
resource "aws_ecs_cluster" "main" {
  # ...
  lifecycle {
    # TODO: Prevent destroy when env is prod
    # Hint: prevent_destroy is a bool — can you combine it with a condition?
    # (Spoiler: you can't use var.env directly here — see the reveal for why)
  }
}
```

<details>
<summary>Reveal answer</summary>

```hcl
# ECS service — ignore autoscaling-managed count
resource "aws_ecs_service" "services" {
  for_each      = var.ecs_services
  name          = each.key
  cluster       = aws_ecs_cluster.main.id
  desired_count = each.value.desired_count

  lifecycle {
    ignore_changes = [desired_count]
  }
}
```

```hcl
# Bonus: prevent_destroy doesn't support dynamic values (var.env).
# It must be a literal bool. The production pattern is:
# - Set prevent_destroy = true in the prod environment's tfvars workspace
# - Or use a separate root module for prod with it hardcoded
# For this lab, set it to true to see it work:

resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = local.current_env.container_insights ? "enabled" : "disabled"
  }

  tags = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

# To test: run `terraform plan -destroy` — it will fail with:
# │ Error: Instance cannot be destroyed
# │ prevent_destroy is set to true
```

</details>

---

## Exercise 8 — Terraform Console

> **Read first**: [`08-terraform-console.md`](../08-terraform-console.md)

**Objective**: Use `terraform console` to inspect your configuration and debug expressions interactively.

### Prerequisites

Your configuration must pass `terraform validate` before the console can load variables.

```bash
terraform console
```

### Tasks — run each in the console

**A. Inspect locals**

```hcl
> local.name_prefix
# Expected: "fintech-platform-dev"

> local.current_env
# Expected: { container_insights = false, enable_deletion_protection = false, log_retention_days = 7 }
```

**B. Preview the filtered for_each**

```hcl
# Which services get a log group?
> { for k, v in var.ecs_services : k => v.enable_logs }
# Expected: { "api-gateway" = true, "scheduler" = false, "worker" = true }

# Simulate the filtered for_each
> { for k, v in var.ecs_services : k => v if v.enable_logs }
# Expected: map with api-gateway and worker only — scheduler excluded
```

**C. Test the ingress rules transformation**

```hcl
# Preview what the dynamic block will iterate over
> local.sg_ingress_rules
# Expected: list of 2 objects with from_port, to_port, protocol, cidr_blocks, description
```

**D. Debug a new expression**

Write a `for` expression in the console that produces a map of service names to their CPU allocation:

```hcl
> { for k, v in var.ecs_services : k => v.cpu }
# Expected: { "api-gateway" = 512, "scheduler" = 256, "worker" = 1024 }
```

Exit the console with `Ctrl+D`.

---

## Final Lab

All exercises are complete. Your starter code should now pass `terraform validate` with no errors.

### Run the full plan

```bash
terraform validate
# Expected: Success! The configuration is valid.

terraform plan -out=tfplan
```

### Expected plan summary

```
Plan: 7 to add, 0 to change, 0 to destroy.

Resources:
  + aws_ecs_cluster.main                          (1)
  + aws_ecs_service.services["api-gateway"]       (1)
  + aws_ecs_service.services["worker"]            (1)
  + aws_ecs_service.services["scheduler"]         (1)
  + aws_cloudwatch_log_group.service_logs["api-gateway"]  (1)
  + aws_cloudwatch_log_group.service_logs["worker"]       (1)
  + aws_security_group.ecs_tasks                  (1)
```

Notice: `scheduler` has no log group — because `enable_logs = false`.

### Apply (optional — requires real AWS VPC)

Update `terraform.tfvars` with a real `vpc_id`, then:

```bash
terraform apply tfplan
```

### Compare with the solution

```bash
diff -r ../starter/ ../solution/
```

Review any differences against your implementation.

---

## Cleanup

Run the following to destroy all resources created during this lab:

```bash
terraform destroy
```

Type `yes` when prompted.

> ⚠️ If `prevent_destroy = true` is set on `aws_ecs_cluster.main` (Exercise 7 bonus), you'll see an error. Temporarily comment out the `prevent_destroy` line and run `terraform destroy` again.

**Resources destroyed**: ECS Cluster, ECS Services (×3), CloudWatch Log Groups (×2), Security Group

**Cost**: ECS clusters and services have no idle cost. CloudWatch log groups cost ~$0.03/GB/month — negligible for a short lab. Total expected cost for a <1 hour lab: **< $0.01**.
