---
agent: "agent"
description: "Creates or updates the project cspell configuration with project-specific words and ignores"
---

# Update cspell configuration with project-specific words and ignores

## Context

* Goal: Add commonly used project-specific words to the cspell configuration, alphabetize the words list, and add useful `ignorePaths` aligned with the project's ignore files.
* cspell supports multiple config formats and file names. The agent must detect which format the project uses rather than assuming any specific one.
* Projects may also use custom dictionary files (`.txt` word lists) organized in a dedicated directory. The agent must discover and respect existing dictionary structure.

## Required Steps

### Step 1: Detect project context

1. Identify the project's primary language and package manager by inspecting files at the workspace root (e.g., `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `*.csproj`, `pom.xml`, `Gemfile`).
2. Determine how cspell is installed or available. Check for: a project dependency (npm, pip, or equivalent), a global install (`cspell --version`), or `npx`/`npx`-equivalent availability. If cspell is not available, ask the user for their preferred installation method.
3. Check for an existing spell-check script in the project's task runner (e.g., `package.json` scripts, `Makefile` targets, `justfile` recipes, `pyproject.toml` scripts). Use the project command when one exists.

### Step 2: Detect cspell configuration

1. Search the workspace root for any cspell config file using a broad glob pattern (e.g., `cspell*`, `.cspell*`). cspell recognizes many naming variants including dotfiles (`.cspell.json`), plain names (`cspell.json`), JSONC (`cspell.jsonc`), JS modules (`cspell.config.{js,cjs,mjs}`), and YAML (`cspell.config.{yaml,yml}`). Also check `package.json` for a `cspell` configuration key.
2. If multiple config files exist, use the first match and note the others for the user.
3. If no config file exists, create `cspell.json` with a minimal scaffold (`version`, `language`, `ignorePaths`, `words`).
4. Record the detected config path and format (JSON, YAML, or JS module) for subsequent steps.

### Step 3: Detect custom dictionaries

1. Search for a `.cspell/` directory or any path referenced in the config's `dictionaryDefinitions` field.
2. Catalog existing custom dictionary text files (`.txt` word lists) and note their names, paths, and apparent categories.
3. Check the `dictionaries` field for enabled built-in dictionaries (e.g., `k8s`, `docker`, `rust`, `aws`, `terraform`, `python`, `csharp`).
4. When adding new words later, route each token to either the inline `words` array or an existing custom dictionary file based on category fit. If no custom dictionaries exist, add all tokens to the inline `words` array.

### Step 4: Run initial spell check

1. Run cspell using the project command discovered in Step 1, or fall back to direct invocation (e.g., `npx cspell "**/*"`, `cspell "**/*"`).
2. Collect unknown words from the output, excluding paths already covered by `ignorePaths`.

### Step 5: Curate and categorize tokens

1. Group unknown tokens into categories: project-specific terms, acronyms, technology names, environment variables, proper nouns, and potential typos.
2. Filter out obvious garbage (long random hashes, base64 strings, generated identifiers).
3. Identify likely typos that should be fixed in source rather than added to the dictionary (e.g., `recieve` → `receive`). Report these separately for the user to review. <!-- cspell:disable-line -->
4. For each remaining token, decide placement: inline `words` array for project-specific terms, or the appropriate custom dictionary file when one exists and the token fits its category.

### Step 6: Update configuration and dictionaries

1. Add curated tokens to the `words` array or the appropriate custom dictionary file. Preserve original casing and avoid introducing duplicates.
2. Sort the `words` array alphabetically (case-insensitive sort, preserve original case).
3. Sort custom dictionary text files alphabetically with one word per line if they follow that convention.
4. Add or refine `ignorePaths` entries to align with the project's ignore files (`.gitignore`, `.dockerignore`, etc.), but do not ignore source folders containing meaningful code and documentation.
5. Preserve the existing config format and style conventions (indentation, trailing commas, module export structure).

### Step 7: Validate and report

1. Re-run cspell using the same command from Step 4.
2. Report the final counts: files checked, issues found, files with issues.
3. If more than 50 issues remain, provide a short rationale and suggest next actions (add more words, fix typos, or add more ignore paths).
4. List any typos identified in Step 5 that should be fixed in source.

## Acceptance criteria

* The cspell configuration includes a comprehensive `ignorePaths` array that excludes generated and vendored folders.
* The `words` array and any custom dictionary files contain the most common project-specific tokens, alphabetized and deduplicated.
* A final cspell run shows a significantly reduced issue count (ideally fewer than 50). When not achievable automatically, provide a prioritized list of remaining tokens and typos for manual review.

## Notes and best practices

* Preserve original casing for tokens (do not normalize to uppercase or lowercase).
* Prefer adding tokens for environment variables, infrastructure outputs, and technology names rather than silencing real typos.
* When in doubt about a token that appears only once in generated files, prefer ignoring the generated file path instead of adding the token.
* For diacritics and special characters (e.g., `Piña`, `José`, `Müller`, `Straße`, `naïve`, `résumé`, `Zürich`), preserve the original forms but consider adding simplified fallbacks only if tests or files use them. <!-- cspell:disable-line -->
* When the project uses a JS/CJS/MJS config format, preserve the module export structure and do not convert to JSON.
* Adapt file-type globs for the spell-check command to the project's languages (e.g., `"**/*.{py,md,yaml,yml}"` for Python projects, `"**/*.{cs,md,json}"` for C# projects).

---

Proceed with the Required Steps to detect, update, and validate the cspell configuration.
