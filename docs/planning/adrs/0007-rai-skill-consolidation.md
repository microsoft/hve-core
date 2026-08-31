---
id: "0007"
title: "Consolidate RAI knowledge into skills consumed by RAI Planner and RAI Reviewer"
description: "Consolidate RAI domain guidance into shared rai-standards and rai-planner skills instead of inline per-agent instructions files."
author: "HVE Core Maintainers"
ms.date: 2026-06-17
ms.topic: reference
status: proposed
proposed_date: 2026-06-17
accepted_date: null
effort: M
deciders:
  - "HVE-Core maintainers"
consulted:
  - "RAI domain owners"
informed:
  - "HVE-Core contributors"
affected_components:
  - ".github/skills/rai/rai-standards/SKILL.md"
  - ".github/skills/project-planning/rai-planner/SKILL.md"
  - ".github/agents/rai-planning/rai-reviewer.agent.md"
  - ".github/agents/rai-planning/subagents/rai-skill-assessor.agent.md"
  - ".github/instructions/rai-planning/rai-license-posture.instructions.md"
  - ".github/instructions/hve-core/licensing-posture.instructions.md"
tags:
  - "rai"
  - "skills"
  - "architecture"
supersedes: null
superseded-by: null
related: []
decisionMetadata:
  driverToTriggerMap:
    "Single source of truth for RAI standards": "consolidation-removes-per-agent-duplication"
    "Reuse across both the RAI Planner and the RAI Reviewer": "shared-skill-load-by-both-consumers"
    "Cleaner licensing-posture isolation from agent orchestration": "dedicated-licensing-posture-overlay"
    "Evolve RAI guidance without editing agent bodies": "edit-skills-not-agents"
---

## Context

The RAI domain guidance in hve-core historically lived in a set of legacy
`rai-*.instructions.md` files. As the RAI capability grew to span both an
authoring agent (RAI Planner) and a review agent (RAI Reviewer, with its
`rai-skill-assessor` subagent), that guidance needed to be shared by more
than one consumer. Carrying the standards inline per agent meant the same
knowledge was duplicated across agent bodies and tended to drift. How should
RAI domain knowledge be structured so it is authored once, consumed by both
the Planner and the Reviewer, and keeps its licensing posture isolated from
agent orchestration logic?

> Source: `https://github.com/microsoft/hve-core/pull/2062`, the refactor that introduces the RAI skill pair and removes the legacy instructions files.
> Source: `https://github.com/microsoft/hve-core/issues/2058`, the issue this decision resolves.
> Source: `.github/instructions/rai-planning/rai-license-posture.instructions.md`, the licensing-posture overlay that the consolidated skills keep isolated from agent orchestration.

## Decision Drivers

* Single source of truth for RAI standards
* Reuse across both the RAI Planner and the RAI Reviewer
* Cleaner licensing-posture isolation from agent orchestration
* Evolve RAI guidance without editing agent bodies

## Considered Options

* Option A: Skill-based consolidation: move RAI guidance into shared `rai-standards` and `rai-planner` skills consumed on demand by both agents.
* Option B: Inline per-agent `rai-*.instructions.md`: keep guidance embedded in each agent's instructions surface.
* Option C: Single shared instructions file referenced via `#file:` from each agent.

## Decision Outcome

Chosen option: **Option A: Skill-based consolidation**.

> In the context of structuring and consuming RAI domain knowledge across the
> RAI Planner and Reviewer, facing the tension between a single source of truth
> and avoiding per-agent duplication, we decided for consolidating RAI guidance
> into shared `rai-standards` and `rai-planner` skills and against
> inline per-agent `rai-*.instructions.md` files or a single shared instructions
> file, to achieve reuse, maintainability, and licensing-posture isolation,
> accepting explicit skill-load dependencies and a larger artifact surface
> shipped as experimental.

