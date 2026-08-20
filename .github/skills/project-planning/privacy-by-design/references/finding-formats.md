---
title: Privacy Finding Formats and Citation Requirements
description: Structured finding schema, severity prioritization, and mandatory citation formats for the privacy-by-design skill.
---

# Privacy Finding Formats and Citation Requirements

This reference captures the structured finding formats and citation requirements used to emit privacy assessment results from the Privacy Reviewer agent.

## Prioritization posture

Privacy findings should be grouped by:

-   PbD Principle number and name
-   Severity rating (CRITICAL/HIGH/MEDIUM/LOW/INFO)
-   Affected jurisdiction(s) and legal obligation(s)
-   Whether the finding is a direct violation or a gap in evidence/documentation

## Finding categories

Use the following categories when classifying or refining findings:

-   Principle violation (active non-compliance)
-   Evidence gap (missing documentation or audit trail)
-   Configuration drift (policy exists but not enforced in code/config)
-   Cross-jurisdictional conflict (compliance in one jurisdiction creates risk in another)
-   Lifecycle protection failure (retention/disposal specific; always cite Principle 05)

## Handoff format

Every finding MUST use this exact JSON-compatible structure:

```json
{
  "id": "PBD-{PRINCIPLE_NUMBER}-{NNN}",
  "principle": "{Principle X: Name}",
  "status": "PASS | FAIL | PARTIAL",
  "severity": "CRITICAL | HIGH | MEDIUM | LOW | INFO",
  "evidence": "{file:line, config key, or infrastructure resource ID}",
  "citation": "{verbatim_legal_reference}; {additional_if_multi_jurisdiction}",
  "recommendation": "{actionable remediation with technical specificity}"
}
