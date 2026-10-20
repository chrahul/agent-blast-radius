###############################################################################
# The planted findings
#
# F-01  Static long-lived access key on an identity that calls Bedrock
# F-02  Excessive blast radius: an agent role that can also destroy compute
# F-03  Privilege chaining: an agent role that can assume a broader role
# F-06  A correctly scoped agent, so the report has a PASS as well as fails
#
# F-04 (unrestricted egress) is in network.tf
# F-05 (Bedrock invocation logging off) is an absence, not a resource
###############################################################################

###############################################################################
# F-01 — the service account nobody remembers creating
#
# A human-shaped IAM user, with a static access key, calling Bedrock. This is
# the single most common real-world finding: an agent wired up with a key
# pasted into a .env file two quarters ago.
###############################################################################

resource "aws_iam_user" "legacy_agent_user" {
  name                 = "${local.prefix}-legacy-agent-svc"
  permissions_boundary = aws_iam_policy.deny_all_boundary.arn
  force_destroy        = true
}

resource "aws_iam_access_key" "legacy_agent_key" {
  user = aws_iam_user.legacy_agent_user.name

  # Lock 3. The key exists and is discoverable. It cannot be used.
  status = "Inactive"
}

resource "aws_iam_user_policy" "legacy_agent_policy" {
  name = "${local.prefix}-legacy-agent-inline"
  user = aws_iam_user.legacy_agent_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BroadBedrockAccess"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:ListFoundationModels"
        ]
        Resource = "*"
      },
      {
        Sid      = "AndItCanReadEverySecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "*"
      }
    ]
  })
}

###############################################################################
# F-02 — excessive blast radius
#
# An agent role scoped for "operations". It can invoke models, read and write
# every bucket, and terminate instances. Each permission was probably added for
# a real reason. Together they are the thirteen-hour-outage shape.
###############################################################################

resource "aws_iam_role" "ops_agent_role" {
  name                 = "${local.prefix}-ops-agent"
  permissions_boundary = aws_iam_policy.deny_all_boundary.arn
  assume_role_policy   = data.aws_iam_policy_document.unassumable_trust.json
  max_session_duration = 43200 # 12 hours. Long-lived sessions are part of the finding.
}

resource "aws_iam_role_policy" "ops_agent_policy" {
  name = "${local.prefix}-ops-agent-inline"
  role = aws_iam_role.ops_agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AnyModel"
        Effect   = "Allow"
        Action   = "bedrock:*"
        Resource = "*"
      },
      {
        Sid      = "AnyBucket"
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = "*"
      },
      {
        Sid    = "AndItCanTerminateCompute"
        Effect = "Allow"
        Action = [
          "ec2:TerminateInstances",
          "ec2:StopInstances",
          "rds:DeleteDBInstance"
        ]
        Resource = "*"
      }
    ]
  })
}

###############################################################################
# F-03 — privilege chaining
#
# This role looks modest. It can invoke one model family and assume one other
# role. The role it can assume is an administrator. Effective blast radius is
# never what the first policy says.
###############################################################################

resource "aws_iam_role" "chained_agent_role" {
  name                 = "${local.prefix}-chained-agent"
  permissions_boundary = aws_iam_policy.deny_all_boundary.arn
  assume_role_policy   = data.aws_iam_policy_document.unassumable_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "chained_agent_policy" {
  name = "${local.prefix}-chained-agent-inline"
  role = aws_iam_role.chained_agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "LooksReasonable"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "*"
      },
      {
        Sid      = "ButItCanBecomeThis"
        Effect   = "Allow"
        Action   = ["sts:AssumeRole"]
        Resource = aws_iam_role.escalation_target_role.arn
      }
    ]
  })
}

resource "aws_iam_role" "escalation_target_role" {
  name                 = "${local.prefix}-escalation-target"
  permissions_boundary = aws_iam_policy.deny_all_boundary.arn
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = random_uuid.trust_lock.result
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "escalation_target_policy" {
  name = "${local.prefix}-escalation-target-inline"
  role = aws_iam_role.escalation_target_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AdministratorInAllButName"
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}

###############################################################################
# F-06 — the control case
#
# A correctly scoped agent. One model, one bucket prefix, one hour sessions,
# no static credentials, no assume-role chain. The report needs a PASS or the
# reader assumes the scanner only knows how to complain.
###############################################################################

resource "aws_iam_role" "scoped_agent_role" {
  name                 = "${local.prefix}-scoped-agent"
  permissions_boundary = aws_iam_policy.deny_all_boundary.arn
  assume_role_policy   = data.aws_iam_policy_document.unassumable_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "scoped_agent_policy" {
  name = "${local.prefix}-scoped-agent-inline"
  role = aws_iam_role.scoped_agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "OneModelFamilyOnly"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:${var.region}::foundation-model/anthropic.claude-3-haiku-*"
      },
      {
        Sid      = "OnePrefixOnly"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "arn:aws:s3:::${local.prefix}-agent-context/*"
      }
    ]
  })
}
