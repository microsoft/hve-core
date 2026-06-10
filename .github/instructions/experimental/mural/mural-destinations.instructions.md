---
description: 'Open destination registry for Mural extractor writeback: registered adapters, intent axis, and per-destination loop-closure metrics.'
applyTo: '**/.copilot-tracking/mural/**, **/.github/instructions/experimental/mural/destinations/**, **/.github/agents/design-thinking/dt-coach.agent.md, **/.github/agents/rai-planning/rai-planner.agent.md, **/.github/agents/project-planning/ux-ui-designer.agent.md'
---

## Mural Destinations

Action-item destinations are an open registry of named adapters. The extractor core does not change when a new destination is added; the new adapter is registered in the data file and the writeback applies the registered tag.

## Registry data file

The authoritative list of adapters lives in [.github/instructions/experimental/mural/destinations/registry.yml](destinations/registry.yml). Layer B agents read it at invocation time. Do not hardcode the destination set into agent or prompt logic.

Each registry entry has:

| Field          | Meaning                                                               |
|----------------|-----------------------------------------------------------------------|
| `id`           | Adapter identifier; becomes the `destination:<id>` reserved tag value |
| `intent`       | Intent axis (`capture`, `synthesize`, `action`, `archive`)            |
| `target`       | Glob describing the artifact the adapter writes to                    |
| `loop_closure` | Description of how items committed via this adapter return to source  |

## Intent axis (Decision D5)

Every extracted action item carries `intent ∈ {create, mutate, append, no-op}`. The (destination, intent) pair selects the adapter:

| Intent   | Adapter behavior                                                                    |
|----------|-------------------------------------------------------------------------------------|
| `create` | Adapter creates a new artifact (work item, ADR, instructions file, deck section).   |
| `mutate` | Adapter modifies an existing artifact identified by `hyperlink` or query.           |
| `append` | Adapter appends to a living document section identified by `hyperlink` or anchor.   |
| `no-op`  | Adapter records the rationale for not actioning (audit-only, `unactioned` adapter). |

`intent` is required. Slot 2 elicits it from the user during adjudication when the board structure does not make it visually obvious. The extractor never guesses intent.

## Loop-closure metrics (Decision D4 + Pattern I)

Loop closure is parameterized per destination. Each adapter declares its `loop_closure` in `registry.yml`. Examples:

* `backlog-item` → state transition observed in ADO/Jira/GitHub.
* `instructions-file` → manual or sample-based confirmation that downstream code follows the instruction.
* `adr` → status check (`Accepted` and not `Superseded`).
* `living-document` → last-updated within the configured freshness window.
* `powerpoint-deck` → export confirmation (downstream telemetry deferred).
* `next-workshop-seed` → artifact presence check in the downstream workshop's seed bundle.
* `unactioned` → rationale survived review (no-op with audit).

Aggregate "loop closure rate" weighs each destination equally unless a workshop family overrides the weights in its own configuration.

## Reserved tag mapping

The writeback applies one reserved tag per writeback channel:

* `destination:<id>` — adapter selection.
* `intent:<create|mutate|append|no-op>` — intent.
* `lifecycle:committed` — adapter accepted the write and returned an external identifier.
* `lifecycle:loop-closed` — loop-closure check passed.

Reserved-tag protection rules in [mural-writeback-hygiene.instructions.md](mural-writeback-hygiene.instructions.md) apply.

## Adding a new destination

1. Add an entry to `destinations/registry.yml` with `id`, `intent`, `target`, and `loop_closure`.
2. Implement the adapter as a handoff target on the relevant Slot 2 agent (work item creation prompt, ADR creation prompt, instructions writer, etc.).
3. Update the workshop family's Slot 2 agent `handoffs` frontmatter to include the new adapter.
4. Do not modify extractor core logic.

## v1 retro coverage

The retro v1 wedge ships with the first three adapters (`backlog-item`, `instructions-file`, `adr`) plus the `unactioned` sink. Other adapters in the registry (`living-document`, `powerpoint-deck`, `next-workshop-seed`) are reserved for subsequent workshop families.

## Override file

Repos that need to hide or override registry entries can supply `destinations/dt-sections.yml` (deep-merge override; not populated by default). Agents read both files and merge entries by `id`.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
