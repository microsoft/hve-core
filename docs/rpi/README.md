---
title: Understanding the RPI Workflow
description: Learn the Research, Plan, Implement workflow for transforming complex tasks into working code
author: Microsoft
ms.date: 2025-01-28
ms.topic: concept
keywords:
  - rpi workflow
  - task researcher
  - task planner
  - task implementor
  - github copilot
estimated_reading_time: 4
---

The RPI (Research, Plan, Implement) workflow transforms complex coding tasks into working solutions through three structured phases. Think of it as a type transformation pipeline:

> Uncertainty → Knowledge → Strategy → Working Code

## Why Use RPI?

Traditional AI coding assistants work well for simple tasks but struggle with complex, multi-file changes. Without structure:

* AI makes assumptions instead of investigating
* Context gets polluted with accumulated guesses
* Implementation details contradict earlier decisions
* You spend time correcting rather than building

RPI solves this by separating concerns into distinct phases, each with its own specialized chat mode.

## The Three Phases

### 🔍 Research Phase (Task Researcher)

**Purpose:** Transform uncertainty into verified knowledge

* Investigates codebase, external APIs, and documentation
* Documents findings with evidence and sources
* Creates ONE recommended approach per scenario
* **Output:** `YYYYMMDD-<topic>-research.md`

### 📋 Plan Phase (Task Planner)

**Purpose:** Transform knowledge into actionable strategy

* Creates coordinated planning files with checkboxes and details
* Includes line number references for precision
* Validates research exists before proceeding
* **Output:** Plan, details, and implementation prompt files

### ⚡ Implement Phase (Task Implementor)

**Purpose:** Transform strategy into working code

* Executes plan task by task with verification
* Tracks all changes in a changes log
* Supports stop controls for review
* **Output:** Working code + `YYYYMMDD-<topic>-changes.md`

## The Critical Rule: Clear Context Between Phases

🔴 **Always use `/clear` or start a new chat between phases.**

Each chat mode has different instructions. Accumulated context causes confusion:

```text
Task Researcher → /clear → Task Planner → /clear → Task Implementor
```

Research findings are preserved in files, not chat history. Clean context lets each mode work optimally.

## When to Use RPI

| Use RPI When...                | Use Quick Edits When... |
|--------------------------------|-------------------------|
| Changes span multiple files    | Fixing a typo           |
| Learning new patterns/APIs     | Adding a log statement  |
| External dependencies involved | Refactoring < 50 lines  |
| Requirements are unclear       | Change is obvious       |

**Rule of Thumb:** If you need to understand something before implementing, use RPI.

## Quick Start

1. **Define the problem** clearly
2. **Research** using `/task-research <topic>` (automatically switches to Task Researcher)
3. **Clear context** with `/clear`
4. **Plan** using `/task-plan` (automatically switches to Task Planner)
5. **Clear context** with `/clear`
6. **Implement** using Task Implementor chat mode

> [!TIP]
> The `/task-research` and `/task-plan` prompts automatically switch to their respective chat modes, so you don't need to manually select Task Researcher or Task Planner.

## Next Steps

* [Task Researcher Guide](task-researcher.md) - Deep dive into research phase
* [Task Planner Guide](task-planner.md) - Create actionable plans
* [Task Implementor Guide](task-implementor.md) - Execute with precision
* [Using Them Together](using-together.md) - Complete workflow example
* [Chat Modes Reference](../../.github/chatmodes/README.md) - All available modes

---

🤖 *Crafted with precision by ✨Copilot using the RPI workflow*