Option B is rejected because embedding the standards in each agent duplicates
the guidance and lets the Planner and Reviewer copies drift apart. Option C is
rejected because referencing one monolithic instructions file from every agent
couples all consumers to a single file and forgoes the on-demand packaging,
metadata, and licensing isolation that the skill format provides.

| Decision Driver                                              | Option A: Skills                       | Option B: Inline instructions | Option C: Shared instructions file      |
|--------------------------------------------------------------|----------------------------------------|-------------------------------|-----------------------------------------|
| Single source of truth for RAI standards                     | Strong: one skill pair authored once   | Weak: copy per agent          | Moderate: one file, no packaging        |
| Reuse across both the RAI Planner and the RAI Reviewer       | Strong: loaded on demand by both       | Weak: duplicated bodies       | Moderate: shared via `#file:` coupling  |
| Cleaner licensing-posture isolation from agent orchestration | Strong: dedicated instructions overlay | Weak: mixed into agent logic  | Weak: mixed into one monolith           |
| Evolve RAI guidance without editing agent bodies             | Strong: edit skills only               | Weak: edit every agent        | Moderate: edit file, all agents coupled |

### Consequences

* Good, because RAI standards have a single source of truth that both the Planner and Reviewer consume, eliminating duplication and drift.
* Good, because the same skills are reused across the RAI Planner and RAI Reviewer (plus the `rai-skill-assessor` subagent) without copy-paste.
* Good, because licensing posture is isolated in dedicated instructions, separate from agent orchestration logic.
* Good, because RAI guidance can evolve by editing the skills, without touching agent bodies.
* Bad, because agents must explicitly load the skills, introducing skill-discovery and load-failure risk that inline guidance did not have.
* Bad, because the artifact surface is larger (two skills plus an agent and a subagent) instead of a single instructions file.
* Bad, because the artifacts ship at `maturity: experimental` and will churn while the format stabilizes.
* Neutral, because changes to the RAI skills require collection and plugin regeneration to propagate to packaged outputs.

## Risks and Mitigations

* Risk: agents fail to discover or load the consolidated skills, leaving RAI guidance unavailable at runtime. Mitigation: declare the required skill loads explicitly in each consuming agent and treat a load failure as a hard stop rather than silent degradation.
* Risk: the larger artifact surface (two skills, an agent, and a subagent) increases maintenance and review burden. Mitigation: ship the artifacts at `maturity: experimental` and gate wider adoption on format stabilization.
* Risk: licensing-posture guidance drifts from the standards it governs. Mitigation: keep the posture overlay in dedicated instructions referenced by the skills, separate from agent orchestration logic.

## Rollback / Exit Strategy

If the skill-based approach proves unmaintainable, revert to per-agent
instructions by reinstating the legacy `rai-*.instructions.md` content inside
each consuming agent and removing the skill-load declarations. The skills are
additive and removable: deleting them and regenerating collections and plugins
restores the prior inline arrangement without data loss.

## Affected Components

* .github/skills/rai/rai-standards/SKILL.md
* .github/skills/project-planning/rai-planner/SKILL.md
* .github/agents/rai-planning/rai-reviewer.agent.md
* .github/agents/rai-planning/subagents/rai-skill-assessor.agent.md
* .github/instructions/rai-planning/rai-license-posture.instructions.md
* .github/instructions/hve-core/licensing-posture.instructions.md

## More Information

* RAI standards skill: `.github/skills/rai/rai-standards/SKILL.md`
* RAI Planner skill: `.github/skills/project-planning/rai-planner/SKILL.md`
* RAI Reviewer agent: `.github/agents/rai-planning/rai-reviewer.agent.md`
* RAI skill-assessor subagent: `.github/agents/rai-planning/subagents/rai-skill-assessor.agent.md`
* RAI licensing-posture overlay: `.github/instructions/rai-planning/rai-license-posture.instructions.md`
* Repository licensing posture: `.github/instructions/hve-core/licensing-posture.instructions.md`

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
