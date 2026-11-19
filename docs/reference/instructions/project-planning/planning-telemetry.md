---
title: Project Planning/Planning Telemetry
description: Telemetry choices in architecture decisions and acceptance criteria in product requirements
sidebar_position: 6
author: Microsoft
ms.date: 2026-11-18
ms.topic: reference
keywords:
  - instruction
  - project-planning
  - project-planning/planning-telemetry
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                                                        |
|-------------|------------------------------------------------------------------------------------------------------------------------------|
| Kind        | instruction                                                                                                                  |
| Source      | `.github/plugins/project-planning/instructions/project-planning/planning-telemetry.instructions.md`                          |
| Invocation  | Applied automatically to `**/.copilot-tracking/adr-plans/**, **/docs/planning/adrs/**, **/.copilot-tracking/prd-sessions/**` |
| Interactive | No                                                                                                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Telemetry choices in architecture decisions and acceptance criteria in product requirements
<!-- END AUTO-GENERATED: overview -->

## When to use it

Apply this instruction when drafting or updating Architecture Decision Records
under `.copilot-tracking/adr-plans/` or `docs/planning/adrs/`, or Product
Requirements Documents under `.copilot-tracking/prd-sessions/`. Use it when an
architecture decision or product requirement affects observable production
behavior so telemetry choices and acceptance criteria stay grounded in
`telemetry-foundations`. Omit telemetry sections when the decision or
requirement introduces no observable runtime behavior.

## Example usage

Draft an ADR at `docs/planning/adrs/0042-async-order-queue.md` or a PRD under
`.copilot-tracking/prd-sessions/order-sync/`. In the ADR, Copilot records the
queue-depth metric and dead-letter alert strategy under **Consequences** with
citations to the matching `telemetry-foundations` section. In the PRD, Copilot
adds measurable latency and failure-rate telemetry acceptance criteria under
**Success Metrics** and **Operational Readiness**.
