# 08 — Terraform Console for Expression Debugging

> **Module**: 1 — Advanced HCL Patterns & Code Design  
> **Time**: ~10 minutes

---

## What & Why

The Terraform console is an interactive REPL for evaluating HCL expressions against your current state and variables. It's the fastest way to debug complex `for` expressions, `locals` logic, and string interpolations — without running `terraform plan` and waiting for providers to do API calls.

---

## Real-World Use Case

> **Scenario**: You're writing a `for` expression to flatten a `map(list(string))` variable into a list of objects for `for_each`. The expression works in your head but Terraform throws a cryptic type error. Instead of guess-and-check with `terraform plan` (which hits the AWS API every time), you drop into `terraform console` and iterate in seconds.

---

## Starting the Console

```bash
# Run from your Terraform working directory
# Loads current state + variables from terraform.tfvars
terraform console
```

```
> # You're in the REPL — type expressions and press Enter
> 1 + 1
2
> "hello-${var.env}"
"hello-prod"
```

Exit with `Ctrl+D` or type `exit`.

---

## Debugging Locals and Expressions

```bash
# Suppose you have this in locals.tf:
# locals {
#   name_prefix = "${var.project}-${var.env}"
# }

> local.name_prefix
"myapp-prod"

# Test a for expression before putting it in code
> { for k, v in var.tenants : k => v.tier }
{
  "acme-corp" = "enterprise"
  "initech"   = "pro"
}

# Test filtering
> { for k, v in var.tenants : k => v if v.tier == "enterprise" }
{
  "acme-corp" = "enterprise"
}
```

---

## Testing Type Conversions

```bash
# toset converts list to set (removes duplicates, unordered)
> toset(["us-east-1a", "us-east-1b", "us-east-1a"])
toset([
  "us-east-1a",
  "us-east-1b",
])

# tomap converts a list of objects to a map
# (Useful when building for_each inputs)
> { for s in var.subnets : s.name => s }
{
  "private-1a" = {
    "az"   = "us-east-1a"
    "cidr" = "10.0.1.0/24"
    "name" = "private-1a"
  }
  ...
}
```

---

## Inspecting State

```bash
# Check resource attributes from current state
> aws_vpc.main.id
"vpc-0abc1234def56789"

> aws_vpc.main.cidr_block
"10.0.0.0/16"

# Check a for_each resource
> aws_subnet.app["us-east-1a"].id
"subnet-0abc1234def56789"

# List all addresses in state
> keys(aws_subnet.app)
[
  "us-east-1a",
  "us-east-1b",
  "us-east-1c",
]
```

---

## Debugging Complex Expressions Step by Step

```bash
# Original expression that throws an error:
# { for team, cidrs in var.team_cidrs : "${team}-${cidrs}" => cidrs }

# Step 1: Check what var.team_cidrs actually looks like
> var.team_cidrs
{
  "platform" = [
    "10.0.1.0/24",
    "10.0.2.0/24",
  ]
  "data"     = [
    "10.1.0.0/24",
  ]
}

# Step 2: Test the key expression alone
> [ for team, cidrs in var.team_cidrs : "${team}-${join(",", cidrs)}" ]
[
  "data-10.1.0.0/24",
  "platform-10.0.1.0/24,10.0.2.0/24",
]

# Step 3: Flatten to get one entry per CIDR
> flatten([for team, cidrs in var.team_cidrs : [for cidr in cidrs : { team = team, cidr = cidr }]])
[
  { "cidr" = "10.1.0.0/24", "team" = "data" },
  { "cidr" = "10.0.1.0/24", "team" = "platform" },
  { "cidr" = "10.0.2.0/24", "team" = "platform" },
]
```

> 💡 **Pro Tip**: Build complex expressions in the console one layer at a time. Get the inner loop working, then wrap it in the outer. Never try to write a 4-level nested expression in one shot.

---

## Useful Built-in Functions to Test in Console

```bash
# String functions
> upper("hello")
"HELLO"

> replace("my-project-name", "-", "_")
"my_project_name"

> format("%-10s %s", "hello", "world")
"hello      world"

# Collection functions
> length(var.availability_zones)
3

> contains(["dev", "staging", "prod"], var.env)
true

> merge({ a = 1 }, { b = 2 })
{ "a" = 1, "b" = 2 }

# CIDR functions
> cidrsubnet("10.0.0.0/16", 8, 1)
"10.0.1.0/24"

> cidrhost("10.0.1.0/24", 10)
"10.0.1.10"

# Encoding
> jsonencode({ key = "value" })
"{\"key\":\"value\"}"

> base64encode("hello terraform")
"aGVsbG8gdGVycmFmb3Jt"
```

---

## Gotchas & Production Notes

- **Console loads state at the time you start it** — if state changes (another apply runs), restart the console to see updated values
- **Console can't execute operations** — it's read-only; you can't `apply` or modify state from it
- **Variables from `terraform.tfvars` are automatically loaded** — but you can also pass `-var` flags: `terraform console -var="env=prod"`
- **Console expressions don't save anywhere** — they're ephemeral; once you find the right expression, copy it directly into your `.tf` file

---

## Summary

| Task | Console Command |
|------|----------------|
| Test a local | `local.name_prefix` |
| Test a for expression | `{ for k, v in var.map : k => v.field }` |
| Check resource attribute | `aws_vpc.main.id` |
| List for_each keys | `keys(aws_subnet.app)` |
| Test a function | `cidrsubnet("10.0.0.0/16", 8, 2)` |
| Debug type | `type(var.my_variable)` |

---

## Module 1 Complete ✅

**You've covered:**
- Production-grade HCL structure and naming conventions
- Complex variable types with `object`, `tuple`, `optional`, and `any`
- Advanced `for_each` and `dynamic` block patterns
- Locals as a logic and transformation layer
- Custom variable validation with clear error messages
- Safe resource refactoring with `moved` blocks
- Precise lifecycle control with `replace_triggered_by`, `ignore_changes`, `prevent_destroy`
- Expression debugging with `terraform console`

---

**Next Module → [Module 2: Module Design & Reusability](../../Module-2/README.md)**
