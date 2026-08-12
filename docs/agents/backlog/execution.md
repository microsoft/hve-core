---
title: Execution Workflow
description: Apply reviewed backlog changes to Azure DevOps, GitHub, or Jira with autonomy gates, dry-run preview, and resumable state
author: Microsoft
ms.date: 2026-08-07
ms.topic: tutorial
keywords:
  - backlog management
  - execution
  - work item creation
  - github copilot
estimated_reading_time: 5
sidebar_position: 6
---

The Execution workflow is the only part of backlog management that changes your tracker. It consumes a reviewed handoff file and applies the planned operations in sequence, or creates a single item through guided field collection.

Run `/backlog-execute run` for a handoff, or `/backlog-execute add` for one item.

## When to Use

* ✅ A handoff file has been reviewed and is ready to apply
* ➕ You need to file one item quickly with correct fields
* 🔁 An interrupted execution needs to resume without duplicating work

## Five Safety Protocols

Every operation here is externally visible. These five protocols run on every path, not as optional refinements.

### Autonomy gating

Three tiers control which operations proceed without approval.

| Tier              | Field and label updates | Iteration assignment | Create | Transition and close |
|-------------------|-------------------------|----------------------|--------|----------------------|
| Full              | Auto                    | Auto                 | Auto   | Auto                 |
| Partial (default) | Auto                    | Gate                 | Gate   | Gate                 |
| Manual            | Gate                    | Gate                 | Gate   | Gate                 |

Autonomy controls per-operation gates only. It never waives the inferred-platform confirmation, the content sanitization guards, or a required human review.

### Dry-run preview

`--dry-run` validates the full operation sequence and reports exactly what would change, without making a call. Use it on any handoff you did not author yourself.

### Upstream human review

A handoff produced by a planning agent carries human-review checkboxes. Execution inspects them before it processes anything, and halts on any unchecked box, naming the artifact and the item that blocked it.

The command never checks a box for you. Full autonomy removes per-operation gates; it does not let the agent approve its own input.

### Content sanitization

Six guards run before any tracker call:

1. Strip `.copilot-tracking/` paths
2. Remove planning reference IDs, including namespaced planner families
3. Resolve or replace temporary placeholders
4. Apply the content-policy public-output guard
5. Neutralize ingested markup so quoted text cannot cross-reference or close an unrelated item, notify uninvolved people, or embed a remote image
6. Stop on a probable secret or credential rather than silently redacting it

Unresolved planning identifiers never reach a tracker API. An internal reference leaking into a public issue body is not recoverable by editing.

### Resumable state

Execution logs each operation as it completes. On resume, completed operations are skipped and temporary identifiers created earlier in the run are rebuilt, so a parent created before an interruption is not created twice.

## Operation Sequence

Operations run in dependency order rather than file order: parents before children, creates before links, links before transitions. An operation that fails logs its error and the batch continues, because one bad field value should not strand the remaining work.

## Platform Differences

| Aspect              | Azure DevOps                               | GitHub                       | Jira                                   |
|---------------------|--------------------------------------------|------------------------------|----------------------------------------|
| Item types          | User-confirmed and recorded as unvalidated | Repository issue types       | Discovered per project                 |
| Body format         | **Markdown or HTML, detected from host**   | Markdown                     | Markdown or ADF                        |
| Hierarchy mechanism | Parent-child work item links               | Issue references, sub-issues | Issue links, epic link                 |
| State change        | State field transition                     | Open and closed, plus reason | **Workflow transition, name resolved** |

> [!NOTE]
> Item types are discovered rather than assumed on GitHub and Jira, where available types vary by organization and project, so a fixed five-type list would be wrong there.
>
> Azure DevOps is the exception: no tool in the granted surface lists a project's process types. The workflow confirms the intended types with you and records them as unvalidated rather than claiming it discovered them.
>
> Jira transitions are resolved by name against the project's workflow before use, because transition IDs differ per workflow scheme.

## Output Artifacts

Execution does not create a new completion summary. It consumes the reviewed handoff in place, checking each operation off as the operation log records it, and writes its per-operation history beside that handoff.

```text
<tracking-root>/execution/<scope-name>/
├── planning-log.md      # Phase tracking and resolved platform
├── handoff.md           # The reviewed execution contract, updated in place as operations complete
├── handoff-logs.md      # Live per-operation record, the destination binding, and the resume authority
└── handoff-dryrun.md    # Written only by a dry run; never read by a live run
```

Each file owns one thing. `handoff.md` owns the approved operation set and its human review. `handoff-logs.md` owns operation history, the verified destination binding, the temporary-identifier mapping, and completion status: an operation counts as complete only when this file holds a successful live entry for it. `handoff-dryrun.md` holds simulated results and never influences a live run.

## Next Steps

* [Discovery](discovery.md): Start a new backlog review
* [Using Workflows Together](using-together.md): End-to-end pipeline walkthrough

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
