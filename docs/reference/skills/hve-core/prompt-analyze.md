---
title: prompt-analyze
description: Compatibility alias for read-only prompt artifact review. Routes static and behavior analysis to hve-builder review mode.
sidebar_position: 6
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - hve-core
  - prompt-analyze
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                            |
|-------------|----------------------------------------------------------------------------------|
| Kind        | skill                                                                            |
| Source      | `.github/skills/hve-core/prompt-analyze`                                         |
| Invocation  | Invoked directly as `/prompt-analyze`, or loaded on demand by referencing agents |
| Interactive | No                                                                               |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Compatibility alias for read-only prompt artifact review. Routes static and behavior analysis to hve-builder review mode.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this compatibility alias for read-only assessment of an existing prompt,
instruction, agent, subagent, skill, reference, or template. It maps `promptFiles`
to HVE Builder targets and selects `review` mode. Choose `prompt-builder` for
approved behavior changes or `prompt-refactor` for behavior-preserving cleanup.
For explanation alone, ask a scoped question rather than requesting an assessment
lifecycle.

## Example usage

Ask: `/prompt-analyze promptFiles=.github/prompts/sample/summarize.prompt.md
requirements=Check whether missing-source handling and evidence citations are
clear. Keep the prompt unchanged.` The path is illustrative; supply an existing
artifact and any expected-output contract.

Expect HVE Builder's independent static findings and its behavior decision for the
unchanged target. Behavior-bearing review requires evidence at the supported
fidelity; a no-runtime target can carry a justified skip. Mechanical validation
is `Not requested` unless you ask for it.

Success is linked evidence with separate static verdict, behavior disposition,
fidelity, and overall outcome. Simulation is not native execution, unavailable
testing remains deferred, and findings do not grant edit authority. Request
corrections separately after deciding which recommendations to accept.
