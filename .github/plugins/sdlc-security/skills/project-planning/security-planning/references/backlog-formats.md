---
title: Security Backlog Formats and Prioritization
description: Prioritization guidance, work-item categories, and backlog handoff formats for the security-planning skill.
---

# Security Backlog Formats and Prioritization

This reference captures the backlog-oriented formats and priorities used to hand off security findings into the implementation workflow.

## Security-test-case work items

When the model includes `security_test_cases[]`, emit a Phase 5 backlog work item for each relevant test case and keep the inline security-test-case matrix in the threat-model output. Security test cases are surfaced both as a backlog handoff artifact and as a structured inline matrix so reviewers can see both the implementation intent and the evidence trail.

Use a category such as `security-test-case` for the backlog handoff, and include the `test_type`, `expected_result`, and the linked target references so the implementation team can trace the case back to the threat-model record.

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

Use an HTML description for ADO and a Markdown body with YAML metadata for GitHub. Include the planner, ID, priority, standards, evidence and cross-planner references; use `WI-SEC-{NNN}` or `{{SEC-TEMP-N}}` and retain the temporary-to-real ID mapping. Put `threat_id`, `stride_category`, `bucket`, and `risk_level` in the description or header. Link the named mitigation to its threat and include implementation, testable acceptance criteria and an unchecked qualified security-review box.

Confirm the destination. Manual produces local drafts only. Partial (default) requires approval for each batch of 5–10; Full requires explicit advance approval of the scoped batch. Do not mark the human-review box or submit unchecked items. Remove credentials, PII, private URLs, state JSON and state pointers. Replace tracking paths with descriptive references and absolute paths with workspace-relative citations; retain standards IDs. End each handoff file with the verbatim Security Planning CAUTION and log sanitization and actual notice emissions in `noticeLog` without the redacted data.

A compact backlog entry can use this structure:

```markdown
- Area: {bucket or GS concern}
- Priority: {Critical/High/Medium/Low/Informational}
- Why it matters: {risk statement}
- Suggested mitigation: {control or action}
- Related standards: {control family or standards reference}
```

## Notes

* GS work items should remain distinct from bucket-specific items.
* AI-specific backlog items should be surfaced when `raiEnabled` is true and the component is model-facing or agentic.
