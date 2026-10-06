---
agent: "agent"
description: "Create or update the project cspell configuration with project words and ignores"
---

# Update cspell configuration with project-specific words and ignores

## Context

* Goal: Add commonly used project-specific words to the cspell configuration, alphabetize the words list, and add useful `ignorePaths` aligned with the project's ignore files.
* cspell supports multiple config formats and file names. The agent must detect which format the project uses rather than assuming any specific one.
* Projects may also use custom dictionary files (`.txt` word lists) organized in a dedicated directory. The agent must discover and respect existing dictionary structure.
* Configuration authority is invocation-bound, not a fixed ranking of file locations. The command that runs cspell determines the base configuration, cspell's own per-file lookup determines overlays, and a custom dictionary participates only when an effective configuration defines and enables it. File enumeration order never establishes authority.

## Required Steps

### Step 1: Detect project context and the authoritative command

1. Identify the project's primary language and package manager by inspecting files at the workspace root (e.g., `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `*.csproj`, `pom.xml`, `Gemfile`).
2. Determine how cspell is installed or available. Check for: a project dependency (npm, pip, or equivalent), a global install (`cspell --version`), or `npx`/`npx`-equivalent availability. If cspell is not available, ask the user for their preferred installation method.
3. Record the installed cspell version. Resolution details below describe cspell 10.x behavior; when the project pins a different major version, confirm the behavior against that version's documentation or observed output before relying on any ordering claim.
4. Check for an existing spell-check script in the project's task runner (e.g., `package.json` scripts, `Makefile` targets, `justfile` recipes, `pyproject.toml` scripts). Use the project command when one exists; it is the authority for the rest of this workflow.
5. From that command, capture the invocation working directory, the file globs it passes, any explicit `--config`, and any config-search controls (`--no-config-search`, `--config-search`, `--stop-config-search-at`, or an equivalent setting). These inputs determine which configuration the project actually uses.

### Step 2: Resolve the authoritative cspell configuration

1. Inventory candidate config files across the workspace using a broad glob pattern (e.g., `cspell*`, `.cspell*`). cspell recognizes many naming variants including dotfiles (`.cspell.json`), plain names (`cspell.json`), JSONC (`cspell.jsonc`), JS modules (`cspell.config.{js,cjs,mjs}`), and YAML (`cspell.config.{yaml,yml}`). Also check `package.json` for a `cspell` configuration key. Treat this inventory as candidates only; enumeration order carries no authority.
2. Identify the invocation-base config, which governs file discovery for the whole run:
   * When the command passes `--config`, that file is the base.
   * Otherwise the base is the config cspell finds from the invocation working directory.
   * Because the base owns discovery, a file excluded by the base `ignorePaths` stays excluded no matter what a nested config says.
3. Determine per-file overlays. Unless config search is turned off, cspell searches upward from each checked file for the nearest recognized config and merges it over the base settings. Only the nearest config applies; an intermediate ancestor between the file and the base participates only when the selected config imports it. In merged settings, nested scalar values win and mergeable arrays accumulate.
4. Apply same-directory recognized-name order when one directory holds more than one representation. In cspell 10.x a `package.json` with an object-valued `cspell` key is selected before `.cspell.json`, then `cspell.json`, then the remaining recognized names. Sibling files are not merged automatically; a sibling participates only through an explicit `import` or an explicit invocation. Verify this ordering against the installed version rather than asserting it from memory.
5. Note that `--config` alone does not disable the per-file search. `--no-config-search` and the `noConfigSearch: true` setting disable it; `--config-search` re-enables it; `--stop-config-search-at` bounds how far the upward search walks.
6. Follow every `import` in the selected configs and record the imported files, since an import can supply the definitions and words a token would otherwise need.
7. If no config file exists anywhere in the resolution chain, create `cspell.json` at the invocation root with a minimal scaffold (`version`, `language`, `ignorePaths`, `words`).
8. Record the resolved base config path, the applicable local config path for the files you intend to change, the imported files, and each candidate you did not select, with the reason.
9. If these inputs do not identify exactly one authoritative mutation target, stop and ask the user which config or dictionary to write to. Present the resolved command, the candidates, and why the choice is ambiguous. Do not guess.

### Step 3: Resolve custom dictionaries

