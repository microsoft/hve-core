---
title: customer-card-render
description: Generate customer-card PowerPoint content YAML from Design Thinking canonical artifacts and build using the shared PowerPoint skill pipeline
sidebar_position: 3
author: Microsoft
ms.date: 2026-09-09
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
Generate customer-card PowerPoint content YAML from Design Thinking canonical artifacts and build using the shared PowerPoint skill pipeline
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill to turn canonical Design Thinking artifacts into customer-card
slides. It handles the mapping from Vision, Problem, Scenario, Use Case, and
Persona Markdown to slide YAML; the shared `powerpoint` skill owns rendering,
styling, export, and validation. Use `powerpoint` directly for a deck that is not
based on those canonical artifacts.

Python 3.11+, `uv`, and the PowerPoint skill are prerequisites. If the shared build
capability is unavailable, stop at that dependency rather than recreate its pipeline.

## Example usage

Ask: `/customer-card-render Build cards from the attached synthetic workshop's
canonical directory into a new local output folder.` Supply `vision-statement.md`,
`problem-statement.md`, and the relevant `scenarios/`, `use-cases/`, and `personas/`
files with their canonical sections. Confirm a destination that will not overwrite
unrelated work.

The mapping step should create per-slide `content.yaml` files and a global style,
then pass the content directory, style path, and PPTX destination to `powerpoint`.
One vision, one problem, one scenario, one use case, and one persona yield eight
slides: the use case occupies four consecutive slides, including a separate
Extensions and Evidence slide.

Success means the deck preserves canonical sections and narrative order without
inventing missing content. The mapping contract preserves
`<insufficient knowledge>` markers; rendering is not evidence that those gaps were
resolved. Review content fidelity and layout before sharing, and use synthetic or
approved public-safe material rather than customer-confidential workshop notes.
