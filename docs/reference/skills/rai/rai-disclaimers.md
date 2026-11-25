---
title: rai-disclaimers
description: "Verbatim RAI Planning CAUTION for Responsible AI planner sessions, reviewer output, and report requests."
sidebar_position: 1
author: Microsoft
ms.date: 2026-11-18
ms.topic: reference
keywords:
  - skill
  - rai
  - rai-disclaimers
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                  |
|-------------|----------------------------------------|
| Kind        | skill                                  |
| Source      | `.github/skills/rai/rai-disclaimers`   |
| Invocation  | Loaded on demand by referencing agents |
| Interactive | No                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Verbatim RAI Planning CAUTION for Responsible AI planner sessions, reviewer output, and report requests.
<!-- END AUTO-GENERATED: overview -->

## When to use it

RAI Planner and RAI Reviewer preload this skill to display the canonical
`RAI Planning` CAUTION block verbatim at session start, in reviewer output, and
when handing off report generation to Report Generator. Use
`security-disclaimers`, `privacy-disclaimers`, `project-planning-disclaimers`,
or `disclaimer-language` for other domains.

## Example usage

RAI Planner and RAI Reviewer declare the skill in their agent frontmatter:

```yaml
skills:
  - rai-disclaimers
  - untrusted-content-boundary
```

At session start with `disclaimerShownAt: null`, RAI Planner emits the
`RAI Planning` CAUTION block verbatim before Phase 1 scoping and persists the
display timestamp in session state. During an RAI review, RAI Reviewer passes
the same verbatim CAUTION block to Report Generator so the resulting report
preserves the legal and compliance review notice.
