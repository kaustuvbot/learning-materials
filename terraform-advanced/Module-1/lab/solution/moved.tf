# ---------------------------------------------------------------------------
# Moved Blocks — Safe Resource Refactoring
# ---------------------------------------------------------------------------
#
# The ECS tasks security group was originally named aws_security_group.app.
# It was renamed to aws_security_group.ecs_tasks for clarity.
#
# This moved block updates the Terraform state address in-place.
# Without it: destroy aws_security_group.app + create aws_security_group.ecs_tasks
#             → all ECS tasks lose their security group → immediate outage.
# With it:    state address updated only → no API calls → zero downtime.
#
# Keep this block for at least one release cycle after the initial apply,
# so all teammates pick up the state migration before it's removed.

moved {
  from = aws_security_group.app
  to   = aws_security_group.ecs_tasks
}
