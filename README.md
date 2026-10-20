# agent-blast-radius

**You already have AI agents running in your AWS account. Which ones can reach production, what credentials are they holding, and can you prove what they did last Tuesday?**

Most organisations cannot answer those three questions today. Not because the tooling is hard, but because nobody has looked.

This repository is a working scanner that answers them, plus a sandbox that plants the problem on purpose so you can see the scanner catch it.

---

## The six questions

| # | Question | What it tells you |
|---|----------|-------------------|
| 1 | Which identities are calling AI APIs? | Your shadow AI inventory |
| 2 | Are they human or non-human? | Static keys versus assumed roles |
| 3 | How old are the credentials, when were they last used? | Whether anything expires |
| 4 | What **else** can that identity reach? | The blast radius number |
| 5 | Can the compute running agents reach the open internet? | Exfiltration path |
| 6 | Can you prove what the agent actually did? | Audit reality |

Question six is usually the uncomfortable one. Bedrock model invocation logging is off by default, so CloudTrail tells you an agent called a model and nothing about what it was asked to do.

---

## Layout

```
terraform/sandbox/   plants the problem, safely
scanner/             the tool
evidence/            scan outputs, screenshots, recordings
docs/                the writeup
```

---

## Status

- [x] Sandbox Terraform
- [ ] Scanner core (questions 1 to 4)
- [ ] Egress and audit checks (questions 5 and 6)
- [ ] Report output
- [ ] Evidence capture and writeup

---

## Safety

The sandbox creates identities that look dangerous and are not. Every one carries a permissions boundary denying all actions, a trust policy nobody can satisfy, and an inactive access key. See `terraform/sandbox/README.md` for the detail.

Everything is prefixed `abr-demo-` and removed by `terraform destroy`. Nothing in this repository costs money to run.

---

## Why this exists

Docker published a useful breakdown of AI agent security risks in October 2026: prompt injection, tool misuse and poisoning, excessive autonomy, credential exposure, and data exfiltration. The framing that stuck with me was that most of these trace back to one thing. The agent can act. So containment and oversight matter more than the model.

That is a good framework. This repository is what happens when you point it at a real AWS account and ask what it finds.

---

Rahul Chaubey · [rahulchaubeyconsulting.com](https://rahulchaubeyconsulting.com)
