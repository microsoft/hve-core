---
title: UX UI Designer
description: "Route UX practitioners between focused coaching, evidence-labelled asset production, inclusion decisions, design intent, and external design surfaces"
sidebar_position: 9
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - project-planning
  - ux-ui-designer
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                     |
|-------------|-----------------------------------------------------------|
| Kind        | agent                                                     |
| Source      | `.github/agents/project-planning/ux-ui-designer.agent.md` |
| Invocation  | Selected from the chat agent picker as `UX UI Designer`   |
| Interactive | Yes                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Route UX practitioners between focused coaching, evidence-labelled asset production, inclusion decisions, design intent, and external design surfaces
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use UX UI Designer when a UX request could span coaching, durable asset
production, inclusion decisions, accessibility guidance, or publication to
Figma or Mural. The agent keeps the project and subject context while routing
each request to one explicit capability.

Choose a capability directly when the route is already clear:

* Use `ux-coaching` to frame a problem, prepare a critique, or build an
  evidence-backed stakeholder case.
* Use `ux-artifacts` to create a needs, journey, structure, inclusion, or
  engineering handoff asset from supplied evidence.
* Use `accessibility` for technical conformance, COGA guidance, Design Intent
  Records, and accessibility verification.

Use the agent to wireframe a screen. It routes structure capture to
`ux-artifacts` with `mode=sketch-structure` first, then treats any picture as a
separate destination step over the completed asset.

Use the agent for Figma or Mural publication because it owns destination
selection, explicit write confirmation, and execution. Asset mappings prepare
content for those destinations but never authorize external writes.

## How to use it

1. Select **UX UI Designer** from the chat agent picker.
2. Describe the practitioner goal, project, subject, and available evidence.
   Include an existing `output_ref` when continuing from coaching or a durable
   UX asset.
3. Answer one routing question if the request matches multiple capabilities.
4. Review the selected route, evidence classes, assumptions, and unresolved
   items returned by the agent.
5. Request a later capability explicitly. Coaching does not automatically
   create an asset, and an asset does not automatically publish externally.
6. For Figma or Mural writes, supply the destination kind, target, and intended
   change, then confirm the exact target when prompted.

## Example usage

Ask the agent to turn completed problem-framing evidence into a journey:

```text
Use the completed problem-framing output for the renewal flow to create a
current-state journey. Preserve unresolved evidence gaps and do not publish it.
```

The agent routes the request to `ux-artifacts` with `mode=map-journey`, passes
the coaching `output_ref` as the explicit source, and returns the journey's new
`output_ref`. It does not rerun coaching or begin a Figma or Mural write.
