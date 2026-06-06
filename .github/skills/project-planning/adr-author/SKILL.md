---
name: adr-author
description: Authoring skill for Architecture Decision Records (ADRs) supporting capture, from-planner-handoff, and adopt-template entry modes with selectable Y-Statement or MADR v4.0.0 output templates, supersession lineage, and ASR trigger evaluation - Brought to you by microsoft/hve-core.
---

# adr-author

## Overview

This skill encodes the per-phase authoring conventions for Architecture Decision Records consumed by the ADR Creator agent. It supports three entry modes and two output templates and converges all of them at the Govern phase, where the final ADR file is written and lineage is updated atomically.

Entry modes (`state.entryMode`):

- **capture** — Interactive authoring driven by user answers to Frame and Decide questions.
- **from-planner-handoff** — Entry from an upstream planner (Security, RAI, SSSC) with pre-populated Frame fields. Frame still requires user confirmation before exit.
- **adopt-template** — One-time setup mode that ingests a project's pre-existing ADR template and emits both the first ADR and a committed `.adr-config.yml`.

Output templates (`state.outputTemplate`):

- **y-statement** — Compact Y-Statement-shaped ADR for low-stakes or reversible decisions. Compressed Frame; ASR triggers optional.
- **madr-v4** — Long-form MADR v4.0.0 ADR for architecturally significant decisions. ASR trigger evaluation required during Frame.

Entry mode and output template are independent: a `from-planner-handoff` session can target either `y-statement` or `madr-v4`, and a `capture` session can do the same. The `adopt-template` mode produces output shaped by the user's normalized template.

Lifecycle at a glance:

| Mode                   | Phase sequence                                        | Output                                              |
|------------------------|-------------------------------------------------------|-----------------------------------------------------|
| `capture`              | Frame → Decide → Govern                               | Shaped by `outputTemplate` (y-statement or madr-v4) |
| `from-planner-handoff` | Frame (confirm pre-populated) → Decide → Govern       | Shaped by `outputTemplate` (y-statement or madr-v4) |
| `adopt-template`       | Ingest → Normalize → Derive Questions → Fill → Govern | First ADR + `.adr-config.yml` per the BYO contract  |

The state machine, hard exit gates, autonomy tiers (`manual`, `partial`, `full`), and the canonical `state.json` schema are defined in `adr-identity.instructions.md`. This skill provides the authoring activities and artifact contracts; it does not redefine the state machine.

## Frame

Activities:

- **Scope** — capture the decision in one or two sentences; bound it to a single project.
- **Decision-makers** — record `deciders`, `consulted`, `informed` (RACI-aligned).
- **Drivers** — list decision drivers (functional needs, business goals).
- **Constraints** — list non-negotiables (regulatory, platform, contractual, time).
- **ASR trigger evaluation** — required when `state.outputTemplate == 'madr-v4'`. Evaluate triggers against the rubric in `adr-standards.instructions.md` and record results in `state.asrTriggers[]`. Defer the rubric and full taxonomy to that file and to `references/asr-trigger-taxonomy.md`.
- **Diagram-format prompt** — when `state.userPreferences.diagramFormat` is unset, ask the user `ascii` or `mermaid` and persist the answer to `state.userPreferences.diagramFormat`. Required before Frame can exit.

Hard exit gate (restated from `adr-identity.instructions.md`):

> The Frame phase cannot advance without all of the following recorded: scope statement, deciders list, decision drivers, ASR triggers determination (when `outputTemplate == 'madr-v4'`), and `userPreferences.diagramFormat`. The user must confirm the Frame summary before advancing.

Output artifacts:

- Frame section of the in-progress ADR draft (working draft only; not yet written to disk).
- Updated `state.json` fields: `scope`, `deciders`, `consulted`, `informed`, `drivers`, `constraints`, `asrTriggers` (when `outputTemplate == 'madr-v4'`), `userPreferences.diagramFormat`.

## Decide

Activities:

- **Option enumeration** — at least two considered options. A single-option ADR is rejected at this gate.
- **Evaluation criteria** — score each option against the drivers and constraints captured in Frame.
- **Decision outcome selection** — name the chosen option and articulate the rationale.
- **Consequences** — document positive, negative, and neutral consequences. Negative consequences are not optional; an ADR with no documented downside is rejected at this gate.

