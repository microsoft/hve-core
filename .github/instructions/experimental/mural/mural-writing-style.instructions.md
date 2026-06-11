---
description: 'Asymmetric writing style for Mural: outbound (writing into Mural) is sticky-concise; inbound (extracting from Mural) is context-hydrated.'
applyTo: '**/.copilot-tracking/mural/**, **/.github/skills/experimental/mural/**, **/.github/agents/design-thinking/dt-coach.agent.md, **/.github/agents/rai-planning/rai-planner.agent.md, **/.github/agents/project-planning/ux-ui-designer.agent.md'
---

## Mural Writing Style

The writing style for Mural is asymmetric. Content moving *into* Mural is constrained by the medium (room-readable stickies). Content moving *out of* Mural is hydrated with the context the medium dropped. Pattern J (role-shape) and the M2 Q3 contract govern both directions.

## Outbound — writing into Mural

Stickies and textboxes are a workshop medium, not a document medium. AI-authored content into Mural follows these limits:

| Surface                              | Limit                                               |
|--------------------------------------|-----------------------------------------------------|
| Sticky text                          | ≤8 words; ≤25 characters per tag                    |
| Textbox body — AI-authored summary   | ≤25 words                                           |
| Textbox body — verbatim user content | No word cap; soft-wrap lines around 1024 characters |
| Area / frame title                   | ≤5 words                                            |
| Tag text                             | ≤25 characters (API hard cap)                       |
| Hyperlink length                     | ≤1024 characters (API hard cap)                     |

Style rules:

* One idea per widget. Never pack multiple thoughts into a single sticky.
* Plain language. No jargon stacking. No bullet lists inside a single sticky.
* No Markdown formatting characters in `text`. Mural renders plain strings.
* Use embedded `\n` as the canonical soft line break for bullets or steps inside one textbox, for example `"* item one\n* item two"`.
* Active voice and present tense for actions ("ship docs", not "documentation will be shipped").
* Title areas as nouns or short noun phrases (not sentences).
* Lineage prefix `[dt:method=N section=NAME run=ID]` is prepended automatically by `_apply_lineage_prefix`; do not author it manually.

## Inbound — extracting from Mural

The downstream consumer (work-item creation, RAI capture, retro action tracking, ADR draft) must not need to round-trip to Mural to disambiguate an extracted widget. Each extracted record carries:

* Full `parentId` chain: area title, room name, mural name, workspace name.
* All `tags[]` resolved to their text (not raw IDs).
* `hyperlink` if set, plus a stable widget URL back to source.
* Spatial neighbors when the destination depends on grouping (affinity clusters, lane-based retros).
* Lineage marker parsed via `_parse_lineage_prefix` into `{method, section, run_id}` when present.
* Author attribution: whether the widget carries the reserved `authored-by-ai` tag.

Hydration is multi-call (no `expand` / `include` in the Mural API). Use the widget context read helpers for single widgets and batched siblings; both cache the mural, room, workspace, and parent-area chain per invocation.

## Hydration depth heuristic

| Destination type     | Required hydration                                                              |
|----------------------|---------------------------------------------------------------------------------|
| `backlog-item`       | Parent area title (becomes work-item area path); tags; hyperlink; widget URL    |
| `instructions-file`  | Parent area title; tags; widget URL; spatial neighbors (for cluster context)    |
| `adr`                | Parent area title; tags; widget URL; spatial neighbors (for option set context) |
| `living-document`    | Parent area title; tags; widget URL; freshness window context                   |
| `powerpoint-deck`    | Parent area title; tags; widget URL; image-asset URLs for any embedded media    |
| `next-workshop-seed` | Full chain plus lineage marker; preserves run_id for downstream traceability    |
| `unactioned`         | Parent area title; tags; widget URL; rationale captured by Slot 2 adjudication  |

## Outbound–inbound asymmetry rationale

Stickies are shorthand for a conversation that happened in the room. Outbound writing protects the medium (room readability). Inbound reading promotes that shorthand into a structured artifact and must restore the conversational context the shorthand assumed. Under-hydration on inbound silently destroys the workshop's value; over-stuffing on outbound silently destroys the workshop itself.

## Language

* English-only for tag text and reserved-tag prefixes.
* Sticky text follows the workshop's working language; the skill does not translate.
* No emoji in tag text (emoji in sticky text is allowed when the workshop authored it).

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
