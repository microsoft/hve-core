---
title: Security Backlog Formats and Prioritization
description: Prioritization guidance, work-item categories, and backlog handoff formats for the security-planning skill.
---

# Security Backlog Formats and Prioritization

This reference captures the backlog-oriented formats and priorities used to hand off security findings into the implementation workflow.

## Prioritization posture

Security backlog items should be grouped by:

* Bucket or cross-cutting GS concern
* Risk rating or severity
* Affected component or control family
* Whether the item is a direct mitigation or an evidence/monitoring action

## Work-item categories

Use the following categories when creating or refining backlog entries:

* Preventive controls
* Detective controls
* Governance and policy
* Supply-chain and dependency hardening
* AI-specific guardrails and model monitoring

## Handoff format

A compact backlog entry can use this structure:

```markdown
- Area: {bucket or GS concern}
- Priority: {High/Medium/Low}
- Why it matters: {risk statement}
- Suggested mitigation: {control or action}
- Related standards: {control family or standards reference}
```

## Notes

* GS work items should remain distinct from bucket-specific items.
* AI-specific backlog items should be surfaced when `raiEnabled` is true and the component is model-facing or agentic.
