---
title: "Tutorial: Handing Off from DT to RPI"
description: Step-by-step tutorial for performing Design Thinking to RPI handoffs at each exit point
sidebar_position: 15
author: Microsoft
ms.date: 2026-06-28
ms.topic: tutorial
keywords:
  - design thinking
  - rpi
  - handoff
  - tutorial
  - integration
estimated_reading_time: 10
---

## Prerequisites

Before starting a handoff, ensure you have:

* A DT Coach session with a project slug, such as `factory-floor-maintenance`
* Completed Methods 7-9 for the Implementation Spec Ready exit
* A coaching state file at `.copilot-tracking/design-thinking-sessions/{project-slug}/coaching-state.md`
* An artifact folder at `docs/design-thinking/{project-slug}/`
* Familiarity with [RPI workflow basics](../rpi/README.md)

> [!NOTE]
> This tutorial continues the manufacturing scenario from [Using DT Methods Together](using-together.md). The team discovered that the plant manager's "quality dashboard" request actually reflects a knowledge-loss problem across shifts.

## Implementation Spec Ready Handoff

The DT-to-RPI handoff can occur at three exit points: Problem Statement Complete (Methods 1-3), Concept Validated (Methods 4-6), and Implementation Spec Ready (Methods 7-9).
Every exit enters the RPI pipeline at the single Task Researcher entry point, and later exits seed the Researcher with progressively richer context.
This tutorial walks through the Implementation Spec Ready exit, which hands off the richest artifact set after Methods 7-9 are complete. The same steps apply to the earlier exits with leaner artifacts.

### What the Handoff Includes

The handoff artifact carries the richer DT evidence you gathered through the Implementation Space:

* Architecture decisions and technical trade-offs
* High-fidelity prototype outcomes and test evidence
* Stakeholder and constraint context from earlier methods
* Confidence markers for each artifact, constraint, and assumption

When you review the handoff before sending it to Task Researcher, pay attention to items marked `assumed`, `unknown`, or `conflicting`. Those items become research targets for the incoming RPI work.

### Step 1: Confirm Readiness with DT Coach

After completing Method 9, ask the coach to assess readiness:

```text
/dt-method-next
```

The coach reviews the completed Implementation Space work and confirms that the handoff is ready for the single Task Researcher entry point.

### Step 2: Generate the Handoff Artifact

Start a new chat session and run the Implementation Space handoff prompt:

```text
/dt-handoff-implementation-space project-slug=factory-floor-maintenance
```

The prompt compiles the available DT artifacts, applies the current handoff contract, and produces two files in `docs/design-thinking/{project-slug}/`:

* `handoff-summary.md`: The structured handoff metadata with confidence markers
* `rpi-handoff-implementation-space.md`: A self-contained document for Task Researcher

### Step 3: Review the Artifact

Open `rpi-handoff-implementation-space.md` and verify that it includes:

* A clear problem framing and implementation context
* Stakeholder context, constraints, and assumptions with confidence markers
* Evidence from High-Fidelity Prototypes, User Testing, and Iteration at Scale
* Clear investigation targets for items marked `assumed`, `unknown`, or `conflicting`

### Step 4: Hand Off to Task Researcher

Clear your chat context and switch to Task Researcher:

```text
/clear
```

Open the generated handoff file in your editor, then invoke Task Researcher:

```text
@task-researcher Research implementation options for the voice-guided
repair system based on the DT handoff artifact that is open in the
editor at docs/design-thinking/factory-floor-maintenance/rpi-handoff-implementation-space.md
```

Task Researcher uses the handoff to:

* Scope technical research around the validated implementation context
* Treat `assumed` items as verification targets
* Treat `unknown` items as primary research targets
* Pass the DT-informed findings into the standard RPI pipeline

### Step 5: Continue Through RPI

After research completes, continue with the standard RPI phases:

```text
/clear → Task Planner → /clear → Task Implementor → /clear → Task Reviewer
```

The researcher's output carries the validated DT context into planning and implementation rather than recreating it from scratch.

## When RPI Returns to DT

The handoff is not one-way. Task Researcher can recommend returning to DT coaching when research reveals issues that trace back to DT assumptions. When that happens, open a new DT Coach session, restate the finding that invalidated the assumption, and resume from the earlier method that needs revision.

## Quick Reference

| Action                              | Command or Step                                                                    |
|-------------------------------------|------------------------------------------------------------------------------------|
| Check readiness                     | `/dt-method-next` in the DT Coach session                                          |
| Generate the implementation handoff | `/dt-handoff-implementation-space project-slug=...`                                |
| Switch to RPI                       | `/clear`, open the handoff artifact, then invoke Task Researcher                   |
| Return to DT from RPI               | Start a new `@dt-coach` session and describe the finding that triggered the return |

## Related Resources

* [DT to RPI Integration](dt-rpi-integration.md): Reference for the handoff contract, per-agent mappings, and confidence markers
* [Using DT Methods Together](using-together.md): End-to-end walkthrough of all nine DT methods
* [RPI Workflow](../rpi/README.md): Research, Plan, Implement, Review framework
* [DT Coach Guide](dt-coach.md): How to use the DT Coach agent

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
