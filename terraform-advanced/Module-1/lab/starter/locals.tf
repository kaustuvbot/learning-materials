locals {

  # ---------------------------------------------------------------------------
  # Naming & Tags
  # ---------------------------------------------------------------------------

  # TODO (Exercise 4A): Define name_prefix as "${var.project}-${var.env}"
  # This is the single source of truth for all resource names.
  name_prefix = "" # ← replace with the correct interpolation

  # TODO (Exercise 4A): Define common_tags with: Project, Environment, ManagedBy = "terraform"
  common_tags = {} # ← replace with the correct map


  # ---------------------------------------------------------------------------
  # Environment Configuration Map
  # ---------------------------------------------------------------------------

  # TODO (Exercise 4B): Complete the env_config map.
  # Each environment entry must have:
  #   - log_retention_days         (number)  — CloudWatch log retention
  #       dev=7, staging=14, prod=90
  #   - container_insights         (bool)    — ECS cluster Container Insights
  #       dev=false, staging=false, prod=true
  #   - enable_deletion_protection (bool)    — RDS/cluster deletion protection
  #       dev=false, staging=false, prod=true
  env_config = {
    dev = {
      # TODO
    }
    staging = {
      # TODO
    }
    prod = {
      # TODO
    }
  }

  # TODO (Exercise 4B): Look up the current environment's config from env_config.
  # Use var.env as the key.
  current_env = {} # ← replace with the correct lookup


  # ---------------------------------------------------------------------------
  # Security Group Ingress Rules
  # ---------------------------------------------------------------------------

  # TODO (Exercise 4C): Define sg_ingress_rules as a list of two rule objects:
  #   Rule 1 — HTTP:  from_port=80,  to_port=80,  protocol="tcp", cidr_blocks=["0.0.0.0/0"], description="HTTP inbound"
  #   Rule 2 — HTTPS: from_port=443, to_port=443, protocol="tcp", cidr_blocks=["0.0.0.0/0"], description="HTTPS inbound"
  sg_ingress_rules = [] # ← replace with the list of rule objects

}
