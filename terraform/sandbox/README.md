# Sandbox

Creates a set of deliberately misconfigured AI agent identities so the scanner has real findings to detect.

## Why this is safe to run in an existing account

Three independent locks, on every identity this stack creates.

**A permissions boundary that denies every action.** Attached policies still read as over-permissive, which is exactly what the scanner detects, but the effective permission is zero. Posture scanning looks at configuration. The configuration is genuinely bad. The capability behind it is not.

**Trust policies gated on an ExternalId generated at apply time and never printed.** Nothing can assume these roles, including you.

**The access key is created with status Inactive.** It exists, it is discoverable, it cannot authenticate.

Everything is prefixed `abr-demo-` and tagged `Project = agent-blast-radius`. The VPC is dedicated, so nothing touches your default VPC or anything already running.

## Cost

Nothing. IAM resources are free. A VPC, subnet and security group are free. There is no NAT gateway, no internet gateway, no compute.

## Run it

```bash
terraform init
terraform plan
terraform apply
```

Pick a region you do not run production in:

```bash
terraform apply -var="region=ap-south-1"
```

## Tear it down

```bash
terraform destroy
```

## What gets planted

| ID | Finding | Resource |
|----|---------|----------|
| F-01 | Static long-lived access key on an identity that calls Bedrock | `abr-demo-legacy-agent-svc` |
| F-02 | Excessive blast radius: invokes models, owns every bucket, terminates compute | `abr-demo-ops-agent` |
| F-03 | Privilege chaining: a modest role that can assume an administrator | `abr-demo-chained-agent` |
| F-04 | Unrestricted egress to 0.0.0.0/0 on every port | `abr-demo-agent-runtime` |
| F-05 | Bedrock model invocation logging disabled | absence, checked per region |
| F-06 | Correctly scoped agent. Should PASS. | `abr-demo-scoped-agent` |

## A note on F-05

There is no Terraform resource for this finding, and that is the point.

CloudTrail records that `bedrock:InvokeModel` was called, by whom, and when. It does not record the prompt or the response. That requires model invocation logging, which is **off by default** and configured once per region.

So in most accounts running agents today you can prove an agent called a model. You cannot prove what it was asked to do.

The remediated configuration is in `network.tf`, commented out. Uncomment it to demonstrate the fixed state.

## A note on key age

The scanner reports access key age as context, but the finding is the **presence** of a static key on an identity that calls AI APIs, not its age. A key created by `terraform apply` five minutes ago is new. The risk is not that it is old. The risk is that it does not expire.
