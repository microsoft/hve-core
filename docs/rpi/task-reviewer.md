---
title: Task Reviewer Guide
description: Use the Task Reviewer custom agent to validate implementation against research and plan specifications
author: Microsoft
ms.date: 2026-01-24
ms.topic: tutorial
keywords:
  - task reviewer
  - rpi workflow
  - review phase
  - github copilot
estimated_reading_time: 4
---

The Task Reviewer custom agent validates completed implementation work against research and plan specifications. It checks convention compliance, runs validation commands, and produces review logs with findings and follow-up work.

## When to Use Task Reviewer

Use Task Reviewer after completing implementation when you need:

* ✅ **Specification validation** against research and plan documents
* 📋 **Convention compliance** checking against instruction files
* 🔍 **Change verification** comparing actual changes to planned changes
* 📝 **Structured findings** with severity levels and evidence

## What Task Reviewer Does

1. **Locates** review artifacts (research, plan, changes logs)
2. **Extracts** implementation checklist from source documents
3. **Validates** each item with evidence from the codebase
4. **Runs** validation commands (lint, build, test)
5. **Documents** findings with severity levels
6. **Identifies** follow-up work for future implementation

> [!NOTE]
> **Why the constraint matters:** Task Reviewer validates against documented specifications, not assumptions. Because it can only review what was documented, gaps in research or planning become visible. This feedback loop improves future RPI cycles.

## Output Artifact

Task Reviewer creates a review log at:

```text
.copilot-tracking/reviews/{{YYYY-MM-DD}}-<topic>-review.md
```

This document includes:

* Implementation checklist from research and plan
* Validation results with evidence
* Additional or deviating changes found
* Missing work and follow-up items
* Overall status (Complete, Needs Rework, Blocked)

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

Task Reviewer filters `.copilot-tracking/` artifacts by date prefix when you provide a scope.

### Step 2: Let It Validate

Task Reviewer works autonomously to:

* Locate related research, plan, and changes files
* Extract implementation checklist items
* Validate each item against the codebase
* Run applicable validation commands
* Document findings with severity levels

### Step 3: Review the Findings

When complete, Task Reviewer provides:

* Summary of validation activities
* Findings count by severity (Critical, Major, Minor)
* Review log location for detailed reference
* Next steps based on review outcome

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
- Research: .copilot-tracking/research/2025-01-28-blob-storage-research.md
- Plan: .copilot-tracking/plans/2025-01-28-blob-storage-plan.instructions.md
- Changes: .copilot-tracking/changes/2025-01-28-blob-storage-changes.md
```

## Understanding Severity Levels

Task Reviewer categorizes findings by impact:

| Severity     | Description                                                     | Example                                        |
|--------------|-----------------------------------------------------------------|------------------------------------------------|
| **Critical** | Implementation incorrect or missing required functionality      | Missing authentication on public endpoint      |
| **Major**    | Implementation deviates from specifications or conventions      | Used deprecated API instead of recommended one |
| **Minor**    | Style issues, documentation gaps, or optimization opportunities | Missing inline comment on complex logic        |

## Tips for Better Reviews

✅ **Do:**

* Review after each implementation phase when possible
* Use time-based scopes for focused reviews
* Address Critical and Major findings before committing
* Let Minor findings accumulate for batch fixes

❌ **Don't:**

* Skip reviews for multi-file changes
* Ignore convention compliance warnings
* Commit without addressing Critical findings

## Common Pitfalls

| Pitfall             | Solution                                                 |
|---------------------|----------------------------------------------------------|
| No artifacts found  | Complete implementation first; verify changes log exists |
| Research not linked | Ensure plan references research document                 |
| Too many findings   | Break implementation into smaller phases                 |

## Next Steps

After Task Reviewer completes, the review status determines your path:

### When Status is Complete

1. **Commit** your changes with a descriptive message
2. **Clean up** planning files if no longer needed
3. **Start** the next RPI cycle for additional work

### When Findings Require Rework

1. **Clear context** using `/clear`
2. **Open** the review log in your editor
3. **Return to implementation** using `/task-implement`

Task Implementor uses the review findings to address Critical and Major issues.

### When Follow-Up Items Need Research

1. **Clear context** using `/clear`
2. **Open** the review log in your editor
3. **Start research** using `/task-research`

Review findings become input for the next research cycle.

### When Additional Planning Is Needed

1. **Clear context** using `/clear`
2. **Open** the review log in your editor
3. **Revise plan** using `/task-plan`

Task Planner incorporates review findings into updated planning.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
