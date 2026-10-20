###############################################################################
# F-04 — unrestricted egress
#
# A dedicated VPC, so the demo never touches your default VPC or anything
# already running. A VPC, subnet and security group cost nothing. No NAT
# gateway, no internet gateway, no instances.
#
# The security group allows egress to 0.0.0.0/0 on every port. This is the
# default shape of almost every security group ever created, and it is the
# control that matters most for data exfiltration: an agent with sensitive
# material in its context and unrestricted egress can send it anywhere.
###############################################################################

resource "aws_vpc" "sandbox" {
  cidr_block           = "10.242.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.prefix}-vpc"
  }
}

resource "aws_subnet" "sandbox" {
  vpc_id     = aws_vpc.sandbox.id
  cidr_block = "10.242.1.0/24"

  tags = {
    Name = "${local.prefix}-subnet"
  }
}

# The finding. Egress anywhere, any port, any protocol.
resource "aws_security_group" "agent_runtime_open" {
  name        = "${local.prefix}-agent-runtime"
  description = "Demo: agent runtime with unrestricted egress. Deliberately misconfigured."
  vpc_id      = aws_vpc.sandbox.id

  egress {
    description = "Anywhere. This is the finding."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}-agent-runtime-sg"
  }
}

# The control case. Egress restricted to the Bedrock VPC endpoint range only.
resource "aws_security_group" "agent_runtime_scoped" {
  name        = "${local.prefix}-agent-runtime-scoped"
  description = "Demo: agent runtime with allow-listed egress. Correctly configured."
  vpc_id      = aws_vpc.sandbox.id

  egress {
    description = "HTTPS to the VPC CIDR only, for interface endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.sandbox.cidr_block]
  }

  tags = {
    Name = "${local.prefix}-agent-runtime-scoped-sg"
  }
}

###############################################################################
# F-05 — Bedrock invocation logging is off
#
# There is no resource here, and that is the point.
#
# CloudTrail records that bedrock:InvokeModel was called, by whom, and when.
# It does not record the prompt or the response. That requires model
# invocation logging, which is off by default and configured once per region.
#
# So in most accounts running agents today you can prove an agent called a
# model. You cannot prove what it was asked to do.
#
# The fix is roughly the block below. Left commented so the scanner finds the
# gap on a fresh apply. Uncomment to demonstrate the remediated state.
###############################################################################

# resource "aws_cloudwatch_log_group" "bedrock_invocations" {
#   name              = "/aws/bedrock/${local.prefix}-invocations"
#   retention_in_days = 30
# }
#
# resource "aws_iam_role" "bedrock_logging" {
#   name = "${local.prefix}-bedrock-logging"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect    = "Allow"
#       Principal = { Service = "bedrock.amazonaws.com" }
#       Action    = "sts:AssumeRole"
#     }]
#   })
# }
#
# resource "aws_bedrock_model_invocation_logging_configuration" "this" {
#   logging_config {
#     text_data_delivery_enabled = true
#     cloudwatch_config {
#       log_group_name = aws_cloudwatch_log_group.bedrock_invocations.name
#       role_arn       = aws_iam_role.bedrock_logging.arn
#     }
#   }
# }
