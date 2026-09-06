---
description: "Coordinate one task through the Research, Plan, Implement, Review, and Follow-up RPI workflow"
agent: RPI Agent
argument-hint: "task=... [continue=...] [followUp=...]"
---

# RPI

## Inputs

* ${input:task}: (Required) Task description or target outcome.
* ${input:continue}: (Optional) Resume the active task from its durable RPI artifacts.
* ${input:followUp}: (Optional) Select a distinct follow-up item from a prior review.

## Requirements

1. Use `${input:task}` as the primary task context and start with research readiness.
2. Sequence `rpi-research`, `rpi-plan`, `rpi-implement`, and `rpi-review` as needed. Planning owns independent critique, implementation owns change evidence and implementation-time plan updates, and review owns outcome routing.
3. For `${input:continue}`, resume the active task from its recorded state and phase artifacts. For `${input:followUp}`, create a child task for the selected item and begin at Research unless the prerequisites for a later phase are supplied.
4. Summarize current lifecycle stage, artifact paths, validation evidence, review execution status and outcome, and the routed follow-up.
