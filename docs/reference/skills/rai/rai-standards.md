---
title: rai-standards
description: "Consolidated Responsible AI standards reference: NIST AI RMF 1.0, AI STRIDE threat-modeling overlay, EU AI Act risk tiers, and an open-standards catalog with phase mapping"
sidebar_position: 1
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - rai
  - rai-standards
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                  |
|-------------|----------------------------------------|
| Kind        | skill                                  |
| Source      | `.github/skills/rai/rai-standards`     |
| Invocation  | Loaded on demand by referencing agents |
| Interactive | No                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Consolidated Responsible AI standards reference: NIST AI RMF 1.0, AI STRIDE threat-modeling overlay, EU AI Act risk tiers, and an open-standards catalog with phase mapping
<!-- END AUTO-GENERATED: overview -->

## When to use it

The RAI Planner loads this standards package for NIST AI RMF mapping, the Microsoft
AI STRIDE overlay, and a paraphrased EU AI Act reference. Use it when an assessment
needs a standards baseline; use the `rai-planner` reference for phase-specific
workflow guidance instead.

Additional organizational frameworks layer onto the default NIST mapping rather
than replacing it. Restricted standards remain citation-only, and regulatory
interpretation requires qualified review rather than reliance on a packaged summary.

## Example usage

Ask the RAI Planner to load `rai-standards` for a fictional document-summarization
assistant. Supply its intended users, data categories, oversight design, and a
short organization-authored policy. Request a standards map, not a legal conclusion.

The planner should retain the NIST baseline, map the supplied policy as an
attributed extension, and select phase-relevant references for measurement,
threat analysis, or impact management. Success is a map from system facts and
planned controls to standards references, with missing evidence and regulatory
questions visible. Do not paste restricted normative text or treat the output as
certification, model evaluation results, or approval to deploy.