1. Collect every `dictionaryDefinitions` entry from the resolved configs and their imports, and search for a `.cspell/` directory or any other referenced dictionary location.
2. Catalog existing custom dictionary text files (`.txt` word lists) and note their names, paths, and apparent categories.
3. Treat a dictionary as active only when a definition supplies its name and an effective `dictionaries` list (or an applicable override or language setting) enables that name. A definition alone does not load the file, and a dictionary file that no config references has no effect.
4. Resolve relative dictionary paths from the config that defines them, not from the process working directory.
5. When the same dictionary name is defined more than once among active definitions, the later effective definition replaces the earlier one. Record which definition wins before writing to any file.
6. Check the `dictionaries` field for enabled built-in dictionaries (e.g., `k8s`, `docker`, `rust`, `aws`, `terraform`, `python`, `csharp`).
7. When adding new words later, route each token to the inline `words` array of the authoritative config or to an active custom dictionary file whose category fits. Never write to an inactive dictionary. If no active custom dictionaries exist, add all tokens to the inline `words` array.

### Step 4: Run initial spell check

1. Run cspell using the project command discovered in Step 1, or fall back to direct invocation (e.g., `npx cspell "**/*"`, `cspell "**/*"`).
2. Collect unknown words from the output, excluding paths already covered by `ignorePaths`.

### Step 5: Curate and categorize tokens

1. Group unknown tokens into categories: project-specific terms, acronyms, technology names, environment variables, proper nouns, and potential typos.
2. Filter out obvious garbage using these heuristics:
   * Hex strings of 16+ characters (`[a-f0-9]{16,}`)
   * Base64 looking strings (`[A-Za-z0-9+/]{20,}={0,2}`)
   * Tokens appearing only in lockfiles, minified assets, or build output
3. Identify likely typos that should be fixed in source rather than added to the dictionary (e.g., `recieve` → `receive`). Report these separately for the user to review. <!-- cspell:disable-line -->
4. For each remaining token, decide placement: inline `words` array for project-specific terms, or the appropriate custom dictionary file when one exists and the token fits its category.

### Step 6: Update configuration and dictionaries

1. Write curated tokens only to the targets resolved in Steps 2 and 3: the inline `words` array of the authoritative config, or an active custom dictionary file. Preserve original casing and avoid introducing duplicates.
2. Sort the `words` array alphabetically (case-insensitive sort, preserve original case).
3. Sort custom dictionary text files alphabetically with one word per line if they follow that convention.
4. Add or refine `ignorePaths` entries to align with the project's ignore files (`.gitignore`, `.dockerignore`, etc.), but do not ignore source folders containing meaningful code and documentation. Add an `ignorePaths` entry to the config that governs discovery for the affected files; an entry placed in a nested config cannot exclude a file the invocation base already enumerated, and cannot re-include a file the base excluded.
5. Preserve the existing config format and style conventions (indentation, trailing commas, module export structure).

### Step 7: Validate and report

1. Re-run cspell using the same command from Step 4, from the same working directory and with the same config and search flags, so the before and after runs are comparable.
2. Report the final counts: files checked, issues found, files with issues.
3. Report the resolution basis for the changes: the command used, the invocation-base config, the applicable local config, each file or dictionary written, and the candidates you did not select with the reason.
4. If the issue count has not meaningfully decreased from baseline (target: ≥80% reduction), provide a short rationale and suggest next actions (add more words, fix typos, or add more ignore paths). When tokens you added are still reported, treat it as a resolution problem: confirm the config you edited is the one the command loads and that any dictionary you wrote to is enabled.
5. List any typos identified in Step 5 that should be fixed in source.

## Acceptance criteria

* Every configuration or dictionary change is written to a target the project's own cspell command actually loads, and the report names the command, base config, local config, and unselected candidates.
* The cspell configuration includes a comprehensive `ignorePaths` array that excludes generated and vendored folders.
* The `words` array and any custom dictionary files contain the most common project-specific tokens, alphabetized and deduplicated.
* A final cspell run shows a meaningful reduction from the baseline (target ≥80%, or the agent documents the remaining categories with rationale).

## Notes and best practices

* Prefer observed command behavior over any remembered ordering rule. When resolution is unclear, run the project command with increased verbosity and let its output identify the configuration in effect.
* Do not reimplement cspell's resolver. Use the tool's own output to confirm which settings applied.
* Preserve original casing for tokens (do not normalize to uppercase or lowercase).
* Prefer adding tokens for environment variables, infrastructure outputs, and technology names rather than silencing real typos.
* When in doubt about a token that appears only once in generated files, prefer ignoring the generated file path instead of adding the token.
* For diacritics and special characters (e.g., `Piña`, `José`, `Müller`, `Straße`, `naïve`, `résumé`, `Zürich`), preserve the original forms but consider adding simplified fallbacks only if tests or files use them. <!-- cspell:disable-line -->
* When the project uses a JS/CJS/MJS config format, preserve the module export structure and do not convert to JSON.
* Adapt file-type globs for the spell-check command to the project's languages (e.g., `"**/*.{py,md,yaml,yml}"` for Python projects, `"**/*.{cs,md,json}"` for C# projects).

---

Proceed with the Required Steps to detect, update, and validate the cspell configuration.
