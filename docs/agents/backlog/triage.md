---
title: Triage Workflow
description: Classify work items and detect duplicates across Azure DevOps, GitHub, and Jira
author: Microsoft
ms.date: 2026-08-07
ms.topic: tutorial
keywords:
  - backlog management
  - triage
  - duplicate detection
  - github copilot
estimated_reading_time: 5
sidebar_position: 3
---

The Triage workflow classifies existing items and recommends field, label, priority, and status changes. It is read-only: triage produces recommendations, and applying them is `backlog-execute`'s job.

Run it with `/backlog-plan triage`.

## When to Use

* 📥 A backlog has accumulated unclassified items
* 🔁 Duplicate reports are suspected
* 📊 Field consistency matters for reporting or filtering
* 🧹 Preparing a backlog before sprint planning

## What It Does

1. Resolves the backing tracker and identifies triage candidates
2. Classifies each item across the platform's categorization dimensions
3. Compares items across several similarity dimensions to flag duplicates
4. Records recommendations with reasoning in a planning file
5. Produces a handoff file for review before anything is applied

> [!NOTE]
> Triage recommends rather than applies. A classification you disagree with costs a line edit in the handoff file, not a tracker correction.

## Classification Dimensions

Every platform classifies along the same conceptual axes. The field names differ.

| Axis            | Azure DevOps         | GitHub                      | Jira                     |
|-----------------|----------------------|-----------------------------|--------------------------|
| Ownership area  | Area Path            | Label (area category)       | Component                |
| Urgency         | Priority             | Label (priority category)   | Priority                 |
| Defect severity | Severity (bugs only) | Label (severity convention) | Priority or custom field |
| Free tagging    | Tags                 | Label (type and lifecycle)  | Labels                   |
| Scheduling      | Iteration Path       | Milestone                   | Sprint                   |

> [!NOTE]
> GitHub expresses most axes through a single label namespace, so its taxonomy carries the weight that separate fields carry elsewhere. Triage applies the repository's existing label conventions rather than imposing a fixed set.

## Duplicate Detection

Duplicate candidates are assessed across multiple similarity dimensions rather than a title match alone: title overlap, description overlap, component or area agreement, and reporter and timeframe proximity. An item is flagged when enough dimensions agree, and the reasoning is recorded so you can judge the call.

Ambiguous duplicates are always gated for human decision regardless of autonomy tier. Closing a real report as a duplicate is expensive to reverse.

## Trigger Criteria

Triage candidates are identified from classification state rather than requiring a manual list: items missing categorization, items in an initial state past a staleness threshold, and items whose type and content disagree.

## Output Artifacts

```text
<tracking-root>/triage/<scope-name>/
├── planning-log.md      # Candidates, classification reasoning, phase tracking, and the plan path
└── triage-plan.md       # Reviewed recommendations, including duplicate candidates and their similarity classification
```

Duplicate evidence lives in `triage-plan.md` rather than a separate file, and that same plan is the execution input: `backlog-execute run <triage-plan.md>` applies the recommendations in a separate pass. Triage itself issues no mutating call.

## Next Steps

* [Sprint Planning](sprint-planning.md): Organize triaged work into an iteration
* [Execution](execution.md): Apply the reviewed triage handoff
* [Using Workflows Together](using-together.md): End-to-end pipeline walkthrough

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
