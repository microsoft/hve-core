---
title: dt-figma-export
description: "Export Design Thinking artifacts to a FigJam board or Figma Design file through the Figma MCP server. Use when a team wants collaborative visual review of Method 1, 3, 4, 5, or 6 artifacts, or accepts a DT Coach board-export offer."
sidebar_position: 4
author: Microsoft
ms.date: 2026-10-02
ms.topic: reference
keywords:
  - skill
  - design-thinking
  - dt-figma-export
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                             |
|-------------|-----------------------------------------------------------------------------------|
| Kind        | skill                                                                             |
| Source      | `.github/skills/design-thinking/dt-figma-export`                                  |
| Invocation  | Invoked directly as `/dt-figma-export`, or loaded on demand by referencing agents |
| Interactive | No                                                                                |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Export Design Thinking artifacts to a FigJam board or Figma Design file through the Figma MCP server. Use when a team wants collaborative visual review of Method 1, 3, 4, 5, or 6 artifacts, or accepts a DT Coach board-export offer.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `dt-figma-export` when a Design Thinking team wants to review or facilitate around existing artifacts on a shared canvas. It suits Method 1 stakeholder maps, Method 3 synthesis themes, Method 4 idea clusters, Method 5 concepts, and Method 6 prototype plans. Run it directly, or accept the board-export offer that DT Coach makes at those method milestones.

The export is additive. The `.copilot-tracking/dt/{project-slug}/` artifacts stay the source of truth, and the skill writes to Figma only after you confirm the exact destination and operation. Use the Mural board export from DT Coach instead when your team works in Mural, and use `ux-artifacts` when you need a durable Markdown UX asset rather than a board.

## Example usage

Export the Method 3 synthesis for a project as both a FigJam board and a Figma Design file:

```text
/dt-figma-export project-slug=warehouse-onboarding method=3 output-type=both
```

The skill reads the project coaching state, confirms the `figma` MCP server connection, and asks you to approve the named destinations before it creates them. It then reports each file title and URL with counts of the sections, sticky notes, text elements, and diagrams it created, and it calls out any items it skipped or failed to write.
