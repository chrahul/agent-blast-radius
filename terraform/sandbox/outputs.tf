###############################################################################
# Outputs
#
# The trust-lock UUID is deliberately NOT output. Without it the demo roles
# cannot be assumed by anything, including you.
###############################################################################

output "planted_findings" {
  description = "What the scanner should detect after apply."
  value = {
    "F-01_static_key_on_ai_identity" = aws_iam_user.legacy_agent_user.name
    "F-02_excessive_blast_radius"    = aws_iam_role.ops_agent_role.name
    "F-03_privilege_chaining"        = aws_iam_role.chained_agent_role.name
    "F-04_unrestricted_egress"       = aws_security_group.agent_runtime_open.id
    "F-05_invocation_logging_off"    = "absence, not a resource. Scanner checks the region."
    "F-06_control_case_should_pass"  = aws_iam_role.scoped_agent_role.name
  }
}

output "safety_locks" {
  description = "Confirm all three locks are in place before you walk away."
  value = {
    permissions_boundary = aws_iam_policy.deny_all_boundary.arn
    access_key_status    = aws_iam_access_key.legacy_agent_key.status
    roles_assumable      = "no, external id required and never printed"
  }
}

output "teardown" {
  value = "terraform destroy removes everything. Nothing here incurs cost."
}
