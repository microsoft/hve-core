---
name: dt-coaching-foundation
description: "Design Thinking coaching foundation knowledge: coach identity and philosophy, quality and fidelity constraints, method sequencing, coaching state schema, and the canonical deck workflow"
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  last_updated: "2026-02-14"
---

# DT Coaching Foundation — Skill Entry

This `SKILL.md` is the **entrypoint** for the Design Thinking coaching foundation knowledge.

The dt-coach agent loads this skill at session start and during a coaching session to
ground coaching behavior in a stable identity, enforce quality and fidelity expectations,
navigate method transitions, persist and recover session state, and run the opt-in
canonical deck workflow. The foundation knowledge stays constant across all nine
Design Thinking methods.

## Foundation references

Load the reference that matches the current coaching moment.

| Reference                                                   | When to load                                                                                                                               |
|-------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------|
| [coaching-identity.md](references/coaching-identity.md)     | At session start and throughout — establishes coach identity, Think/Speak/Empower philosophy, boundaries, and the Progressive Hint Engine. |
| [quality-constraints.md](references/quality-constraints.md) | Before any artifact generation — enforces fidelity rules, anti-polish stance, and quality-by-space expectations.                           |
| [method-sequencing.md](references/method-sequencing.md)     | At method transitions and space boundaries — guides the nine-method sequence, transition protocol, and non-linear iteration.               |
| [coaching-state.md](references/coaching-state.md)           | For persistence and session recovery — defines the coaching state schema, update rules, and recovery protocol.                             |
| [canonical-deck.md](references/canonical-deck.md)           | For opt-in canonical deck and customer-card generation — governs activation, offer points, and the PowerPoint build branch.                |

## Skill layout

* `SKILL.md` — this file (skill entrypoint).
* `references/` — the DT coaching foundation knowledge documents.
  * `coaching-identity.md` — coach identity, philosophy, and interaction conventions.
  * `quality-constraints.md` — fidelity rules and quality standards across all methods.
  * `method-sequencing.md` — method transitions, space boundaries, and iteration patterns.
  * `coaching-state.md` — coaching state schema, file conventions, and recovery protocol.
  * `canonical-deck.md` — opt-in canonical deck and customer-card workflow.
