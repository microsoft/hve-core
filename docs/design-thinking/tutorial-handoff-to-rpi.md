---
title: "Tutorial: Handing Off from DT to RPI"
description: Step-by-step tutorial for performing Design Thinking to RPI handoffs at each exit point
author: Microsoft
ms.date: 2026-02-25
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

* A DT Coach session with a project slug (e.g., `factory-floor-maintenance`)
* Completed methods for your chosen exit point (Methods 1-3, 4-6, or 7-8)
* Coaching state file at `.copilot-tracking/dt/{project-slug}/coaching-state.md`
* Familiarity with [RPI workflow basics](../rpi/README.md)

> [!NOTE]
> This tutorial continues the manufacturing scenario from [Using DT Methods Together](using-together.md). The team discovered that the plant manager's "quality dashboard" request actually reflects a knowledge-loss problem across shifts.

## Choosing Your Exit Point

DT-to-RPI handoff can happen at three exit points. Your choice depends on how much DT work is complete and how much you want RPI to handle.

| Exit Point                 | After Methods | RPI Target       | You Have                                                | RPI Does                            |
|----------------------------|---------------|------------------|---------------------------------------------------------|-------------------------------------|
| Problem Statement Complete | 1-3           | Task Researcher  | Validated problem, stakeholder map, themes              | Research solutions, plan, implement |
| Concept Validated          | 4-6           | Task Planner     | Tested concepts, constraint discoveries, narrowed scope | Plan implementation, implement      |
| Implementation Spec Ready  | 7-8           | Task Implementor | Functional specs, test results, architecture decisions  | Implement the validated design      |

Earlier exits transfer more work to RPI. Later exits transfer a more refined, validated artifact.

## Exit Point 1: Problem Space Handoff (Methods 1-3 → Task Researcher)

This scenario hands off after Input Synthesis. The team has a validated problem statement but has not yet generated solutions.

### Step 1: Confirm Readiness with DT Coach

After completing Method 3, ask the coach to assess readiness:

```text
/dt-method-next
```

The coach reviews your Problem Space outputs and presents options. When it offers the lateral handoff option, confirm that you want to hand off to RPI rather than continuing into the Solution Space.

### Step 2: Run the Handoff Prompt

Start a new chat session and run the Problem Space handoff prompt:

```text
/dt-handoff-problem-space project-slug=factory-floor-maintenance
```

The prompt reads your coaching state, compiles artifacts from Methods 1-3, assesses readiness, and produces two files:

* `.copilot-tracking/dt/factory-floor-maintenance/handoff-summary.md`: The handoff metadata with confidence markers
* `.copilot-tracking/dt/factory-floor-maintenance/rpi-handoff-problem-space.md`: A self-contained document for Task Researcher

### Step 3: Review the Handoff Artifact

Open `rpi-handoff-problem-space.md` and verify the contents. A well-formed artifact includes:

* A problem statement framed as a research topic
* Stakeholder context with roles and perspectives
* Research themes with supporting evidence
* Constraints tagged as `validated`, `assumed`, `unknown`, or `conflicting`
* Investigation targets (items the researcher should verify or explore)

For the manufacturing scenario, the problem statement would read something like: "Night-shift operators lack the informal expert network that day-shift teams rely on for quality problem resolution, leading to 3x higher defect rates during off-hours." Items tagged `assumed` (such as "operators prefer voice interaction over touch") become verification targets for the researcher.

### Step 4: Hand Off to Task Researcher

Clear your chat context and switch to Task Researcher:

```text
/clear
```

Open `rpi-handoff-problem-space.md` in your editor so the researcher agent can see it. Then invoke Task Researcher:

```text
@task-researcher Research solutions for the knowledge-loss problem
described in the DT handoff. The handoff artifact is open in the
editor at .copilot-tracking/dt/factory-floor-maintenance/rpi-handoff-problem-space.md
```

Task Researcher uses the handoff to:

* Scope technical research around the stakeholder-validated problem rather than assumed requirements
* Treat `assumed` items as verification targets
* Treat `unknown` items as primary research targets
* Investigate from each stakeholder perspective identified in the handoff

