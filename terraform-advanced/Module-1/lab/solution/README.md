# Module 1 Lab — Solution

This directory contains the complete, working solution for the Module 1 lab.

**Only open this after attempting each exercise yourself.**

---

## Files

| File | Key patterns demonstrated |
|------|--------------------------|
| `variables.tf` | `map(object(...))` with `optional()` fields; two validation blocks on `project`; enum validation on `env` |
| `locals.tf` | `name_prefix` single source of truth; `env_config` lookup table; `current_env` derivation; `sg_ingress_rules` transformation |
| `main.tf` | `for_each` on `map(object)`; filtered `for_each` with `if`; `dynamic "ingress"` block; `ignore_changes` + `prevent_destroy` lifecycle hooks; Container Insights setting block |
| `moved.tf` | `moved` block declaring security group rename — no destroy, no downtime |
| `terraform.tfvars` | Complete variable values matching all three services |

---

## How to verify the solution

```bash
terraform init
terraform validate
# Expected: Success! The configuration is valid.

terraform plan
# Expected: Plan: 7 to add, 0 to change, 0 to destroy.
# Notice: scheduler has no log group (enable_logs = false)
```

---

## Key differences from the starter

- `ecs_services` has a proper `map(object(...))` type — rejects malformed input at plan time
- `env_config` lookup table replaces scattered `var.env == "prod" ? ... : ...` ternaries
- `for_each` on log groups is filtered — `scheduler` gets no log group because `enable_logs = false`
- `dynamic "ingress"` block — adding a new rule means editing `locals.tf` only, not the SG resource block
- `lifecycle { ignore_changes = [desired_count] }` — Auto Scaling can adjust tasks without Terraform fighting it on the next apply
- `moved` block — state address updated safely, no security group recreation

→ Return to the lab: [`LAB_RUNBOOK.md`](../../LAB_RUNBOOK.md)
