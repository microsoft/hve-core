---
name: vally-tests
description: 'Authors Vally conformance tests for prompts, instructions, agents, and skills, including refusals for jailbreak, prompt-injection, harmful-elicitation, TOS, CoC, and PII-extraction stimuli'
license: MIT
user-invocable: true
compatibility: 'Requires Vally CLI 0.4.0+, PowerShell 7+, bash, and Python 3.11+ with uv for corpus-import workflows'
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-05-27"
---

# Vally Tests Skill

## Purpose

This skill authors Vally conformance tests for the four supported artifact kinds in this repository: prompts, instructions, agents, and skills. Each test exercises a documented behavior the artifact already claims and routes the result through an appropriate Vally grader so failures are explainable. Test authoring is bounded by a refusal taxonomy that keeps the skill out of adversarial, harmful, or policy-evasion territory.

Follow the shared content-policy public-output guard for eval stimuli and any public summaries derived from this skill. Vally tests are not a venue for terms-of-service boundary mapping, payload generation, refusal-text scoring, hidden-instruction disclosure, PII extraction, or secret extraction.

The skill ships:

* A canonical authoring workflow used by both the Vally Test Author prompt and the Prompt Builder subagent.
* Per-kind reference files that enumerate every conformance check the skill knows how to express.
* A grader catalog that maps Vally CLI 0.4.0 grader types to the checks they fit.
* A safety refusal taxonomy with regex patterns the safety lint script consumes.
* Helper scripts and asset templates for stimulus emission, corpus import, and dedupe.

## When to Invoke

Invoke this skill in one of two modes:

* From-artifact mode. The caller points at one artifact file (a `.prompt.md`, `.instructions.md`, `.agent.md`, or `SKILL.md`) and asks for conformance test stimuli that verify the artifact's stated behaviors. The skill detects the artifact kind from the filename, looks up the matching per-kind reference, picks graders, and appends stimulus blocks to the routed Vally eval file.
* Corpus-import mode. The caller supplies a CSV or XLSX corpus that follows the shipped template, and the skill turns each row into a stimulus block in the routed eval file. Used when a large batch of behaviors needs identical formatting and dedupe handling.

Do not invoke this skill to:

* Generate adversarial probes, jailbreak attempts, prompt-injection payloads, or red-team stimuli.
* Test refusal quality on harmful, illegal, or policy-violating prompts.
* Author stimuli that elicit PII, secrets, hidden instructions, or model self-disclosure.
* Store payload examples, paraphrased prohibited requests, or quoted flagged content in Vally eval specs, corpus rows, PR summaries, issue bodies, or comments.
* Replace Responsible AI threat modeling. RAI work lives in the RAI Planner agent.

## Authoring Workflow

Each invocation follows the same six-step pipeline:

1. **Artifact-kind detection.** Resolve the kind from the artifact path or the corpus row's `kind` column. Supported kinds: `prompt`, `instructions`, `agent`, `skill`. Reject unknown kinds with a refusal block.
2. **Reference lookup.** Load the matching reference file from `references/` and select the check or checks the stimulus exercises.
3. **Grader selection.** Use `references/grader-catalog.md` to pick a Vally grader (`semantic_similarity`, `contains`, `regex`, `json_schema`) appropriate for the check's expected response shape.
4. **Stimulus emission.** Run a safety self-check against the refusal taxonomy regex set. Refusing here is the correct outcome for any stimulus that matches a refusal category.
5. **Safety self-check.** Run a safety self-check against the refusal taxonomy regex set. Refusing here is the correct outcome for any stimulus that matches a refusal category.
6. **Dedupe and append.** Compute a SHA-256 hash of the normalized prompt text, compare against existing stimuli in the target eval file, and append only when novel.

The pipeline is identical for both invocation modes. Corpus-import mode runs steps 2 through 6 once per row.

## Safety Refusal Taxonomy

Authoring is bounded by seven refusal categories. Any stimulus that matches a category's regex set is refused before it reaches the dedupe step. The categories and their normative source are listed below. The full regex set lives in `references/refusal-taxonomy.md` and is consumed by the safety lint script.

| Category                  | Definition                                                                                                                | Normative Source        |
|---------------------------|---------------------------------------------------------------------------------------------------------------------------|-------------------------|
| jailbreak                 | Attempts to bypass model safety policies through persona switching, hypothetical framing, or roleplay coercion.           | Project Code of Conduct |
| prompt-injection          | Attempts to override system or developer instructions through embedded or external content.                               | Project Code of Conduct |
| harmful-elicitation       | Requests for content that causes physical, financial, psychological, or reputational harm.                                | Project Code of Conduct |
| tos-violation             | Stimuli that solicit content prohibited by GitHub, Microsoft, or model-provider terms of service.                         | Project Code of Conduct |
| coc-violation             | Stimuli that violate this repository's Code of Conduct, including harassment, discrimination, or doxxing.                 | Project Code of Conduct |
| model-refusal-elicitation | Attempts to provoke a model refusal so the refusal text itself can be scored, graded, or used to map provider boundaries. | RAI Planner guidance    |
| pii-extraction            | Attempts to elicit personally identifiable information, secrets, credentials, or proprietary training data.               | RAI Planner guidance    |

When a request triggers a refusal, emit the canonical refusal block:

