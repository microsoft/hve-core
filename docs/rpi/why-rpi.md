---
title: Why the RPI Workflow Works
description: The psychology and principles behind the evidence-led RPI lifecycle and its entry surfaces
sidebar_position: 2
author: Microsoft
ms.date: 2026-07-13
ms.topic: concept
keywords:
  - rpi workflow
  - ai constraints
  - research readiness
  - hallucination prevention
  - ai coding
  - task reviewer
estimated_reading_time: 8
---

AI coding assistants are brilliant at simple tasks. Ask for a function that reverses a string, and you'll get working code in seconds. Ask for a feature that touches twelve files across three services, and you'll get something that looks right, compiles cleanly, and breaks everything it touches.

If you've spent hours debugging AI-generated code that ignored your project's conventions, used variable names that don't match anything in your codebase, or confidently called APIs that don't exist, you're not alone. The problem isn't that AI is incapable. The problem is that we're asking it to do too many things at once.

## The Real Problem

Here's what took us a while to figure out: AI is doing exactly what it's designed to do. When you ask it to "build a feature," it generates plausible output quickly. The issue is that "plausible" and "correct" aren't the same thing.

> [!WARNING]
> **The failure mode you'll recognize**
>
> You: "Build me a Terraform module for Azure IoT"
>
> AI: *immediately generates 2000 lines of code*
>
> Reality: Missing dependencies, wrong variable names, outdated patterns, breaks existing infrastructure

Why does this happen? Because AI can't tell the difference between investigating and implementing. When you ask for code, it writes code. It doesn't stop to verify that the variable naming convention it chose matches your existing modules. It doesn't check whether the resource it's creating already exists. It doesn't ask itself whether the API it's calling is current or deprecated.

AI writes first and thinks never. Not because it's broken, but because that's the only mode it has when you give it unrestricted access to both research and implementation.

## The Counterintuitive Insight

The solution isn't teaching AI to be smarter. It's preventing AI from doing certain things at certain times.

RPI keeps Research, Plan, Implement, Review, and Follow-up distinct so a task uses the smallest credible action at each point. It starts with research readiness: supplied or completed research is reused when adequate, while Task Researcher or `/rpi-research` investigates a demonstrated requirements, acceptance, dependency, material-risk, complexity, uncertainty, or decision-critical gap.

* [Task Researcher](task-researcher.md) investigates a demonstrated gap and produces evidence for planning readiness.
* [Task Planner](task-planner.md) owns the overall plan and phase details, may use `RPI Planner` for one bounded phase, and records independent critique.
* [Task Implementor](task-implementor.md) directly executes approved work, records changes and validation, and returns material amendments for fresh critique.
* [Task Reviewer](task-reviewer.md) creates one evidence-reconciliation record and routes defects, decision gaps, research gaps, and residual work.

When a long lifecycle needs a fresh context, durable artifacts preserve the task identity, evidence, decisions, and next action. A reset can reduce accumulated context, but it does not require a new research stage or a fresh run of every lifecycle concept.

Use `RPI Agent` as a user-selected wrapper that activates the applicable RPI skills. Use `/rpi-quick` as the skill-based full-flow entry point. They are alternative entry surfaces for the same phase skills, not autonomous dispatchers of specialized task workers.

### The Difference in Practice

**Without RPI**, AI thinks: "This looks like a reasonable variable name. I'll use `prefix`."

**With RPI**, research evidence can find: "12 existing modules in this repository use `resource_prefix`, not `prefix`; `variables.tf` contains the established pattern."

When AI knows it cannot implement during research, it stops optimizing for "plausible code" and starts optimizing for "verified truth." The constraint changes the goal.

## What Happens in Each Lifecycle Concept

Understanding what AI does differently in each phase helps explain why separation works.

### Research: Investigating a Demonstrated Gap

Research runs when readiness shows that planning cannot responsibly proceed with the supplied evidence. Task Researcher remains focused on the gap:

* Searches for existing patterns instead of inventing new ones.
* Cites precise source locations when they support a finding.
* Distinguishes evidence, assumptions, and unresolved questions.
* Documents dependencies, APIs, conventions, and planning readiness.

When evidence is adequate, Research is reused or satisfied-and-skipped instead of repeated.

### Planning Phase: Sequencing, Not Improvising

Task Planner synthesizes adequate evidence into actionable steps. The planning parent owns the overall checklist and phase details, and it can delegate one exact `Pxx` phase to `RPI Planner` when bounded authoring materially helps. Planning focuses on:

* Breaking work into logical, sequenced tasks.
* Identifying dependencies between changes.
* Defining clear success criteria for each step.
* Recording marker-addressed `Pxx` and `Pxx-Txx` work, assumptions, and dependencies.
* Recording independent `rpi-plan-critique` evidence before implementation readiness.

