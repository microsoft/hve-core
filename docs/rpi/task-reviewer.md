---
title: Task Reviewer Guide
description: Use the Task Reviewer custom agent to validate implementation against research and plan specifications
sidebar_position: 7
author: Microsoft
ms.date: 2026-07-13
ms.topic: tutorial
keywords:
  - task reviewer
  - rpi workflow
  - review phase
  - github copilot
estimated_reading_time: 4
---

The Task Reviewer custom agent reconciles completed implementation evidence against the plan, phase details, critique dispositions, amendments, changes, and validation evidence. It records findings and routes the next action without changing the reviewed sources.

## When to Use Task Reviewer

Use Task Reviewer after completing implementation when you need:

* ✅ **Evidence reconciliation** across plan, phase details, critique, amendments, changes, and validation
* 📋 **Convention compliance** checking against instruction files
* 🔍 **Change verification** comparing actual changes to planned changes
* 📝 **Structured findings** with severity levels and evidence

## What Task Reviewer Does

1. **Locates** one task artifact set: plan, phase details, critique, amendments, changes, research, and validation evidence
2. **Reconciles** requirements, acceptance criteria, `Pxx` and `Pxx-Txx` completion evidence, `AM-xxx` amendments, `CHG-xxx` changes, and `DIV-xxx` divergences
3. **Uses** bounded independent review lenses only for a defined uncertainty
4. **Records** substantive severity-graded `RV-xxx` findings with evidence and a destination
5. **Separates** execution status from outcome so actual progress does not imply acceptance
6. **Routes** defects, decision gaps, research gaps, and residual work to distinct next owners

> [!NOTE]
> **Why the constraint matters:** Task Reviewer validates against documented evidence, not assumptions. Separating execution status from outcome makes incomplete work, justified divergence, defects, and residual work visible to the stage that can resolve each one.

## Output Artifact

Task Reviewer creates a review record at:

```text
.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md
```

This document includes:

* Artifact paths and evidence boundary
* Plan-to-change reconciliation by `Pxx` and `Pxx-Txx`
* Critique, amendment, and divergence assessment
* Severity-graded `RV-xxx` findings and validation evidence
* Execution status (`Complete`, `Partial`, or `Blocked`) separate from outcome (`Conformant`, `Conformant with justified divergence`, `Defects found`, `Residual work`, or `Not accepted`)
* Explicit next-owner routing

## How to Use Task Reviewer

### Option 1: Use the Prompt Shortcut (Recommended)

Type `/task-review` in GitHub Copilot Chat to start the review:

```text
/task-review
```

This automatically switches to Task Reviewer and begins the review protocol.

### Option 2: Select the Custom Agent Manually

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Click the agent picker dropdown at the top
3. Select **Task Reviewer**
4. Describe the scope of your review

### Option 3: Using Scope Parameters

Specify a time-based scope to filter artifacts:

```text
/task-review today
/task-review this week
/task-review since last review
```

When using a bounded scope, provide the dated artifact paths or the stable task slug and date so Task Reviewer can form one unambiguous evidence set.

### Step 2: Let It Validate

Task Reviewer works autonomously to:

* Locate the related plan, phase details, critique, amendments, changes, research, and validation evidence
* Reconcile each planned `Pxx` and `Pxx-Txx` item with completion and change evidence
* Assess critique dispositions and significant divergences
* Record available validation evidence or an explicit unavailable or skipped reason
* Document severity-graded `RV-xxx` findings and route each open item

### Step 3: Review the Findings

When complete, Task Reviewer provides:

* Summary of validation activities
* Findings count by severity (Critical, High, Medium, Low)
* Review log location for detailed reference
* Separate execution status, outcome, and next-owner routing

## Example Prompts

Basic review of recent work:

```text
/task-review
Review the blob storage implementation completed today.
```

Review with specific artifact reference:

```text
/task-review
Validate against:
- Research: .copilot-tracking/research/2025-01-28/blob-storage-research.md
- Plan: .copilot-tracking/plans/2025-01-28/blob-storage-plan.md
- Phase details: .copilot-tracking/details/2025-01-28/blob-storage-phase-details.md
- Plan critique: .copilot-tracking/reviews/plans/2025-01-28/blob-storage-plan-critique.md
- Changes: .copilot-tracking/changes/2025-01-28/blob-storage-changes.md
```

## Understanding Severity Levels

Task Reviewer categorizes findings by impact:

| Severity     | Description                                                     | Example                                        |
|--------------|-----------------------------------------------------------------|------------------------------------------------|
| **Critical** | Implementation incorrect or missing required functionality      | Missing authentication on public endpoint      |
| **High**     | A defect materially affects acceptance, reliability, or safety  | Error path exposes a request identifier        |
| **Medium**   | Evidence or behavior needs correction before acceptance         | A planned validation is unavailable            |
| **Low**      | A bounded, non-blocking improvement is useful                   | Follow-up documentation can clarify a decision |

## Tips for Better Reviews

✅ **Do:**

* Review after each implementation phase when possible
* Use time-based scopes for focused reviews
* Address findings through their recorded next owner before committing
* Keep residual work distinct from defects and decision gaps

❌ **Don't:**

* Skip reviews for multi-file changes
* Merge residual work into a defect or planning decision
* Commit without resolving or explicitly accepting material findings

## Common Pitfalls

| Pitfall                | Solution                                                                                                              |
|------------------------|-----------------------------------------------------------------------------------------------------------------------|
| No artifact set formed | Provide dated plan, phase-details, critique, and changes paths for one task                                           |
| Evidence is incomplete | Record the evidence boundary and route the missing research or validation work                                        |
| Divergence is unclear  | Reconcile `DIV-xxx` with its `AM-xxx`, phase-detail update, and critique disposition                                 |
| Too many findings      | Group evidence by `Pxx` or `Pxx-Txx` and route each item to the smallest responsible owner                           |

## Next Steps

After Task Reviewer completes, execution status and outcome determine your path:

### When the Outcome Is Conformant

1. **Commit** your changes with a descriptive message
2. **Clean up** planning files if no longer needed
3. **Start** the next RPI cycle for additional work

### When the Outcome Contains Defects

1. **Clear context** using `/clear`
2. **Open** the review log in your editor
3. **Return to implementation** using `/task-implement`

Task Implementor uses the routed `RV-xxx` findings to address defects.

### When Findings Identify a Research Gap

1. **Clear context** using `/clear`
2. **Open** the review log in your editor
3. **Start research** using `/task-research`

Task Researcher receives the evidence gap and the relevant `RV-xxx` finding.

### When Findings Identify a Decision Gap

1. **Clear context** using `/clear`
2. **Open** the review log in your editor
3. **Revise plan** using `/task-plan`

Task Planner incorporates the decision gap into the plan and phase-details artifact. Residual work becomes a distinct follow-up item rather than an implicit rework request.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
