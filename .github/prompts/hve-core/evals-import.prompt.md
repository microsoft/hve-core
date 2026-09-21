---
description: "Imports a CSV or XLSX corpus into Vally eval suites with safety lint and dedupe"
argument-hint: "[path=...] [kind=auto]"
---

# Evals Import

## Inputs

* (Required) path - ${input:path}: Corpus file to import. Must exist and end in `.csv` or `.xlsx`.
* (Optional) kind - ${input:kind:auto}: Artifact kind override (`prompt`, `instructions`, `agent`, or `skill`). Defaults to `auto` for detection from each row's `kind` column.

## What this prompt does

Dispatches the `Vally Test Author` subagent in `corpus-import` mode. The subagent validates the column contract, dedupes by SHA-256 of the normalized prompt text, runs the safety lint per row, and appends surviving rows to the eval file it resolves from its own routing rules.

Every imported row carries `tags.advisory: true`. The subagent enforces this and it cannot be overridden by the corpus.

Search for and apply `content-policy-citation.instructions.md`. Corpus rows must be benign conformance stimuli; rows that would create policy-boundary probes, payload examples, hidden-instruction disclosure attempts, PII or secret extraction, terms-of-service evasion, or refusal-text scoring are refused rather than imported.

## Column Contract

The `Vally Test Author` subagent owns the canonical column contract; consult it for the authoritative template. The CSV is the source of truth; XLSX inputs must match the same header column-for-column.

Header row:

```text
prompt,kind,target_artifact,grader,tags,expected_refusal_category,notes
```

Field notes:

* `prompt` — the stimulus prompt text. Non-empty.
* `kind` — one of `prompt`, `instructions`, `agent`, `skill`.
* `target_artifact` — repo-relative path to the artifact under test. Non-empty.
* `grader` — Vally grader type (`semantic_similarity`, `contains`, `regex`, `json_schema`).
* `tags` — semicolon-separated `key=value` pairs. The importer adds `advisory: true` regardless of input.
* `expected_refusal_category` — optional; one of the seven refusal categories the subagent enforces (jailbreak, prompt-injection, harmful-elicitation, tos-violation, coc-violation, model-refusal-elicitation, pii-extraction).
* `notes` — free-form annotation.

## Required Protocol

1. Validate `path` exists and ends in `.csv` or `.xlsx`. If validation fails, return an error that names the bad path and stop without dispatching the subagent.
2. Dispatch the `Vally Test Author` subagent with `mode=corpus-import`, `path=<resolved>`, and `kind=<resolved or auto>`. The subagent enforces `tags.advisory: true` on every appended row.
3. Surface the subagent's outputs: the JSON report path at `logs/vally-test-author-<timestamp>.json` plus summary counts for rows imported, duplicates skipped, and refusals triggered.
