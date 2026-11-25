---
title: privacy-disclaimers
description: Verbatim CAUTION notices for Privacy Planner sessions and Privacy Reviewer findings. Use the section for the active role.
sidebar_position: 1
author: Microsoft
ms.date: 2026-11-18
ms.topic: reference
keywords:
  - skill
  - privacy
  - privacy-disclaimers
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                        |
|-------------|----------------------------------------------|
| Kind        | skill                                        |
| Source      | `.github/skills/privacy/privacy-disclaimers` |
| Invocation  | Loaded on demand by referencing agents       |
| Interactive | No                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Verbatim CAUTION notices for Privacy Planner sessions and Privacy Reviewer findings. Use the section for the active role.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Privacy Planner and Privacy Reviewer preload this skill so they can emit the
canonical privacy professional-review CAUTION block verbatim without duplicating
disclaimer text across agents. Select `Privacy Planning` for plans and planner
handoffs, and `Privacy Review` for review findings. Use `security-disclaimers`,
`rai-disclaimers`, `project-planning-disclaimers`, or `disclaimer-language` for
other domains.

## Example usage

Privacy Planner declares the skill in its agent frontmatter:

```yaml
skills:
  - privacy-disclaimers
  - untrusted-content-boundary
```

When a new privacy planning session starts with `disclaimerShownAt: null`, the
agent outputs the `Privacy Planning` CAUTION block verbatim before Phase 1
questions and records the display timestamp in session state. Privacy Reviewer
loads the `Privacy Review` section instead when rendering privacy review reports.
