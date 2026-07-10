---
name: dt-methods
description: Design Thinking method coaching knowledge across all nine methods including per-method techniques, deep expertise, and industry context (energy, financial services, healthcare, manufacturing, nonprofit and social impact, pharmaceuticals and life sciences, professional services, public sector, retail and CPG)
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  last_updated: "2026-05-31"
---

# Design Thinking Methods Skill

Entrypoint for Design Thinking method coaching knowledge. The `dt-coach` agent loads the method reference matching the active method in coaching state, the matching deep reference when advanced technique is needed, and the industry reference when an industry context applies.

## How to use this skill

* Read the method reference for the method currently active in coaching state to ground day-to-day coaching.
* Read the matching deep reference when the conversation needs advanced facilitation, recovery techniques, or expert frameworks beyond the core method guidance.
* Read the industry reference when the team has identified one of the nine covered industries as their context, and weave its vocabulary, constraints, and empathy tools into method-specific guidance.
* Read [dt-coach-telemetry.instructions.md](references/dt-coach-telemetry.instructions.md) when DT session artifacts need observable telemetry expectations grounded in `telemetry-foundations`.

## Method references

| Method | Name                     | Core reference                                                          | Deep reference                                    |
|--------|--------------------------|-------------------------------------------------------------------------|---------------------------------------------------|
| 1      | Scope Conversations      | [method-01-scope.md](references/method-01-scope.md)                     | [method-01-deep.md](references/method-01-deep.md) |
| 2      | Design Research          | [method-02-research.md](references/method-02-research.md)               | [method-02-deep.md](references/method-02-deep.md) |
| 3      | Input Synthesis          | [method-03-synthesis.md](references/method-03-synthesis.md)             | [method-03-deep.md](references/method-03-deep.md) |
| 4      | Brainstorming            | [method-04-brainstorming.md](references/method-04-brainstorming.md)     | [method-04-deep.md](references/method-04-deep.md) |
| 5      | User Concepts            | [method-05-concepts.md](references/method-05-concepts.md)               | [method-05-deep.md](references/method-05-deep.md) |
| 6      | Low-Fidelity Prototypes  | [method-06-lofi-prototypes.md](references/method-06-lofi-prototypes.md) | [method-06-deep.md](references/method-06-deep.md) |
| 7      | High-Fidelity Prototypes | [method-07-hifi-prototypes.md](references/method-07-hifi-prototypes.md) | [method-07-deep.md](references/method-07-deep.md) |
| 8      | User Testing             | [method-08-testing.md](references/method-08-testing.md)                 | [method-08-deep.md](references/method-08-deep.md) |
| 9      | Iteration at Scale       | [method-09-iteration.md](references/method-09-iteration.md)             | [method-09-deep.md](references/method-09-deep.md) |

## Industry context references

Load the matching reference when the team identifies its industry context.

| Reference                                                                                         | When to load                                                                                      |
|---------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------|
| [industry-energy.md](references/industry-energy.md)                                               | Energy-sector vocabulary, constraints, empathy tools, and reference scenario.                     |
| [industry-financial-services.md](references/industry-financial-services.md)                       | Financial services vocabulary, constraints, empathy tools, and reference scenario.                |
| [industry-healthcare.md](references/industry-healthcare.md)                                       | Healthcare vocabulary, constraints, empathy tools, and reference scenario.                        |
| [industry-manufacturing.md](references/industry-manufacturing.md)                                 | Manufacturing vocabulary, constraints, empathy tools, and reference scenario.                     |
| [industry-nonprofit-social-impact.md](references/industry-nonprofit-social-impact.md)             | Nonprofit and social impact vocabulary, constraints, empathy tools, and reference scenario.       |
| [industry-pharmaceuticals-life-sciences.md](references/industry-pharmaceuticals-life-sciences.md) | Pharmaceuticals and life sciences vocabulary, constraints, empathy tools, and reference scenario. |
| [industry-professional-services.md](references/industry-professional-services.md)                 | Professional services vocabulary, constraints, empathy tools, and reference scenario.             |
| [industry-public-sector.md](references/industry-public-sector.md)                                 | Public sector and government vocabulary, constraints, empathy tools, and reference scenario.      |
| [industry-retail-cpg.md](references/industry-retail-cpg.md)                                       | Retail and consumer goods vocabulary, constraints, empathy tools, and reference scenario.         |

## Skill layout

```text
.
├── SKILL.md
└── references/
    ├── method-01-scope.md
    ├── method-01-deep.md
    ├── method-02-research.md
    ├── method-02-deep.md
    ├── method-03-synthesis.md
    ├── method-03-deep.md
    ├── method-04-brainstorming.md
    ├── method-04-deep.md
    ├── method-05-concepts.md
    ├── method-05-deep.md
    ├── method-06-lofi-prototypes.md
    ├── method-06-deep.md
    ├── method-07-hifi-prototypes.md
    ├── method-07-deep.md
    ├── method-08-testing.md
    ├── method-08-deep.md
    ├── method-09-iteration.md
    ├── method-09-deep.md
    ├── industry-energy.md
    ├── industry-financial-services.md
    ├── industry-healthcare.md
    ├── industry-manufacturing.md
    ├── industry-nonprofit-social-impact.md
    ├── industry-pharmaceuticals-life-sciences.md
    ├── industry-professional-services.md
    ├── industry-public-sector.md
    ├── industry-retail-cpg.md
    └── dt-coach-telemetry.instructions.md
```

