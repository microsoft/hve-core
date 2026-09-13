---
title: HVE Builder Reviewer
description: "Reviews one prompt, instruction, agent, subagent, or skill candidate in fresh context against the hve-builder requirements catalog and review rubric, and returns severity-graded findings with the smallest resolving change as suggestions for the calling agent to verify. Use during an hve-builder review pass when isolating the review would help."
sidebar_position: 1
author: Microsoft
ms.date: 2026-09-11
ms.topic: reference
keywords:
  - agent
  - hve-core
  - hve-builder-review
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                    |
|-------------|--------------------------------------------------------------------------|
| Kind        | agent                                                                    |
| Source      | `.github/agents/hve-core/subagents/hve-builder-review.agent.md`          |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly) |
| Interactive | No                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Reviews one prompt, instruction, agent, subagent, or skill candidate in fresh context against the hve-builder requirements catalog and review rubric, and returns severity-graded findings with the smallest resolving change as suggestions for the calling agent to verify. Use during an hve-builder review pass when isolating the review would help.
<!-- END AUTO-GENERATED: overview -->

## When to use it

`HVE Builder Reviewer` is an optional helper that [hve-builder](../../../skills/hve-core/hve-builder) may dispatch during its review pass, not a required step and not something a user selects. The main agent reviews its own candidate by default; it asks this reviewer for a fresh-context pass when the authoring context is long or invested in its own reasoning, when the change alters a decision rule, stage gate, write authority, or safety behavior, or when the caller asks for an isolated review.

The reviewer reads the candidate and the supplied requirements catalog, review rubric, and repository instructions, then returns severity-graded findings with the smallest resolving change for each, plus a suggested `Pass`, `Revise`, or `Blocked` verdict. It can also verify a named set of finding IDs after corrections as targeted closure.

Every finding is a suggestion. The main agent reads each cited location, confirms or rejects the finding, applies the required corrections itself, and records the review evidence. The reviewer writes no file, never inspects agent `tools:` configuration, and never speaks to the user.

## Example usage

A representative dispatch from an `hve-builder` run that just changed a skill's stage gates:

```text
Review .github/skills/example/example-skill/SKILL.md and its references/workflow.md
against the hve-builder requirements catalog and review rubric. Purpose: the skill
now requires local validation before its review stage. Baseline: the pre-edit copy
at the supplied path. Read-only; ignore tools: configuration. Return one complete
finding set.
```

The reviewer returns, for example, one High required finding that the new gate is stated in the SKILL.md flow but contradicted by an older sentence in the reference, with the section names and a one-line fix. The main agent reads both sections, confirms the contradiction, removes the stale sentence, and asks the reviewer to close that finding ID.
