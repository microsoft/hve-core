---
title: Design Thinking
description: Design Thinking coaching identity, quality constraints, and methodology skills for AI-enhanced design thinking across nine methods
sidebar_position: 4
author: Microsoft
ms.date: 2026-08-03
ms.topic: reference
---

Choose this package for teams using AI-enhanced Design Thinking across the nine methods and their Problem, Solution, and Implementation spaces.

It provides coaching and learning agents, method prompts, canonical-deck workflows, and RPI handoff support.

> [!NOTE]
> Preview: Design Thinking components are labeled preview to disclose their lifecycle posture.

Lifecycle labels are disclosure metadata. In the channel model, both Stable and PreRelease include the same active stable, preview, and experimental content; publication cadence and source ownership can differ.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                  | Maturity | Description                                                                                                                                           |
|-----------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| **dt-coach**          | preview  | Design Thinking coach guiding teams through the 9-method HVE framework with Think/Speak/Empower                                                       |
| **dt-learning-tutor** | preview  | Design Thinking learning tutor providing structured curriculum, comprehension checks, and adaptive pacing                                             |
| **rpi-agent**         | stable   | User-selected RPI workflow wrapper for Research, Plan, Implement, Review, and Follow-up. Use when one task needs lifecycle coordination.              |
| **rpi-planner**       | stable   | Revise one assigned RPI plan phase and matching phase details within a shared planning artifact. Use when a parent needs bounded phase authoring.     |
| **rpi-researcher**    | stable   | Executes one delegated internal, external, or hybrid RPI research lane and progressively writes owned evidence. Use for independent research threads. |

### Prompts

| Name                                | Maturity | Description                                                                                                     |
|-------------------------------------|----------|-----------------------------------------------------------------------------------------------------------------|
| **dt-canonical-deck**               | preview  | Canonical deck workflow: opt-in offer, snapshot generation/refresh, and optional customer-card PowerPoint build |
| **dt-figma-export**                 | preview  | Export Design Thinking artifacts to a FigJam board or Figma Design file via the Figma MCP server                |
| **dt-handoff-implementation-space** | preview  | Compiles DT Methods 7-9 into research-ready input for rpi-research at the Implementation Space exit             |
| **dt-handoff-problem-space**        | preview  | Compiles DT Methods 1-3 into research-ready input for rpi-research at the Problem Space exit                    |
| **dt-handoff-solution-space**       | preview  | Compiles DT Methods 4-6 into research-ready input for rpi-research at the Solution Space exit                   |
| **dt-method-04-convergence**        | preview  | Theme discovery for Design Thinking Method 4c through philosophy-based clustering                               |
| **dt-method-04-ideation**           | preview  | Divergent ideation for Design Thinking Method 4b with constraint-informed solution generation                   |
| **dt-method-05-concepts**           | preview  | Concept articulation for Design Thinking Method 5b from brainstorming themes                                    |
| **dt-method-05-evaluation**         | preview  | Stakeholder alignment and three-lens evaluation for Design Thinking Method 5c                                   |
| **dt-method-06-building**           | preview  | Scrappy prototype building with fidelity enforcement for Design Thinking Method 6b                              |
| **dt-method-06-planning**           | preview  | Concept analysis and prototype approach design for Design Thinking Method 6a                                    |
| **dt-method-06-testing**            | preview  | Hypothesis-driven testing and constraint validation for Design Thinking Method 6c                               |
| **dt-method-next**                  | preview  | Assess DT project state and recommend next method with sequencing validation                                    |
| **dt-resume-coaching**              | preview  | Resume a Design Thinking coaching session - reads coaching state and re-establishes context                     |
| **dt-start-project**                | preview  | Start a new Design Thinking coaching project with state initialization and first coaching interaction           |
| **rpi**                             | stable   | Coordinate one task through the Research, Plan, Implement, Review, and Follow-up RPI workflow                   |

### Instructions

| Name                                   | Maturity | Description                                                                                                                                                                                                                                                 |
|----------------------------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **design-thinking/dt-coach-telemetry** | stable   | Applies Design Thinking telemetry expectations to DT session artifacts                                                                                                                                                                                      |
| **shared/hve-core-location**           | stable   | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name                       | Maturity | Description                                                                                                                                                                                                                                                                                                           |
|----------------------------|----------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **dt-coaching-foundation** | preview  | Design Thinking coaching foundation knowledge: coach identity and philosophy, quality and fidelity constraints, method sequencing, coaching state schema, and the canonical deck workflow                                                                                                                             |
| **dt-curriculum**          | preview  | Design Thinking learning curriculum covering nine progressive modules across the full Problem, Solution, and Implementation Space methods plus a shared manufacturing reference scenario for teaching and practice                                                                                                    |
| **dt-methods**             | preview  | Design Thinking method coaching knowledge across all nine methods including per-method techniques, deep expertise, and industry context (energy, financial services, healthcare, manufacturing, nonprofit and social impact, pharmaceuticals and life sciences, professional services, public sector, retail and CPG) |
| **dt-rpi-integration**     | preview  | Design Thinking handoff knowledge for research-ready rpi-research inputs and DT-aware rpi-plan, rpi-implement, and rpi-review context                                                                                                                                                                                 |
| **rpi-implement**          | stable   | Execute an approved RPI plan, maintain current planning state, and record implementation evidence. Use when implementation is ready to begin or resume.                                                                                                                                                               |
| **rpi-plan**               | stable   | Create evidence-based RPI plans and phase details from supplied context, research, drafts, and decisions. Use when implementation planning is needed.                                                                                                                                                                 |
| **rpi-plan-critique**      | stable   | Independently critique an RPI plan and phase details against supplied evidence without editing plan sources. Use when planning credibility needs a read-only assessment.                                                                                                                                              |
| **rpi-research**           | stable   | Research-only RPI playbook that gathers task evidence, writes dated research artifacts under .copilot-tracking/research/, and hands off planning-ready findings. Use when the user needs evidence, alternatives, or task framing first.                                                                               |
| **rpi-review**             | stable   | Compare RPI planning and implementation evidence, record review findings, and route follow-up work. Use when an implementation needs acceptance review.                                                                                                                                                               |
| **telemetry-foundations**  | stable   | Declarative OpenTelemetry-aligned telemetry vocabulary and instrumentation conventions for traces, metrics, logs, and PII handling                                                                                                                                                                                    |

<!-- END AUTO-GENERATED ARTIFACTS -->

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
