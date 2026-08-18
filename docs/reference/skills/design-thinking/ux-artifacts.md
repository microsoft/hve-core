---
title: ux-artifacts
description: "Produce evidence-labelled UX needs, journey, structure, inclusion, and engineering-handoff assets. Use when a practitioner needs a durable UX artifact rather than coaching."
sidebar_position: 5
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - skill
  - design-thinking
  - ux-artifacts
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                          |
|-------------|--------------------------------------------------------------------------------|
| Kind        | skill                                                                          |
| Source      | `.github/skills/design-thinking/ux-artifacts`                                  |
| Invocation  | Invoked directly as `/ux-artifacts`, or loaded on demand by referencing agents |
| Interactive | No                                                                             |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Produce evidence-labelled UX needs, journey, structure, inclusion, and engineering-handoff assets. Use when a practitioner needs a durable UX artifact rather than coaching.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `ux-artifacts` when supplied UX evidence or decisions need a durable Markdown asset:

* `frame-needs` records current context and source-labelled user needs.
* `map-journey` turns supplied current-experience evidence or an explicit problem-framing output into a staged journey.
* `sketch-structure` records what a surface contains and how it behaves: regions, controls, interaction states, and transitions.
* `decide-inclusion` records who a concept may exclude, the demands it creates, and alternatives or research gaps.
* `prepare-handoff` records implementation-facing flow, states, recovery, rationale, and unresolved engineering questions.

Use `ux-coaching` instead when the practitioner needs to reason through problem framing, critique, or stakeholder advocacy. Use `accessibility` for technical conformance, COGA guidance, Design Intent Records, and verification. Figma and Mural references shape completed assets but do not perform external writes.

## Example usage

Create a journey from a completed problem-framing coaching output:

```text
/ux-artifacts mode=map-journey project=renewal-flow subject=returning-customer source=.copilot-tracking/ux-coaching/renewal-flow/problem-framing.md
```

The skill writes the current journey to:

```text
.copilot-tracking/ux-artifacts/renewal-flow/returning-customer/map-journey.md
```

The result keeps observed, reported, assumed, and unresolved content distinct. Missing stages remain unresolved rather than being invented. A later explicit Figma or Mural request can pass this path as `source`; mapping does not authorize a write.
