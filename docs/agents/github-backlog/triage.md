---
title: Triage Workflow
description: Classify, label, and detect duplicate GitHub issues using structured triage analysis
author: Microsoft
ms.date: 2026-02-12
ms.topic: tutorial
keywords:
  - github backlog manager
  - issue triage
  - labels
  - duplicate detection
  - github copilot
estimated_reading_time: 5
---

The Triage workflow classifies issues discovered in the previous phase, recommending labels, detecting duplicates, and producing handoff files for sprint planning or direct execution.

## When to Use

* 🏷️ Issues need labels assigned or updated after a discovery pass
* 🔁 Suspected duplicates require confirmation before closing
* 📊 Preparing issue metadata for milestone assignment in sprint planning
* 🧹 Cleaning up a backlog with inconsistent or missing labels

## What It Does

1. Reads issue analysis files produced by the discovery workflow
2. Evaluates each issue against a 17-label taxonomy organized by category
3. Compares issues across four similarity dimensions to detect duplicates
4. Generates confidence scores for label suggestions and duplicate matches
5. Produces triage recommendations with reasoning for each classification

> [!NOTE]
> Triage recommendations are proposals, not automatic changes. The execution workflow applies labels and closes duplicates only after you review and approve the handoff file.

## Label Taxonomy

The triage workflow uses a structured label taxonomy organized into four categories:

| Category  | Labels                                                          | Purpose                            |
|-----------|-----------------------------------------------------------------|------------------------------------|
| Type      | bug, feature, enhancement, documentation, maintenance, security | Classifies the nature of work      |
| Lifecycle | needs-triage, duplicate, wontfix, breaking-change               | Controls issue disposition         |
| Scope     | agents, prompts, instructions, infrastructure                   | Maps to repository components      |
| Community | good-first-issue, help-wanted, question                         | Contributor engagement and support |

Each issue receives one label per category where applicable. The triage workflow explains its reasoning for each suggested label, allowing you to adjust before execution.

## Duplicate Detection

Duplicate detection compares issues across four dimensions:

* Title similarity using normalized keyword matching
* Description overlap through content comparison
* Label set intersection to identify functionally equivalent issues
* Assignee and milestone alignment to catch split work items

When confidence exceeds the threshold, the workflow links the duplicate pair in its recommendation file and suggests which issue to keep based on age, completeness, and discussion activity.

## Output Artifacts

```text
.copilot-tracking/github-issues/triage/<YYYY-MM-DD>/
├── planning-log.md    # Progress tracking and analysis results
└── triage-plan.md     # Label suggestions, duplicate findings, and recommended operations
```

The triage plan includes reasoning for each classification, making it possible to adjust recommendations before execution applies them.

## How to Use

### Option 1: Prompt Shortcut

```text
Triage the issues discovered in my latest discovery session
```

```text
Check for duplicates in microsoft/hve-core issues labeled "needs-triage"
```

### Option 2: Direct Agent

Attach or reference the discovery output files when starting a triage conversation. The agent reads the issue analysis and begins classification automatically.

## Example Prompt

```text
Triage all issues from my latest discovery pass for microsoft/hve-core.
Apply the standard label taxonomy and flag any potential duplicates with
confidence scores above 70%.
```

## Tips

✅ Do:

* Run discovery first to build a complete issue inventory before you triage
* Review duplicate pairs before approving closure recommendations
* Adjust label suggestions in the handoff file before passing to execution
* Use the confidence scores to prioritize which recommendations to review first

❌ Don't:

* Triage issues you haven't discovered (the workflow needs analysis files as input)
* Auto-approve all triage recommendations without reviewing confidence scores
* Modify the handoff file format (execution depends on the checkbox structure)
* Run triage and execution in the same session without clearing context

## Common Pitfalls

| Pitfall                               | Solution                                                                    |
|---------------------------------------|-----------------------------------------------------------------------------|
| Low confidence on label suggestions   | Provide more context in the issue description or add manual labels          |
| False-positive duplicate matches      | Review the four similarity dimensions and adjust the confidence threshold   |
| Missing labels from taxonomy          | Verify the label exists in the repository before expecting triage to use it |
| Triage conflicts with existing labels | The workflow flags conflicts rather than overwriting existing labels        |

## Next Steps

1. Review and adjust the triage handoff file before proceeding
2. Move to [Sprint Planning](sprint-planning.md) to assign milestones, or skip directly to [Execution](execution.md) for label-only changes

> [!TIP]
> For repositories with custom label schemes, update the taxonomy reference before running triage. The workflow applies whatever taxonomy is configured, so mismatches produce irrelevant suggestions.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
