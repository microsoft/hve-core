---
title: Understanding the RPI Workflow
description: Learn how Research, Plan, Implement, Review, and Follow-up guide evidence-led delivery
sidebar_position: 1
author: Microsoft
ms.date: 2026-07-15
ms.topic: concept
keywords:
  - rpi workflow
  - rpi agent
  - rpi research
  - rpi plan
  - rpi implement
  - rpi review
  - follow-up
  - github copilot
estimated_reading_time: 7
---

The RPI (Research, Plan, Implement, Review) lifecycle guides complex coding tasks toward verified outcomes and explicit follow-up. It keeps five concepts distinct without requiring every run to execute all of them. Start with research readiness: reuse supplied or completed evidence when it is adequate, and activate research only for a demonstrated gap.

> Task context and evidence → Research when needed → Plan → Implement → Review → Follow-up

## Why Use RPI

AI coding assistants can complete simple tasks quickly, but complex changes require more than plausible code. The assistant must verify existing patterns, understand dependencies, preserve decisions, and compare the result with explicit acceptance criteria.

RPI solves this through a counterintuitive insight: when AI knows it cannot implement, it stops optimizing for "plausible code" and starts optimizing for "verified truth." The constraint changes the goal.

### Key benefits

* Assesses evidence before opening a research stage, so adequate research is reused rather than repeated.
* Uses verified existing patterns instead of inventing plausible ones.
* Preserves decisions, changes, validation, and review routing in durable task artifacts.

> [!TIP]
> See [Why the RPI Workflow Works](why-rpi) for the psychology, quality comparisons, and entry surfaces behind the lifecycle.

RPI separates lifecycle concepts without requiring an autonomous chain of specialized task workers. Use `RPI Agent` as a user-selected lifecycle wrapper, `/rpi-quick` as a skill-based full-flow entry point, or a direct phase skill when you need focused work.

## The Lifecycle Concepts

### 🔬 Research with rpi-research

Use `/rpi-research` only when available evidence is not adequate for requirements, acceptance criteria, dependencies, material risks, complexity, uncertainty, or a decision-critical question. Multi-file changes, new patterns, external integrations, and architecture decisions can reveal a gap, but they do not automatically require fresh research.

Research is read-only. It searches the workspace and relevant external sources, distinguishes evidence from assumptions, evaluates alternatives, and records planning readiness. When research runs, its durable output is:

```text
.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md
```

Reuse supplied or completed evidence when it is adequate. Record why research was reused or satisfied-and-skipped so the next phase does not repeat the investigation.

### 📋 Plan with rpi-plan

Use `/rpi-plan` when adequate evidence must become a sequenced, verifiable implementation strategy. Planning focuses on dependencies, acceptance criteria, boundaries, and stable work identifiers instead of changing source files.

The skill creates or revises three coordinated artifacts:

```text
.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md
.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md
.copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md
```

The plan uses stable `Pxx` phase IDs and `Pxx-Txx` task IDs with matching `<!-- rpi:... -->` markers. Phase details add evidence-based context, boundaries, dependencies, validation expectations, and completion evidence. An independent critique records `Pass`, `Revise`, or `Blocked` before implementation readiness.

### ⚡ Implement with rpi-implement

Use `/rpi-implement` to execute approved `Pxx` or `Pxx-Txx` work. Provide the dated plan, phase details, critique disposition, and exact phase or task when the execution scope is bounded.

Implementation records material work and truthful validation in:

```text
.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md
```

Each material change receives a `CHG-xxx` identifier. Completion checkboxes change only after evidence exists. If implementation needs a significant departure from the approved plan, it records a linked `DIV-xxx` and `AM-xxx`, updates the affected phase details, and returns the amendment for fresh plan critique. Affected dependent work resumes only after a `Pass` disposition; unrelated completed work remains intact.

### ✅ Review with rpi-review

Use `/rpi-review` when the implementation evidence is ready for acceptance review. Review does not modify the sources under review. It compares requirements, acceptance criteria, plan and task completion, critique dispositions, amendments, changes, divergences, and validation evidence in one record:

```text
.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md
```

