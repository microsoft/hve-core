---
name: prd-template
description: "Product Requirements Document template Framework Skill providing guided section prompts, variable-driven inputs, and phased authoring workflow as machine-readable document-section YAML for content-generation hosts - Brought to you by microsoft/hve-core."
license: MIT
user-invocable: false
metadata:
  authors: "HVE Core contributors"
  spec_version: "1.0"
  framework_revision: "2026.1"
  last_updated: "2026-07-23"
  skill_based_on: "https://github.com/chris-buckley/agnostic-prompt-standard"
---

# PRD Template — Skill Entry

This `SKILL.md` is the **entrypoint** for the PRD Template framework skill.

The skill encodes a Product Requirements Document structure as `document-section` items with variable-driven templates. Content-generation hosts load the Framework Skill, collect variable values from the user, substitute `{{var}}` tokens, and render the final document. It is not user-invocable; it serves as a data contract consumed by content-generation orchestration.

## Consumer contract

1. Read [`index.yml`](index.yml) to discover globals, phase assignments, and the section roster.
2. Resolve each section ID listed under `phaseMap.<phase>` to its per-item file under [`items/`](items/).
3. Validate each item file against [`scripts/linting/schemas/document-section.schema.json`](../../../../scripts/linting/schemas/document-section.schema.json).
4. Collect values for `globals` and per-section `inputs` before rendering.
5. Substitute `{{var}}` tokens in each section's `template` field, resolving item-local inputs first, then manifest globals.

## Globals

The manifest declares three globals collected once and reused across all sections:

| Variable         | Description                    | Required |
|------------------|--------------------------------|----------|
| `product_name`   | Product or feature name        | Yes      |
| `team_owner`     | Team responsible for delivery  | No       |
| `target_release` | Target release version or date | No       |

## Authoring phases

Sections are grouped into three phases matching the PRD authoring lifecycle:

* **outline** — Establish context and constraints: Background, Problem Statement, Non-Goals.
* **draft** — Define what to build and for whom: Goals and Success Metrics, Target Users, Requirements, Technical Approach.
* **finalize** — Close out planning: Milestones, Risks, Open Questions.

## Items

Each section lives in `items/<id>.yml` and declares its own template with `{{var}}` tokens, optional per-section inputs, and an optional applicability discriminator.

| ID                          | Title                     | Phase    |
|-----------------------------|---------------------------|----------|
| `background`                | Background                | outline  |
| `problem-statement`         | Problem Statement         | outline  |
| `non-goals`                 | Non-Goals                 | outline  |
| `goals-and-success-metrics` | Goals and Success Metrics | draft    |
| `target-users`              | Target Users              | draft    |
| `requirements`              | Requirements              | draft    |
| `technical-approach`        | Technical Approach        | draft    |
| `milestones`                | Milestones                | finalize |
| `risks`                     | Risks                     | finalize |
| `open-questions`            | Open Questions            | finalize |
