---
title: Project Planning/Github Backlog Grooming
description: "Reusable GitHub backlog grooming policy for evidence-backed assessment, advisory dispositions, and approved writeback"
sidebar_position: 7
author: Microsoft
ms.date: 2026-08-25
ms.topic: reference
keywords:
  - instruction
  - project-planning
  - project-planning/github-backlog-grooming
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                           |
|-------------|---------------------------------------------------------------------------------|
| Kind        | instruction                                                                     |
| Source      | `.github/instructions/project-planning/github-backlog-grooming.instructions.md` |
| Invocation  | Applied automatically to `**/.copilot-tracking/github-issues/backlog/**`        |
| Interactive | No                                                                              |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Reusable GitHub backlog grooming policy for evidence-backed assessment, advisory dispositions, and approved writeback
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this instruction when an open GitHub issue inventory needs an
evidence-backed health review. It defines how to compare issues, reconcile
acceptance signals with current repository state and history, assign advisory
dispositions, and report results without changing candidate issues.

Backlog Manager applies the instruction directly for interactive GitHub
Grooming requests. It accepts or builds an ordinary issue inventory, gathers
repository evidence, and returns the compact advisory report. The policy does
not require automation manifests, checkpoints, digests, or publication jobs.

Repository automation can reuse the assessment policy while keeping its worker
schema, provenance, validation, and publication mechanics in the owning agent
and workflow. Use backlog triage for label and milestone recommendations, and
use GitHub Backlog Executor only after a maintainer approves a grooming
handoff.

Grooming never closes issues. A handoff can contain one `Update` or `Comment`
per issue, must include the issue's current `updated_at` value, and requires
explicit approval for every proposed field or comment. Changed issue state
invalidates the approval and requires reassessment.

## Example usage

A maintainer asks Backlog Manager to assess two open issues against the default
branch and related history. One request is already satisfied by a merged pull
request and current documentation. The other still describes missing work.
Backlog Manager returns advisory output without invoking a workflow worker or
mutating either issue.

| Issue | Similarity | Disposition      | Status   | Recommended next step                                              |
|-------|------------|------------------|----------|--------------------------------------------------------------------|
| #123  | Distinct   | Likely completed | Assessed | Verify the cited acceptance evidence, then decide whether to close |
| #456  | Distinct   | Still needed     | Assessed | Keep open and clarify the remaining acceptance signal              |

### Issue #123: Document the supported setup

* Selection reason: Included in the maintainer-supplied inventory
* Activity and ownership: Open, recently reviewed, no active assignee
* Acceptance signals: Publish the supported setup and link it from the guide
* Repository evidence: `docs/getting-started/example.md`; pull request #789
* Lineage evidence: Pull request #789 delivered the current documentation
* Grooming finding: Current repository evidence satisfies the requested outcome
* Recommended next step: Verify the evidence before making a maintainer-owned closure decision
* Assessment status: Assessed
* Deferral reason: None

If the maintainer instead approves a title correction for issue #456, Backlog
Manager prepares one `Update` with only the approved `title` and the issue's
RFC 3339 `Expected Updated At` value. GitHub Backlog Executor rechecks that
value immediately before applying the update.
