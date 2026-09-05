---
title: "UX artifact mode: Map journey"
description: Produce an evidence-labelled staged journey from supplied current-experience evidence or an explicit problem-framing output pointer.
---

# Map journey

Use this mode when current-experience evidence exists and the practitioner needs a durable journey asset. Do not use it to discover the problem or manufacture stages from a generic lifecycle.

## Inputs

* Explicit `source` or in-context evidence
* Scenario and represented users
* Current-experience sequence or known stages
* Actions, thoughts, pain points, and outcomes supported by the source

When `source` is a completed problem-framing output, follow the pointer-first transfer in [evidence-model.md](evidence-model.md). Never read coaching state directly.

## Output body

After the common evidence sections, write:

```markdown
## Scenario

* Users: <represented users or roles>
* Starting context: <known trigger>
* Intended outcome: <supported outcome>

## Journey Stages

| Stage   | User actions       | Thoughts or questions          | Pain points                          | Opportunities                                 | Basis and source                             |
|---------|--------------------|--------------------------------|--------------------------------------|-----------------------------------------------|----------------------------------------------|
| <stage> | <supported action> | <supported thought or Unknown> | <supported pain point or None known> | <evidence-grounded opportunity or Unresolved> | <Observed, Reported, or Assumed plus source> |

## Cross-Journey Findings

* <pattern that is supported across stages>

## Validation Priorities

* <assumption or unresolved stage whose answer would most change the journey>
```

## Evidence rules

* Sequence stages from supplied evidence, not a default awareness-to-outcome template.
* A reported thought is not observed behavior. Keep their evidence classes separate.
* An opportunity states a problem-space direction, not a finished interface solution.
* Missing stages, emotions, or touchpoints remain unresolved.

## Completion conditions

* The journey has a supported scenario and at least one stage.
* Every populated row carries a basis and source.
* Assumptions and unresolved gaps remain visible.
* A completed problem-framing source is consumed without re-framing or duplicated intake.

## Stop conditions

Stop with a partial journey when the source does not establish sequence. State that observation or additional evidence is needed rather than inventing a standard journey.
