# Example: Locals as Logic Layers
#
# Demonstrates:
#   - Environment configuration map — all per-env settings in one place
#   - Derived naming locals — single source of truth for names
#   - Feature flag locals — conditional resources without scattered ternaries
#   - Data transformation locals — reshape inputs for for_each / dynamic blocks
#
# Run: terraform init && terraform plan
# Try: TF_VAR_env=dev terraform plan   (to see dev config instead of prod)

terraform {
  required_version = ">= 1.9"
}

variable "env" {
  type    = string
  default = "prod"
}

variable "project" {
  type    = string
  default = "myapp"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "force_waf" {
  type    = bool
  default = false
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "allowed_cidr_blocks" {
  type    = list(string)
  default = ["10.0.0.0/8", "172.16.0.0/12"]
}

variable "team_cidrs" {
  type = map(list(string))
  default = {
    platform = ["10.0.1.0/24", "10.0.2.0/24"]
    data     = ["10.1.0.0/24"]
  }
}

locals {
  # ✅ Pattern 1: Environment configuration map
  # All environment-specific values in one lookup table.
  # Change one value here — it propagates everywhere automatically.
  env_config = {
    dev = {
      instance_class        = "db.t4g.micro"
      multi_az              = false
      backup_retention_days = 1
      deletion_protection   = false
    }
    staging = {
      instance_class        = "db.t4g.medium"
      multi_az              = false
      backup_retention_days = 3
      deletion_protection   = false
    }
    prod = {
      instance_class        = "db.r7g.xlarge"
      multi_az              = true
      backup_retention_days = 30
      deletion_protection   = true
    }
  }

  # Derived config for the current environment — resource blocks stay clean
  db = local.env_config[var.env]

  # ✅ Pattern 2: Derived naming locals — single source of truth
  name_prefix  = "${var.project}-${var.env}"
  region_short = substr(var.aws_region, 0, 6)       # "us-eas" from "us-east-1"
  bucket_prefix = "${local.name_prefix}-${local.region_short}"

  common_tags = {
    Project     = var.project
    Environment = var.env
    Region      = var.aws_region
    ManagedBy   = "terraform"
  }

  # ✅ Pattern 3: Feature flag locals
  # No more scattered `var.env == "prod" ? ... : ...` inside resource blocks
  features = {
    enable_waf        = var.env == "prod" || var.force_waf
    enable_cloudtrail = var.env != "dev"
    enable_guardduty  = var.env == "prod"
    nat_gateway_count = var.env == "prod" ? length(var.availability_zones) : 1
  }

  # ✅ Pattern 4: Data transformation
  # Transform a list of CIDRs into structured rule objects for a dynamic block
  ingress_rules = [
    for cidr in var.allowed_cidr_blocks : {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [cidr]
      description = "HTTPS from ${cidr}"
    }
  ]

  # Flatten map(list) → list of objects — useful for for_each with unique keys
  all_team_cidrs = flatten([
    for team, cidrs in var.team_cidrs : [
      for cidr in cidrs : { team = team, cidr = cidr }
    ]
  ])
}

# Downstream resource blocks are clean — no env-specific logic here
output "db_config_for_env" {
  description = "Shows env config map: different values per environment"
  value       = local.db
}

output "name_prefix" {
  description = "Naming prefix used across all resources"
  value       = local.name_prefix
}

output "bucket_prefix" {
  description = "Globally unique bucket prefix (includes region)"
  value       = local.bucket_prefix
}

output "features" {
  description = "Feature flags derived from environment — no scattered ternaries"
  value       = local.features
}

output "ingress_rules" {
  description = "CIDR list transformed into structured rule objects"
  value       = local.ingress_rules
}

output "all_team_cidrs" {
  description = "Flattened map(list) → list of objects"
  value       = local.all_team_cidrs
}
