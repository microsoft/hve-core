---
title: Task Planner Guide
description: Use the Task Planner custom agent to create actionable implementation plans from research findings
author: Microsoft
ms.date: 2026-01-24
ms.topic: tutorial
keywords:
  - task planner
  - rpi workflow
  - planning phase
  - github copilot
estimated_reading_time: 4
---

The Task Planner custom agent transforms research findings into actionable implementation plans. It creates coordinated planning files with checkboxes, detailed specifications, and line number references for precise execution.

## When to Use Task Planner

Use Task Planner after completing research when you need:

* 📋 **Structured implementation steps** with clear checkboxes
* 📐 **Detailed specifications** for each task
* 🔗 **Cross-references** to research findings
* ⏱️ **Phased execution** with dependencies

## What Task Planner Does

1. **Validates** that research exists (MANDATORY first step)
2. **Creates** two coordinated planning files
3. **Links** specifications to research with line numbers
4. **Organizes** tasks into logical phases with dependencies

> [!NOTE]
> **Why the constraint matters:** Task Planner receives verified research and transforms it into actionable steps. Because it can't implement, it focuses entirely on sequencing, dependencies, and success criteria—the plan becomes a contract that prevents improvisation during implementation.

## Output Artifacts

Task Planner creates two files:

```text
.copilot-tracking/
├── plans/
│   └── {{YYYY-MM-DD}}-<topic>-plan.instructions.md   # Checklist with phases
└── details/
    └── {{YYYY-MM-DD}}-<topic>-details.md             # Specifications for each task
```

### Plan File

Contains checkboxes for phases and tasks, references to details with line numbers.

### Details File

Contains specifications for each task: files to modify, success criteria, research references.

## How to Use Task Planner

### Step 1: Clear Context

🔴 **Start with `/clear` or a new chat** after Task Researcher completes.

### Step 2: Invoke Task Planner

#### Option 1: Use the Prompt Shortcut (Recommended)

Type `/task-plan` in GitHub Copilot Chat with the research document opened in the editor. This automatically switches to Task Planner and begins the planning protocol. You can optionally provide the research file path:

```text
/task-plan
```

If you don't specify a file, Task Planner will search for recent research documents in `.copilot-tracking/research/` and ask you to confirm which one to use.

#### Option 2: Select the Custom Agent Manually

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Click the agent picker dropdown
3. Select **Task Planner**

### Step 3: Reference Your Research

Provide the path to your research document and any additional context.

### Step 4: Review the Plan

Task Planner will create all three files. Review:

* Are phases in logical order?
* Do tasks have clear success criteria?
* Are dependencies correctly identified?

## Example Prompt

With `.copilot-tracking/research/2025-01-28-blob-storage-research.md` opened in the editor

```text
/task-plan
Focus on:
- The streaming upload approach recommended in the research
- Phased rollout: storage client first, then writer class, then tests
- Include error handling and retry logic in each phase
```

## Tips for Better Plans

✅ **Do:**

* Reference specific research document
* Mention which recommended approach to use
* Suggest logical phases if you have preferences
* Include any additional constraints

❌ **Don't:**

* Skip the research phase
* Ask for implementation (that's next step)
* Ignore the planning files once created

## Understanding the Plan Structure

### Phases

High-level groupings of related work:

```markdown
### [ ] Phase 1: Storage Client Setup
### [ ] Phase 2: Writer Implementation
### [ ] Phase 3: Integration Testing
```

### Tasks

Specific work items within phases:

```markdown
* [ ] Task 1.1: Create BlobStorageClient class
  * Details: .copilot-tracking/details/2025-01-28-blob-storage-details.md (Lines 10-25)
```

### Line References

Every task references exact lines in the details file, which in turn references research:

```text
Plan → Details (Lines X-Y) → Research (Lines A-B)
```

## Common Pitfalls

| Pitfall              | Solution                             |
|----------------------|--------------------------------------|
| Research not found   | Complete Task Researcher first       |
| Phases too large     | Break into smaller, verifiable tasks |
| Missing dependencies | Review task order and prerequisites  |

## Next Steps

After Task Planner completes:

1. **Review** all three planning files
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
