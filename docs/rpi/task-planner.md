---
title: Task Planner Guide
description: Use the Task Planner custom agent to create actionable implementation plans from research findings
sidebar_position: 5
author: Microsoft
ms.date: 2026-07-13
ms.topic: tutorial
keywords:
  - task planner
  - rpi workflow
  - planning phase
  - github copilot
estimated_reading_time: 4
---

The Task Planner custom agent transforms supplied evidence, research findings, and decisions into actionable implementation plans. It creates a coordinated plan and phase-details artifact with stable IDs for precise execution.

## When to Use Task Planner

Use Task Planner when you have supplied evidence, completed research, or task context and need:

* 📋 **Structured implementation steps** with clear checkboxes
* 📐 **Detailed specifications** for each task
* 🔗 **Cross-references** to research findings
* ⏱️ **Phased execution** with dependencies

## What Task Planner Does

1. **Assesses** supplied and completed evidence against planning readiness
2. **Activates research** only when a demonstrated readiness gap remains
3. **Creates** a dated plan and matching phase-details artifact
4. **Organizes** tasks into logical phases with dependencies and stable markers
5. **Records** an independent critique disposition before implementation handoff

> [!NOTE]
> **Why the constraint matters:** Task Planner uses evidence that is already supplied or complete before activating more research. Because it cannot implement, it focuses on sequencing, dependencies, acceptance criteria, and a credible handoff rather than making source changes.

## Output Artifacts

Task Planner creates a plan, matching phase-details artifact, and independent critique:

```text
.copilot-tracking/
├── plans/
│   └── {{YYYY-MM-DD}}/
│       └── {{task_slug}}-plan.md                     # Checklist with phases
└── details/
  └── {{YYYY-MM-DD}}/
    └── {{task_slug}}-phase-details.md            # Evidence-based details for each task

.copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md
```

### Plan File

Contains checkboxes for phases and tasks, requirements, decisions, amendments, critique disposition, and a handoff. `Pxx` and `Pxx-Txx` IDs are paired with stable markers immediately before the matching headings.

### Details File

Contains evidence-based context, boundaries, likely targets, dependencies, validation expectations, completion evidence, and unresolved items for each phase and task.

## How to Use Task Planner

### Step 1: Clear Context

🔴 **Start with `/clear` or a new chat** after Task Researcher completes.

### Step 2: Invoke Task Planner

#### Option 1: Use the Prompt Shortcut (Recommended)

Type `/task-plan` in GitHub Copilot Chat with the research document opened in the editor. This automatically switches to Task Planner and begins the planning protocol. You can optionally provide the research file path:

```text
/task-plan
```

If you want to invoke the planning step as the skill command instead of the prompt shortcut, use `/rpi-plan`.

Provide supplied research, decisions, and acceptance criteria when available. Task Planner reuses adequate evidence and activates research only when it identifies a demonstrated planning-readiness gap.

#### Option 2: Select the Custom Agent Manually

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Click the agent picker dropdown
3. Select **Task Planner**

### Step 3: Reference Your Evidence

Provide available research, task context, decisions, dependencies, and acceptance criteria.

### Step 4: Review the Plan

Task Planner will create the plan, phase-details artifact, and critique. Review:

* Are phases in logical order?
* Do tasks have clear success criteria?
* Are dependencies correctly identified?

## Example Prompt

With `.copilot-tracking/research/2025-01-28/blob-storage-research.md` opened in the editor

```text
/task-plan
Focus on:
- The streaming upload approach recommended in the research
- Phased rollout: storage client first, then writer class, then tests
- Include error handling and retry logic in each phase
```

## Tips for Better Plans

✅ **Do:**

* Reference supplied research and decisions when available
* Mention which recommended approach to use
* Suggest logical phases if you have preferences
* Include any additional constraints

❌ **Don't:**

* Treat research as mandatory when the supplied evidence is already ready
* Ask for implementation (that's next step)
* Ignore the planning files once created

## Understanding the Plan Structure

### Phases

High-level groupings of related work:

```markdown
<!-- rpi:phase id=P01 -->
### [ ] P01: Storage Client Setup

<!-- rpi:phase id=P02 -->
### [ ] P02: Writer Implementation

<!-- rpi:phase id=P03 -->
### [ ] P03: Integration Testing
```

### Tasks

Specific work items within phases:

```markdown
<!-- rpi:task id=P01-T01 -->
#### [ ] P01-T01: Create BlobStorageClient class

* Detail section: P01-T01 in .copilot-tracking/details/2025-01-28/blob-storage-phase-details.md
```

### Stable Marker Navigation

Every task uses the same stable ID, heading, and marker in the plan and phase-details artifact. These references remain stable as the artifact evolves:

```text
Plan P01-T01 → Phase details P01-T01 → Supporting evidence
```

## Common Pitfalls

| Pitfall              | Solution                             |
|----------------------|--------------------------------------|
| Evidence gap remains | Use Task Researcher for the specific planning-readiness gap |
| Phases too large     | Break into smaller, verifiable tasks |
| Missing dependencies | Review task order and prerequisites  |

## Next Steps

After Task Planner completes:

1. **Review** the plan, phase-details artifact, and critique disposition
2. **Clear context** using `/clear` or starting a new chat
3. **Proceed to implementation** using `/task-implement` to switch to [Task Implementor](task-implementor.md)

The `/task-implement` prompt automatically locates the plan and switches to Task Implementor.

> [!TIP]
> Use the **⚡ Implement** handoff button when available to transition directly to Task Implementor with context.

After implementation, continue to [Task Reviewer](task-reviewer.md) to validate against specifications.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
