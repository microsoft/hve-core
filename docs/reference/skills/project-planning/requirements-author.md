---
title: requirements-author
description: "Requirements authoring guide for BRD and PRD across Discover, Define, and Govern with canonical templates and handoff contracts"
sidebar_position: 14
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - project-planning
  - requirements-author
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                 |
|-------------|-------------------------------------------------------|
| Kind        | skill                                                 |
| Source      | `.github/skills/project-planning/requirements-author` |
| Invocation  | Loaded on demand by referencing agents                |
| Interactive | No                                                    |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Requirements authoring guide for BRD and PRD across Discover, Define, and Govern with canonical templates and handoff contracts
<!-- END AUTO-GENERATED: overview -->

## When to use it

BRD Builder and PRD Builder load this skill to author testable requirements,
maintain traceability, and govern approval and handoff. Use BRD scope for business
context and decision ownership; use PRD scope for product behavior, acceptance
criteria, and non-functional requirements. It is load-only, not a direct slash
command. Choose `functional-planner` after requirements exist when you need a
tracker-ready hierarchy rather than another requirements document.

## Example usage

Ask BRD Builder to use `requirements-author` for a fictional order-intake service,
with a supplied problem statement, stakeholder roles, scope, and outcome evidence.
Expect Discover to resolve ownership and assumptions, Define to build requirements
and traceability, and Govern to retain quality and approval evidence before
producing a durable `BRD_TO_PRD_HANDOFF_V1` payload.

Then give PRD Builder that handoff's actual path and the product constraints. The
PRD flow should validate the payload, preserve approved business scope, and develop
testable FR/NFR statements and acceptance criteria. If feasibility candidates are
also supplied, each receives a PRD-owned disposition; they are not automatically
accepted requirements.

Success means requirements trace to goals and acceptance criteria, gaps are
explicit, and quality reports support the relevant exit gates. A complete-looking
template is not approval. Unsupported handoffs, missing evidence, and required
human signoff remain blockers rather than inferred facts.
