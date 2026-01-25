---
title: Using RPI Agents Together
description: Complete walkthrough of the RPI workflow from research through review
author: Microsoft
ms.date: 2026-01-24
ms.topic: tutorial
keywords:
  - rpi workflow
  - task researcher
  - task planner
  - task implementor
  - task reviewer
  - complete workflow
estimated_reading_time: 5
---

This guide walks through a complete RPI workflow, showing how the four custom agents work together to transform a complex task into validated code.

## The Complete Workflow

```text
┌─────────────────┐   Handoff    ┌─────────────────┐   Handoff    ┌─────────────────┐   Handoff    ┌─────────────────┐
│ Task Researcher │ ──────────→ │  Task Planner   │ ──────────→ │ Task Implementor│ ──────────→ │  Task Reviewer  │
│                 │  📋 Create   │                 │  ⚡ Implement  │                 │  ✅ Review   │                 │
│ Uncertainty     │    Plan      │ Knowledge       │              │ Strategy        │              │ Working Code    │
│     ↓           │              │     ↓           │              │     ↓           │              │     ↓           │
│ Knowledge       │              │ Strategy        │              │ Working Code    │              │ Validated Code  │
└─────────────────┘              └─────────────────┘              └─────────────────┘              └─────────────────┘
        ↓                                ↓                                ↓                                ↓
   research.md                   plan.md + details.md           code + changes.md              review.md + findings
        ↑                                ↑
        └────────────────────────────────┴──────────────── 🔬 Research More / 📋 Revise Plan ────────────────────────┘
```

## Critical Rule: Clear Context

🔴 **Use `/clear` or start a new chat between EVERY phase.**

Why this matters:

* Each agent has different instructions and behaviors
* Accumulated context causes confusion and errors
* Research findings are in files, not chat history
* Clean context lets each agent work optimally

## Walkthrough: Adding Azure Blob Storage

Let's walk through adding Azure Blob Storage to a Python data pipeline.

### Phase 1: Research

1. Use `/task-research` with your topic to start research (this automatically selects Task Researcher):

```text
/task-research Azure Blob Storage integration for Python data pipeline
```

1. Provide additional context in your message:

```text
I need to add Azure Blob Storage integration to our Python data pipeline.
The pipeline currently writes to local disk in src/pipeline/writers/.

Research:
- Azure SDK for Python blob storage options
- Authentication approaches (managed identity vs connection string)
- Streaming uploads for files > 1GB
- Error handling and retry patterns

Focus on approaches that match our existing patterns in the codebase.
```

1. Wait for completion (20-60 minutes). Task Researcher will:

   * Search your codebase for existing patterns
   * Research Azure SDK documentation
   * Evaluate authentication options
   * Create a research document with recommendations

1. Review the output:

```text
## 🔬 Task Researcher: Azure Blob Storage Integration

✅ Research document created at:
.copilot-tracking/research/2025-01-28-blob-storage-research.md

Key findings:
- Recommended: azure-storage-blob SDK with async streaming
- Authentication: Managed identity for production, connection string for dev
- Existing pattern: WriterBase class in src/pipeline/writers/base.py
```

### Phase 2: Plan

1. Clear context: `/clear`
1. Use `/task-plan` with the research file **open** (this automatically selects Task Planner):

   ```text
   /task-plan
   ```

1. Provide additional planning guidance:

   ```text
   /task-plan
   Focus on:
   - The streaming upload approach recommended in the research
   - Phased rollout: storage client first, then writer class, then integration
   - Include error handling and retry logic
   ```

1. Review the output. Task Planner creates two files:

   ```text
   .copilot-tracking/plans/2025-01-28-blob-storage-plan.instructions.md
   .copilot-tracking/details/2025-01-28-blob-storage-details.md
   ```

1. Verify the plan structure:

