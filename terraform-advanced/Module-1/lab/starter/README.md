# Module 1 Lab — Starter

> **Scenario**: Refactor a fintech platform's ECS configuration using all eight HCL patterns from Module 1.
>
> **Work through exercises in order** — each one builds on the previous. Follow the [LAB_RUNBOOK.md](../../LAB_RUNBOOK.md) for full instructions.

---

## Files

| File | What to complete |
|------|-----------------|
| `variables.tf` | Add `map(object(...))` type for `ecs_services` (Ex 2), add validation blocks (Ex 5) |
| `locals.tf` | Naming locals, env config map, ingress rules (Ex 4) |
| `main.tf` | `for_each`, dynamic ingress block, lifecycle hooks (Ex 3, 7) |
| `moved.tf` | Declare resource rename (Ex 6) |
| `terraform.tfvars.example` | Copy to `terraform.tfvars` and set `vpc_id` |

---

## Quick Start

```bash
cp terraform.tfvars.example terraform.tfvars
# Set vpc_id to a real VPC in your AWS account

terraform init
terraform validate  # errors expected until TODOs are completed
```

---

## What You're Building

A production-grade ECS configuration with 3 services (`api-gateway`, `worker`, `scheduler`) — typed variables, filtered log groups, dynamic security group rules, lifecycle hooks, validation, and a safe resource rename via `moved` block.

→ Full walkthrough: [`LAB_RUNBOOK.md`](../../LAB_RUNBOOK.md)
→ Reference solution: [`../solution/`](../solution/)
