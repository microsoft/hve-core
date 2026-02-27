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

| Exit Point                 | After Methods | RPI Target      | You Have                                                | RPI Does                                       |
|----------------------------|---------------|-----------------|---------------------------------------------------------|------------------------------------------------|
| Problem Statement Complete | 1-3           | Task Researcher | Validated problem, stakeholder map, themes              | Research solutions, plan, implement            |
| Concept Validated          | 4-6           | Task Researcher | Tested concepts, constraint discoveries, narrowed scope | Research with richer context, plan, implement  |
| Implementation Spec Ready  | 7-8           | Task Researcher | Functional specs, test results, architecture decisions  | Research with richest context, plan, implement |

Earlier exit points provide leaner artifacts requiring broader Researcher investigation. Later exit points provide richer context from additional DT methods, narrowing the Researcher's scope. Every exit enters the full RPI pipeline at Task Researcher.

## What Task Researcher Needs From Your Handoff

Every handoff artifact contains three categories of information that shape how Task Researcher scopes its investigation:

| Category    | What It Contains                                       | How the Researcher Uses It                          |
|-------------|--------------------------------------------------------|-----------------------------------------------------|
| Artifacts   | DT method outputs with file paths and evidence summary | Establishes the evidence base and validated context |
| Constraints | Technical, environmental, or workflow limitations      | Bounds the solution space the researcher explores   |
| Assumptions | Beliefs not yet independently verified                 | Drives verification targets and research priorities |

Each item carries a **confidence marker** that tells the Researcher how much trust to place in it:

| Marker        | Meaning                                            | Researcher Action                               |
|---------------|----------------------------------------------------|-------------------------------------------------|
| `validated`   | Confirmed through multiple sources or observation  | Treats as established fact, no re-investigation |
| `assumed`     | Stated by a source but not independently confirmed | Marks as a verification target                  |
| `unknown`     | Identified gap not yet investigated                | Marks as a primary research target              |
| `conflicting` | Multiple sources disagree                          | Investigates to resolve the conflict            |

When you review your handoff artifact before giving it to Task Researcher, pay attention to items marked `assumed`, `unknown`, or `conflicting`. These drive the Researcher's investigation scope. If too many critical items carry weak markers, consider returning to DT coaching to strengthen the evidence before handing off.

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

## Exit Point 2: Solution Space Handoff (Methods 4-6 → Task Researcher)

This scenario hands off after Lo-Fi Prototypes. The team has tested concepts and narrowed directions but has not built functional prototypes.

### Step 1: Confirm Readiness

After completing Method 6, use `/dt-method-next` to assess readiness. The coach confirms that lo-fi prototypes have been tested with real users and concepts are narrowed to one or two directions.

### Step 2: Generate the Solution Space Handoff

```text
/dt-handoff-solution-space project-slug=factory-floor-maintenance
```

This produces:

* `.copilot-tracking/dt/factory-floor-maintenance/handoff-solution-space.md`: The handoff metadata
* `.copilot-tracking/dt/factory-floor-maintenance/rpi-handoff-solution-space.md`: A self-contained document for Task Researcher

The Solution Space handoff includes everything from the Problem Space plus:

* Tested concepts with D/F/V (Desirability/Feasibility/Viability) evaluations
* Constraint discoveries categorized by type (Physical/Environmental/Workflow) and severity (Blocker/Friction/Minor)
* Validated and invalidated assumptions from lo-fi prototype testing
* User behavior patterns observed during testing

### Step 3: Verify the Solution Space Artifact

Open `rpi-handoff-solution-space.md` and verify the contents. A well-formed Solution Space artifact includes everything from Exit Point 1 plus:

* Tested concepts with D/F/V evaluation results and stakeholder alignment evidence
* Constraint discoveries categorized by type and severity, each with a confidence marker
* A clear distinction between validated assumptions (evidence from testing) and invalidated assumptions (disproven by prototype feedback)
* User behavior patterns with specific observations, not generalizations

Check the confidence markers carefully. At Exit Point 2, you should see more `validated` markers than at Exit Point 1 because lo-fi prototype testing produces direct evidence. Items still marked `assumed` or `unknown` become the Researcher's primary investigation targets.

### Step 4: Invoke Task Researcher