```markdown
### [ ] Phase 1: Storage Client Setup
* [ ] Task 1.1: Create BlobStorageClient class
* [ ] Task 1.2: Add configuration schema

### [ ] Phase 2: Writer Implementation
* [ ] Task 2.1: Create BlobWriter extending WriterBase
* [ ] Task 2.2: Implement streaming upload

### [ ] Phase 3: Integration
* [ ] Task 3.1: Update pipeline factory
* [ ] Task 3.2: Add integration tests
```

### Phase 3: Implement

1. Clear context: `/clear`
1. Use `/task-implement` to start implementation (automatically switches to Task Implementor):

   ```text
   /task-implement
   ```

   Or use the generated prompt for a specific plan:

   ```text
   /implement-blob-storage
   ```

1. Review at each phase. After Phase 1 completes:

```text
Phase 1 complete. Changes:
- Added: src/storage/blob_client.py
- Modified: src/config/schema.py

Ready for review. Continue to Phase 2?
```

Check the code, run linters, then continue.

1. Final output:

When all phases complete:

```text
Implementation complete!

Changes log: .copilot-tracking/changes/2025-01-28-blob-storage-changes.md

Files created (3):
- src/storage/blob_client.py
- src/pipeline/writers/blob_writer.py
- tests/integration/test_blob_writer.py

Files modified (2):
- src/config/schema.py
- src/pipeline/factory.py

Ready for review.
```

### Phase 4: Review

1. Clear context: `/clear`
2. Use `/task-review` to validate the implementation (automatically switches to Task Reviewer):

   ```text
   /task-review
   ```

3. Task Reviewer validates against specifications:

   * Locates research, plan, and changes artifacts
   * Extracts implementation checklist from source documents
   * Validates each item with evidence from the codebase
   * Runs validation commands (lint, build, test)

4. Review the findings:

```text
## ✅ Task Reviewer: Blob Storage Integration

| 📊 Summary            |                                                             |
|-----------------------|-------------------------------------------------------------|
| **Review Log**        | .copilot-tracking/reviews/2025-01-28-blob-storage-review.md |
| **Overall Status**    | Complete                                                    |
| **Critical Findings** | 0                                                           |
| **Major Findings**    | 0                                                           |
| **Minor Findings**    | 2                                                           |
| **Follow-Up Items**   | 1                                                           |

Minor findings:
- Missing docstring on BlobStorageClient.upload_stream()
- Consider adding retry count to configuration schema

Follow-up item:
- Add performance benchmarks for large file uploads (deferred from research)

Ready for commit.
```

1. Address findings and commit:

   * Fix Minor findings if desired (optional for commit)
   * Address Critical and Major findings before committing
   * Note Follow-Up items for future RPI cycles

## Artifact Summary

After completing RPI, you have:

| Artifact | Location                      | Purpose                      |
|----------|-------------------------------|------------------------------|
| Research | `.copilot-tracking/research/` | Evidence and recommendations |
| Plan     | `.copilot-tracking/plans/`    | Checkboxes and phases        |
| Details  | `.copilot-tracking/details/`  | Task specifications          |
| Changes  | `.copilot-tracking/changes/`  | Change log                   |
| Review   | `.copilot-tracking/reviews/`  | Validation findings          |
| Code     | Your source directories       | Working implementation       |

## Common Patterns

### Iterating on Research

If implementation reveals missing research:

1. Note the gap in your current session
2. Clear context
3. Return to Task Researcher
4. Research the specific gap
5. Update plan if needed
6. Continue implementation

### Handling Complex Tasks

For very large tasks:

1. Break into multiple RPI cycles
2. Each cycle handles one component
3. Use research from previous cycles
4. Build incrementally

### Team Handoffs

RPI artifacts support handoffs:

* Research doc explains decisions
* Plan shows remaining work
* Changes log shows what's done
* Review log shows validation status

## Iteration Loops

The Review phase can trigger iteration back to earlier phases when findings reveal gaps.

### Iteration Paths

| Review Status | Action                      | Target Phase |
|---------------|-----------------------------|--------------|
| Complete      | Commit changes              | Done         |
| Needs Rework  | Fix implementation issues   | Implement    |
| Research Gap  | Investigate missing context | Research     |
| Plan Gap      | Add missing scope           | Plan         |

