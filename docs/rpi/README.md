---
title: Understanding the RPI Workflow
description: Learn how Research, Plan, Implement, Review, and Follow-up guide evidence-led delivery
sidebar_position: 1
author: Microsoft
ms.date: 2026-07-13
ms.topic: concept
keywords:
  - rpi workflow
  - task researcher
  - task planner
  - task implementor
  - task reviewer
  - follow-up
  - github copilot
estimated_reading_time: 4
---

The RPI (Research, Plan, Implement, Review) lifecycle guides complex coding tasks toward verified outcomes and explicit follow-up. It keeps five concepts distinct without requiring every run to execute all of them. Start with research readiness: reuse supplied or completed evidence when it is adequate, and activate research only for a demonstrated gap.

> Task context and evidence → Research when needed → Plan → Implement → Review → Follow-up

## Why Use RPI?

AI coding assistants are brilliant at simple tasks and break everything they touch on complex ones. The root cause: AI can't tell the difference between investigating and implementing. When you ask for code, it writes code. It doesn't stop to verify that patterns match your existing modules or that the APIs it's calling actually exist.

RPI solves this through a counterintuitive insight: when AI knows it cannot implement, it stops optimizing for "plausible code" and starts optimizing for "verified truth." The constraint changes the goal.

### Key Benefits

* Assesses evidence before opening a research stage, so adequate research is reused rather than repeated.
* Uses verified existing patterns instead of inventing plausible ones.
* Preserves decisions, changes, validation, and review routing in durable task artifacts.

> [!TIP]
> **Want the full explanation?** See [Why the RPI Workflow Works](why-rpi.md) for the psychology, quality comparisons, and RPI entry surfaces.

RPI separates lifecycle concepts without requiring an autonomous chain of specialized task workers. Use `RPI Agent` as a user-selected lifecycle wrapper, `/rpi-quick` as a skill-based full-flow entry point, or a direct phase skill when you need focused work.

## The Lifecycle Concepts

### 🔬 Research Phase (Task Researcher)

Research begins only when readiness identifies a requirements, acceptance, dependency, material-risk, complexity, uncertainty, or decision-critical gap. Task Researcher and `/rpi-research` are appropriate when such investigation is needed.

* Investigates codebase, external APIs, and documentation within the demonstrated gap.
* Documents evidence, source locations, decisions, and planning readiness.
* Produces `.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md` when research runs.

### 📋 Plan Phase (Task Planner)

Planning transforms adequate evidence into an actionable strategy. The planning parent owns the overall checklist and phase details, may use `RPI Planner` for one bounded `Pxx` phase, and records an independent `rpi-plan-critique` disposition.

* Creates `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md`.
* Creates `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md`.
* Creates `.copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md`.

### ⚡ Implement Phase (Task Implementor)

Implementation directly and flexibly executes approved `Pxx` or `Pxx-Txx` work. Task Implementor or `/rpi-implement` records completion evidence, `CHG-xxx` changes, and truthful validation in `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md`.

Significant divergence creates a linked `DIV-xxx` and `AM-xxx`, updates affected phase details, and returns to planning for fresh critique before affected dependent work resumes.

### ✅ Review Phase (Task Reviewer)

Review writes one evidence-reconciliation record at `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md`. It compares the plan, phase details, critique, amendments, changes, and validation evidence; optional generic bounded lenses are used only when they reduce a specific uncertainty.

Review keeps execution status (`Complete`, `Partial`, or `Blocked`) separate from its outcome and routes actionable gaps to the earliest responsible stage.

### ➡️ Follow-up

Follow-up does not rename or repeat another lifecycle concept. It routes defects to implementation, decision gaps to planning, evidence gaps to research, and residual work to a distinct next item.

## RPI Skill Commands

Use the skill-style slash commands when you want explicit RPI entry points in chat:

* `/rpi-quick` is the skill-based full-flow entry point. It assesses research readiness, then coordinates the applicable lifecycle concepts with one task identity.
* `/rpi-research` focuses on a demonstrated research gap.
* `/rpi-plan` creates or revises the plan, phase details, and critique disposition from adequate evidence.
* `/rpi-implement` directly executes approved work and records evidence-led changes.
* `/rpi-review` reconciles evidence in one review record and routes follow-up.

Select `RPI Agent` when you want a user-selected lifecycle wrapper that activates these same skills. `RPI Agent` and `/rpi-quick` are alternative entry surfaces, not autonomous dispatchers of specialized task workers.

## Managing Context Between Lifecycle Concepts

Use `/clear` or a new chat when a long lifecycle has accumulated context, you are switching concepts, or the conversation is no longer serving the task well. A context reset is a tool for clarity, not a requirement to repeat research or restart the lifecycle.

Durable artifacts carry the necessary context:

```text
research, when it runs → plan and details → changes → review and routed follow-up
```

Resume with the same stable task ID and open or reference the relevant dated artifacts. Navigate plan and detail sections with `Pxx`, `Pxx-Txx`, headings, and `<!-- rpi:... -->` markers.

For the technical explanation of why this matters, see [Context Engineering](context-engineering.md).

## When to Use RPI

| Use RPI artifacts when...                                      | Use a smaller direct edit when...              |
|-----------------------------------------------------------------|-------------------------------------------------|
| The task needs evidence, planning, or review routing           | The change is clear and isolated                |
| Dependencies, risk, or uncertainty need explicit handling      | Existing evidence and acceptance are sufficient  |
| A handoff needs durable task evidence                           | No durable lifecycle evidence is needed          |

**Rule of Thumb:** Use research when readiness identifies a gap; use the smallest lifecycle action that gives the task credible evidence and a clear owner.

## Quick Start

1. **Define the task** with requirements, acceptance criteria, decisions, dependencies, and available evidence.
2. **Assess research readiness** and use `/rpi-research` or Task Researcher only if a demonstrated gap remains.
3. **Plan** with `/rpi-plan` when durable planning is needed.
4. **Implement** approved work with `/rpi-implement` or Task Implementor.
5. **Review** with `/rpi-review`, then route defects, decisions, evidence gaps, or residual work through Follow-up.

> [!TIP]
> Use `/rpi-quick` or select `RPI Agent` when you want a lifecycle entry surface. Use a direct phase skill when the required next action is already clear.

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
