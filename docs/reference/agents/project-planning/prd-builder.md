---
title: PRD Builder
description: "Product Requirements Document builder with guided Q&A and references"
sidebar_position: 7
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - project-planning
  - prd-builder
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                  |
|-------------|--------------------------------------------------------|
| Kind        | agent                                                  |
| Source      | `.github/agents/project-planning/prd-builder.agent.md` |
| Invocation  | Selected from the chat agent picker as `PRD Builder`   |
| Interactive | Yes                                                    |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Product Requirements Document builder with guided Q&A and references
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use PRD Builder to develop measurable product requirements from a product brief, references, or a requirements handoff. It iteratively connects functional and non-functional requirements to goals and acceptance criteria. Use BRD Builder for business-level framing and Functional Planner for the later work-item hierarchy.

## How to use it

1. Select `PRD Builder` and provide the product problem, intended users, scope, and available references.
2. Answer focused questions as the agent establishes the document and refines requirements. Describe observable behavior rather than prescribing code or internal implementation steps.
3. Review citations, conflicts, quality findings, and open questions before final approval.
4. Request a backlog handoff separately when ready. Document completion does not create tracker items or implement the product.

## Example usage

Ask: "Build a PRD for a resumable import experience using `requirements/import-brief.md`. Cover user-visible progress, cancellation, recovery, and measurable limits. Keep architecture decisions separate and flag missing evidence."

Expect a traceable PRD with testable behavior, acceptance criteria, and an explicit lifecycle status. Success means an engineer can understand what must hold without mistaking an implementation suggestion for a product requirement.
