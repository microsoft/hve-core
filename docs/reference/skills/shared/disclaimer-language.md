---
title: disclaimer-language
description: "Verbatim CAUTION disclaimers for HVE planning, coaching, and review agents, one section per planner or review family, plus the session-state fields that track display. Preloaded by the agents that show them."
sidebar_position: 2
author: Microsoft
ms.date: 2026-10-31
ms.topic: reference
keywords:
  - skill
  - shared
  - disclaimer-language
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                       |
|-------------|---------------------------------------------|
| Kind        | skill                                       |
| Source      | `.github/skills/shared/disclaimer-language` |
| Invocation  | Loaded on demand by referencing agents      |
| Interactive | No                                          |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Verbatim CAUTION disclaimers for HVE planning, coaching, and review agents, one section per planner or review family, plus the session-state fields that track display. Preloaded by the agents that show them.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Planning, coaching, and review agents preload this skill so they can show their
professional-review disclaimer without reading another file. Pick the H2 block
for the workflow and show it verbatim. The agent's identity protocol decides
when the disclaimer appears, and only a human may check the review checkbox
that goes with it.

## Example usage

The Security Planner preloads this skill along with the untrusted-content
boundary:

```yaml
skills:
  - disclaimer-language
  - untrusted-content-boundary
```

When you start a new security plan, the planner shows the `Security Planning`
CAUTION block word for word before any phase work begins. It then records the
time in `disclaimerShownAt` in
`.copilot-tracking/security-plans/<project>/state.json`. Resuming the plan in a
later chat skips the full disclaimer, because that timestamp is already set. To
confirm the first display, check that `disclaimerShownAt` holds a timestamp
after the planner's first response.