Y-Statement assembly (when `state.outputTemplate == 'y-statement'`):

- Compose the chosen option using the verbatim six-slot formula in `templates/y-statement.md`:

  > In the context of (USE CASE), facing (CONCERN), we decided for (OPTION) and against (ALTERNATIVES), to achieve (QUALITY), accepting (DOWNSIDE).

- The Y-Statement is the entire Decide output for the `y-statement` template. The full MADR options table is omitted.

Hard exit gate:

> The Decide phase cannot advance without at least two considered options, the chosen option, and the decision rationale recorded. The user must confirm the Decide summary before advancing.

## Govern

This phase converges all three entry modes and is the only phase that writes ADR files to disk.

Activities:

1. **MADR v4 frontmatter assembly** — render the ADR frontmatter from `templates/madr-v4.md`. The template is reproduced verbatim from MADR v4.0.0 (CC0); see `references/standards-excerpts.md` for attribution. Merge `templates/madr-v4-frontmatter-overlay.md` on top to inject hve-core extension fields (`id`, `deciders`, `tags`, `supersedes`, `superseded-by`, `related`, `asr_triggers`) without modifying the verbatim upstream template (GP-17).
2. **Diagram render** — based on `state.userPreferences.diagramFormat`, embed the diagram body from either `templates/diagram-ascii.md` or `templates/diagram-mermaid.md`. Skill callers do not branch on platform; the template selection is purely data-driven.
3. **Lineage validation** — apply the six supersession rules summarized below; full text is in `references/lineage-rules.md`.
4. **Frontmatter validation** — invoke `scripts/validate_frontmatter.py` against the staged ADR file. The script returns a non-zero exit code on schema or enum violations and is the single authority for frontmatter shape.
5. **Lineage allocator** — invoke `scripts/update_lineage.py` to mutate `.adr-config.yml`. The allocator is the only writer of `last_decision_id`. Manual edits to `last_decision_id` are forbidden.
6. **Final write** — write the ADR to `docs/planning/adrs/{NNNN}-{slug}.md`. The path is derived from the allocator-issued `NNNN` and the slugified ADR title.
7. **Handoff trigger** — emit the dual-format (ADO + GitHub) work items per `adr-handoff.instructions.md`. This skill stops at handoff emission; routing is the agent's responsibility.

Govern uses the autonomy and disclaimer banners required by `adr-identity.instructions.md` and `shared/disclaimer-language.instructions.md`. Do not duplicate those texts here; load them at runtime.

## Supersession Lineage Rules (Summary)

Brief enumeration. Full normative text and edge cases live in `references/lineage-rules.md`.

1. `supersedes` and `superseded-by` are each a scalar string or `null`.
2. Single-parent supersession — a given ADR has at most one `superseded-by`.
3. Status transition — the superseding ADR's `status` becomes `accepted`; the superseded ADR's `status` becomes `superseded`.
4. Lineage updates are atomic — both ADR files MUST be updated in the same Govern phase.
5. The lineage allocator (`scripts/update_lineage.py`) is the single writer of `last_decision_id` in `.adr-config.yml`; manual edits are forbidden.

## Status Taxonomy

ADR `status` is one of six closed values. Full definitions and lifecycle transitions live in `adr-standards.instructions.md`.

- `proposed` — under active drafting; not yet decided.
- `accepted` — decision adopted; current authority for the scope.
- `rejected` — considered and declined; retained for historical context.
- `deprecated` — no longer recommended but not yet replaced.
- `superseded` — replaced by a newer ADR via the lineage rules below.
- `withdrawn` — proposal withdrawn before decision.

## ASR Trigger Catalog (Summary)

ASR (Architecturally Significant Requirement) triggers are evaluated only when `state.outputTemplate == 'madr-v4'`. The closed enum has eight values:

- `cost`
- `performance`
- `security`
- `compliance`
- `availability`
- `scalability`
- `maintainability`
- `evolvability`

The trigger rubric, evaluation prompts, and example mappings are defined in `adr-standards.instructions.md` and elaborated in `references/asr-trigger-taxonomy.md`. Do not introduce trigger values outside the closed enum.

