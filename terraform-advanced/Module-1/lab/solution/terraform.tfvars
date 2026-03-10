project    = "fintech-platform"
env        = "dev"
aws_region = "us-east-1"

# Replace with a real VPC ID from your AWS account
vpc_id = "vpc-xxxxxxxxxxxxxxxxx"

ecs_services = {
  api-gateway = {
    cpu                = 512
    memory             = 1024
    port               = 8080
    health_check_path  = "/health"
    desired_count      = 2
    enable_logs        = true
    enable_autoscaling = true
  }
  worker = {
    cpu               = 1024
    memory            = 2048
    port              = 9000
    health_check_path = "/ready"
    desired_count     = 1
    enable_logs       = true
    # enable_autoscaling omitted — uses optional() default of false
  }
  scheduler = {
    cpu               = 256
    memory            = 512
    port              = 9090
    health_check_path = "/ping"
    desired_count     = 1
    enable_logs       = false # no CloudWatch log group for this service
    # enable_autoscaling omitted — uses optional() default of false
  }
}
