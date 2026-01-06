---
title: Task Planner Guide
description: Use the Task Planner chat mode to create actionable implementation plans from research findings
author: Microsoft
ms.date: 2025-01-28
ms.topic: tutorial
keywords:
  - task planner
  - rpi workflow
  - planning phase
  - github copilot
estimated_reading_time: 4
---

The Task Planner chat mode transforms research findings into actionable implementation plans. It creates coordinated planning files with checkboxes, detailed specifications, and line number references for precise execution.

## When to Use Task Planner

Use Task Planner after completing research when you need:

* 📋 **Structured implementation steps** with clear checkboxes
* 📐 **Detailed specifications** for each task
* 🔗 **Cross-references** to research findings
* ⏱️ **Phased execution** with dependencies

## What Task Planner Does

1. **Validates** that research exists (MANDATORY first step)
2. **Creates** three coordinated planning files
3. **Links** specifications to research with line numbers
4. **Organizes** tasks into logical phases with dependencies
5. **Generates** an implementation prompt for Task Implementor

## Output Artifacts

Task Planner creates three files:

```text
.copilot-tracking/
├── plans/
│   └── YYYYMMDD-<topic>-plan.instructions.md   # Checklist with phases
├── details/
│   └── YYYYMMDD-<topic>-details.md             # Specifications for each task
└── prompts/
    └── implement-<topic>.prompt.md              # Execution instructions
```

### Plan File

Contains checkboxes for phases and tasks, references to details with line numbers.

### Details File

Contains specifications for each task: files to modify, success criteria, research references.

### Implementation Prompt

Contains step-by-step instructions for Task Implementor, including stop controls.

## How to Use Task Planner

### Step 1: Clear Context

🔴 **Start with `/clear` or a new chat** after Task Researcher completes.

### Step 2: Invoke Task Planner

#### Option 1: Use the Prompt Shortcut (Recommended)

Type `/task-plan` in GitHub Copilot Chat with the research document opened in the editor. This automatically switches to Task Planner mode and begins the planning protocol. You can optionally provide the research file path:

```text
/task-plan
```

If you don't specify a file, Task Planner will search for recent research documents in `.copilot-tracking/research/` and ask you to confirm which one to use.

#### Option 2: Select the Chat Mode Manually

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Click the chat mode dropdown
3. Select **Task Planner**

### Step 3: Reference Your Research

Provide the path to your research document and any additional context.

### Step 4: Review the Plan

Task Planner will create all three files. Review:

* Are phases in logical order?
* Do tasks have clear success criteria?
* Are dependencies correctly identified?

## Example Prompt

With `.copilot-tracking/research/20250128-blob-storage-research.md` opened in the editor

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
  * Details: .copilot-tracking/details/20250128-blob-storage-details.md (Lines 10-25)
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
3. **Proceed to implementation** with [Task Implementor](task-implementor.md)

Use the generated implementation prompt (`.copilot-tracking/prompts/implement-*.prompt.md`) with Task Implementor.

---

🤖 *Crafted with precision by ✨Copilot using the RPI workflow*
