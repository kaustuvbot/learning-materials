# Example: Terraform Console for Interactive Debugging
#
# This file is designed to be explored interactively with:
#   terraform console
#
# Run: terraform init
# Then: terraform console
# Then paste the expressions from the comments below one at a time.
#
# The console loads all variables (with defaults) and evaluates locals,
# so you can debug complex expressions before putting them in real code.

terraform {
  required_version = ">= 1.9"
}

# -----------------------------------------------------------------------
# Sample data — try inspecting and transforming these in the console
# -----------------------------------------------------------------------

variable "env" {
  type    = string
  default = "prod"
}

variable "project" {
  type    = string
  default = "myapp"
}

variable "tenants" {
  type = map(object({
    tier        = string
    enable_logs = bool
    cidr        = string
  }))
  default = {
    acme-corp = { tier = "enterprise", enable_logs = true,  cidr = "10.1.0.0/24" }
    initech   = { tier = "pro",        enable_logs = false, cidr = "10.2.0.0/24" }
    initrode  = { tier = "starter",    enable_logs = false, cidr = "10.3.0.0/24" }
    globodyne = { tier = "enterprise", enable_logs = true,  cidr = "10.4.0.0/24" }
  }
}

variable "team_cidrs" {
  type = map(list(string))
  default = {
    platform = ["10.0.1.0/24", "10.0.2.0/24"]
    data     = ["10.1.0.0/24"]
    security = ["192.168.0.0/24", "192.168.1.0/24", "192.168.2.0/24"]
  }
}

locals {
  name_prefix = "${var.project}-${var.env}"

  env_config = {
    dev     = { instance_class = "db.t4g.micro",  multi_az = false, max_connections = 100 }
    staging = { instance_class = "db.t4g.medium", multi_az = false, max_connections = 500 }
    prod    = { instance_class = "db.r7g.xlarge", multi_az = true,  max_connections = 5000 }
  }

  db = local.env_config[var.env]

  # A nested transformation — build this up step by step in the console
  all_team_cidrs = flatten([
    for team, cidrs in var.team_cidrs : [
      for cidr in cidrs : { team = team, cidr = cidr }
    ]
  ])

  enterprise_tenants = { for k, v in var.tenants : k => v if v.tier == "enterprise" }
}

# -----------------------------------------------------------------------
# Console exercises — paste these into `terraform console` one at a time
# -----------------------------------------------------------------------

# EXERCISE 1: Inspect variables and locals
#
#   var.env
#   var.tenants
#   local.name_prefix
#   local.db
#   local.db.instance_class

# EXERCISE 2: Build a for expression step by step
#
#   Step 1 — inspect the raw map:
#     var.tenants
#
#   Step 2 — extract tiers only:
#     { for k, v in var.tenants : k => v.tier }
#
#   Step 3 — filter to enterprise only:
#     { for k, v in var.tenants : k => v if v.tier == "enterprise" }
#
#   Step 4 — get just the keys:
#     [for k, v in var.tenants : k if v.tier == "enterprise"]
#
#   Step 5 — verify it matches local.enterprise_tenants:
#     local.enterprise_tenants

# EXERCISE 3: Debug a flatten expression step by step
#
#   Step 1 — inspect the nested map:
#     var.team_cidrs
#
#   Step 2 — inner for (per team):
#     [for team, cidrs in var.team_cidrs : "${team}: ${join(", ", cidrs)}"]
#
#   Step 3 — without flatten (nested list):
#     [for team, cidrs in var.team_cidrs : [for cidr in cidrs : { team = team, cidr = cidr }]]
#
#   Step 4 — with flatten (flat list):
#     flatten([for team, cidrs in var.team_cidrs : [for cidr in cidrs : { team = team, cidr = cidr }]])
#
#   Step 5 — verify against the local:
#     local.all_team_cidrs

# EXERCISE 4: Test built-in functions
#
#   cidrsubnet("10.0.0.0/16", 8, 1)       # → "10.0.1.0/24"
#   cidrsubnet("10.0.0.0/16", 8, 2)       # → "10.0.2.0/24"
#   cidrhost("10.0.1.0/24", 10)           # → "10.0.1.10"
#
#   contains(["dev", "staging", "prod"], var.env)
#   can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", "v1.2.3"))    # → true
#   can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", "latest"))    # → false
#
#   merge({ a = 1, b = 2 }, { b = 99, c = 3 })   # b from second map wins
#   keys(var.tenants)
#   values(var.tenants)[0]
#   length(var.tenants)
#
#   upper("hello")
#   replace("my-app-prod", "-", "_")
#   split("-", "my-app-prod")
#   join("/", ["us", "east", "1"])

# EXERCISE 5: Test type conversion and can()
#
#   can(cidrhost("10.0.0.0/16", 0))     # → true  (valid CIDR)
#   can(cidrhost("not-a-cidr", 0))      # → false (invalid CIDR)
#   try(tonumber("42"), 0)              # → 42
#   try(tonumber("abc"), 0)             # → 0  (fallback)
#   tostring(true)                      # → "true"
#   tonumber("3.14")                    # → 3.14

# -----------------------------------------------------------------------
# Outputs — run `terraform plan` to see computed values without apply
# -----------------------------------------------------------------------

output "name_prefix"          { value = local.name_prefix }
output "db_config"            { value = local.db }
output "all_team_cidrs"       { value = local.all_team_cidrs }
output "enterprise_tenants"   { value = keys(local.enterprise_tenants) }
output "log_enabled_tenants"  { value = [for k, v in var.tenants : k if v.enable_logs] }
output "subnet_example"       { value = cidrsubnet("10.0.0.0/16", 8, 1) }
