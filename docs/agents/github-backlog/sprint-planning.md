---
title: Sprint Planning Workflow
description: Organize triaged issues into milestones with priority sequencing and capacity awareness
author: Microsoft
ms.date: 2026-02-12
ms.topic: tutorial
keywords:
  - github backlog manager
  - sprint planning
  - milestones
  - github copilot
estimated_reading_time: 5
---

The Sprint Planning workflow organizes triaged issues into milestones, sequences work by priority, and produces execution-ready handoff files that map issues to their target sprint.

## When to Use

* 📅 Starting a new sprint or release cycle and need to assign issues to milestones
* 🎯 Issues have been triaged but lack milestone assignments
* 🔄 Rebalancing work across milestones after scope changes or team adjustments
* 📋 Creating milestone structure for a new project or repository

## What It Does

1. Reads triage output to understand issue classification and priority levels
2. Discovers existing milestones or recommends new ones based on issue patterns
3. Maps issues to milestones considering priority, dependencies, and grouping
4. Sequences work within each milestone based on priority assessment and blocking relationships
5. Produces a sprint plan with milestone assignments and a handoff file for execution

> [!NOTE]
> Sprint planning does not create milestones automatically. It recommends milestone assignments in a handoff file that the execution workflow applies after your review.

## Milestone Discovery

The workflow follows a structured approach to milestone management:

1. Queries the repository for existing open milestones with due dates
2. Maps triaged issues to milestones by area label and priority
3. Identifies issues that fit no current milestone and recommends creating new ones
4. Checks milestone capacity using issue count and priority distribution
5. Flags milestones that appear overloaded relative to their due date
6. Produces a milestone map showing current and recommended assignments

This process ensures sprint plans build on existing repository structure rather than creating parallel tracking systems.

## Output Artifacts

```text
.copilot-tracking/github-issues/sprint/<milestone-kebab>/
├── sprint-analysis.md    # Milestone mapping and capacity review
├── sprint-plan.md        # Recommended assignments and sequencing
└── handoff.md            # Execution-ready handoff with checkboxes
```

The sprint plan includes reasoning for each milestone assignment, making it possible to adjust recommendations before execution applies them.

## How to Use

### Option 1: Prompt Shortcut

```text
Plan the next sprint for microsoft/hve-core using my latest triage results
```

```text
Assign milestones to all triaged issues without milestone assignments
```

### Option 2: Direct Agent

Start a conversation with the GitHub Backlog Manager agent and reference your triage output. The agent reads the triage analysis and handoff files, then builds a sprint plan based on current milestone structure.

## Example Prompt

```text
Plan sprint assignments for microsoft/hve-core. Use the v2.1 milestone for
high-priority bugs and the v2.2 milestone for enhancements. Create a new
"documentation-refresh" milestone for any docs-area issues without a milestone.
```

## Tips

✅ Do:

* Run triage before sprint planning so issues have consistent labels and priorities
* Review milestone capacity recommendations before approving assignments
* Use the sequencing output to identify blocking chains within a milestone
* Adjust milestone assignments in the handoff file before passing to execution

❌ Don't:

* Plan sprints without triaged issues (issues that lack triage metadata produce unreliable plans)
* Ignore capacity warnings for milestones approaching their due date
* Create milestones through sprint planning when they should be created through repository settings
* Assume the workflow sees private milestones (verify MCP token permissions)

## Common Pitfalls

| Pitfall                                | Solution                                                                |
|----------------------------------------|-------------------------------------------------------------------------|
| Issues assigned to closed milestones   | The workflow flags these for reassignment; review before execution      |
| Milestone names don't match repository | Verify milestone names in the handoff match existing milestones exactly |
| Priority conflicts within a milestone  | Review the sequencing recommendations and adjust priority labels first  |
| Too many issues for a single milestone | Split across milestones or re-prioritize lower-priority items out       |

## Next Steps

1. Review the sprint plan and handoff file for accuracy
2. Proceed to the [Execution workflow](execution.md) to apply milestone assignments

> [!TIP]
> For teams with fixed sprint cadences, create milestones in advance through repository settings. Sprint planning works best when it maps to existing milestones rather than recommending new ones.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
