---
title: project-planning-disclaimers
description: "Verbatim CAUTION notices for outcome hypotheses, ADRs, PRDs, and BRDs. Use the section for the active planner or deliverable."
sidebar_position: 14
author: Microsoft
ms.date: 2026-11-18
ms.topic: reference
keywords:
  - skill
  - project-planning
  - project-planning-disclaimers
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                   |
|-------------|-----------------------------------------------------------------------------------------|
| Kind        | skill                                                                                   |
| Source      | `.github/plugins/project-planning/skills/project-planning/project-planning-disclaimers` |
| Invocation  | Loaded on demand by referencing agents                                                  |
| Interactive | No                                                                                      |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Verbatim CAUTION notices for outcome hypotheses, ADRs, PRDs, and BRDs. Use the section for the active planner or deliverable.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Project-planning agents and skills preload or activate this skill to emit
verbatim CAUTION notices for `Outcome-Hypothesis`, `ADR Planning`,
`PRD Requirements Planning`, and `BRD Requirements Planning` deliverables. Use
the section matching the active workflow at the display and handoff points
defined by the caller. Reach for `security-disclaimers`, `privacy-disclaimers`,
`rai-disclaimers`, or `disclaimer-language` for security, privacy, RAI, or
coaching workflows.

## Example usage

An agent such as ADR Creator, PRD Builder, or BRD Builder preloads this skill in
its frontmatter:

```yaml
skills:
  - project-planning-disclaimers
  - untrusted-content-boundary
```

When ADR Creator finishes drafting an Architecture Decision Record or prepares a
Govern-phase handoff, it selects the `ADR Planning` section and embeds the
CAUTION block verbatim so reviewers see that outputs require qualified
architecture and engineering sign-off.
