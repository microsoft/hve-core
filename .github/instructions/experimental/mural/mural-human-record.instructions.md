---
description: 'Mural is the durable record of human conversation; AI never silently authors decisions and AI contribution must remain visible somewhere durable.'
applyTo: '**/.github/agents/design-thinking/dt-coach.agent.md, **/.github/agents/rai-planning/rai-planner.agent.md, **/.github/agents/project-planning/ux-ui-designer.agent.md, **/.github/instructions/experimental/mural/**'
---

## Mural Human Record

The Mural board is the durable record of the human conversation that produced it. Every Layer B agent and prompt that touches a board operates *on* that record; it never silently substitutes for it.

## Core invariants

* The human authors `text`. AI never edits, paraphrases, or replaces sticky / textbox / shape `text`.
* AI contribution is always visible somewhere durable: either authored as a sticky on the board (facilitator mode) or recorded as the absence of any board change during the session (extractor mode).
* Silent AI authorship of a decision is forbidden in both modes. A "decision" is any sticky or note that asserts a fact, conclusion, action, or commitment for the human team.
* Every widget AI co-authors carries the reserved `authored-by-ai` tag (enforced by `_maybe_apply_author_tag` in the skill). Removing or stripping the reserved tag requires explicit `--force-reserved`.
* Any update or delete against a widget *not* tagged `authored-by-ai` requires `--require-author-tag` to be satisfied or `--force-human` to be passed; the skill emits `MuralHumanAuthoredProtected` (exit 77) otherwise.

## Mode parameter

Every Layer B invocation declares `mode ∈ {extractor, facilitator}` in its frontmatter or argument-hint. Mode is never inferred at runtime.

| Mode          | What AI may do on the board                                                                                                    | What AI may never do                                                     |
|---------------|--------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------|
| `extractor`   | Read widgets; apply tags / hyperlinks / parentId via writeback; create lineage marker prefixes on AI-authored scaffolding only | Author stickies during the live workshop; mutate human `text`            |
| `facilitator` | Author stickies that capture spoken dialogue; structure areas / lanes; tag and hyperlink                                       | Pre-author decisions before they are spoken; mutate other humans' `text` |

## Role-shape table

The role-shape selection drives which contract applies. Layer B agents must declare role-shape consistent with `mode`.

| Surface                    | Role-shape               | AI is …   | Mural's role                                |
|----------------------------|--------------------------|-----------|---------------------------------------------|
| Chat-native (no Mural)     | Author                   | Generator | N/A                                         |
| Group Mural, AI-after      | Analyst (extractor)      | Extractor | Frozen artifact; AI reads + writes metadata |
| Group Mural, AI-co-present | Structurer (facilitator) | Co-author | Live record; AI writes stickies in-room     |

## Recording AI contribution

When AI contributes content into Mural under facilitator mode:

1. The widget is created via the skill (never a sideband channel).
2. The reserved `authored-by-ai` tag is auto-attached.
3. A `hyperlink` back to the source artifact (prompt invocation log, transcript, planning file) is set on the widget when one exists.
4. The widget's `parentId` places it inside the area whose title classifies it.
5. If the widget instantiates a DT method or section, the lineage prefix `[dt:method=N section=NAME run=ID]` is prepended to the title via `_apply_lineage_prefix`.

## When mode cannot be honored

If a Layer B agent cannot satisfy the visibility invariant for the current request (for example, the user asks the AI to "just decide" without authoring anything), the agent stops and surfaces the conflict. It does not proceed with a silent decision.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
