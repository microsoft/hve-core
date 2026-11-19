---
title: Rai/Rai Telemetry
description: Model-output telemetry evidence in RAI impact assessments
sidebar_position: 1
author: Microsoft
ms.date: 2026-11-18
ms.topic: reference
keywords:
  - instruction
  - rai
  - rai/rai-telemetry
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                |
|-------------|--------------------------------------------------------------------------------------|
| Kind        | instruction                                                                          |
| Source      | `.github/plugins/sdlc-responsible-ai/instructions/rai/rai-telemetry.instructions.md` |
| Invocation  | Applied automatically to `**/.copilot-tracking/rai-plans/**`                         |
| Interactive | No                                                                                   |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Model-output telemetry evidence in RAI impact assessments
<!-- END AUTO-GENERATED: overview -->

## When to use it

Apply this instruction when producing Responsible AI impact assessments under
`.copilot-tracking/rai-plans/`. It requires model-output latency, refusal rate,
and content-filter trigger metrics to follow the instrument, unit, and PII
conventions in `telemetry-foundations`. Reach for `security-telemetry` or
`privacy-telemetry` instead when authoring security models, supply-chain plans,
or privacy impact assessments.

## Example usage

Update an impact assessment at
`.copilot-tracking/rai-plans/support-assistant/impact-assessment.md` for a
customer-facing chat endpoint. Copilot applies the instruction automatically and
records model-output latency in standard units, refusal-rate counters, and
content-filter trigger metrics using `telemetry-foundations` naming without
capturing raw user prompts in telemetry attributes.
