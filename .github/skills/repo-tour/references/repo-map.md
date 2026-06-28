---
description: hve-core repository area map and one-level-deeper sub-structure used as the starting narrative for the guided repo tour
---

# Repo Map

Starting narrative for the guided tour. Reconcile each area against the live tree before describing it; this map is a backbone, not the source of truth.

## Repo Area Map

| Area               | What lives there                                                                                                                                |
|--------------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| `docs/`            | Guides, the RPI workflow, role guides, and templates: the "how this repo works" reading.                                                       |
| `.github/`         | The building blocks: `agents/`, `prompts/`, `instructions/`, and `skills/` that define the customizations, plus CI `workflows/`.               |
| `scripts/`         | Automation for linting, validation, and packaging, organized by function, each with an `npm run` entry point.                                  |
| `evals/`           | Evaluation harnesses that check agent behavior and skill quality.                                                                              |
| `collections/`     | Manifests that bundle sets of agents, prompts, instructions, and skills for distribution.                                                      |
| Logging & tracking | `logs/` holds output from validation scripts; `.copilot-tracking/` (gitignored) holds in-progress AI-workflow artifacts: research, plans, changes, and reviews. |

## One Level Deeper

* `docs/`: `hve-guide/` (lifecycle and role guides), `getting-started/` (install and first workflow), `rpi/` (researcher, planner, implementor docs), `contributing/`, and `templates/`.
* `.github/`: `agents/` (and `agents/**/subagents/`), `prompts/`, `instructions/`, and `skills/{collection}/{skill}/SKILL.md` are the customizations; `workflows/` is CI; `actions/` holds composite actions; `ISSUE_TEMPLATE/` holds issue forms. Most are organized into `{collection-id}` subfolders.
* `scripts/`: `linting/`, `security/`, `collections/`, `extension/`, `devcontainer/`, `plugins/`, `lib/` (shared helpers), and `tests/` (mirrors the source layout). Each surface has an `npm run` entry point.
* `evals/`: `agent-behavior/`, `skill-quality/`, `script-validation/`, `baseline-equivalence/`, `behavior-conformance/`, and `skill-hygiene/`: each holds the test cases for that check.
* Logging & tracking: `logs/` holds per-script JSON results; `.copilot-tracking/` holds `research/`, `plans/`, `changes/`, and `reviews/` for in-progress AI work.
