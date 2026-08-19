---
title: Experimental/Mural/Mural Seeding Patterns
description: "Cross-cutting Mural seeding conventions: duplicate-then-populate, source-artifact-to-area binding, anchor inheritance, probe-before-bulk, z-order visibility (detection-only), layout primitives applied across DT, RAI, and UX/UI workflows."
sidebar_position: 5
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - instruction
  - experimental
  - experimental/mural/mural-seeding-patterns
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                                                                                                                                                                              |
|-------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Kind        | instruction                                                                                                                                                                                                                                        |
| Source      | `.github/instructions/experimental/mural/mural-seeding-patterns.instructions.md`                                                                                                                                                                   |
| Invocation  | Applied automatically to `**/.github/agents/design-thinking/dt-coach.agent.md, **/.github/agents/rai-planning/rai-planner.agent.md, **/.github/agents/project-planning/ux-ui-designer.agent.md, **/.github/skills/design-thinking/ux-artifacts/**` |
| Interactive | No                                                                                                                                                                                                                                                 |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Cross-cutting Mural seeding conventions: duplicate-then-populate, source-artifact-to-area binding, anchor inheritance, probe-before-bulk, z-order visibility (detection-only), layout primitives applied across DT, RAI, and UX/UI workflows.
<!-- END AUTO-GENERATED: overview -->

## When to use it

These instructions apply automatically when Design Thinking, Responsible AI,
or UX workflows seed a Mural board from a source artifact. Use the patterns
after the caller has defined the artifact decomposition, expected cardinality,
target-area intent, and source-to-area bindings.

Keep workflow-specific content rules with the caller. `ux-artifacts` owns the
current UX area mapping and its per-row element type and cardinality, so read
that mapping rather than a copy; an enumeration repeated here drifts whenever
the caller adds a mode or an area. These instructions then govern the shared
mechanics: duplicate-then-populate, parent resolution, anchor inheritance,
probes, layout primitives, visibility checks, and reserved tags.

Use the Mural skill for authentication, command syntax, and transport. Use the
related human-record, log-hygiene, writeback-hygiene, and writing-style
instructions for their respective safeguards.

## Example usage

A UX caller maps a completed journey into one stage container per stage, one
element per evidence-backed pain point, and one element per opportunity. The
caller declares the target areas and expected counts before execution.

The executing agent then:

1. Duplicates the supplied source board or instantiates its template.
2. Resolves each declared parent area and inherits available anchors.
3. Probes every target area before bulk creation.
4. Creates typed widgets through a supported layout primitive.
5. Applies `authored-by-ai` and the workflow lineage tag.
6. Stops and asks a human to correct the board when a probe reports an
   unbound, mismatched, or occluded target.

The seeding patterns do not invent missing journey stages, destination areas,
or content bindings. Those remain caller-owned decisions.
