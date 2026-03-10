# Example: Custom Validation Rules
#
# Demonstrates:
#   - Enum constraints with helpful error messages
#   - Length and format validation (multiple blocks = multiple clear errors)
#   - CIDR format validation using can()
#   - Object field validation
#   - Cross-field validation (Terraform 1.9+)
#
# Run: terraform init && terraform plan
# Break it: TF_VAR_env=production terraform plan  (triggers enum validation error)
# Break it: TF_VAR_project=MY_PROJECT terraform plan  (triggers format error)

terraform {
  required_version = ">= 1.9"
}

# ✅ Pattern 1: Enum constraint
# Catches "production" instead of "prod" at plan time with a clear message
variable "env" {
  type        = string
  description = "Deployment environment"
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "env must be one of: dev, staging, prod. Got: '${var.env}'."
  }
}

# ✅ Pattern 2: Length + format validation
# Use multiple validation blocks — one error message per violated constraint
variable "project" {
  type        = string
  description = "Project name — used as prefix in all resource names"
  default     = "myapp"

  validation {
    condition     = length(var.project) >= 2 && length(var.project) <= 20
    error_message = "project must be between 2 and 20 characters. Got length: ${length(var.project)}."
  }

  validation {
    # can() returns true if the expression succeeds, false if it throws
    # regex() throws on non-match — can() converts that to false
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project))
    error_message = "project must start with a letter and contain only lowercase letters, numbers, and hyphens. Got: '${var.project}'."
  }
}

# ✅ Pattern 3: CIDR format validation
# can(cidrhost(...)) returns true for valid CIDRs, false for invalid ones
variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block (e.g. 10.0.0.0/16). Got: '${var.vpc_cidr}'."
  }
}

# ✅ Pattern 4: Object field validation
# Validate constraints on specific fields of a typed object
variable "db_config" {
  type = object({
    instance_class        = string
    backup_retention_days = number
  })
  default = {
    instance_class        = "db.t4g.micro"
    backup_retention_days = 7
  }

  validation {
    condition     = var.db_config.backup_retention_days >= 1 && var.db_config.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 1 and 35 (AWS RDS limit). Got: ${var.db_config.backup_retention_days}."
  }

  validation {
    condition     = can(regex("^db\\.", var.db_config.instance_class))
    error_message = "instance_class must start with 'db.' (e.g. db.t4g.micro, db.r7g.xlarge). Got: '${var.db_config.instance_class}'."
  }
}

# ✅ Pattern 5: Cross-field validation (Terraform 1.9+)
# Validate relationships between two variables
variable "min_capacity" {
  type    = number
  default = 2
}

variable "max_capacity" {
  type    = number
  default = 10

  validation {
    condition     = var.max_capacity >= var.min_capacity
    error_message = "max_capacity (${var.max_capacity}) must be >= min_capacity (${var.min_capacity})."
  }
}

output "validated_config" {
  description = "All variables passed validation — safe to use downstream"
  value = {
    env       = var.env
    project   = var.project
    vpc_cidr  = var.vpc_cidr
    db_config = var.db_config
    capacity  = { min = var.min_capacity, max = var.max_capacity }
  }
}

output "subnets" {
  description = "Subnets derived from vpc_cidr — only reachable if vpc_cidr is valid"
  value = {
    private_1 = cidrsubnet(var.vpc_cidr, 8, 1)
    private_2 = cidrsubnet(var.vpc_cidr, 8, 2)
    public_1  = cidrsubnet(var.vpc_cidr, 8, 10)
  }
}
