---
name: dt-rpi-integration
description: Design Thinking handoff knowledge for research-ready rpi-research inputs and DT-aware rpi-plan, rpi-implement, and rpi-review context
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  last_updated: "2026-07-15"
---

# Design Thinking → RPI Integration — Skill Entry

This skill is the entry point for Design Thinking to RPI integration knowledge.

The DT coach loads these references when Design Thinking coaching graduates into the RPI workflow. Every DT exit produces research-ready input for `rpi-research`. The retained downstream phases, `rpi-plan`, `rpi-implement`, and `rpi-review`, consume the resulting context. `RPI Agent` is the lifecycle wrapper when end-to-end coordination is needed; it does not replace `rpi-research` as the handoff target.

## Integration references

| Reference                                                        | When to load                                                                                          |
|------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| [Handoff contract](references/rpi-handoff-contract.md)           | Exit points, artifact schemas, RPI input contracts, and quality markers for lateral DT-to-RPI handoff |
| [Research context](references/rpi-research-context.md)           | DT-aware `rpi-research` framing for handoffs from the DT coach                                        |
| [Planning context](references/rpi-planning-context.md)           | DT-aware `rpi-plan` context for plans originating from DT artifacts                                   |
| [Implement context](references/rpi-implement-context.md)         | DT-aware `rpi-implement` context applying fidelity and stakeholder constraints                        |
| [Review context](references/rpi-review-context.md)               | DT-aware `rpi-review` criteria for evaluating Design Thinking artifacts                               |
| [Subagent handoff](references/subagent-handoff.md)               | Readiness assessment, artifact compilation, and validation via subagent dispatch                      |
| [Image prompt generation](references/image-prompt-generation.md) | Method 5 concept visualization with lo-fi prompt enforcement                                          |

## Skill layout

* `SKILL.md` — this file (skill entrypoint).
* `references/` — the DT-to-RPI integration reference documents.
  * `rpi-handoff-contract.md` — DT-to-RPI handoff contract: exit points, artifact schemas, RPI input contracts, and confidence markers.
  * `rpi-research-context.md` provides DT-aware `rpi-research` context.
  * `rpi-planning-context.md` provides DT-aware `rpi-plan` context.
  * `rpi-implement-context.md` provides DT-aware `rpi-implement` context.
  * `rpi-review-context.md` provides DT-aware `rpi-review` context.
  * `subagent-handoff.md` provides the subagent dispatch workflow for handoff readiness, compilation, and validation.
  * `image-prompt-generation.md` provides Method 5 lo-fi image prompt generation guidance.
