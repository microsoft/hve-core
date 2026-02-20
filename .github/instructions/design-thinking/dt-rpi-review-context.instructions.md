---
description: "DT-aware task-reviewer context: quality criteria for Design Thinking artifacts"
applyTo: '**/.copilot-tracking/dt/**'
---

# DT Review Context

When task-reviewer (see `docs/rpi/task-reviewer.md`) operates on DT artifacts, these criteria augment standard review behavior. The review question shifts from "does the code work?" to "does the artifact serve the Design Thinking process?" Evaluate coaching quality, method fidelity, and stakeholder coverage alongside structural correctness.

## Review Criteria Adjustments

| Standard Review          | DT-Informed Review                                               |
|--------------------------|------------------------------------------------------------------|
| Code correctness focus   | Coaching quality and method fidelity focus                       |
| Pass/fail assessment     | Space-appropriate fidelity assessment (rough/scrappy/functional) |
| Style guide conformance  | Coaching identity conformance (Think/Speak/Empower)              |
| Single output evaluation | Multi-stakeholder coverage evaluation                            |
| Forward-only approval    | Iteration-aware evaluation supporting return paths               |

## Quality Criteria by Artifact Type

| Artifact Type            | Key Quality Criteria                                                                                                   |
|--------------------------|------------------------------------------------------------------------------------------------------------------------|
| Coaching instructions    | Think/Speak/Empower structure; coaching boundaries maintained; no directive language; progressive hints                |
| Method instructions      | Correct space assignment; exit signals defined; coaching hat triggers; non-linear iteration support                    |
| Deep instructions        | Advanced techniques beyond base method; domain expertise depth; fidelity appropriate to space                          |
| Industry context         | Domain vocabulary mapping; industry-specific constraints; stakeholder archetypes; reference scenarios                  |
| Handoff artifacts        | Confidence markers applied (validated/assumed/unknown/conflicting); exit point and target agent alignment              |
| Agent definitions        | Subagent delegation patterns; handoff labels; core principles aligned with coaching identity                           |
| Method output artifacts  | Fidelity matches current space; multi-source evidence; stakeholder coverage across identified groups                   |
| Coaching state artifacts | Session continuity maintained; method progress accurately tracked; recovery points clearly marked; no stale references |

## DT Review Checklist Additions

When reviewing DT artifacts, add these checks to the standard review checklist:

* Language guides thinking through observations ("I'm noticing..."), not directives ("You must..."), to maintain coaching tone
* Output quality matches the method's space tier: rough in Problem, scrappy in Solution, functional in Implementation
* Perspectives from all identified stakeholder groups are represented, not just the most obvious
* Claims trace to research data (Method 2+) or acknowledged assumptions (Method 1) for evidence grounding
* Content encourages revisiting and refining without framing backward movement as regression
* Token budgets follow artifact limits: ambient (coaching identity, quality constraints, review context) ≤800; method ≤1,500; deep ≤2,500 tokens

## Anti-Patterns to Flag

| Anti-Pattern                                      | Severity | Rationale                                                          |
|---------------------------------------------------|----------|--------------------------------------------------------------------|
| Directive coaching language ("You must...")       | Major    | Violates Think/Speak/Empower identity                              |
| Production-quality output in early methods        | Major    | Violates anti-polish stance and space fidelity rules               |
| Missing stakeholder perspectives                  | Major    | Violates multi-stakeholder requirement                             |
| Single-source conclusions                         | Major    | Violates multi-source validation rule                              |
| Skipped method exit signals                       | Critical | Invalidates downstream work; violates method sequencing            |
| Confidence markers missing from handoff artifacts | Major    | Downstream agents cannot assess artifact reliability               |
| Unresolved conflicting markers passed downstream  | Critical | Invalidates downstream work; violates handoff contract reliability |

## Severity Mapping

| Severity | Description                                | Examples                                                                                                                  |
|----------|--------------------------------------------|---------------------------------------------------------------------------------------------------------------------------|
| Critical | Violations that invalidate downstream work | Skipped exit signals, wrong space assignment, unresolved conflicting markers passed downstream                            |
| Major    | Violations that degrade artifact quality   | Directive language, missing stakeholders, single-source conclusions, missing confidence markers, over-polished prototypes |
| Minor    | Stylistic or structural issues             | Leaked internal reasoning in Speak layer, ideal-only testing conditions, token budget slightly exceeded                   |

These criteria complement co-loaded instruction files (`dt-quality-constraints`, `dt-coaching-identity`, `dt-method-sequencing`, `dt-rpi-handoff-contract`): reference their content during review rather than duplicating it.
