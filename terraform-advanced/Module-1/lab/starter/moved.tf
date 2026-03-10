# ---------------------------------------------------------------------------
# Moved Blocks — Safe Resource Refactoring
# ---------------------------------------------------------------------------
#
# Exercise 6 scenario:
#   When this project was first applied, the ECS tasks security group was
#   declared as aws_security_group.app. It was later renamed to
#   aws_security_group.ecs_tasks for clarity.
#
#   Without a moved block, Terraform would:
#     1. Destroy aws_security_group.app   ← takes down all ECS tasks
#     2. Create  aws_security_group.ecs_tasks
#
#   With a moved block, Terraform updates the state address in-place.
#   No destroy. No downtime.
#
# TODO (Exercise 6): Write the moved block that declares this rename.
#
# moved {
#   from = ???
#   to   = ???
# }
