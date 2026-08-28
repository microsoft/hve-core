---
name: engagement-report-council-critique
description: Template prompt for running one independent Council critique against research evidence
argument-hint: "Critic run, output path, draft, research, coverage, audience, and template"
---

# Engagement Report Council Critique

## Goal

Review one draft independently against the supplied research. Return evidence-
backed findings to the report generator without rewriting or reconciling the
report.

## Success criteria

* Every finding identifies the affected claim or section
* Every accuracy finding cites supplied research evidence
* Missing evidence is distinguished from contradictory evidence
* Sensitive-content issues identify unnecessary disclosure without repeating
  the sensitive content
* The critique remains independent of other model critiques
* Critic run and available model provenance are recorded

## Inputs

* `${input:critic-run-id}`: (Required) Unique identifier for this isolated run
* `${input:critique-path}`: (Required) Target path for the critique artifact
* `${input:draft}`: (Required) Draft report content or readable local path
* `${input:research}`: (Required) Normalized research content or readable path
* `${input:coverage}`: (Required) Source coverage summary
* `${input:audience}`: (Required) Intended report audience
* `${input:template}`: (Required) Report template content or readable path

## Review criteria

Review `${input:draft}` independently against `${input:research}`,
`${input:coverage}`, `${input:audience}`, and `${input:template}`. Identify the
run as `${input:critic-run-id}` and write the result only to
`${input:critique-path}`.

1. Accuracy and source grounding
2. Completeness and material omissions
3. Proportion and unsupported emphasis
4. Directionality and attribution
5. Completion state and accountable ownership
6. Data minimization and audience-appropriate disclosure
7. Terminology, dates, and audience fit
8. Progression from the prior period

## Output Format

Begin with:

```markdown
## Critic Metadata

* Critic run: {critic-run-id}
* Model: {model identifier or unavailable}
* Critique artifact: {target critique path}
```

Then, for each section, provide:

```markdown
## {Section Name}

Accuracy: accurate | needs-edit | unsupported
Completeness: complete | minor-gap | material-gap

### Findings

* Severity: high | medium | low
* Claim: {affected draft claim}
* Finding: {concise issue}
* Evidence: {research finding identifier}
* Proposed direction: {remove, narrow, verify, or retain}

### Missing material

* {research finding not reflected in the draft}
```

## Stop rules

* Do not read another critique
* Do not rewrite the draft
* Do not reconcile findings
* Do not infer facts beyond the supplied research

Use the selected model identifier when visible; otherwise record `unavailable`.
