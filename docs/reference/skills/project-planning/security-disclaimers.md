---
title: security-disclaimers
description: "Verbatim CAUTION notices for Security Planning, SSSC Planning, and Security-Review. Use the named section when displaying a notice or rendering a report or handoff."
sidebar_position: 18
author: Microsoft
ms.date: 2026-11-18
ms.topic: reference
keywords:
  - skill
  - project-planning
  - security-disclaimers
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                        |
|-------------|------------------------------------------------------------------------------|
| Kind        | skill                                                                        |
| Source      | `.github/plugins/sdlc-security/skills/project-planning/security-disclaimers` |
| Invocation  | Loaded on demand by referencing agents                                       |
| Interactive | No                                                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Verbatim CAUTION notices for Security Planning, SSSC Planning, and Security-Review. Use the named section when displaying a notice or rendering a report or handoff.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Security Planner, SSSC Planner, Security Reviewer, SSSC Reviewer, and security
report tooling preload or read this skill to emit verbatim CAUTION notices for
`Security Planning`, `SSSC Planning`, and `Security-Review`. Pick the section
that matches the active planner, reviewer, or threat-model output. Use
`rai-disclaimers`, `privacy-disclaimers`, `project-planning-disclaimers`, or
`disclaimer-language` for non-security workflows.

## Example usage

Security Planner preloads this skill in its agent frontmatter:

```yaml
skills:
  - security-disclaimers
  - untrusted-content-boundary
```

When starting a new security plan or resuming a session with
`disclaimerShownAt: null`, the planner displays the `Security Planning` CAUTION
block verbatim before asking Phase 1 scoping questions, then updates
`disclaimerShownAt` and appends a `session-start-disclaimer` entry in
`state.json`. If the skill cannot be loaded, the planner halts before phase
work.
