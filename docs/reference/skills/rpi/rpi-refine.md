---
title: rpi-refine
description: "Review completed RPI work for what can be removed, simplified, consolidated, or redesigned across code, docs, domain language, tests, architecture, error boundaries, performance, language versions, and configuration, then route findings into planning or follow-up. Use when completed work needs subtractive refinement review."
sidebar_position: 5
author: Microsoft
ms.date: 2026-11-12
ms.topic: reference
keywords:
  - skill
  - rpi
  - rpi-refine
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                        |
|-------------|------------------------------------------------------------------------------|
| Kind        | skill                                                                        |
| Source      | `.github/skills/rpi/rpi-refine`                                              |
| Invocation  | Invoked directly as `/rpi-refine`, or loaded on demand by referencing agents |
| Interactive | No                                                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Review completed RPI work for what can be removed, simplified, consolidated, or redesigned across code, docs, domain language, tests, architecture, error boundaries, performance, language versions, and configuration, then route findings into planning or follow-up. Use when completed work needs subtractive refinement review.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `rpi-refine` after implementation finishes to examine completed work for what can be removed, simplified, consolidated, or redesigned across everything the session touched.
While [rpi-review](rpi-review) checks whether delivered work meets planned requirements and acceptance criteria, `rpi-refine` looks across code, tests, documents, domain language, conventions, SDKs and libraries, base assumptions, error boundaries, runtime performance, language versions, and configuration to cut unnecessary weight and surface workarounds that warrant redesign.

During an [rpi](rpi) or [RPI Agent](../../agents/hve-core/rpi-agent) session, `rpi-refine` runs alongside `rpi-review` in the Review phase, and the [RPI Workflow canvas](../../../rpi/rpi-workflow-canvas) displays both reviews together in its Review view.
When a Project coordinates the session on significant changes, the coordinator can create a dedicated fresh-context session just to run and manage `rpi-refine` and hand back the completed record; without a Project coordinator (standalone `/rpi-refine` or single-session RPI), the current main agent runs and manages `rpi-refine` directly.

The main agent owns the refinement analysis, backward logic tracing, assumption and domain judgment, and authoring of `-refinement.md` across four subtractive lenses.
When subagent dispatch is available, the main agent creates and manages regular subagents strictly for narrow targeted lookups (such as finding existing SDKs/helpers, enumerating call sites, checking test overlap, or scanning docs/configs for duplicates); pass `subagents=none` to run every lookup directly in the main agent:

* Logic, branching, error boundaries, and performance: removable logic lines, deep branching simplified by tracing backward from outputs to inputs, redundant internal guards where failing fast or handling errors higher up the stack is cleaner (never removing trust-boundary, containment, auth, secret, or untrusted-content checks), and CPU, memory, or I/O waste.
* Conventions, SDKs, libraries, and language versions: missed workspace helpers or SDKs, leftover scaffolding from corrected assumptions, avoidable added packages versus hand-rolled code replaceable by existing libraries, unused current-version language features, and safe non-breaking version upgrade offers.
* Assumptions, architecture, abstractions, and tests: compensating logic stacked on flawed base assumptions, premature patterns or missing abstractions, obsolete shims, architectural workarounds, redundant or skewed tests, and sharp edges likely to cause future human or agent mistakes.
* Documents, domain language, and infrastructure: unneeded files, updates placed in the wrong document, missing domain concepts that unify scattered terms, conflicting or AI-sounding prose, unwarranted configuration or infrastructure changes, and stale config cleanup.

The skill writes `.copilot-tracking/reviews/logs/<YYYY-MM-DD>/<task_slug>-refinement.md` with severity-graded `RF-xxx` findings and `FD-xxx` decision events in `## Parent Decision Record`, keeping execution status (`Complete`, `Partial`, `Blocked`) separate from outcome (`Clean`, `Refinements identified`, `Redesign needed`, `Residual cleanup`, `Not accepted`).
Accepted multi-step refactorings, domain definitions, security-touching refinements, and assumption redesigns route to [rpi-plan](rpi-plan) (as new `Pxx` planning phases on the active plan or as a separate RPI session), isolated local removals route to [rpi-implement](rpi-implement), version or SDK checks route to [rpi-research](rpi-research), and optional cleanups route to follow-up.
`standard` depth is the default, `surface` inspects only latest-loop changes after a repeated loop with significant changes, and `deep` requires explicit direction.

Reach for a different asset when:

* You need requirement-by-requirement acceptance verification and business-source alignment. Use [rpi-review](rpi-review).
* You are reviewing a pull request outside RPI tracking artifacts. Use the [Code Review](../../agents/coding-standards/code-review) agent.

## Example usage

```text
/rpi-refine task=offline-sync
```

The skill initializes the refinement record, performs the main-agent review across all four subtractive lenses (using targeted subagent lookups only for narrow searches such as locating existing retry helpers), verifies evidence at workspace paths, and walks through actionable `RF-xxx` findings:

```text
### RF-001 [Medium]: outbox.ts implements custom timer backoff when retryWithBackoff already exists

Dimension: Dependencies and SDKs
Current state: src/offline/outbox.ts scheduleNext maintains 64 lines of custom exponential timer state and Retry-After parsing.
What to remove or rework: Delete scheduleNext and delegate to retryWithBackoff in src/net/retry.ts.
Proposed destination: rpi-plan (new follow-up phase).
```

After decisions are recorded in `## Parent Decision Record`, the final response reports execution and outcome separately:

```text
* Review execution: Complete; Outcome: Refinements identified (standard depth)
* RF-001 (Medium, Dependencies and SDKs) accepted -> rpi-plan; RF-002 (Low, Documents and language) accepted -> rpi-plan

## Next Steps

Run `/rpi-plan` to add a follow-up phase for RF-001 and RF-002.
```
