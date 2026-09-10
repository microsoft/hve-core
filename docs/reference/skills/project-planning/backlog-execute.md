---
title: backlog-execute
description: "Mutating backlog execution for Azure DevOps, GitHub, and Jira. Use to create one item or apply a reviewed handoff to a confirmed tracker."
sidebar_position: 2
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - project-planning
  - backlog-execute
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                             |
|-------------|-----------------------------------------------------------------------------------|
| Kind        | skill                                                                             |
| Source      | `.github/skills/project-planning/backlog-execute`                                 |
| Invocation  | Invoked directly as `/backlog-execute`, or loaded on demand by referencing agents |
| Interactive | No                                                                                |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Mutating backlog execution for Azure DevOps, GitHub, and Jira. Use to create one item or apply a reviewed handoff to a confirmed tracker.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `add` to create one work item or `run` to apply a reviewed handoff to one
confirmed Azure DevOps, GitHub, or Jira destination. Use `backlog-plan` for
read-only discovery and triage. Execution requires a compatible write surface;
missing tools do not authorize switching trackers or bypassing the host's limits.

Partial autonomy is the default. Full autonomy does not waive destination
confirmation, sanitization, human-review gates, or unresolved duplicate decisions.
An unchecked review checkbox stops handoff processing under every tier.

## Example usage

After a human reviews a sample handoff, ask: `/backlog-execute run the attached
handoff for example-org/sample-service on GitHub --dry-run --autonomy partial`.
Replace the illustrative destination with the intended repository and confirm it
when asked. Include parent-child relationships and acceptance criteria, not tokens
or personal data.

The dry run should validate and render the operation set without making mutating
calls. Its `handoff-dryrun.md` record must remain separate from live execution logs.
Success is a reviewable preview of exactly what would be sent, with invalid fields
or unresolved references reported instead of guessed.

For a single item, use `add` with a title, description, and confirmed destination;
the skill asks for missing mutation-critical fields. A later authorized live run
records returned keys operation by operation. On resume, only successful live
entries establish completion; simulated keys and checked boxes alone cannot do so.
