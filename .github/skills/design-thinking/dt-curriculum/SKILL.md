---
name: dt-curriculum
description: Design Thinking learning curriculum covering nine progressive modules across the full Problem, Solution, and Implementation Space methods plus a shared manufacturing reference scenario for teaching and practice
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  last_updated: "2026-02-14"
---

# DT Curriculum — Skill Entry

This `SKILL.md` is the **entrypoint** for the Design Thinking learning curriculum.

The dt-learning-tutor agent loads this skill to teach Design Thinking concepts, run
comprehension checks, and assign practice exercises. The curriculum spans nine
progressive modules — one per Design Thinking method — and a shared manufacturing
reference scenario that threads through every module so learners build on consistent
context as they advance from the Problem Space to the Implementation Space.

## Curriculum references

Load the module that matches the method the learner is studying. Load the manufacturing
scenario alongside any module that uses scenario-based checks or exercises.

| Reference                                                                               | When to load                                                                          |
|-----------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| [curriculum-01-scoping.md](references/curriculum-01-scoping.md)                         | Teaching Method 1: Scope Conversations (Problem Space).                               |
| [curriculum-02-research.md](references/curriculum-02-research.md)                       | Teaching Method 2: Design Research (Problem Space).                                   |
| [curriculum-03-synthesis.md](references/curriculum-03-synthesis.md)                     | Teaching Method 3: Synthesis (Problem Space).                                         |
| [curriculum-04-brainstorming.md](references/curriculum-04-brainstorming.md)             | Teaching Method 4: Brainstorming (Solution Space).                                    |
| [curriculum-05-concepts.md](references/curriculum-05-concepts.md)                       | Teaching Method 5: User Concepts (Solution Space).                                    |
| [curriculum-06-prototypes.md](references/curriculum-06-prototypes.md)                   | Teaching Method 6: Low-Fidelity Prototypes (Solution Space).                          |
| [curriculum-07-testing.md](references/curriculum-07-testing.md)                         | Teaching Method 7: High-Fidelity Prototypes (Implementation Space).                   |
| [curriculum-08-iteration.md](references/curriculum-08-iteration.md)                     | Teaching Method 8: User Testing (Implementation Space).                               |
| [curriculum-09-handoff.md](references/curriculum-09-handoff.md)                         | Teaching Method 9: Iteration at Scale (Implementation Space).                         |
| [curriculum-scenario-manufacturing.md](references/curriculum-scenario-manufacturing.md) | Alongside any module using scenario-based comprehension checks or practice exercises. |

## Skill layout

* `SKILL.md` — this file (skill entrypoint).
* `references/` — the DT curriculum knowledge documents.
  * `curriculum-01-scoping.md` through `curriculum-09-handoff.md` — one module per Design Thinking method.
  * `curriculum-scenario-manufacturing.md` — shared factory-floor reference scenario used across all nine modules.
