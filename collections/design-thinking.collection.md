# Design Thinking

Coaching identity, quality constraints, and methodology skills for AI-enhanced design thinking across nine methods. The collection supports the HVE Design Thinking pyramid structure spanning Problem, Solution, and Implementation spaces.

> Preview: Core features are complete and functional. Suitable for adoption with the understanding that refinements may follow.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                  | Description                                                                                                                                           |
|-----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| **dt-coach**          | Design Thinking coach guiding teams through the 9-method HVE framework with Think/Speak/Empower                                                       |
| **dt-learning-tutor** | Design Thinking learning tutor providing structured curriculum, comprehension checks, and adaptive pacing                                             |
| **rpi-agent**         | User-selected RPI workflow wrapper for Research, Plan, Implement, Review, and Follow-up. Use when one task needs lifecycle coordination.              |
| **rpi-planner**       | Revise one assigned RPI plan phase and matching phase details within a shared planning artifact. Use when a parent needs bounded phase authoring.     |
| **rpi-researcher**    | Executes one delegated internal, external, or hybrid RPI research lane and progressively writes owned evidence. Use for independent research threads. |

### Prompts

| Name                                | Description                                                                                                     |
|-------------------------------------|-----------------------------------------------------------------------------------------------------------------|
| **dt-canonical-deck**               | Canonical deck workflow: opt-in offer, snapshot generation/refresh, and optional customer-card PowerPoint build |
| **dt-figma-export**                 | Export Design Thinking artifacts to a FigJam board or Figma Design file via the Figma MCP server                |
| **dt-handoff-implementation-space** | Compiles DT Methods 7-9 into research-ready input for rpi-research at the Implementation Space exit             |
| **dt-handoff-problem-space**        | Compiles DT Methods 1-3 into research-ready input for rpi-research at the Problem Space exit                    |
| **dt-handoff-solution-space**       | Compiles DT Methods 4-6 into research-ready input for rpi-research at the Solution Space exit                   |
| **dt-method-04-convergence**        | Theme discovery for Design Thinking Method 4c through philosophy-based clustering                               |
| **dt-method-04-ideation**           | Divergent ideation for Design Thinking Method 4b with constraint-informed solution generation                   |
| **dt-method-05-concepts**           | Concept articulation for Design Thinking Method 5b from brainstorming themes                                    |
| **dt-method-05-evaluation**         | Stakeholder alignment and three-lens evaluation for Design Thinking Method 5c                                   |
| **dt-method-06-building**           | Scrappy prototype building with fidelity enforcement for Design Thinking Method 6b                              |
| **dt-method-06-planning**           | Concept analysis and prototype approach design for Design Thinking Method 6a                                    |
| **dt-method-06-testing**            | Hypothesis-driven testing and constraint validation for Design Thinking Method 6c                               |
| **dt-method-next**                  | Assess DT project state and recommend next method with sequencing validation                                    |
| **dt-resume-coaching**              | Resume a Design Thinking coaching session - reads coaching state and re-establishes context                     |
| **dt-start-project**                | Start a new Design Thinking coaching project with state initialization and first coaching interaction           |

### Instructions

| Name                                                                        | Description                                                                                                                                                                                                                                                 |
|-----------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **.github/skills/design-thinking/dt-methods/references/dt-coach-telemetry** | Design Thinking Coach telemetry overlay applying telemetry-foundations vocabulary to DT session artifacts                                                                                                                                                   |
| **shared/hve-core-location**                                                | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name                       | Description                                                                                                                                                                                                                                                                                                           |
|----------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **dt-coaching-foundation** | Design Thinking coaching foundation knowledge: coach identity and philosophy, quality and fidelity constraints, method sequencing, coaching state schema, and the canonical deck workflow                                                                                                                             |
| **dt-curriculum**          | Design Thinking learning curriculum covering nine progressive modules across the full Problem, Solution, and Implementation Space methods plus a shared manufacturing reference scenario for teaching and practice                                                                                                    |
| **dt-methods**             | Design Thinking method coaching knowledge across all nine methods including per-method techniques, deep expertise, and industry context (energy, financial services, healthcare, manufacturing, nonprofit and social impact, pharmaceuticals and life sciences, professional services, public sector, retail and CPG) |
| **dt-rpi-integration**     | Design Thinking handoff knowledge for research-ready rpi-research inputs and DT-aware rpi-plan, rpi-implement, and rpi-review context                                                                                                                                                                                 |
| **rpi-implement**          | Execute an approved RPI plan, preserve amendments, and record evidence-led changes. Use when implementation is ready to begin or resume.                                                                                                                                                                              |
| **rpi-plan**               | Create evidence-based RPI plans and phase details from supplied context, research, drafts, and decisions. Use when implementation planning is needed.                                                                                                                                                                 |
| **rpi-plan-critique**      | Independently critique an RPI plan and phase details against supplied evidence without editing plan sources. Use when planning credibility needs a read-only assessment.                                                                                                                                              |
| **rpi-research**           | Research-only RPI playbook that gathers task evidence, writes dated research artifacts under .copilot-tracking/research/, and hands off planning-ready findings. Use when the user needs evidence, alternatives, or task framing first.                                                                               |
| **rpi-review**             | Compare RPI planning and implementation evidence, record review findings, and route follow-up work. Use when an implementation needs acceptance review.                                                                                                                                                               |
| **telemetry-foundations**  | Declarative OpenTelemetry-aligned telemetry vocabulary and instrumentation conventions for traces, metrics, logs, and PII handling                                                                                                                                                                                    |

<!-- END AUTO-GENERATED ARTIFACTS -->
