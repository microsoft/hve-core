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
3. If Discover has a named external evidence gap, review the proposed bounded `rpi-research` segment before confirming it. The agent records a disposition for each material finding and keeps unresolved evidence as an open question or unvalidated assumption.
4. For substantial Define authoring with dependencies or interruption risk, the agent may propose an `rpi-plan` segment, followed by a linked `rpi-implement` segment after you accept the Plan. These segments organize drafting without replacing the BRD template or quality review.
5. Review the BRD Quality Reviewer findings and resolve the quality gate before Govern.
6. Supply the required approver signoff and review the versioned BRD-to-PRD handoff. The agent does not replace business approval with its own assessment.

Proposed RPI segments are recorded in session state as `rpiInvocations`; existing `researchReceipts` remain available. A Research, Plan, or Implement segment does not approve requirements or clear a phase gate.

## Example usage

Ask: "Create a BRD for reducing delayed service requests. Use `requirements/process-notes.md`, identify missing stakeholders, and define measurable outcomes without selecting a technology."

Expect an iterative BRD, traceability evidence, quality findings, and a handoff only when its approval conditions are met. Success means requirements connect to business goals and unresolved ownership or evidence remains explicit.
