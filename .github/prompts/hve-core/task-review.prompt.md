---
description: "Initiate RPI acceptance review from plan, detail, critique, amendment, and change evidence"
agent: Task Reviewer
argument-hint: "[task=...] [plan=...] [details=...] [critique=...] [changes=...] [research=...] [scope=...]"
---

# Task Review

## Inputs

* ${input:task}: (Optional) Task description or task slug.
* ${input:plan}: (Optional) Plain Markdown RPI plan path.
* ${input:details}: (Optional) RPI phase-details path.
* ${input:critique}: (Optional) RPI plan-critique path.
* ${input:changes}: (Optional) RPI changes path.
* ${input:research}: (Optional) RPI research path.
* ${input:scope}: (Optional) Exact phase, task, or finding scope to review.

## Requirements

1. Resolve one coherent task artifact set and requested scope from the supplied `${input:task}`, `${input:plan}`, `${input:details}`, `${input:critique}`, `${input:changes}`, `${input:research}`, and `${input:scope}` values.
2. Use `rpi-review` to compare evidence and write one review record with `RV-xxx` findings.
3. Keep execution status separate from outcome, and route defects, decision gaps, research gaps, and residual work to distinct next actions.
4. Summarize the review record, severity counts, validation evidence, status, outcome, and recommended destination.
