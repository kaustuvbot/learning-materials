locals {

  # ---------------------------------------------------------------------------
  # Naming & Tags
  # ---------------------------------------------------------------------------

  # Single source of truth for all resource name prefixes.
  # Change var.project or var.env once — every resource name updates.
  name_prefix = "${var.project}-${var.env}"

  common_tags = {
    Project     = var.project
    Environment = var.env
    ManagedBy   = "terraform"
  }


  # ---------------------------------------------------------------------------
  # Environment Configuration Map
  # ---------------------------------------------------------------------------

  # All per-environment settings in one place.
  # Adding a new environment = adding a new map key, no resource logic changes.
  env_config = {
    dev = {
      log_retention_days         = 7
      container_insights         = false
      enable_deletion_protection = false
    }
    staging = {
      log_retention_days         = 14
      container_insights         = false
      enable_deletion_protection = false
    }
    prod = {
      log_retention_days         = 90
      container_insights         = true
      enable_deletion_protection = true
    }
  }

  # Derived config for the current environment — used throughout resource blocks.
  current_env = local.env_config[var.env]


  # ---------------------------------------------------------------------------
  # Security Group Ingress Rules
  # ---------------------------------------------------------------------------

  # Defined as a list of objects here so the security group resource block
  # stays clean — just a dynamic block with no inline data.
  sg_ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP inbound"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS inbound"
    }
  ]

}