The researcher produces a research file at `.copilot-tracking/research/` following standard RPI conventions.

### Step 5: Continue the RPI Pipeline

After research completes, proceed through the standard RPI phases:

```text
/clear → Task Planner → /clear → Task Implementor → /clear → Task Reviewer
```

Each phase consumes the previous phase's output. The DT context flows through: the planner references the researcher's DT-informed findings, and the implementor inherits fidelity constraints and stakeholder validation steps.

## Exit Point 2: Solution Space Handoff (Methods 4-6 → Task Planner)

This scenario hands off after Lo-Fi Prototypes. The team has tested concepts and narrowed directions but has not built functional prototypes.

### Step 1: Confirm Readiness

After completing Method 6, use `/dt-method-next` to assess readiness. The coach confirms that lo-fi prototypes have been tested with real users and concepts are narrowed to one or two directions.

### Step 2: Generate the Solution Space Handoff

```text
/dt-handoff-solution-space project-slug=factory-floor-maintenance
```

This produces:

* `.copilot-tracking/dt/factory-floor-maintenance/handoff-solution-space.md`: The handoff metadata
* `.copilot-tracking/dt/factory-floor-maintenance/rpi-handoff-solution-space.md`: A self-contained document for Task Planner

The Solution Space handoff includes everything from the Problem Space plus:

* Tested concepts with D/F/V (Desirability/Feasibility/Viability) evaluations
* Constraint discoveries categorized by type (Physical/Environmental/Workflow) and severity (Blocker/Friction/Minor)
* Validated and invalidated assumptions from lo-fi prototype testing
* User behavior patterns observed during testing

### Step 3: Hand Off to Task Planner

Clear context and switch to Task Planner:

```text
/clear
```

Open `rpi-handoff-solution-space.md` and invoke the planner:

```text
@task-planner Plan implementation for the voice-guided repair system.
The DT handoff artifact is open at
.copilot-tracking/dt/factory-floor-maintenance/rpi-handoff-solution-space.md
```

Task Planner creates an implementation plan that:

* Enforces space-appropriate fidelity (no premature polishing)
* Includes stakeholder validation steps at each phase
* Weights task priority using confidence markers from the handoff
* Builds iteration loops that can route work back to DT methods when needed

### Step 4: Continue Through RPI

```text
/clear → Task Implementor → /clear → Task Reviewer
```

The planner's output already accounts for DT constraints, so the implementor builds against validated specifications rather than assumptions.

## Exit Point 3: Validation Space Handoff (Methods 7-8 → Task Implementor)

This is the richest handoff, carrying cumulative artifact lineage from all completed methods. The team has functional prototypes, test results, and architecture decisions.

### Step 1: Run the Handoff Prompt

```text
/dt-handoff-implementation-space project-slug=factory-floor-maintenance
```

This prompt determines an exit tier based on which Implementation Space methods are complete:

| Tier | Methods Complete | Handoff Richness |
|------|------------------|------------------|
| 1    | Method 7 only    | Guided           |
| 2    | Methods 7-8      | Structured       |
| 3    | Methods 7-9      | Comprehensive    |

The prompt routes to Task Implementor when the prototype is near production-ready, or to Task Planner when significant architecture gaps remain.

### Step 2: Hand Off to Task Implementor

```text
/clear
```

Open the handoff artifact and invoke the implementor:

```text
@task-implementor Implement the voice-guided repair system based on
the DT handoff. The handoff artifact is open at
.copilot-tracking/dt/factory-floor-maintenance/rpi-handoff-implementation-space.md
```

The implementor works with:

* Hi-fi prototype specifications and architecture decisions
* Test results showing which approaches users preferred (e.g., glove-friendly controls driving 40% higher adoption)
* Fidelity constraints from the originating DT space
* DT artifact references for traceability

## When RPI Returns to DT

The handoff is not one-way. Any RPI agent can recommend returning to DT coaching when their work reveals issues that trace back to DT assumptions. This section shows what that looks like in practice.

### Recognizing Return Signals

Each RPI agent encounters different situations that warrant a return:

**Task Researcher** recommends returning when:

* The problem statement needs revision based on new technical evidence
* Research reveals unrepresented stakeholders whose needs change the problem framing
* Fundamental DT assumptions are invalidated by technical investigation

**Task Planner** recommends returning when:

* Core assumptions remain unresolved even after research, making planning unreliable
* Fidelity requirements conflict with the originating DT space
* The plan reveals that the solution direction needs stakeholder re-validation

**Task Implementor** recommends returning when:

* Real-world constraints (performance, integration, infrastructure) invalidate the concepts validated during DT prototyping
* Implementation reveals that the user experience differs significantly from what was tested

**Task Reviewer** flags items for DT re-entry when:

* Artifact quality criteria are not met (missing stakeholder coverage, incorrect confidence markers)
* Implementation diverges from the validated DT direction without documented rationale

### Practical Example: Researcher Returns to DT

Continuing the manufacturing scenario: Task Researcher investigates the voice-guided repair concept and discovers that the factory's Wi-Fi infrastructure cannot support real-time voice processing in the production area. This invalidates a core DT assumption (that voice interaction is feasible on the factory floor).

The researcher's output includes a recommendation:

```text
⚠️ DT Return Recommended: The assumption that voice interaction
is feasible on the factory floor (marked 'assumed' in the handoff)
is invalidated by infrastructure constraints. Recommend returning
to DT Method 2 for targeted research on connectivity options,
then re-synthesizing in Method 3.
```

### Re-entering DT Coaching

When an RPI agent recommends returning, start a new DT Coach session that picks up where you left off:

```text
@dt-coach We completed Methods 1-3 and handed off to RPI, but the
researcher found that our voice interaction assumption is invalid
due to Wi-Fi constraints. We need to revisit Method 2 to research
connectivity options on the factory floor.
```

The DT Coach reads your existing coaching state, sees the completed methods and transition log, and re-enters Method 2 with the new evidence. It does not start from scratch. The iteration history in the coaching state preserves everything learned from the original DT session and the RPI research.

After addressing the gap (researching offline-capable alternatives, re-synthesizing with updated constraints), you can hand off to RPI again with a revised handoff artifact that reflects the new understanding.

### Tracking the Round Trip

The coaching state records each transition in its `transition_log`:

```yaml
transition_log:
  - type: lateral
    from_method: 3
    to: rpi-researcher
    rationale: "Problem Space complete: handoff to RPI pipeline"
    date: "2026-02-20"
  - type: non-linear
    from_method: 3
    to_method: 2
    trigger: "RPI researcher invalidated voice feasibility assumption"
    date: "2026-02-22"
  - type: lateral
    from_method: 3
    to: rpi-researcher
    rationale: "Revised Problem Space with offline-capable alternatives"
    date: "2026-02-24"
```

This log gives the full history: the original handoff, the return to DT with the reason, and the subsequent re-handoff with updated artifacts. Every team member can trace how the project evolved.

## Quick Reference

| Action                 | Command or Step                                                                                    |
|------------------------|----------------------------------------------------------------------------------------------------|
| Check readiness        | `/dt-method-next` in DT Coach session                                                              |
| Problem Space handoff  | `/dt-handoff-problem-space project-slug=...`                                                       |
| Solution Space handoff | `/dt-handoff-solution-space project-slug=...`                                                      |
| Implementation handoff | `/dt-handoff-implementation-space project-slug=...`                                                |
| Switch to RPI agent    | `/clear`, open handoff artifact, invoke `@task-researcher` / `@task-planner` / `@task-implementor` |
| Return to DT from RPI  | Start new `@dt-coach` session, describe the finding that triggered the return                      |

## Related Resources

* [DT to RPI Integration](dt-rpi-integration.md): Reference for the handoff contract, per-agent mappings, and confidence markers
* [Using DT Methods Together](using-together.md): End-to-end walkthrough of all nine DT methods
* [RPI Workflow](../rpi/README.md): Research, Plan, Implement, Review framework
* [DT Coach Guide](dt-coach.md): How to use the DT Coach agent

> Brought to you by microsoft/hve-core

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
