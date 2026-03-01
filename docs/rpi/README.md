---
title: Understanding the RPI Workflow
description: Learn the Research, Plan, Implement, Review workflow for transforming complex tasks into validated code
sidebar_position: 1
author: Microsoft
ms.date: 2026-02-18
ms.topic: concept
keywords:
  - rpi workflow
  - task researcher
  - task planner
  - task implementor
  - task reviewer
  - github copilot
estimated_reading_time: 4
---

The RPI (Research, Plan, Implement, Review) workflow transforms complex coding tasks into validated solutions through four structured phases. Think of it as a type transformation pipeline:

> Uncertainty → Knowledge → Strategy → Working Code → Validated Code

## Why Use RPI?

AI coding assistants are brilliant at simple tasks and break everything they touch on complex ones. The root cause: AI can't tell the difference between investigating and implementing. When you ask for code, it writes code. It doesn't stop to verify that patterns match your existing modules or that the APIs it's calling actually exist.

RPI solves this through a counterintuitive insight: when AI knows it cannot implement, it stops optimizing for "plausible code" and starts optimizing for "verified truth." The constraint changes the goal.

### Key Benefits

* Uses verified existing patterns instead of inventing plausible ones.
* Traces every decision to specific files and line numbers.
* Creates research documents anyone can follow, eliminating tribal knowledge.

> [!TIP]
> **Want the full explanation?** See [Why the RPI Workflow Works](why-rpi.md) for the psychology, quality comparisons, and guidance on choosing between strict RPI and rpi-agent.

RPI separates concerns into distinct phases, each with its own specialized custom agent.

## The Four Phases

### 🔬 Research Phase (Task Researcher)

This phase transforms uncertainty into verified knowledge.

* Investigates codebase, external APIs, and documentation
* Documents findings with evidence and sources
* Creates ONE recommended approach per scenario
* Output: `{{YYYY-MM-DD}}-<topic>-research.md`

### 📋 Plan Phase (Task Planner)

This phase transforms knowledge into actionable strategy.

* Creates coordinated planning files with checkboxes and details
* Includes line number references for precision
* Validates research exists before proceeding
* Output: Plan and details files

### ⚡ Implement Phase (Task Implementor)

This phase transforms strategy into working code.

* Executes plan task by task with verification
* Tracks all changes in a changes log
* Supports stop controls for review
* Output: Working code + `{{YYYY-MM-DD}}-<topic>-changes.md`

### ✅ Review Phase (Task Reviewer)

This phase transforms working code into validated code.

* Validates implementation against research and plan specifications
* Checks convention compliance using instruction files
* Runs validation commands (lint, build, test)
* Identifies follow-up work and iteration needs
* Output: `{{YYYY-MM-DD}}-<topic>-review.md`

## The Critical Rule: Clear Context Between Phases

🔴 **Always use `/clear` or start a new chat between phases.**

Each custom agent has different instructions. Accumulated context causes confusion:

```text
Task Researcher → /clear → Task Planner → /clear → Task Implementor → /clear → Task Reviewer
```

Research findings are preserved in files, not chat history. Clean context lets each agent work optimally. After clearing, open the relevant `.copilot-tracking/` artifact in your editor so the next agent can see it (for example, open the research document before invoking Task Planner).

For the technical explanation of why this matters, see [Context Engineering](context-engineering.md).

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
6. **Implement** using `/task-implement` (automatically switches to Task Implementor)
7. **Clear context** with `/clear`
8. **Review** using `/task-review` (automatically switches to Task Reviewer)

> [!TIP]
> The `/task-research`, `/task-plan`, `/task-implement`, and `/task-review` prompts automatically switch to their respective custom agents, so you don't need to manually select them.

## Next Steps

* [Task Researcher Guide](task-researcher.md) - Deep dive into research phase
* [Task Planner Guide](task-planner.md) - Create actionable plans
* [Task Implementor Guide](task-implementor.md) - Execute with precision
* [Task Reviewer Guide](task-reviewer.md) - Validate implementations
* [Using Them Together](using-together.md) - Complete workflow example
* [Context Engineering](context-engineering.md) - Why context management matters
* [Agents Reference](https://github.com/microsoft/hve-core/blob/main/.github/CUSTOM-AGENTS.md) - All available agents
* [Agent Systems Catalog](../agents/) - Browse all agent families beyond RPI

## See Also

* [Engineer Guide](../hve-guide/roles/engineer.md) - Role-specific guide for engineers using RPI agents
* [Tech Lead Guide](../hve-guide/roles/tech-lead.md) - Architecture review and prompt engineering workflows
* [Stage 6: Implementation](../hve-guide/lifecycle/implementation.md) - Where RPI fits in the project lifecycle

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
