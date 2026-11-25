---
title: Privacy/Privacy Telemetry
description: Auditable processing and consent signals in privacy plans and reviews
sidebar_position: 1
author: Microsoft
ms.date: 2026-11-18
ms.topic: reference
keywords:
  - instruction
  - privacy
  - privacy/privacy-telemetry
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                                     |
|-------------|-----------------------------------------------------------------------------------------------------------|
| Kind        | instruction                                                                                               |
| Source      | `.github/instructions/privacy/privacy-telemetry.instructions.md`                                          |
| Invocation  | Applied automatically to `**/.copilot-tracking/privacy-plans/**, **/.copilot-tracking/privacy-reviews/**` |
| Interactive | No                                                                                                        |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Auditable processing and consent signals in privacy plans and reviews
<!-- END AUTO-GENERATED: overview -->

## When to use it

Apply this instruction when authoring privacy plans under
`.copilot-tracking/privacy-plans/` or privacy review reports under
`.copilot-tracking/privacy-reviews/`. It ensures observable data-processing
decisions, consent-state transitions, and retention or erasure events are backed
by auditable log or metric signals following `telemetry-foundations` PII rules.
Skip telemetry additions when a privacy artifact covers non-observable policy
work.

## Example usage

Edit `.copilot-tracking/privacy-plans/customer-portal/privacy-plan.md` to
document a user erasure workflow. Copilot applies the instruction automatically
and prompts you to record the auditable erasure completion log event and
retention metric while stripping personal identifiers according to
`telemetry-foundations`. During a review in
`.copilot-tracking/privacy-reviews/`, findings about consent or processing
controls without corresponding log or metric evidence are flagged for
remediation.
