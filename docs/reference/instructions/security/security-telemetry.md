---
title: Security/Security Telemetry
description: "Telemetry evidence for security plans, supply-chain plans, and supply-chain reviews"
sidebar_position: 2
author: Microsoft
ms.date: 2026-11-18
ms.topic: reference
keywords:
  - instruction
  - security
  - security/security-telemetry
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                                                                       |
|-------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| Kind        | instruction                                                                                                                                 |
| Source      | `.github/instructions/security/security-telemetry.instructions.md`                                                                          |
| Invocation  | Applied automatically to `**/.copilot-tracking/security-plans/**, **/.copilot-tracking/sssc-plans/**, **/.copilot-tracking/sssc-reviews/**` |
| Interactive | No                                                                                                                                          |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Telemetry evidence for security plans, supply-chain plans, and supply-chain reviews
<!-- END AUTO-GENERATED: overview -->

## When to use it

Apply this instruction when working on security plans under
`.copilot-tracking/security-plans/`, supply-chain security plans under
`.copilot-tracking/sssc-plans/`, or supply-chain reviews under
`.copilot-tracking/sssc-reviews/`. It aligns STRIDE threat entries with
`telemetry-foundations` log severity levels and enforces `vcs.*` and `ci.*`
resource attributes on build and release controls. Use `rai-telemetry` or
`privacy-telemetry` for RAI or privacy planning artifacts instead.

## Example usage

Edit a security plan at
`.copilot-tracking/security-plans/api-gateway/security-plan.md` or a
supply-chain review under `.copilot-tracking/sssc-reviews/`. For the security
plan, Copilot cross-references authentication failure STRIDE threats with
`telemetry-foundations` security-event log severities. For the supply-chain
review, Copilot flags build provenance findings that lack supporting `vcs.*` or
`ci.*` telemetry attributes.
