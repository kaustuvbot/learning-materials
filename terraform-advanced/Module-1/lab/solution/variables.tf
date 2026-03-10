variable "project" {
  type        = string
  description = "Project name — used as prefix in all resource names"

  validation {
    condition     = length(var.project) >= 2 && length(var.project) <= 20
    error_message = "project must be between 2 and 20 characters."
  }

  validation {
    # can() returns true if the regex matches; false (not an error) if it doesn't
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project))
    error_message = "project must start with a letter and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "env" {
  type        = string
  description = "Deployment environment"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "env must be one of: dev, staging, prod. Got: '${var.env}'."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy into"
  default     = "us-east-1"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where ECS tasks and the security group will be deployed"
}

variable "ecs_services" {
  description = "Map of ECS service configurations"
  type = map(object({
    cpu                = number
    memory             = number
    port               = number
    health_check_path  = string
    desired_count      = number
    enable_logs        = optional(bool, true)
    enable_autoscaling = optional(bool, false)
  }))
}
