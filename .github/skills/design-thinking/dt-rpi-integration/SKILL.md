---
name: dt-rpi-integration
description: Design Thinking to RPI handoff knowledge covering the DT-to-RPI handoff contract, DT-aware research/planning/implement/review contexts, subagent handoff workflow, and Method 5 image prompt generation
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  last_updated: "2026-02-14"
---

# Design Thinking → RPI Integration — Skill Entry

This `SKILL.md` is the **entrypoint** for Design Thinking to RPI integration knowledge.

The dt-coach loads these references at handoff points where Design Thinking coaching graduates into the RPI (Research → Plan → Implement) workflow. The RPI agents and their subagents consume the same references to interpret DT-origin artifacts, apply DT-aware context, and validate handoffs.

## Integration references

| Reference                                                        | When to load                                                                                          |
|------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| [Handoff contract](references/rpi-handoff-contract.md)           | Exit points, artifact schemas, RPI input contracts, and quality markers for lateral DT-to-RPI handoff |
| [Research context](references/rpi-research-context.md)           | DT-aware Task Researcher framing for handoffs from the DT coach                                       |
| [Planning context](references/rpi-planning-context.md)           | DT-aware Task Planner context for plans originating from DT artifacts                                 |
| [Implement context](references/rpi-implement-context.md)         | DT-aware Task Implementor context applying fidelity and stakeholder constraints                       |
| [Review context](references/rpi-review-context.md)               | DT-aware Task Reviewer criteria for evaluating Design Thinking artifacts                              |
| [Subagent handoff](references/subagent-handoff.md)               | Readiness assessment, artifact compilation, and validation via subagent dispatch                      |
| [Image prompt generation](references/image-prompt-generation.md) | Method 5 concept visualization with lo-fi prompt enforcement                                          |

## Skill layout

* `SKILL.md` — this file (skill entrypoint).
* `references/` — the DT-to-RPI integration reference documents.
  * `rpi-handoff-contract.md` — DT-to-RPI handoff contract: exit points, artifact schemas, RPI input contracts, and confidence markers.
  * `rpi-research-context.md` — DT-aware Task Researcher context.
  * `rpi-planning-context.md` — DT-aware Task Planner context.
  * `rpi-implement-context.md` — DT-aware Task Implementor context.
  * `rpi-review-context.md` — DT-aware Task Reviewer context.
  * `subagent-handoff.md` — subagent dispatch workflow for handoff readiness, compilation, and validation.
  * `image-prompt-generation.md` — Method 5 lo-fi image prompt generation guidance.
