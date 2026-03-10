# Module 1: Advanced HCL Patterns & Code Design

> **Prerequisite**: Terraform basics — `init`, `plan`, `apply`, variables, outputs, simple providers  
> **Outcome**: Write production-grade HCL that is readable, DRY, safe to refactor, and debuggable  
> **Time**: 1–2 hours

---

## Overview

Writing Terraform that works is easy. Writing Terraform that a team of 10 can maintain across 50 environments without breaking production is a different discipline entirely. This module covers the HCL patterns that separate toy configs from battle-tested infrastructure code.

---

## Subtopics

| # | File | Description |
|---|------|-------------|
| 1 | [01-production-grade-hcl.md](./01-production-grade-hcl.md) | Writing production-grade HCL (beyond basics) |
| 2 | [02-complex-variable-types.md](./02-complex-variable-types.md) | Complex variable types: objects, tuples, any |
| 3 | [03-advanced-for-each-dynamic-blocks.md](./03-advanced-for-each-dynamic-blocks.md) | Advanced `for_each` and dynamic blocks |
| 4 | [04-locals-as-logic-layers.md](./04-locals-as-logic-layers.md) | Locals as logic layers (reducing duplication) |
| 5 | [05-custom-validation-rules.md](./05-custom-validation-rules.md) | Custom validation rules for variables |
| 6 | [06-moved-blocks.md](./06-moved-blocks.md) | Moved blocks for safe resource refactoring |
| 7 | [07-lifecycle-hooks.md](./07-lifecycle-hooks.md) | Lifecycle hooks: `replace_triggered_by`, `ignore_changes` |
| 8 | [08-terraform-console.md](./08-terraform-console.md) | Terraform console for expression debugging |

---

## Lab

- [Starter](./lab/starter/) — incomplete code for hands-on practice  
- [Solution](./lab/solution/) — complete working solution  

---

## Next Module → Module 2: Module Design & Reusability
