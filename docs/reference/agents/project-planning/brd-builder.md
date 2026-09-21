---
title: BRD Builder
description: "Business Requirements Document builder with guided Q&A and references"
sidebar_position: 3
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - project-planning
  - brd-builder
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                  |
|-------------|--------------------------------------------------------|
| Kind        | agent                                                  |
| Source      | `.github/agents/project-planning/brd-builder.agent.md` |
| Invocation  | Selected from the chat agent picker as `BRD Builder`   |
| Interactive | Yes                                                    |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Business Requirements Document builder with guided Q&A and references
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use BRD Builder to turn an initiative into solution-neutral business requirements with stakeholder ownership, measurable goals, and traceability. Use PRD Builder for product-level behavior once the business direction is established; do not use a BRD to prescribe implementation details.

## How to use it

1. Select `BRD Builder` and provide the initiative name, business problem, affected stakeholders, and reference material.
2. Establish scope and ownership in Discover, then refine testable requirements and their goal and acceptance-criteria links in Define.
3. Review the BRD Quality Reviewer findings and resolve the quality gate before Govern.
4. Supply the required approver signoff and review the versioned BRD-to-PRD handoff. The agent does not replace business approval with its own assessment.

## Example usage

Ask: "Create a BRD for reducing delayed service requests. Use `requirements/process-notes.md`, identify missing stakeholders, and define measurable outcomes without selecting a technology."

Expect an iterative BRD, traceability evidence, quality findings, and a handoff only when its approval conditions are met. Success means requirements connect to business goals and unresolved ownership or evidence remains explicit.
