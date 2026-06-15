---
title: Eval Suite Routing
description: Per-artifact-kind routing rules and DR-03 fallback that direct vally-tests stimulus blocks to the correct Vally eval suite file or directory
---

# Eval Suite Routing

This reference documents how the `vally-tests` skill routes newly authored stimulus blocks to the correct Vally eval suite file or directory based on the artifact kind under test. Every stimulus emitted by this skill MUST be tagged `tags.advisory: true` so that failures surface in CI summaries without blocking the build. Graduation from advisory to authoritative is governed by the policy in [evals/behavior-conformance/README.md](../../../../../evals/behavior-conformance/README.md) (section `## Graduation policy`); this skill does not graduate stimuli on its own. Per-kind targets, fallback rules, and the DR-03 contingency for the `skill` kind are detailed below.

## Routing Table

| Kind           | Primary Target                                        | Fallback                        | Notes                                                           |
|----------------|-------------------------------------------------------|---------------------------------|-----------------------------------------------------------------|
| `prompt`       | `evals/behavior-conformance/prompts.eval.yaml`        | n/a                             | One stimulus block per check from `references/prompts.md`.      |
| `instructions` | `evals/behavior-conformance/instructions.eval.yaml`   | n/a                             | One stimulus block per check from `references/instructions.md`. |
| `agent`        | `evals/agent-behavior/stimuli/<slug>.yml`             | n/a                             | One file per agent, slug = agent filename minus `.agent.md`.    |
| `skill`        | `evals/behavior-conformance/skill-behavior.eval.yaml` | `evals/skill-quality/eval.yaml` | See DR-03 note below.                                           |

## Per-Kind Detail

### `prompt`

* Primary target: [evals/behavior-conformance/prompts.eval.yaml](../../../../../evals/behavior-conformance/prompts.eval.yaml).
* Filesystem state: exists today.
* Append-vs-create rule: append a new stimulus block to the existing `stimuli:` array. The file is single-purpose and aggregates all prompt conformance stimuli. Dedupe is enforced by the Phase 5 dedupe rule (SHA-256 of normalized prompt text); see Phase 5 dedupe rule.
* Class recipe: not applicable. Per-prompt checks come from `references/prompts.md`.

### `instructions`

* Primary target: [evals/behavior-conformance/instructions.eval.yaml](../../../../../evals/behavior-conformance/instructions.eval.yaml).
* Filesystem state: exists today.
* Append-vs-create rule: append a new stimulus block to the existing `stimuli:` array. The file is single-purpose and aggregates all instruction conformance stimuli. Dedupe is enforced by the Phase 5 dedupe rule (SHA-256 of normalized prompt text); see Phase 5 dedupe rule.
* Class recipe: not applicable. Per-instruction checks come from `references/instructions.md`.

### `agent`

* Primary target: [evals/agent-behavior/stimuli/](../../../../../evals/agent-behavior/stimuli/) as `evals/agent-behavior/stimuli/<slug>.yml`.
* Filesystem state: directory exists today with one YAML file per agent (e.g., `ado-backlog-manager.yml`, `task-researcher.yml`).
* Slug convention: `<slug>` is the agent filename minus the `.agent.md` suffix. Example: `task-researcher.agent.md` routes to `evals/agent-behavior/stimuli/task-researcher.yml`.
* Append-vs-create rule: if `<slug>.yml` exists, append the new stimulus block to its `stimuli:` array; otherwise create the file with the standard preamble and a single `stimuli:` entry. Dedupe within the file is enforced by the Phase 5 dedupe rule (SHA-256 of normalized prompt text); see Phase 5 dedupe rule.
* Class recipe: a class recipe from `references/class-recipes.md` (future per-this-skill reference, to be authored under a follow-up work item) governs the per-class shape of agent stimuli (for example, `class-recipe`, `field-vocab`, `tracking-file-write`). Until that file exists, follow the shape of an existing stimulus in the same agent's file.

### `skill`

* Primary target: [evals/behavior-conformance/skill-behavior.eval.yaml](../../../../../evals/behavior-conformance/skill-behavior.eval.yaml).
* Filesystem state: exists today; status is Active per `evals/behavior-conformance/README.md`.
* Append-vs-create rule: append a new stimulus block to the existing `stimuli:` array, tagged with `tags.skill: <skill-slug>` and `tags.shape: knowledge | tool-trigger | bleed-detection`. Dedupe is enforced by the Phase 5 dedupe rule (SHA-256 of normalized prompt text); see Phase 5 dedupe rule.
* Class recipe: not applicable. Per-skill checks come from `references/skills.md`.
* Fallback: see DR-03 note below.

## Advisory-by-Default Policy

Every stimulus authored by this skill MUST set `tags.advisory: true`. Advisory stimuli are collected by the eval driver and surfaced in the per-trial JSONL output and the pull request summary, but they do not promote the overall exit code to non-zero and therefore do not fail the build. This keeps the inner-loop signal visible while the model contract stabilizes.

Graduation from advisory to authoritative requires a separate decision per stimulus and is governed by the policy in [evals/behavior-conformance/README.md](../../../../../evals/behavior-conformance/README.md) (section `## Graduation policy`). The policy requires at least 30 CI runs of executions in advisory mode, a rolling 7-day false-positive rate of at most 5%, CODEOWNERS sign-off, a CHANGELOG entry, and a 14-day rollback window. This skill never flips `tags.advisory: false` on its own.

## DR-03 Note

DR-03 of the Vally Test Authoring plan defers the cutover of the legacy `skill-behavior.eval.yaml` flow until after the new authoring pipeline lands. The primary `skill`-kind target file exists today, but the cutover that consolidates skill behavior coverage is explicitly out of scope for the skill itself.

When the primary `skill`-kind target file is absent at consumption time, the subagent falls back to [evals/skill-quality/eval.yaml](../../../../../evals/skill-quality/eval.yaml) and appends the stimulus block to its existing `stimuli:` array, matching the single-aggregated-file convention observed under `evals/skill-quality/`. The appended block carries a leading YAML comment block of the form `# Deferred cutover per DR-03; see WI-12.` so the provenance survives the eventual migration back to `skill-behavior.eval.yaml`.

WI-12 is the work item tracking the `skill-behavior.eval.yaml` cutover per the plan. If the work item identifier has not yet been created at the time this skill is consumed, the subagent records `WI-12 (pending)` in the comment block and proceeds.
