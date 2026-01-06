---
title: Using RPI Modes Together
description: Complete walkthrough of the RPI workflow from research through implementation
author: Microsoft
ms.date: 2025-01-28
ms.topic: tutorial
keywords:
  - rpi workflow
  - task researcher
  - task planner
  - task implementor
  - complete workflow
estimated_reading_time: 5
---

This guide walks through a complete RPI workflow, showing how the three chat modes work together to transform a complex task into working code.

## The Complete Workflow

```text
┌─────────────────┐    /clear    ┌─────────────────┐    /clear    ┌─────────────────┐
│ Task Researcher │ ──────────→ │  Task Planner   │ ──────────→ │ Task Implementor│
│                 │              │                 │              │                 │
│ Uncertainty     │              │ Knowledge       │              │ Strategy        │
│     ↓           │              │     ↓           │              │     ↓           │
│ Knowledge       │              │ Strategy        │              │ Working Code    │
└─────────────────┘              └─────────────────┘              └─────────────────┘
        ↓                                ↓                                ↓
   research.md                   plan.md + details.md           code + changes.md
```

## Critical Rule: Clear Context

🔴 **Use `/clear` or start a new chat between EVERY phase.**

Why this matters:

* Each mode has different instructions and behaviors
* Accumulated context causes confusion and errors
* Research findings are in files, not chat history
* Clean context lets each mode work optimally

## Walkthrough: Adding Azure Blob Storage

Let's walk through adding Azure Blob Storage to a Python data pipeline.

### Phase 1: Research

1. Use `/task-research` with your topic to start research (this automatically selects Task Researcher mode):

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
## **Task Researcher**: Deep Analysis of Azure Blob Storage Integration

✅ Research document created at:
.copilot-tracking/research/20250128-blob-storage-research.md

Key findings:
- Recommended: azure-storage-blob SDK with async streaming
- Authentication: Managed identity for production, connection string for dev
- Existing pattern: WriterBase class in src/pipeline/writers/base.py
```

### Phase 2: Plan

1. Clear context: `/clear`
1. Use `/task-plan` with the research file **open** (this automatically selects Task Planner mode):

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

1. Review the output. Task Planner creates three files:

   ```text
   .copilot-tracking/plans/20250128-blob-storage-plan.instructions.md
   .copilot-tracking/details/20250128-blob-storage-details.md
   .copilot-tracking/prompts/implement-blob-storage.prompt.md
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
1. Select Task Implementor mode
1. Submit your implementation request:

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

Changes log: .copilot-tracking/changes/20250128-blob-storage-changes.md

Files created (3):
- src/storage/blob_client.py
- src/pipeline/writers/blob_writer.py
- tests/integration/test_blob_writer.py

Files modified (2):
- src/config/schema.py
- src/pipeline/factory.py

Ready for commit. Planning files can be cleaned up.
```

## Artifact Summary

After completing RPI, you have:

| Artifact | Location                      | Purpose                      |
|----------|-------------------------------|------------------------------|
| Research | `.copilot-tracking/research/` | Evidence and recommendations |
| Plan     | `.copilot-tracking/plans/`    | Checkboxes and phases        |
| Details  | `.copilot-tracking/details/`  | Task specifications          |
| Prompt   | `.copilot-tracking/prompts/`  | Execution instructions       |
| Changes  | `.copilot-tracking/changes/`  | Change log                   |
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

## Quick Reference

| Phase     | Invoke With                  | Mode             | Output                         |
|-----------|------------------------------|------------------|--------------------------------|
| Research  | `/task-research <topic>`     | Task Researcher  | research.md                    |
| Plan      | `/task-plan [research-path]` | Task Planner     | plan.md, details.md, prompt.md |
| Implement | Select Task Implementor mode | Task Implementor | code + changes.md              |

> [!TIP]
> `/task-research` and `/task-plan` automatically switch to the appropriate chat mode.

Remember: **Always `/clear` between phases!**

## RPI Agent

For tasks that don't require strict phase separation, **rpi-agent** provides autonomous execution with subagent delegation. RPI-agent combines research and implementation into a single workflow, making it ideal for:

* Straightforward feature implementations
* Bug fixes with clear scope
* Discovery during implementation as deeper research can be handed off to Task Researcher from RPI Agent

See [Chat Modes Reference](../../.github/chatmodes/README.md) for rpi-agent details.

## Related Guides

* [RPI Overview](README.md) - Understand the workflow
* [Task Researcher](task-researcher.md) - Deep research phase
* [Task Planner](task-planner.md) - Create actionable plans
* [Task Implementor](task-implementor.md) - Execute with precision

---

🤖 *Crafted with precision by ✨Copilot using the RPI workflow*
