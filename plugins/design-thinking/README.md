<!-- markdownlint-disable-file -->
# Design Thinking

Design Thinking coaching identity, quality constraints, and methodology instructions for AI-enhanced design thinking across nine methods

> **⚠️ Experimental** — This collection is experimental. Contents and behavior may change or be removed without notice.

## Install

```bash
copilot plugin install design-thinking@hve-core
```

## Agents

| Agent             | Description                                                                                                                                       |
|-------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| dt-coach          | Design Thinking coach guiding teams through the 9-method HVE framework with Think/Speak/Empower philosophy - Brought to you by microsoft/hve-core |
| dt-learning-tutor | Design Thinking learning tutor providing structured curriculum, comprehension checks, and adaptive pacing - Brought to you by microsoft/hve-core  |

## Commands

| Command                         | Description                                                                                                                                  |
|---------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| dt-start-project                | Start a new Design Thinking coaching project with state initialization and first coaching interaction - Brought to you by microsoft/hve-core |
| dt-resume-coaching              | Resume a Design Thinking coaching session — reads coaching state and re-establishes context - Brought to you by microsoft/hve-core           |
| dt-method-next                  | Assess DT project state and recommend next method with sequencing validation - Brought to you by microsoft/hve-core                          |
| dt-handoff-implementation-space | Compiles DT Methods 7-9 outputs into RPI-ready handoff artifact with tiered routing                                                          |
| dt-handoff-problem-space        | Problem Space exit handoff — compiles DT Methods 1-3 outputs into RPI-ready artifact targeting task-researcher                               |
| dt-handoff-solution-space       | Solution Space exit handoff — compiles DT Methods 4-6 outputs into RPI-ready artifact targeting task-planner                                 |
| dt-method-04-ideation           | Divergent ideation for Design Thinking Method 4b with constraint-informed solution generation - Brought to you by microsoft/hve-core         |
| dt-method-04-convergence        | Theme discovery for Design Thinking Method 4c through philosophy-based clustering - Brought to you by microsoft/hve-core                     |
| dt-method-05-concepts           | Concept articulation for Design Thinking Method 5b from brainstorming themes - Brought to you by microsoft/hve-core                          |
| dt-method-05-evaluation         | Stakeholder alignment and three-lens evaluation for Design Thinking Method 5c - Brought to you by microsoft/hve-core                         |
| dt-method-06-planning           | Concept analysis and prototype approach design for Design Thinking Method 6a - Brought to you by microsoft/hve-core                          |
| dt-method-06-building           | Scrappy prototype building with fidelity enforcement for Design Thinking Method 6b - Brought to you by microsoft/hve-core                    |
| dt-method-06-testing            | Hypothesis-driven testing and constraint validation for Design Thinking Method 6c - Brought to you by microsoft/hve-core                     |

## Instructions

