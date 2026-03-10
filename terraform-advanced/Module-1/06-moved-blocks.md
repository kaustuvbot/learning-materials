# 06 — Moved Blocks for Safe Resource Refactoring

> **Module**: 1 — Advanced HCL Patterns & Code Design  
> **Time**: ~10 minutes

---

## What & Why

Renaming a resource, moving it into a module, or changing from `count` to `for_each` used to mean Terraform would destroy and recreate the resource — a serious risk for stateful infrastructure like RDS, EBS volumes, or ECS services. `moved` blocks (introduced in Terraform 1.1) tell Terraform that a resource was renamed in code but is the same physical resource in state.

---

## Real-World Use Case

> **Scenario**: You built an ECS cluster early in the project as `aws_ecs_cluster.main`. Six months later, you're extracting all compute resources into a reusable module called `module.compute`. Terraform sees `aws_ecs_cluster.main` being deleted and `module.compute.aws_ecs_cluster.main` being created. Without a `moved` block, that's a production outage.

---

## Basic `moved` Block

```hcl
# Before (old address in state):
# aws_ecs_cluster.main

# After (new address after refactor):
# module.compute.aws_ecs_cluster.main

# Declare the move — Terraform updates state, no destroy/recreate
moved {
  from = aws_ecs_cluster.main
  to   = module.compute.aws_ecs_cluster.main
}
```

When you run `terraform plan`, Terraform shows:

```
# aws_ecs_cluster.main has moved to module.compute.aws_ecs_cluster.main
```

No destroy. No recreate. State address updated in-place.

---

## Common Refactoring Scenarios

### 1. Renaming a Resource

```hcl
# Old name
# resource "aws_security_group" "app" { ... }

# New name (better clarity)
# resource "aws_security_group" "ecs_tasks" { ... }

moved {
  from = aws_security_group.app
  to   = aws_security_group.ecs_tasks
}
```

### 2. `count` → `for_each` Migration

```hcl
# Old: using count (fragile — index-based state addresses)
resource "aws_iam_user" "deployers" {
  count = 3
  name  = "deployer-${count.index}"
}
# State addresses: aws_iam_user.deployers[0], [1], [2]

# New: using for_each (stable — name-based addresses)
resource "aws_iam_user" "deployers" {
  for_each = toset(["alice", "bob", "carol"])
  name     = each.key
}
# State addresses: aws_iam_user.deployers["alice"], ["bob"], ["carol"]

# Declare the moves explicitly
moved {
  from = aws_iam_user.deployers[0]
  to   = aws_iam_user.deployers["alice"]
}

moved {
  from = aws_iam_user.deployers[1]
  to   = aws_iam_user.deployers["bob"]
}

moved {
  from = aws_iam_user.deployers[2]
  to   = aws_iam_user.deployers["carol"]
}
```

> ⚠️ **Warning**: This migration only works if the mapping is known. If your `count` resources were dynamically ordered (from a sorted list), verify the mapping carefully before running `terraform apply`. A wrong `moved` block causes Terraform to update the wrong resource.

### 3. Moving into a Module

```hcl
# Moving standalone resources into a new module
moved {
  from = aws_vpc.main
  to   = module.networking.aws_vpc.main
}

moved {
  from = aws_subnet.public[0]
  to   = module.networking.aws_subnet.public["us-east-1a"]
}
```

### 4. Moving Between Module Versions (Module Refactor)

```hcl
# If a module internally renames a resource across versions,
# the module author adds a moved block inside the module.
# Callers get the safe rename automatically.

# Inside module source (modules/ecs/main.tf):
moved {
  from = aws_ecs_service.app      # old internal name
  to   = aws_ecs_service.service  # new internal name
}
```

> 💡 **Pro Tip**: As a module author, you can include `moved` blocks in your module to handle internal refactors without forcing all callers to do state surgery. This is one of the most underused features for public/shared modules.

---

## Lifecycle of `moved` Blocks

```
1. Write moved block
2. Run terraform plan → verify only moves, no destroy/create
3. Run terraform apply → state updated
4. Keep moved blocks in code for one release cycle (so teammates can apply)
5. Remove moved blocks in a follow-up PR — they serve no purpose after state is updated
```

> ⚠️ **Warning**: Removing a `moved` block before everyone has applied it will cause Terraform to show a destroy for that resource for anyone who applies after removal. Keep moved blocks for at least one sprint after the initial apply.

---

## Gotchas & Production Notes

- **`moved` blocks don't work across providers** — you can't move a resource from one AWS account's state to another
- **Can't move between resource types** — only within the same resource type; `aws_security_group.old → aws_security_group.new` is valid; `aws_security_group → aws_vpc_security_group` is not
- **Multiple moves in one file are fine** — Terraform processes all `moved` blocks before planning

---

## Summary

| Use Case | `from` | `to` |
|----------|--------|------|
| Rename resource | `aws_sg.app` | `aws_sg.ecs_tasks` |
| Extract to module | `aws_vpc.main` | `module.net.aws_vpc.main` |
| count → for_each | `aws_iam_user.deployers[0]` | `aws_iam_user.deployers["alice"]` |
| Module-internal refactor | Put `moved` inside module | Callers get it automatically |

---

**Next → [07 — Lifecycle Hooks](./07-lifecycle-hooks.md)**
