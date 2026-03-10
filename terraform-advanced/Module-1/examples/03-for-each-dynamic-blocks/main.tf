# Example: Advanced for_each and Dynamic Blocks
#
# Demonstrates:
#   - for_each over map(object()) — one resource block manages N resources
#   - list → map conversion with for expression (stable state addresses)
#   - Filtering with if in for_each
#   - Dynamic blocks for repeated nested config
#   - Conditional dynamic blocks with [1] : [] pattern
#
# Run: terraform init && terraform plan

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
# Pattern 1: for_each over map(object()) — one block manages all tenants
# Adding a new tenant = adding a map entry in tfvars, no resource block changes
# -----------------------------------------------------------------------

variable "tenants" {
  type = map(object({
    tier        = string   # "starter" | "pro" | "enterprise"
    enable_logs = bool
  }))
  default = {
    acme-corp = { tier = "enterprise", enable_logs = true }
    initech   = { tier = "pro",        enable_logs = false }
    initrode  = { tier = "starter",    enable_logs = false }
  }
}

# One resource block manages all tenants
# State addresses: null_resource.tenant_storage["acme-corp"], etc.
resource "null_resource" "tenant_storage" {
  for_each = var.tenants
  triggers = {
    name = "tenant-${each.key}-data"
    tier = each.value.tier
  }
}

# -----------------------------------------------------------------------
# Pattern 2: list → map conversion for stable state addresses
# Key by a stable business identifier (name), never by list index
# -----------------------------------------------------------------------

variable "subnets" {
  type = list(object({
    name = string
    cidr = string
    az   = string
  }))
  default = [
    { name = "private-1a", cidr = "10.0.1.0/24", az = "us-east-1a" },
    { name = "private-1b", cidr = "10.0.2.0/24", az = "us-east-1b" },
    { name = "private-1c", cidr = "10.0.3.0/24", az = "us-east-1c" },
  ]
}

resource "null_resource" "subnet" {
  # Convert list → map keyed by name for stable state addresses
  # If we used count, inserting a subnet at position 0 would shift all addresses
  for_each = { for s in var.subnets : s.name => s }

  triggers = {
    cidr = each.value.cidr
    az   = each.value.az
  }
}

# -----------------------------------------------------------------------
# Pattern 3: Filtering with if in for_each
# Only create log groups for tenants with enable_logs = true
# -----------------------------------------------------------------------

resource "null_resource" "tenant_logs" {
  for_each = { for k, v in var.tenants : k => v if v.enable_logs }

  triggers = {
    log_group = "/tenant/${each.key}/app"
  }
}

# -----------------------------------------------------------------------
# Pattern 4: Dynamic blocks — repeated nested config driven by a variable
# In a real codebase: dynamic "ingress" in aws_security_group
# -----------------------------------------------------------------------

variable "ingress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    description = string
  }))
  default = [
    { from_port = 443, to_port = 443, description = "HTTPS" },
    { from_port = 80,  to_port = 80,  description = "HTTP redirect" },
    { from_port = 8080, to_port = 8080, description = "App port" },
  ]
}

# Simulates a security group — dynamic block generates one ingress per rule
resource "null_resource" "security_group" {
  triggers = {
    # Dynamic block output — in real code this drives actual ingress blocks
    rules = jsonencode([
      for rule in var.ingress_rules : {
        port        = rule.from_port
        description = rule.description
      }
    ])
  }
}

# -----------------------------------------------------------------------
# Pattern 5: Conditional dynamic block with [1] : [] pattern
# Include the logging block only when the feature is enabled
# -----------------------------------------------------------------------

variable "enable_access_logs" {
  type    = bool
  default = false
}

variable "log_bucket" {
  type    = string
  default = ""
}

resource "null_resource" "s3_bucket_with_optional_logging" {
  triggers = {
    name = "app-assets"
    # Logging config: present only when enabled
    # The [1] : [] pattern generates either one iteration (enabled) or none (disabled)
    logging_enabled = tostring(var.enable_access_logs)
    log_target      = var.enable_access_logs ? var.log_bucket : "disabled"
  }
}

# -----------------------------------------------------------------------
# Outputs — useful for inspecting state addresses and filter results
# -----------------------------------------------------------------------

output "tenant_state_addresses" {
  description = "Stable state addresses using map keys (not indexes)"
  value       = [for k in keys(null_resource.tenant_storage) : "null_resource.tenant_storage[\"${k}\"]"]
}

output "subnet_state_addresses" {
  description = "Stable state addresses — key by name, not list index"
  value       = [for k in keys(null_resource.subnet) : "null_resource.subnet[\"${k}\"]"]
}

output "log_enabled_tenants" {
  description = "Only tenants with enable_logs = true were created"
  value       = keys(null_resource.tenant_logs)
}
