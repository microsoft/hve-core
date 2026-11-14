---
title: customer-card-render
description: Generate customer-card slide content YAML from Design Thinking canonical artifacts
sidebar_position: 4
author: Microsoft
ms.date: 2026-10-27
ms.topic: reference
keywords:
  - skill
  - experimental
  - customer-card-render
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                  |
|-------------|----------------------------------------------------------------------------------------|
| Kind        | skill                                                                                  |
| Source      | `.github/skills/experimental/customer-card-render`                                     |
| Invocation  | Invoked directly as `/customer-card-render`, or loaded on demand by referencing agents |
| Interactive | No                                                                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Generate customer-card slide content YAML from Design Thinking canonical artifacts
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill to turn canonical Design Thinking artifacts into customer-card
slide content. It handles the mapping from Vision, Problem, Scenario, Use Case, and
Persona Markdown to slide YAML. It does not build, style, export, or validate a
presentation file. For an explicitly requested HTML presentation, hand reviewed
YAML to HVE Slides; levelled HTML/MP4 demos use the HVE Demo Material workflow.

Python 3.11+ and `uv` are prerequisites.

## Example usage

Ask: `/customer-card-render Generate card content from the attached synthetic
workshop's canonical directory into a new local output folder.` Supply `vision-statement.md`,
`problem-statement.md`, and the relevant `scenarios/`, `use-cases/`, and `personas/`
files with their canonical sections. Confirm a destination that will not overwrite
unrelated work.

The mapping step should create per-slide `content.yaml` files and a global style.
One vision, one problem, one scenario, one use case, and one persona yield eight
slides: the use case occupies four consecutive slides, including a separate
Extensions and Evidence slide.

Success means the generated content preserves canonical sections and narrative order without
inventing missing content. The mapping contract preserves
`<insufficient knowledge>` markers; generation is not evidence that those gaps were
resolved. Review content fidelity before sharing, and use synthetic or
approved public-safe material rather than customer-confidential workshop notes.
