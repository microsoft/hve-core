---
title: hve-builder-tester
description: "Run one complete black-box behavior test of a prompt, instruction, agent, subagent, or skill with explicit fidelity and independent grading. Use as the final behavior gate after hve-builder freezes a candidate, or directly to test an existing artifact without changing it."
sidebar_position: 4
author: Microsoft
ms.date: 2026-09-04
ms.topic: reference
keywords:
  - skill
  - hve-core
  - hve-builder-tester
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                |
|-------------|--------------------------------------------------------------------------------------|
| Kind        | skill                                                                                |
| Source      | `.github/skills/hve-core/hve-builder-tester`                                         |
| Invocation  | Invoked directly as `/hve-builder-tester`, or loaded on demand by referencing agents |
| Interactive | No                                                                                   |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Run one complete black-box behavior test of a prompt, instruction, agent, subagent, or skill with explicit fidelity and independent grading. Use as the final behavior gate after hve-builder freezes a candidate, or directly to test an existing artifact without changing it.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `hve-builder-tester` when an artifact's behavior, not its formatting, needs evidence: after `hve-builder` freezes a Major change, or on its own to test an existing prompt, instruction, agent, subagent, or skill without editing it. It designs black-box scenarios, executes them once at the artifact's reasoning profile, has an independent grader assess the evidence, and writes a durable report that states fidelity and limitations.

Use `hve-builder` when the artifact needs to change; the tester never edits a target or retests within the same run. Use mechanical validation such as `npm run validate:skills` for structure and frontmatter, which this skill does not replace.

## Example usage

Ask to test a new `csv-profiler` skill and its worker subagent together. The skill creates a sandbox, designs scenarios with realistic user requests and fixture data, and keeps expected outcomes in a separate grader-only design. It dispatches `HVE Artifact Tester` at the skill's profile to follow the artifacts literally in simulation.

It logs which actions were observed, simulated, or emulated, dispatches an independent grader over the finalized design and log, and writes a report under `.copilot-tracking/hve-builder/` with the verdict, coverage, untested behavior, and an unchecked human-review box. The report preserves decisive trace evidence before sandbox cleanup. Native execution requires an explicit request and satisfied containment preconditions.
