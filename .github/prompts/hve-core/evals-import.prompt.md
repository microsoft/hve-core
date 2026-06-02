---
description: "Imports a CSV or XLSX corpus into Vally eval suites with safety lint and dedupe - Brought to you by microsoft/hve-core"
agent: Prompt Builder
argument-hint: "[path=...] [kind=auto]"
---

# Evals Import

## Inputs

* (Required) path - ${input:path}: Corpus file to import. Must exist and end in `.csv` or `.xlsx`.
* (Optional) kind - ${input:kind:auto}: Artifact kind override (`prompt`, `instructions`, `agent`, or `skill`). Defaults to `auto` for detection from each row's `kind` column.

## What this prompt does

Dispatches the `Vally Test Author` subagent in `corpus-import` mode. The subagent invokes `.github/skills/hve-core/vally-tests/scripts/import_corpus.py` to validate the column contract, dedupe by SHA-256 of the normalized prompt text, run the repo-wide safety lint per row, and append surviving rows to the routed eval file per `.github/skills/hve-core/vally-tests/references/eval-suite-routing.md`.

Every imported row carries `tags.advisory: true`. This is enforced by `import_corpus.py` and cannot be overridden by the corpus.

## Column Contract

The canonical column contract lives at `.github/skills/hve-core/vally-tests/assets/corpus-import-template.csv`. The CSV is the source of truth; XLSX inputs must match the same header column-for-column.

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
* `expected_refusal_category` — optional; one of the seven refusal categories from `.github/skills/hve-core/vally-tests/references/refusal-taxonomy.md`.
* `notes` — free-form annotation.

## Required Protocol

1. Validate `path` exists and ends in `.csv` or `.xlsx`. If validation fails, return an error that names the bad path and stop without dispatching the subagent.
2. Dispatch the `Vally Test Author` subagent with `mode=corpus-import`, `path=<resolved>`, and `kind=<resolved or auto>`. The subagent enforces `tags.advisory: true` on every appended row via `import_corpus.py`.
3. Surface the subagent's outputs: the JSON report path at `logs/vally-test-author-import-<timestamp>.json` plus summary counts for rows imported, duplicates skipped, and refusals triggered.
