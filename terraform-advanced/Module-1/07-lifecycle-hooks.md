# 07 — Lifecycle Hooks: `replace_triggered_by`, `ignore_changes`

> **Module**: 1 — Advanced HCL Patterns & Code Design  
> **Time**: ~15 minutes

---

## What & Why

Terraform's default behavior — detect drift, recreate on attribute change — isn't always right for production. Lifecycle meta-arguments give you precise control: replace *this* resource when *that* resource changes, ignore out-of-band changes, prevent accidental deletion, or always recreate before destroying.

---

## Real-World Use Case

> **Scenario**: Your ECS task definition is updated whenever the container image digest changes (pushed by a CI pipeline, not Terraform). You want the ECS *service* to redeploy when the task definition changes, but Terraform doesn't automatically connect those two resources. Separately, your RDS instance's `password` is rotated by AWS Secrets Manager — Terraform shouldn't try to "fix" it during every plan.

---

## `ignore_changes`

Tells Terraform to ignore specific attribute changes after initial creation.

```hcl
resource "aws_ecs_service" "api" {
  name            = "${local.name_prefix}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.desired_count

  lifecycle {
    # desired_count is managed by Application Auto Scaling at runtime.
    # Without this, every terraform apply resets it to var.desired_count,
    # fighting the autoscaler.
    ignore_changes = [desired_count]
  }
}
```

```hcl
resource "aws_db_instance" "main" {
  identifier     = "${local.name_prefix}-rds"
  instance_class = var.db_instance_class
  password       = var.db_password_initial  # Only used on creation

  lifecycle {
    # Password is rotated by AWS Secrets Manager after initial creation.
    # Ignore it to prevent Terraform from reverting to the initial value.
    ignore_changes = [password]
  }
}
```

> ⚠️ **Warning**: `ignore_changes = [all]` is almost always wrong. It tells Terraform to ignore *all* configuration drift on the resource — effectively making it unmanaged. Use it only as a last resort for resources managed by external systems entirely, and document why.

---

## `replace_triggered_by`

Force a resource to be replaced (destroy + create) when another resource or attribute changes — even if the resource itself hasn't changed.

```hcl
# ECS task definition is updated when a new image is pushed.
# The ECS service needs to redeploy, but Terraform doesn't automatically
# know that a task definition version bump means the service needs replacing.

resource "aws_ecs_service" "api" {
  name            = "${local.name_prefix}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn

  lifecycle {
    # When the task definition is replaced (new version), replace the service too.
    # This forces a redeployment with zero downtime (with proper rolling config).
    replace_triggered_by = [aws_ecs_task_definition.api]
  }
}
```

```hcl
# Trigger EC2 instance replacement when its launch template changes.
# Without this, the instance keeps running the old config until manually replaced.

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.bastion_instance_type

  launch_template {
    id      = aws_launch_template.bastion.id
    version = aws_launch_template.bastion.latest_version
  }

  lifecycle {
    replace_triggered_by = [aws_launch_template.bastion]
  }
}
```

> 💡 **Pro Tip**: `replace_triggered_by` accepts specific attributes too, not just whole resources. Use `replace_triggered_by = [aws_launch_template.bastion.latest_version]` to be more precise and only trigger on version changes, not tag-only updates to the launch template.

---

## `create_before_destroy`

Creates the replacement resource before destroying the old one. Critical for resources that other resources depend on (like SSL certs, security groups, launch templates).

```hcl
resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    # New cert must exist before ALB listener can switch to it.
    # Without this: old cert deleted → ALB breaks → new cert created → ALB fixed.
    # Outage window: seconds to minutes.
    create_before_destroy = true
  }
}
```

---

## `prevent_destroy`

Refuses to destroy the resource. Terraform plan fails with an error if any plan would destroy it.

```hcl
resource "aws_rds_cluster" "main" {
  cluster_identifier = "${local.name_prefix}-aurora"
  # ... other config

  lifecycle {
    # Prevents accidental `terraform destroy` from wiping production database.
    # Remove this temporarily only when intentionally decommissioning.
    prevent_destroy = true
  }
}
```

> ⚠️ **Warning**: `prevent_destroy = true` only works if the Terraform config containing it is applied. If someone removes the resource block entirely from the config (without removing `prevent_destroy` first), Terraform will destroy it because the block is gone. It's a guardrail, not a guarantee.

---

## `precondition` and `postcondition` (Terraform 1.2+)

Validate assumptions before and after resource operations.

```hcl
data "aws_ami" "app" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["myapp-*"]
  }

  lifecycle {
    postcondition {
      condition     = self.architecture == "x86_64"
      error_message = "AMI ${self.id} is ${self.architecture}, but only x86_64 is supported for this instance type."
    }
  }
}
```

---

## Gotchas & Production Notes

- **`replace_triggered_by` causes destroy+create by default** — ensure the resource has `create_before_destroy = true` if downtime is unacceptable
- **`ignore_changes` doesn't prevent drift detection in plan** — Terraform still *shows* the drift, it just doesn't act on it; use this to communicate intentionally to the team
- **`prevent_destroy` doesn't protect against `terraform state rm`** — state removal bypasses lifecycle rules entirely

---

## Summary

| Hook | Effect | Use When |
|------|--------|----------|
| `ignore_changes = [attr]` | Skip drift on specific attributes | External system owns the value |
| `ignore_changes = [all]` | Skip all drift (dangerous) | Resource fully managed externally |
| `replace_triggered_by` | Force replace on dependency change | Deployments, launch template updates |
| `create_before_destroy` | New resource first, then destroy old | Anything with dependents |
| `prevent_destroy` | Plan fails if destroy is planned | Stateful production resources |
| `precondition` | Validate assumptions before apply | Data source validity, AMI correctness |

---

**Next → [08 — Terraform Console for Expression Debugging](./08-terraform-console.md)**
