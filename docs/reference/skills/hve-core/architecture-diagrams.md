---
title: architecture-diagrams
description: Architecture diagram authoring for cloud infrastructure and declared data catalogs. Use when rendering Azure IaC or DS_CATALOG_V1 relationships as caller-selected ASCII or Mermaid diagrams.
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-19
ms.topic: reference
keywords:
  - skill
  - hve-core
  - architecture-diagrams
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                   |
|-------------|-----------------------------------------------------------------------------------------|
| Kind        | skill                                                                                   |
| Source      | `.github/skills/hve-core/architecture-diagrams`                                         |
| Invocation  | Invoked directly as `/architecture-diagrams`, or loaded on demand by referencing agents |
| Interactive | No                                                                                      |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Architecture diagram authoring for cloud infrastructure and declared data catalogs. Use when rendering Azure IaC or DS_CATALOG_V1 relationships as caller-selected ASCII or Mermaid diagrams.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `architecture-diagrams` when infrastructure source files need a reviewable
ASCII or Mermaid architecture view, or when a `DS_CATALOG_V1` catalog needs an
entity relationship diagram generated from declared relationships.

Use `data-catalog` first when entity meaning, endpoints, cardinality, join keys,
or confidence have not been declared. The diagram skill renders those facts but
does not infer them from SQL or ORM sources.

## Example usage

Ask for a Mermaid diagram from a data catalog containing Customer and Sales
Order Line entities with a confirmed one-to-many relationship. The skill emits
an `erDiagram` using the declared cardinality, includes scalar or composite join
keys in the relationship label, and lists confidence and evidence basis for
review. Selecting ASCII produces the same facts in compact text form.
