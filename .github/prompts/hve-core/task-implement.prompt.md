---
description: "Execute an approved marker-based RPI plan using Task Implementor"
agent: Task Implementor
argument-hint: "[plan=...] [details=...] [phase=...] [task=...]"
---

# Task Implementation

## Inputs

* ${input:plan}: (Optional) Plain Markdown RPI plan path.
* ${input:details}: (Optional) RPI phase-details path.
* ${input:phase}: (Optional) Exact `Pxx` phase to execute.
* ${input:task}: (Optional) Exact `Pxx-Txx` task to execute.

## Requirements

1. Resolve `${input:plan}`, `${input:details}`, critique disposition, amendments, and existing changes record through stable markers and headings.
2. Execute the requested scope through `rpi-implement`, checking off completed `Pxx` and `Pxx-Txx` entries only after completion evidence exists.
3. Record material changes as `CHG-xxx`; link every significant `DIV-xxx` divergence to an `AM-xxx` amendment in the plan and matching phase-detail update.
4. Summarize execution status, changed files, validation evidence, unresolved work, and the `rpi-review` handoff.
