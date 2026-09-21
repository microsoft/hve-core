---
title: privacy-standards
description: "Privacy planning reference for data-flow reasoning, standards mapping, and DPIA thresholds"
sidebar_position: 11
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - project-planning
  - privacy-standards
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                               |
|-------------|-----------------------------------------------------|
| Kind        | skill                                               |
| Source      | `.github/skills/project-planning/privacy-standards` |
| Invocation  | Loaded on demand by referencing agents              |
| Interactive | No                                                  |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Privacy planning reference for data-flow reasoning, standards mapping, and DPIA thresholds
<!-- END AUTO-GENERATED: overview -->

## When to use it

Privacy Planner and Privacy Reviewer load this reference for data-lifecycle
mapping, privacy-risk reasoning, control selection, and data protection impact
assessment (DPIA) threshold questions. It separates data categories from processing
purpose and covers collection through deletion. It is a planning aid, not legal
advice or a substitute for formal regulatory interpretation.

## Example usage

Ask the Privacy Planner to load `privacy-standards` for a fictional support portal.
Provide a schema-level inventory of contact details and ticket text, processing
purposes, retention periods, sharing boundaries, and deletion behavior. Use field
names and synthetic examples, not real ticket contents.

The planner should map the lifecycle, flag evidence needed for sensitive data or
cross-organization sharing, and assess whether deeper DPIA review is warranted.
Expect controls and findings with applicable citation fields such as
`nist_pf_category` or `gdpr_article`, backed by the relevant references rather
than guessed legal claims. Success is an evidence-linked privacy review input
with open questions and qualified-review needs clearly separated from decisions
already supported by evidence.
