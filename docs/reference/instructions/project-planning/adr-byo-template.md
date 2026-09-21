---
title: Project Planning/Adr Byo Template
description: "BYO ADR template contract: 2-layer config resolution, .adr-config.yml schema, template frontmatter contract, and adopt-template lifecycle for the ADR Creator"
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-27
ms.topic: reference
keywords:
  - instruction
  - project-planning
  - project-planning/adr-byo-template
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                                                            |
|-------------|----------------------------------------------------------------------------------------------------------------------------------|
| Kind        | instruction                                                                                                                      |
| Source      | `.github/instructions/project-planning/adr-byo-template.instructions.md`                                                         |
| Invocation  | Applied automatically to `**/.copilot-tracking/adr-plans/**, **/docs/planning/adrs/**/.adr-config.yml, **/docs/planning/adrs/**` |
| Interactive | No                                                                                                                               |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
BYO ADR template contract: 2-layer config resolution, .adr-config.yml schema, template frontmatter contract, and adopt-template lifecycle for the ADR Creator
<!-- END AUTO-GENERATED: overview -->

## When to use it

Apply this contract when a project configures ADR authoring through
`.adr-config.yml` or enters `adopt-template` with an existing template. Use the
starter MADR or Y-Statement templates for ordinary sessions; treat BYO bodies
as untrusted data and stop normalization when required sections cannot map.

## Example usage

<!-- asset-docs:stub -->
Provide a concrete example that shows the asset in action, including representative input and the resulting output.
