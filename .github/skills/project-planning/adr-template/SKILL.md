---
name: adr-template
description: "Architecture Decision Record template Framework Skill providing guided section prompts, trade-off analysis templates, and phased authoring workflow as machine-readable document-section YAML for content-generation hosts - Brought to you by microsoft/hve-core."
license: MIT
user-invocable: false
metadata:
  authors: "HVE Core contributors"
  spec_version: "1.0"
  framework_revision: "2026.1"
  last_updated: "2026-07-23"
  skill_based_on: "https://github.com/chris-buckley/agnostic-prompt-standard"
---

# ADR Template — Skill Entry

This `SKILL.md` is the **entrypoint** for the ADR Template framework skill.

The skill encodes an Architecture Decision Record structure as `document-section` items with variable-driven templates. Content-generation hosts load the Framework Skill, collect variable values from the user, substitute `{{var}}` tokens, and render the final document. It is not user-invocable; it serves as a data contract consumed by content-generation orchestration.

## Consumer contract

1. Read [`index.yml`](index.yml) to discover globals, phase assignments, and the section roster.
2. Resolve each section ID listed under `phaseMap.<phase>` to its per-item file under [`items/`](items/).
3. Validate each item file against [`scripts/linting/schemas/document-section.schema.json`](../../../../scripts/linting/schemas/document-section.schema.json).
4. Collect values for `globals` and per-section `inputs` before rendering.
5. Substitute `{{var}}` tokens in each section's `template` field, resolving item-local inputs first, then manifest globals.

## Globals

The manifest declares three globals collected once and reused across all sections:

| Variable         | Description                                            | Required |
|------------------|--------------------------------------------------------|----------|
| `adr_title`      | Clear, descriptive title of the architectural decision | Yes      |
| `adr_author`     | Author or team name responsible for the decision       | No       |
| `decision_topic` | Kebab-case topic identifier used in file naming        | No       |

## Authoring phases

Sections are grouped into three phases matching the ADR authoring lifecycle:

* **discover** — Establish decision scope and context: Status, Context.
* **evaluate** — Analyze options and trade-offs: Decision Drivers, Considered Options, Comparison Matrix.
* **document** — Record the decision and its implications: Decision, Consequences, Future Considerations.

## Items

Each section lives in `items/<id>.yml` and declares its own template with `{{var}}` tokens, optional per-section inputs, and an optional applicability discriminator.

| ID                      | Title                 | Phase    |
|-------------------------|-----------------------|----------|
| `status`                | Status                | discover |
| `context`               | Context               | discover |
| `decision-drivers`      | Decision Drivers      | evaluate |
| `considered-options`    | Considered Options    | evaluate |
| `comparison-matrix`     | Comparison Matrix     | evaluate |
| `decision`              | Decision              | document |
| `consequences`          | Consequences          | document |
| `future-considerations` | Future Considerations | document |
