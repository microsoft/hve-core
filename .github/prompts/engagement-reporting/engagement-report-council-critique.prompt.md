---
name: engagement-report-council-critique
description: Template prompt for running one independent Council critique against research evidence
argument-hint: "Draft report and research findings"
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

## Review criteria

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

The report generator inserts the critic run identifier, target critique path,
draft, research, coverage summary, audience, and template below this line. Use
the selected model identifier when visible; otherwise record `unavailable`.