## Adopt-Template Lifecycle

Five-step pointer. Full lifecycle, including GP-13 (the `.adr-config.yml` schema and the 2-layer config resolution), lives in `adr-byo-template.instructions.md`.

1. **Ingest** — accept the user's existing ADR template file or template directory.
2. **Normalize** — invoke `scripts/normalize_template.py` to convert the template into the canonical ADR frontmatter and section structure.
3. **Derive Questions** — generate the Frame and Decide question set from the normalized template's required fields.
4. **Fill** — execute the derived questions to populate the first ADR.
5. **Govern** — run the standard Govern phase. When `lineage_fields` are absent from the adopted template, the agent MUST warn the user and require an explicit confirmation before writing; this is the warn-and-confirm Govern behavior referenced in `adr-byo-template.instructions.md`.

## Templates

- `templates/madr-v4.md` — MADR v4.0.0 ADR template (verbatim, CC0). Used by Govern frontmatter assembly when `state.outputTemplate == 'madr-v4'`.
- `templates/y-statement.md` — Six-slot Y-Statement formula for Decide assembly when `state.outputTemplate == 'y-statement'`.
- `templates/diagram-ascii.md` — ASCII diagram block, selected when `state.userPreferences.diagramFormat == "ascii"`.
- `templates/diagram-mermaid.md` — Mermaid diagram block, selected when `state.userPreferences.diagramFormat == "mermaid"`.

## References

- `references/standards-excerpts.md` — MADR v4.0.0 verbatim text and CC0 attribution; Y-Statement attribution; status taxonomy.
- `references/lineage-rules.md` — Full text of the six supersession rules with edge cases and worked examples.
- `references/asr-trigger-taxonomy.md` — Full ASR trigger taxonomy, rubric prompts, and examples for each of the eight enum values.

## Scripts

- `scripts/render_template.py` — Renders a template from `templates/` against a Frame+Decide payload to produce an in-memory ADR draft. Path-traversal guarded: refuses any output path outside `docs/planning/adrs/`.
- `scripts/validate_frontmatter.py` — Validates ADR frontmatter against the MADR v4 schema and the closed enums. Returns non-zero on violation. Path-traversal guarded against the same root.
- `scripts/update_lineage.py` — Single writer of `last_decision_id` in `.adr-config.yml`. Mutates predecessor ADRs' `superseded-by` atomically with the new ADR's `supersedes`. Path-traversal guarded.
- `scripts/normalize_template.py` — Converts a user-supplied ADR template into the canonical structure used by `templates/madr-v4.md`. Used only by the `adopt-template` lifecycle. Path-traversal guarded.

All scripts treat their working directory as untrusted input and reject paths that resolve outside the project ADR root.

## Source Attribution

- `templates/madr-v4.md` — reproduced byte-identical from [MADR v4.0.0](https://github.com/adr/madr/blob/4.0.0/template/adr-template.md) (tag `4.0.0`, file `template/adr-template.md`), released under [CC0-1.0](https://creativecommons.org/publicdomain/zero/1.0/). CC0 does not require attribution; it is recorded here for transparency. Upstream typographical anomalies (for example, the unbalanced quotation in the `status:` placeholder) are preserved intentionally to keep the file diff-clean against the upstream release.

## Mandatory Load Directives

The ADR Creator agent enforces a phase→section load contract per `adr-identity.instructions.md`. Each phase MUST load its section of this skill before executing phase work, and MUST append the section anchor to `state.phaseSkillsLoaded`:

| Phase  | Section anchor | Required `phaseSkillsLoaded` entry |
|--------|----------------|------------------------------------|
| Frame  | `#frame`       | `adr-author#frame`                 |
| Decide | `#decide`      | `adr-author#decide`                |
| Govern | `#govern`      | `adr-author#govern`                |

The agent loads sections via `read_file` against this skill file and records the entry in `state.phaseSkillsLoaded` before any phase work executes. Re-entering a previously loaded phase does not require reloading; the agent checks `phaseSkillsLoaded` first.

---

> Brought to you by microsoft/hve-core

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