```text
This skill authors conformance tests only. The request appears to fall under <category>. Please consult <Project Code of Conduct | RAI Planner agent> for the appropriate process.
```

Substitute the matched `<category>` and the most relevant normative source. Do not negotiate, rephrase, or partially fulfill the request.

## Helper Script Index

Helper scripts ship as parity pairs (`.ps1` and `.sh`) where the workflow does not require Python. Python is used only for the corpus-import path because the source-of-truth interchange format is CSV with an XLSX mirror.

| Script                              | Purpose                                                                                           | Language      | Delivery |
|-------------------------------------|---------------------------------------------------------------------------------------------------|---------------|----------|
| `scripts/New-Stimulus.ps1`          | Scaffolds a single stimulus YAML block from an artifact path and appends to the routed eval file. | PowerShell 7+ | Phase 2  |
| `scripts/new-stimulus.sh`           | Parity counterpart for the PowerShell stimulus scaffolder.                                        | bash          | Phase 2  |
| `scripts/import_corpus.py`          | Reads the CSV or XLSX corpus template and emits dedupe-checked stimulus blocks per kind.          | Python 3.11+  | Phase 2  |
| `scripts/Lint-VallyTestSafety.ps1`  | Runs the refusal taxonomy regex set against a candidate stimulus and exits non-zero on match.     | PowerShell 7+ | Phase 3  |
| `scripts/lint-vally-test-safety.sh` | Parity counterpart for the safety lint script.                                                    | bash          | Phase 3  |

All helpers honour a shared dedupe contract: SHA-256 of the prompt text after Unicode NFC normalization and whitespace collapse.

The helpers emit a JSON run report to `logs/vally-test-author-<timestamp>.json`, where `<timestamp>` is `YYYYMMDD-HHMMSS` (UTC). The report captures, at minimum: `mode`; `inputs` (the resolved `files`/`path` and `kind`); `target_eval_file`; `stimuli_appended` (count and per-row hash); `dedupe_results` (count and per-row hash for skipped duplicates); `refusal_check` (per-row category match, if any); `safety_lint_exit_code`; `blockers` (any ambiguous safety-lint outcomes surfaced for review); and `written_paths`.

## Reference Index

References capture the conformance taxonomy, grader selection rules, eval-suite routing, and the regex source of truth for the refusal taxonomy. Each file targets a specific decision point in the authoring workflow.

| Reference                          | Covers                                                                  |
|------------------------------------|-------------------------------------------------------------------------|
| `references/prompts.md`            | The 12 conformance checks emitted for `.prompt.md` artifacts.           |
| `references/instructions.md`       | The 8 conformance checks emitted for `.instructions.md` artifacts.      |
| `references/agents.md`             | The 10 conformance checks emitted for `.agent.md` artifacts.            |
| `references/skills.md`             | The 10 conformance checks emitted for `SKILL.md` artifacts.             |
| `references/grader-catalog.md`     | Vally CLI 0.4.0 grader types, selection rules, and gotchas.             |
| `references/refusal-taxonomy.md`   | Regex source of truth for the 7 refusal categories and worked examples. |
| `references/eval-suite-routing.md` | Maps artifact kind to the canonical Vally eval file under `evals/`.     |

## Asset Index

Assets supply the interchange formats the corpus-import path consumes. The CSV is the source of truth. The XLSX mirror is regenerated from the CSV by `import_corpus.py` and is never edited directly.

| Asset                                | Purpose                                                                                                       |
|--------------------------------------|---------------------------------------------------------------------------------------------------------------|
| `assets/corpus-import-template.csv`  | Canonical CSV template with header `prompt,kind,target_artifact,grader,tags,expected_refusal_category,notes`. |
| `assets/corpus-import-template.xlsx` | Excel mirror of the CSV regenerated by the import script.                                                     |

## Output Targets per Kind

Authored stimuli always land in one of the routed Vally eval files. The router is encoded in `references/eval-suite-routing.md` and mirrored here for quick lookup.

| Kind         | Target Eval File                                      | Vally Suite Name     |
|--------------|-------------------------------------------------------|----------------------|
| prompt       | `evals/behavior-conformance/prompts.eval.yaml`        | behavior-conformance |
| instructions | `evals/behavior-conformance/instructions.eval.yaml`   | behavior-conformance |
| agent        | `evals/agent-behavior/eval.yaml`                      | agent-behavior       |
| skill        | `evals/behavior-conformance/skill-behavior.eval.yaml` | behavior-conformance |

Never write to `evals/baseline-equivalence/`, `evals/script-validation/`, or `evals/results/` from this skill. Those targets serve baseline equivalence, script validation, and historical comparison flows that are out of scope for conformance authoring.

## Contributing

Follow these conventions when extending this skill:

* New per-kind checks belong in the matching `references/{kind}.md` file. Bump the check count in this SKILL.md when the reference adds or removes checks.
* New grader types belong in `references/grader-catalog.md` and only after the matching Vally CLI version is pinned in `package.json` devDependencies.
* New refusal categories require updates to `references/refusal-taxonomy.md`, the regex set the safety lint script consumes, the Safety Refusal Taxonomy table above, and the canonical refusal block.
* Helper scripts must ship in parity pairs (`.ps1` and `.sh`) unless the workflow has a hard Python dependency. Python helpers live under `scripts/` and are configured by the skill's `pyproject.toml`.