### Rework Flow

When Task Reviewer identifies Critical or Major findings:

1. Clear context: `/clear`
2. Open the review log in your editor
3. Use `/task-implement` to address findings
4. Task Implementor uses the review log to guide fixes
5. Return to review: `/task-review`

### Escalation Flow

When Task Reviewer identifies research or planning gaps:

1. Clear context: `/clear`
2. Open the review log in your editor
3. Choose the appropriate phase:
   * `/task-research` for missing technical context
   * `/task-plan` for scope additions
4. Complete the phase and continue through the workflow

## Quick Reference

| Phase     | Invoke With                  | Agent            | Output              |
|-----------|------------------------------|------------------|---------------------|
| Research  | `/task-research <topic>`     | Task Researcher  | research.md         |
| Plan      | `/task-plan [research-path]` | Task Planner     | plan.md, details.md |
| Implement | `/task-implement`            | Task Implementor | code + changes.md   |
| Review    | `/task-review [scope]`       | Task Reviewer    | review.md           |

> [!TIP]
> `/task-research`, `/task-plan`, `/task-implement`, and `/task-review` all automatically switch to the appropriate custom agent.

Remember: **Always `/clear` between phases!**

## Handoff Buttons

RPI agents include handoff buttons that streamline transitions between workflow phases. When an agent completes its work, handoff buttons appear in the chat interface.

### Available Handoffs

| From Agent       | Handoff Button   | Target Agent     | Action                         |
|------------------|------------------|------------------|--------------------------------|
| Task Researcher  | 📋 Create Plan   | Task Planner     | Starts planning with research  |
| Task Planner     | ⚡ Implement      | Task Implementor | Executes the plan              |
| Task Implementor | ✅ Review         | Task Reviewer    | Reviews implementation         |
| Task Reviewer    | 🔬 Research More | Task Researcher  | Researches identified gaps     |
| Task Reviewer    | 📋 Revise Plan   | Task Planner     | Updates plan based on findings |

### Using Handoff Buttons

1. Complete work in current agent
2. Click the handoff button in the chat interface
3. The target agent activates with the appropriate prompt pre-filled
4. Conversation context carries over automatically

### When to Use Manual Transitions

Use `/clear` and manual `/task-*` commands instead of handoffs when:

* You need to reset conversation context completely
* You want to provide custom parameters to the next agent
* The handoff button doesn't match your intended workflow

## RPI Agent: When Simplicity Fits

For tasks that don't require strict phase separation, **rpi-agent** provides autonomous execution with subagent delegation. Use it when the scope is clear and you don't need the deep iterative research that comes from constraint-based separation.

### Quick Decision Guide

| Choose Strict RPI when...    | Choose rpi-agent when...           |
|------------------------------|------------------------------------|
| Deep research is critical    | Scope is clear and straightforward |
| Multi-file pattern discovery | Minimal external research needed   |
| Team handoff needed          | Quick iteration during development |
| Compliance or security work  | Exploratory or prototype work      |

### Escalation Path

You don't have to decide upfront. Start with rpi-agent for speed, and if the task reveals hidden complexity, it can hand off to Task Researcher. This hybrid approach gives you speed for simple tasks and the verified truth that comes from constraint-based research when you need it.

> [!TIP]
> For the full explanation of why constraints change AI behavior, see [Why the RPI Workflow Works](why-rpi.md#the-counterintuitive-insight).

See [Agents Reference](../../.github/CUSTOM-AGENTS.md) for rpi-agent implementation details.

## Related Guides

* [RPI Overview](README.md) - Understand the workflow
* [Task Researcher](task-researcher.md) - Deep research phase
* [Task Planner](task-planner.md) - Create actionable plans
* [Task Implementor](task-implementor.md) - Execute with precision
* [Task Reviewer](task-reviewer.md) - Validate implementations

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