Clear context and switch to Task Researcher:

```text
/clear
```

Open `rpi-handoff-solution-space.md` and invoke the researcher:

```text
@task-researcher Research implementation options for the voice-guided
repair system. The DT handoff artifact is open at
.copilot-tracking/dt/factory-floor-maintenance/rpi-handoff-solution-space.md
```

Task Researcher uses the richer Solution Space artifacts to:

* Narrow technical research scope using validated concepts and constraint discoveries
* Treat invalidated assumptions as resolved (no re-investigation needed)
* Focus on feasibility gaps and implementation options for the tested directions
* Produce a research file that feeds the standard RPI pipeline

### Step 5: Continue Through RPI

```text
/clear → Task Planner → /clear → Task Implementor → /clear → Task Reviewer
```

The researcher's output already incorporates DT constraints and validated concepts, so the planner builds against evidence rather than assumptions.

## Exit Point 3: Implementation Space Handoff (Methods 7-9 → Task Researcher)

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

The Implementation Space provides the richest artifacts of any exit point, giving the Researcher the most complete context to work with.

### Step 2: Review the Handoff Artifact

Open the generated handoff artifact and verify the contents match your exit tier:

**All tiers (Method 7+):**

* Architecture decisions and technical trade-offs with comparison results
* Fidelity mapping matrix and performance benchmarks
* Integration validation results with confidence markers
* Specification drafts connected to prototype evidence

**Tier 2+ (Methods 7-8):**

* Test protocols and participant profiles
* Behavioral observation data (not just opinions)
* Severity-frequency matrix findings
* Assumption validation results showing which assumptions were confirmed, challenged, or invalidated

**Tier 3 (Methods 7-9):**

* Refinement log with baseline measurements
* Scaling assessment across technical, user, process, and constraint dimensions
* Deployment plan with change management and rollback capability
* Adoption metrics (leading and lagging indicators)

At this exit point, most items should carry `validated` markers because hi-fi prototypes and user testing produce strong evidence. Items still marked `assumed` or `unknown` stand out as clear research targets for the Researcher.

### Step 3: Hand Off to Task Researcher

```text
/clear
```

Open the handoff artifact and invoke the researcher:

```text
@task-researcher Research implementation approach for the voice-guided
repair system. The DT handoff artifact is open at
.copilot-tracking/dt/factory-floor-maintenance/rpi-handoff-implementation-space.md
```

Task Researcher uses the richest available context to:

* Validate architecture decisions against current technical landscape
* Confirm that test results and user preferences still hold
* Research integration options and production-readiness requirements
* Produce a research file that feeds the standard RPI pipeline

### Step 4: Continue Through RPI

```text
/clear → Task Planner → /clear → Task Implementor → /clear → Task Reviewer
```

The researcher's output carries validated DT specifications, hi-fi prototype findings, and architecture decisions through the full pipeline. The planner and implementor inherit this rich context rather than re-deriving it.

## When RPI Returns to DT

The handoff is not one-way. Task Researcher can recommend returning to DT coaching when research reveals issues that trace back to DT assumptions. Other RPI agents (Planner, Implementor, Reviewer) surface issues through the standard RPI chain; the Researcher aggregates these signals and determines whether a DT return is warranted.

### Recognizing Return Signals

Task Researcher recommends returning to DT when:

* The problem statement needs revision based on new technical evidence
* Research reveals unrepresented stakeholders whose needs change the problem framing
* Fundamental DT assumptions are invalidated by technical investigation
* Downstream RPI agents (Planner, Implementor, or Reviewer) surface issues that trace back to unresolved DT assumptions

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

| Action                 | Command or Step                                                               |
|------------------------|-------------------------------------------------------------------------------|
| Check readiness        | `/dt-method-next` in DT Coach session                                         |
| Problem Space handoff  | `/dt-handoff-problem-space project-slug=...`                                  |
| Solution Space handoff | `/dt-handoff-solution-space project-slug=...`                                 |
| Implementation handoff | `/dt-handoff-implementation-space project-slug=...`                           |
| Switch to RPI agent    | `/clear`, open handoff artifact, invoke `@task-researcher`                    |
| Return to DT from RPI  | Start new `@dt-coach` session, describe the finding that triggered the return |

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
