---
title: privacy-by-design
description: "Privacy by Design (PbD) knowledge base for assessing proactive privacy practices against the 7 Foundation Principles, with data retention and disposal lifecycle checks and cross-jurisdictional mappings (GDPR, CCPA, APP)."
sidebar_position: 11
author: Microsoft
ms.date: 2026-09-06
ms.topic: reference
keywords:
  - skill
  - project-planning
  - privacy-by-design
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                               |
|-------------|-----------------------------------------------------|
| Kind        | skill                                               |
| Source      | `.github/skills/project-planning/privacy-by-design` |
| Invocation  | Loaded on demand by referencing agents              |
| Interactive | No                                                  |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Privacy by Design (PbD) knowledge base for assessing proactive privacy practices against the 7 Foundation Principles, with data retention and disposal lifecycle checks and cross-jurisdictional mappings (GDPR, CCPA, APP).
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this knowledge base when reviewing a feature or data flow against the seven Privacy by Design principles. For example, a customer portal review can examine privacy-protective defaults, consent controls, retention schedules, and disposal evidence together.

Provide the system boundary, applicable jurisdictions, data categories, and available implementation evidence. Use the `privacy-standards` skill instead when you need general standards mapping or DPIA threshold guidance without a principle-level assessment.

The skill supports review preparation, not legal advice or compliance certification. Have a qualified reviewer validate regulatory interpretations and proposed actions.

## Example usage

During a privacy review, ask the agent to use `privacy-by-design` to assess a customer portal's consent defaults and account-deletion lifecycle. Supply the data-flow description, consent configuration, retention policy, and deletion-test results.

The expected assessment records a verdict for each principle, evidence-backed findings with severity and suggested actions, and any missing evidence. For example, a documented retention policy without evidence that deletion runs should produce an explicit evidence gap rather than an unsupported passing result.
