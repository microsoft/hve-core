---
title: hve-builder-tester
description: "Assess a frozen prompt, instruction, agent, subagent, or skill through black-box behavior testing with explicit fidelity and independent grading. Use for hve-builder candidate assessment and reassessment after corrections, or to test an existing artifact without editing it."
sidebar_position: 4
author: Microsoft
ms.date: 2026-09-07
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
Assess a frozen prompt, instruction, agent, subagent, or skill through black-box behavior testing with explicit fidelity and independent grading. Use for hve-builder candidate assessment and reassessment after corrections, or to test an existing artifact without editing it.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `hve-builder-tester` when an artifact's behavior, not its formatting, needs evidence: after `hve-builder` freezes a Major change, or on its own to test an existing prompt, instruction, agent, subagent, or skill without editing it. It designs black-box scenarios, executes them once at the artifact's reasoning profile, has an independent grader assess the evidence, and writes a durable report that states fidelity and limitations.

Use `hve-builder` when the artifact needs to change. Each tester invocation assesses one frozen candidate without editing it or starting a repair loop. The HVE Builder parent may use required findings to fix the artifact and request a fresh assessment within its ongoing run. Use mechanical validation such as `npm run validate:skills` for structure and frontmatter, which this skill does not replace.

## Example usage

Ask to test a new `csv-profiler` skill and its worker subagent together. The skill creates a sandbox, designs scenarios with realistic user requests and fixture data, and keeps expected outcomes in a separate grader-only design. It dispatches `HVE Artifact Tester` at the skill's profile to follow the artifacts literally in simulation.

It logs which actions were observed, simulated, or emulated, dispatches an independent grader over the finalized design and log, and writes a report under `.copilot-tracking/hve-builder/` with the verdict, coverage, untested behavior, and an unchecked human-review box. The report preserves decisive trace evidence before sandbox cleanup. Native execution requires an explicit request and satisfied containment preconditions.
