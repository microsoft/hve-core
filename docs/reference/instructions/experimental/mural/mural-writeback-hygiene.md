---
title: Experimental/Mural/Mural Writeback Hygiene
description: "Writeback hygiene rules for Mural: tags, hyperlinks, and parentId are the only stable channels; reserved tags are protected; tag manifests are re-applied defensively."
sidebar_position: 6
author: Microsoft
ms.date: 2026-08-27
ms.topic: reference
keywords:
  - instruction
  - experimental
  - experimental/mural/mural-writeback-hygiene
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                                                                                                                                                                                                   |
|-------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Kind        | instruction                                                                                                                                                                                                                                                             |
| Source      | `.github/instructions/experimental/mural/mural-writeback-hygiene.instructions.md`                                                                                                                                                                                       |
| Invocation  | Applied automatically to `**/.copilot-tracking/mural/**, **/.github/skills/experimental/mural/**, **/.github/agents/design-thinking/dt-coach.agent.md, **/.github/agents/rai-planning/rai-planner.agent.md, **/.github/agents/project-planning/ux-ui-designer.agent.md` |
| Interactive | No                                                                                                                                                                                                                                                                      |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Writeback hygiene rules for Mural: tags, hyperlinks, and parentId are the only stable channels; reserved tags are protected; tag manifests are re-applied defensively.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use these instructions when enriching existing Mural widgets after or during a
workshop. Write only tags, hyperlinks, and `parentId`, preserve protected human
content and reserved tags, and surface merge or bulk failures instead of
blindly retrying; text authoring belongs only to same-call AI scaffolding.

## Example usage

<!-- asset-docs:stub -->
Provide a concrete example that shows the asset in action, including representative input and the resulting output.