Substantive findings receive severity-graded `RV-xxx` identifiers and explicit destinations. Review keeps execution status (`Complete`, `Partial`, or `Blocked`) separate from outcome (`Conformant`, `Conformant with justified divergence`, `Defects found`, `Residual work`, or `Not accepted`). This distinction prevents completed execution from being mistaken for accepted work.

### ➡️ Follow-up

Follow-up does not rename or repeat another lifecycle concept. It routes defects to implementation, decision gaps to planning, evidence gaps to research, and residual work to a distinct next item.

## RPI Entry Surfaces

Choose the smallest entry surface that owns the next action:

| Entry surface    | Use it when                                          | Contract                                                                        |
|------------------|------------------------------------------------------|---------------------------------------------------------------------------------|
| `RPI Agent`      | You want a user-selected lifecycle wrapper           | Activates the applicable RPI skills with one task identity                      |
| `/rpi-quick`     | You want a skill-based full-flow entry point         | Coordinates research readiness, planning, implementation, review, and follow-up |
| `/rpi-research`  | A demonstrated evidence gap blocks credible progress | Produces research evidence without planning or implementation                   |
| `/rpi-plan`      | Adequate evidence needs an implementation strategy   | Produces the plan, phase details, and critique disposition                      |
| `/rpi-implement` | Approved work is ready to execute                    | Produces source changes, change evidence, and validation                        |
| `/rpi-review`    | Implementation evidence is ready for reconciliation  | Produces one review record and routes open work                                 |

Select `RPI Agent` when you want a user-selected lifecycle wrapper that activates these same skills. `RPI Agent` and `/rpi-quick` are alternative entry surfaces, not autonomous dispatchers of specialized task workers.

## Managing Context Between Lifecycle Concepts

Use `/clear` or a new chat when a long lifecycle has accumulated context, you are switching concepts, or the conversation is no longer serving the task well. A context reset is a tool for clarity, not a requirement to repeat research or restart the lifecycle.

Durable artifacts carry the necessary context:

```text
research, when it runs → plan and details → changes → review and routed follow-up
```

Resume with the same stable task ID and open or reference the relevant dated artifacts. Navigate plan and detail sections with `Pxx`, `Pxx-Txx`, headings, and `<!-- rpi:... -->` markers.

For the technical explanation of why this matters, see [Context Engineering](context-engineering).

## When to Use RPI

| Use RPI artifacts when...                                 | Use a smaller direct edit when...               |
|-----------------------------------------------------------|-------------------------------------------------|
| The task needs evidence, planning, or review routing      | The change is clear and isolated                |
| Dependencies, risk, or uncertainty need explicit handling | Existing evidence and acceptance are sufficient |
| A handoff needs durable task evidence                     | No durable lifecycle evidence is needed         |

Use research when readiness identifies a gap. Otherwise, select the smallest lifecycle action that gives the task credible evidence and a clear owner.

## Quick Start

1. Define the task with requirements, acceptance criteria, decisions, dependencies, and available evidence.
2. Assess research readiness and use `/rpi-research` only if a demonstrated gap remains.
3. Plan with `/rpi-plan` when durable planning is needed.
4. Implement approved work with `/rpi-implement`.
5. Review with `/rpi-review`, then route defects, decisions, evidence gaps, or residual work through Follow-up.

> [!TIP]
> Use `/rpi-quick` or select `RPI Agent` when you want a lifecycle entry surface. Use a direct phase skill when the required next action is already clear.

## Next Steps

* [Why the RPI Workflow Works](why-rpi) - Understand why phase separation improves evidence and traceability
* [Using RPI Together](using-together) - Follow a complete workflow example
* [Context Engineering](context-engineering) - Why context management matters
* [Agents Reference](https://github.com/microsoft/hve-core/blob/main/.github/CUSTOM-AGENTS.md) - All available agents
* [Agent Systems Catalog](../agents/) - Browse all agent families beyond RPI

## See Also

* [Engineer Guide](../hve-guide/roles/engineer) - Role-specific guide for engineers using RPI
* [Tech Lead Guide](../hve-guide/roles/tech-lead) - Architecture review and prompt engineering workflows
* [Stage 6: Implementation](../hve-guide/lifecycle/implementation) - Where RPI fits in the project lifecycle

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
