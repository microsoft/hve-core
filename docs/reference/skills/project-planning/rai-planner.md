---
title: rai-planner
description: "On-demand RAI planner reference pack covering Phase 1 capture, Phase 2 risk classification, Phase 5 impact assessment, and Phase 6 review and backlog handoff."
sidebar_position: 13
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - project-planning
  - rai-planner
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                         |
|-------------|-----------------------------------------------|
| Kind        | skill                                         |
| Source      | `.github/skills/project-planning/rai-planner` |
| Invocation  | Loaded on demand by referencing agents        |
| Interactive | No                                            |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
On-demand RAI planner reference pack covering Phase 1 capture, Phase 2 risk classification, Phase 5 impact assessment, and Phase 6 review and backlog handoff.
<!-- END AUTO-GENERATED: overview -->

## When to use it

The RAI Planner agent loads this pack at the relevant phase boundary: capture,
risk classification, impact assessment, or review and backlog handoff. It is not
a standalone slash command. Use `rai-standards` for the standards baseline; this
pack provides phase-specific questioning, evidence, tradeoff, and handoff guidance.

## Example usage

In an existing RAI Planner session for a fictional summarization assistant, ask to
continue impact assessment using the `rai-planner` reference. Supply the recorded
threats, proposed controls, synthetic evaluation summary, and known limitations.

The Phase 5 flow should build an evidence register that distinguishes preventive,
detective, and response controls, their coverage, and verification status. If a
mitigation trades transparency against privacy, expect the conflict and residual
risk to remain explicit rather than silently resolved.

At Phase 6, the agent reviews scope, controls, evidence, and tradeoffs before
drafting the selected backlog handoff. Success is linked sections in `rai-plan.md`
and only the handoff artifacts actually produced, with gaps and human-review
needs visible. This is not regulatory approval or automatic tracker execution;
signing is optional and must not be claimed when it was not performed.
