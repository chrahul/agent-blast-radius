###############################################################################
# agent-blast-radius :: sandbox
#
# This stack DELIBERATELY creates misconfigured identities so the scanner has
# something real to find. It is safe to run in an existing account because of
# three independent locks, applied to every identity it creates:
#
#   1. A permissions boundary that denies every action. Attached policies still
#      READ as over-permissive, which is what the scanner detects, but the
#      effective permission is zero.
#   2. Trust policies gated on an ExternalId that is generated at apply time
#      and never printed. Nothing can assume these roles.
#   3. Access keys created with status = Inactive.
#
# Posture scanning looks at configuration. The configuration here is genuinely
# bad. The capability behind it is not.
#
# Everything is named abr-demo-* and tagged. `terraform destroy` removes all
# of it. Nothing here costs money.
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "agent-blast-radius"
      Purpose   = "security-demo-deliberately-misconfigured"
      ManagedBy = "terraform"
      Owner     = var.owner
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  prefix     = "abr-demo"
  account_id = data.aws_caller_identity.current.account_id
}

# Nobody knows this value. It is never output. Without it, none of the demo
# roles can be assumed, even by the account root.
resource "random_uuid" "trust_lock" {}

###############################################################################
# Lock 1 — the permissions boundary
#
# An IAM permissions boundary caps the maximum permission an identity can have,
# regardless of what its attached policies say. This one denies everything.
###############################################################################

resource "aws_iam_policy" "deny_all_boundary" {
  name        = "${local.prefix}-deny-all-boundary"
  description = "Safety boundary for agent-blast-radius demo identities. Denies all actions. Do not detach."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyEverything"
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}

###############################################################################
# Lock 2 — a trust policy document nothing can satisfy
###############################################################################

data "aws_iam_policy_document" "unassumable_trust" {
  statement {
    sid     = "RequiresUnknownExternalId"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [random_uuid.trust_lock.result]
    }
  }
}
