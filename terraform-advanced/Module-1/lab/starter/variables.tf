variable "project" {
  type        = string
  description = "Project name — used as prefix in all resource names"

  # TODO (Exercise 5): Add two validation blocks:
  # 1. Length between 2 and 20 characters
  # 2. Must match regex ^[a-z][a-z0-9-]*$ (lowercase letters, numbers, hyphens; starts with a letter)
}

variable "env" {
  type        = string
  description = "Deployment environment"

  # TODO (Exercise 5): Add a validation block — only allow: dev, staging, prod
  # Include the invalid value in the error message: "Got: '${var.env}'."
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

  # TODO (Exercise 2): Replace 'type = any' with a proper map(object({...})) type.
  # Fields needed:
  #   - cpu                (number)  — ECS task CPU units (256, 512, 1024, 2048, 4096)
  #   - memory             (number)  — ECS task memory in MB
  #   - port               (number)  — container port the service listens on
  #   - health_check_path  (string)  — ALB target group health check path
  #   - desired_count      (number)  — initial number of running tasks
  #   - enable_logs        (bool)    — optional, default true  — create a CloudWatch log group
  #   - enable_autoscaling (bool)    — optional, default false — register with App Auto Scaling
  type = any # ← replace this line with the correct type definition
}
