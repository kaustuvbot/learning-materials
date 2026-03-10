# Example: Moved Blocks for Safe Resource Refactoring
#
# Demonstrates:
#   - Simple resource rename (old name → new name)
#   - count → for_each migration with explicit moved blocks
#   - Moving resources into a module
#
# Run: terraform init && terraform plan
#
# To simulate the "before" state, you would:
#   1. Comment out the moved blocks and the new resources
#   2. Uncomment the old resources
#   3. terraform apply   (creates resources with old addresses)
#   4. Uncomment new resources + moved blocks, remove old resources
#   5. terraform plan    (shows "moved" in plan, no destroy/recreate)
#   6. terraform apply   (state addresses updated, no infrastructure change)

terraform {
  required_version = ">= 1.9"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# -----------------------------------------------------------------------
# Scenario 1: Simple rename
#
# Old name: null_resource.app_sg   (was generic, unclear purpose)
# New name: null_resource.ecs_tasks_sg  (explicit — security group for ECS tasks)
#
# Without moved block: Terraform destroys app_sg, creates ecs_tasks_sg
# With moved block:    Terraform updates state address only — no infrastructure change
# -----------------------------------------------------------------------

resource "null_resource" "ecs_tasks_sg" {
  triggers = {
    name        = "ecs-tasks-security-group"
    description = "Security group for ECS task containers"
  }
}

moved {
  from = null_resource.app_sg        # old state address
  to   = null_resource.ecs_tasks_sg  # new state address
}

# -----------------------------------------------------------------------
# Scenario 2: count → for_each migration
#
# Old (fragile, index-based state addresses):
#   null_resource.deployers[0]  → "alice"
#   null_resource.deployers[1]  → "bob"
#   null_resource.deployers[2]  → "carol"
#
# New (stable, name-based state addresses):
#   null_resource.deployers["alice"]
#   null_resource.deployers["bob"]
#   null_resource.deployers["carol"]
#
# Risk: verify the index-to-name mapping carefully before applying
# -----------------------------------------------------------------------

resource "null_resource" "deployers" {
  for_each = toset(["alice", "bob", "carol"])
  triggers = {
    username = each.key
  }
}

moved {
  from = null_resource.deployers[0]
  to   = null_resource.deployers["alice"]
}

moved {
  from = null_resource.deployers[1]
  to   = null_resource.deployers["bob"]
}

moved {
  from = null_resource.deployers[2]
  to   = null_resource.deployers["carol"]
}

# -----------------------------------------------------------------------
# Scenario 3: Moving into a module (illustration — requires actual module)
#
# In a real codebase after extracting resources into module.networking:
#
# moved {
#   from = null_resource.vpc
#   to   = module.networking.null_resource.vpc
# }
#
# moved {
#   from = null_resource.subnet["private-1a"]
#   to   = module.networking.null_resource.subnet["private-1a"]
# }
# -----------------------------------------------------------------------

# -----------------------------------------------------------------------
# Lifecycle of moved blocks:
#
# 1. Write moved block
# 2. terraform plan  → verify "moved" actions only (no destroy/create)
# 3. terraform apply → state addresses updated
# 4. Keep moved blocks for one sprint (so all teammates can apply)
# 5. Remove moved blocks in a follow-up PR
# -----------------------------------------------------------------------

output "deployer_state_addresses" {
  description = "Stable, name-based state addresses after for_each migration"
  value       = [for k in keys(null_resource.deployers) : "null_resource.deployers[\"${k}\"]"]
}
