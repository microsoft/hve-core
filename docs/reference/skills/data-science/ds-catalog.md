---
title: ds-catalog
description: "Create and enrich durable data catalogs using the native DS_CATALOG_V1 Markdown contract, declared entity relationships, privacy citation fields, and stable relationship IDs. Use when inventorying engagement data, recording semantic relationships, or preparing a catalog for ERD rendering."
sidebar_position: 3
author: Microsoft
ms.date: 2026-08-14
ms.topic: reference
keywords:
  - skill
  - data-science
  - ds-catalog
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                    |
|-------------|------------------------------------------|
| Kind        | skill                                    |
| Source      | `.github/skills/data-science/ds-catalog` |
| Invocation  | Loaded on demand by referencing agents   |
| Interactive | No                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Create and enrich durable data catalogs using the native DS_CATALOG_V1 Markdown contract, declared entity relationships, privacy citation fields, and stable relationship IDs. Use when inventorying engagement data, recording semantic relationships, or preparing a catalog for ERD rendering.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `ds-catalog` when an engagement needs a durable inventory of business
entities, declared relationships, lineage, data tiers, access state, and
privacy citations. It is the source authority for catalog-driven ERD rendering.

Use `ds-dataops` for pipeline tier behavior and validation rules, and use
`privacy-standards` when sensitivity or privacy mappings need interpretation.
The catalog records those decisions but does not make them.

## Example usage

Ask the Data Workstream Coach to catalog a CRM customer entity and an ERP order
entity. The skill writes `DS_CATALOG_V1` frontmatter with stable entity and
relationship IDs, paired join keys, confidence, basis, and reconciled coverage.
The same declared relationship can then be rendered without inferring semantics
from SQL or ORM files.
