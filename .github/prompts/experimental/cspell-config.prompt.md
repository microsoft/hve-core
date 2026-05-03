---
agent: "agent"
description: "Creates or updates the cspell.json file with project-specific words and ignores"
---

# Update cspell.json with project-specific words and ignores

## Context

- Goal: Add commonly used project-specific words to `cspell.json`, alphabetize the words list, and add useful `ignorePaths` (based on the contents of .gitignore).

## Instructions for Copilot/GitHub assistant

1. Run a spell-check across the workspace using `npx cspell --config cspell.json "**/*"`.

2. Collect unknown words reported by cspell (exclude paths already in `ignorePaths`).

3. From the report, build a curated candidate list by grouping tokens into categories.

4. Filter out obvious garbage/generated tokens (long random hashes) and likely typos that should instead be fixed in source (e.g., `recieve` → `receive`). <!-- cspell:disable-line -->

5. Add high-value tokens to the `words` array in `cspell.json`, preserving exact casing, and sort the array alphabetically (case-insensitive sort but keep original case strings). Avoid introducing duplicates.

6. Add or refine `ignorePaths` to match the .gitignore file, but do not ignore source folders containing meaningful code and docs.

7. Re-run cspell and report the final counts (files checked, issues found, files with issues). If >50 issues remain, provide a short rationale and suggest next actions (add more words, fix typos, or add more ignores).

## Acceptance criteria

- `cspell.json` includes a comprehensive `ignorePaths` array that excludes common generated folders and per-project node_modules.

- `words` array contains the most common project-specific tokens and is alphabetized and deduped.

- A final cspell run shows a significantly reduced number of issues (ideally < 50). If not achievable automatically, the assistant should provide a prioritized list of remaining tokens and typos for manual review.

## Notes and best practices

- Preserve original casing for tokens (don't normalize to uppercase/lowercase).

- Prefer adding tokens for env vars/infra outputs (e.g., `VITE_*`, `AZURE_*`, `ENTRA_*`) rather than silencing real typos.

- When in doubt about a token that appears only once in generated files, prefer ignoring the generated file path instead of adding the token.

- For diacritics (e.g., `Piña`, `José`), preserve the diacritic forms but consider adding accentless fallbacks only if tests or files use them.

## Example commands

```bash
# run cspell
npx cspell --config cspell.json "**/*"
```

## Outcome

A clean `cspell.json`, an updated cspell run summary, and a short changelog of added tokens/ignores.
