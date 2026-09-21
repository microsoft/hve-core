---
title: adr-author
description: "Authoring skill for Architecture Decision Records (ADRs) supporting capture, from-planner-handoff, and adopt-template entry modes with selectable Y-Statement or MADR v4.0.0 output templates, supersession lineage, and ASR trigger evaluation."
sidebar_position: 1
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - project-planning
  - adr-author
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                        |
|-------------|------------------------------------------------------------------------------|
| Kind        | skill                                                                        |
| Source      | `.github/skills/project-planning/adr-author`                                 |
| Invocation  | Invoked directly as `/adr-author`, or loaded on demand by referencing agents |
| Interactive | No                                                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Authoring skill for Architecture Decision Records (ADRs) supporting capture, from-planner-handoff, and adopt-template entry modes with selectable Y-Statement or MADR v4.0.0 output templates, supersession lineage, and ASR trigger evaluation.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill directly or through ADR Creator to record one architectural
decision, its alternatives, rationale, and consequences. Choose `capture` for a
new conversation, `from-planner-handoff` for pre-populated planning evidence, or
`adopt-template` to normalize an existing project template.

Entry mode and output format are independent. A Y-Statement suits a compact,
reversible decision; MADR v4 adds architecturally significant requirement (ASR)
evaluation. This is decision documentation, not implementation or backlog execution.

## Example usage

Ask: `/adr-author Capture the decision between a queue and synchronous calls for
our sample order service. Use madr-v4 and an ASCII diagram. The platform team
decides; latency and failure isolation are the drivers.` Supply constraints and
evidence for both options, using team roles rather than personal contact details.

The expected flow confirms Frame, evaluates at least two options and their
downsides in Decide, and waits for confirmation before Govern. Govern validates
the document and lineage, allocates its identifier, and writes the ADR under
`docs/planning/adrs/`. Success is a validated decision with rationale and traceable
consequences, not an unreviewed assertion that an option won.

For `from-planner-handoff`, attach the planner's findings but still confirm Frame.
For `adopt-template`, supply the existing template and expect normalization plus
the first ADR and project configuration; missing lineage fields require explicit
confirmation before writing. Sensitive-content checks remain required in every
route, and emitted work items are handoffs rather than tracker mutations.
