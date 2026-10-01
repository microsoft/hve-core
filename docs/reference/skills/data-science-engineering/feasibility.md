---
title: feasibility
description: "Author and validate durable data and ML feasibility studies using the Feasibility Study Interchange Profile, constrained YAML authority, UUID URN identity, lifecycle lineage, and evidence traceability. Use when assessing whether available data and technical evidence support a proposed outcome."
sidebar_position: 6
author: Microsoft
ms.date: 2026-08-19
ms.topic: reference
keywords:
  - skill
  - data-science-engineering
  - feasibility
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                 |
|-------------|-------------------------------------------------------|
| Kind        | skill                                                 |
| Source      | `.github/skills/data-science-engineering/feasibility` |
| Invocation  | Loaded on demand by referencing agents                |
| Interactive | No                                                    |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Author and validate durable data and ML feasibility studies using the Feasibility Study Interchange Profile, constrained YAML authority, UUID URN identity, lifecycle lineage, and evidence traceability. Use when assessing whether available data and technical evidence support a proposed outcome.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `feasibility` when a proposed data or ML outcome needs an evidence-led
recommendation that remains durable and machine-consumable. It preserves
capability candidates, findings, risks, gaps, criteria state, provenance, and
lifecycle lineage in one Markdown study.

Use `experiment-design` to frame a specific experiment and
`ml-experimentation` for ML tracking or readiness. A future Functional Planner
may consume the study, but this skill does not allocate functional requirement
numbers or write downstream mappings into the source.

## Example usage

Assess whether six months of historical interaction and outcome data supports a
recommendation pilot. The skill creates one constrained YAML authority block,
assigns stable UUID URNs, links the capability candidate to evidence, records
the unresolved quality threshold as a review gap, and validates the study before
publication.