| Instruction                          | Description                                                                                                                                                                                                                                |
|--------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| dt-coaching-identity                 | Required instructions when working with or doing any Design Thinking (DT); Contains instructions for the Design Thinking coach identity, philosophy, and user interaction and communication requirements for consistent coaching behavior. |
| dt-method-07-hifi-prototypes         | Design Thinking Method 7: High-Fidelity Prototypes; technical translation, functional prototypes, and specifications                                                                                                                       |
| dt-method-07-deep                    | Deep expertise for Method 7: High-Fidelity Prototypes; fidelity translation, architecture, and specification writing                                                                                                                       |
| dt-method-08-testing                 | Design Thinking Method 8: User Testing - evidence-based evaluation, test protocols, and non-linear iteration support                                                                                                                       |
| dt-method-sequencing                 | Method transition rules, nine-method sequence, space boundaries, and non-linear iteration support for Design Thinking coaching                                                                                                             |
| dt-quality-constraints               | Quality constraints, fidelity rules, and output standards for Design Thinking coaching across all nine methods                                                                                                                             |
| dt-coaching-state                    | Coaching state schema for Design Thinking session persistence, method progress tracking, and session recovery                                                                                                                              |
| dt-industry-healthcare               | Healthcare industry context for DT coaching — vocabulary, constraints, empathy tools, and reference scenarios                                                                                                                              |
| dt-rpi-handoff-contract              | DT-to-RPI handoff contract defining exit points, artifact schemas, and per-agent input requirements for lateral transitions from Design Thinking to RPI workflow                                                                           |
| dt-rpi-implement-context             | DT-aware task-implementor context: fidelity constraints, stakeholder validation, and iteration support                                                                                                                                     |
| dt-rpi-planning-context              | DT-aware task-planner context: fidelity constraints, iteration support, and confidence-informed planning for DT artifacts                                                                                                                  |
| dt-rpi-research-context              | DT-aware task-researcher context — frames research around DT methods, stakeholder needs, and empathy-driven inquiry                                                                                                                        |
| dt-rpi-review-context                | DT-aware task-reviewer context: quality criteria for Design Thinking artifacts                                                                                                                                                             |
| dt-method-01-deep                    | Deep expertise for Method 1: Scope Conversations, covering advanced stakeholder analysis, power dynamics, and scope negotiation                                                                                                            |
| dt-method-01-scope                   | Method 1 Scope Conversations coaching knowledge for Design Thinking: frozen vs fluid assessment, stakeholder discovery, constraint patterns, and conversation navigation                                                                   |
| dt-method-03-deep                    | Deep expertise for Method 3: Input Synthesis — advanced affinity analysis, insight frameworks, and problem statement articulation                                                                                                          |
| dt-method-04-deep                    | Deep expertise for Method 4: Brainstorming — advanced facilitation techniques, creative block recovery, and convergence frameworks                                                                                                         |
| dt-method-05-deep                    | Deep expertise for Method 5: User Concepts, covering advanced D/F/V analysis, image prompt crafting, concept stress-testing, and portfolio management                                                                                      |
| dt-method-02-research                | Method 2 Design Research coaching knowledge: interview techniques, research planning, environmental observation, and insight extraction patterns                                                                                           |
| dt-method-02-deep                    | Deep expertise for Method 2: Design Research, covering advanced interview techniques, ethnographic observation, and evidence triangulation                                                                                                 |
| dt-method-03-synthesis               | Method 3 Input Synthesis coaching knowledge: pattern recognition, theme development, synthesis validation, and Problem-to-Solution Space transition readiness                                                                              |
| dt-method-08-deep                    | Deep expertise for Method 8: Test and Validate — advanced test design, small-sample analysis, iteration triggers, and bias mitigation                                                                                                      |
| dt-method-09-iteration               | Design Thinking Method 9: Iteration at Scale — systematic refinement, scaling patterns, and organizational deployment                                                                                                                      |
| dt-method-09-deep                    | Deep expertise for Method 9: Iteration at Scale — change management, scaling, and adoption measurement                                                                                                                                     |
| dt-method-06-deep                    | Deep expertise for Method 6: Low-Fidelity Prototypes; advanced paper prototyping, service blueprinting, and experience prototyping                                                                                                         |
| dt-industry-manufacturing            | Manufacturing industry context for DT coaching — vocabulary, constraints, empathy tools, and reference scenarios                                                                                                                           |
| dt-industry-energy                   | Energy industry context for DT coaching — vocabulary, constraints, empathy tools, and reference scenarios                                                                                                                                  |
| dt-image-prompt-generation           | M365 Copilot image prompt generation techniques for Design Thinking Method 5 concept visualization with lo-fi enforcement                                                                                                                  |
| dt-method-04-brainstorming           | Design Thinking Method 4: AI-assisted brainstorming with divergent ideation and convergent clustering for solution space entry                                                                                                             |
| dt-method-05-concepts                | Design Thinking Method 5: User Concepts coaching with concept articulation, three-lens evaluation, and stakeholder alignment for Solution Space development                                                                                |
| dt-method-06-lofi-prototypes         | Design Thinking Method 6: Lo-fi prototyping techniques, scrappy enforcement, feedback planning, and constraint discovery for Solution Space exit                                                                                           |
| dt-curriculum-01-scoping             | DT Curriculum Module 1: Scope Conversations — concepts, techniques, checks, and exercises                                                                                                                                                  |
| dt-curriculum-02-research            | DT Curriculum Module 2: Design Research — concepts, techniques, checks, and exercises                                                                                                                                                      |
| dt-curriculum-03-synthesis           | DT Curriculum Module 3: Synthesis — concepts, techniques, checks, and exercises                                                                                                                                                            |
| dt-curriculum-04-brainstorming       | DT Curriculum Module 4: Brainstorming — concepts, techniques, checks, and exercises                                                                                                                                                        |
| dt-curriculum-05-concepts            | DT Curriculum Module 5: User Concepts — concepts, techniques, checks, and exercises                                                                                                                                                        |
| dt-curriculum-06-prototypes          | DT Curriculum Module 6: Low-Fidelity Prototypes — concepts, techniques, checks, and exercises                                                                                                                                              |
| dt-curriculum-07-testing             | DT Curriculum Module 7: High-Fidelity Prototypes — concepts, techniques, checks, and exercises                                                                                                                                             |
| dt-curriculum-08-iteration           | DT Curriculum Module 8: User Testing — concepts, techniques, checks, and exercises                                                                                                                                                         |
| dt-curriculum-09-handoff             | DT Curriculum Module 9: Iteration at Scale — concepts, techniques, checks, and exercises                                                                                                                                                   |
| dt-curriculum-scenario-manufacturing | Manufacturing reference scenario for DT learning — factory floor improvement project used across all 9 curriculum modules                                                                                                                  |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

