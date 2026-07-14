---
description: "Initiate evidence-based RPI planning from supplied task context, research, drafts, and decisions"
agent: Task Planner
argument-hint: "[task=...] [research=...] [context=...] [draft=...] [decisions=...]"
---

# Task Plan

## Inputs

* ${input:task}: (Optional) Task description or target outcome.
* ${input:research}: (Optional) Completed research or evidence path.
* ${input:context}: (Optional) Caller-supplied task context.
* ${input:draft}: (Optional) Draft plan or phase details.
* ${input:decisions}: (Optional) Decisions, dependencies, and acceptance criteria.

## Requirements

1. Treat supplied research, context, drafts, and decisions as the starting point. Activate `rpi-research` only when a planning-readiness gap is material.
2. Create or revise the plain Markdown plan and phase-details artifacts through `rpi-plan`, using stable task, phase, and task IDs plus contextual markers.
3. Obtain an independent `rpi-plan-critique` result through the planning workflow before finalizing a durable plan.
4. Summarize planning readiness, artifact paths, critique disposition, unresolved decisions, and the recommended next RPI stage.