The plan becomes a contract. When implementation begins, the AI follows the plan rather than making decisions on the fly.

### Implementation Phase: Following, Not Inventing

Task Implementor or `/rpi-implement` directly executes approved `Pxx` or `Pxx-Txx` work. It remains flexible within the evidence boundary:

* No time wasted rediscovering conventions.
* Completion checkboxes change only after completion evidence exists.
* `CHG-xxx` changes and truthful validation establish what happened.
* A significant `DIV-xxx` links to an `AM-xxx` amendment, updates affected details, and receives fresh critique before affected dependent work resumes.

### Review Phase: Validating, Not Assuming

Task Reviewer or `/rpi-review` writes one record that reconciles implementation against documented evidence:

* Compares the plan, phase details, critique, amendments, changes, and validation evidence.
* Uses optional generic bounded lenses only when they reduce a specific uncertainty.
* Separates execution status from outcome and records validation as passed, failed, skipped, or unavailable.
* Routes defects to implementation, decision gaps to planning, research gaps to research, and residual work to follow-up.

### Follow-up: Routing, Not Relabeling

Follow-up records the next owner after review. It does not hide work inside a generic loop or merge residual work into the active task. A task can return to the earliest affected concept, or residual work can become a distinct next item.

## The Quality Difference

RPI produces measurably different outcomes than traditional AI coding:

| Aspect             | Traditional Approach                       | RPI Approach                                                        |
|--------------------|--------------------------------------------|---------------------------------------------------------------------|
| Pattern matching   | Invents plausible patterns                 | Uses verified patterns when evidence is needed                      |
| Traceability       | "The AI wrote it this way"                | Links decisions and changes to durable evidence                     |
| Knowledge transfer | Context remains in one conversation        | Reusable research, plan, change, and review artifacts               |
| Rework             | Assumptions surface late                   | Review routes each gap to the earliest responsible lifecycle concept |
| Validation         | Hope it works or manual testing            | Records evidence or an explicit unavailable or skipped reason       |

### The Paradigm Shift

Stop asking AI: "Write this code."

Start asking: "Help me research, plan, then implement with evidence."

RPI treats research as a readiness decision, planning as evidence-led coordination, implementation as direct execution, and review as evidence reconciliation. The task takes only the lifecycle actions it needs.

## The Learning Curve

Let's be honest: your first RPI lifecycle may feel slower. You're learning to judge research readiness, preserve durable evidence, and choose the smallest responsible next action.

By your third feature, the lifecycle feels natural. Research becomes faster because you can identify a genuine gap, planning tightens because you recognize the evidence needed for your codebase, and implementation can remain focused on approved work.

The value compounds over time. Research, planning, change, and review artifacts can accumulate into institutional memory when the task needs them. New team members can understand how decisions were made and which work remains.

## Choosing an RPI Entry Surface

HVE Core provides alternative surfaces for the same RPI phase skills. Choose the entry point that matches how you want to begin, then take only the lifecycle actions the task needs.

### RPI Agent

Select `RPI Agent` when you want a user-selected lifecycle wrapper. It activates matching RPI skills, begins with research readiness, and preserves one task identity across any durable artifacts.

### rpi-quick

Use `/rpi-quick` when you want the skill-based full-flow entry point. It follows the same research-readiness, planning, implementation, review, and follow-up contract as `RPI Agent`.

### Direct Phase Skills

Use `/rpi-research`, `/rpi-plan`, `/rpi-implement`, or `/rpi-review` when the next responsible lifecycle action is known. Task Researcher remains appropriate when readiness shows that dedicated investigation is needed.

### Matching the Entry Surface to the Task

| Entry surface       | Use it when                                          | Lifecycle contract                                 |
|---------------------|------------------------------------------------------|----------------------------------------------------|
| `RPI Agent`         | You want a user-selected wrapper around phase skills | Research readiness and applicable phase activation |
| `/rpi-quick`        | You want a skill-based full-flow entry point         | Same phase skills and durable task identity        |
| Direct phase skills | The next responsible action is already known         | Bounded Research, Plan, Implement, or Review work  |

### Evidence-Driven Escalation

Research readiness, planning critique, implementation amendments, and review findings determine when the task returns to an earlier concept. Start with adequate evidence when it exists; activate Task Researcher or `/rpi-research` when a demonstrated gap prevents credible planning or review.

## Next Steps

Ready to try it yourself?

* [Your First RPI Workflow](../getting-started/first-workflow.md): 15-minute hands-on tutorial
* [Using the Agents Together](using-together.md): context management and handoffs
* [RPI Overview](./): the lifecycle concepts explained
* [Task Reviewer Guide](task-reviewer.md): validation and iteration

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
