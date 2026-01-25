---
description: 'Provides prompt instructions for pull request (PR) generation - Brought to you by microsoft/edge-ai'
maturity: stable
---

# Pull Request (PR) Generation Instructions

## Inputs

* ${input:branch:origin/main}: (Optional, defaults to origin/main) Base branch reference for diff generation
* ${input:excludeMarkdown}: (Optional) When true, exclude markdown diffs from pr-reference generation

## Core Guidance

* Aim to apply `git` expertise and Azure Bicep or Terraform knowledge when interpreting diffs.
* Rely on the instructions in this prompt to shape an accurate PR title and description.
* Keep PR content grounded in `pr-reference.xml` only.
* Keep the writing style human-readable and high quality while maintaining technical detail.
* Avoid claiming benefits like security improvements unless commit messages or code comments state them explicitly.
* Avoid mentioning linting errors or auto-generated Bicep or Terraform documentation.
* Avoid creating follow-up tasks for documentation or tests.
* Check for PR templates before generating content and use the repository template when available.
* Auto-detect change types from file patterns and extract issue references from commits and branch names.
* Leave checkboxes requiring manual verification unchecked.
* Preserve template structure and formatting without removing sections.
* Ask the user for direction when progression is unclear.

## Required Steps

This protocol guides the PR generation flow from discovery to cleanup.

### Step 1: Handle pr-reference.xml inputs

Treat `.copilot-tracking/pr/pr-reference.xml` as the canonical diff source.

* If `pr-reference.xml` is provided, confirm with the user whether to use it before proceeding.
* If the user declines, delete `pr-reference.xml` before continuing.
* Plan to record the total line count and note it in the chat.
* If `pr-reference.xml` is not provided, run `git fetch {{remote}} {{branch}}` using `${input:branch:origin/main}`.
* Plan to create `pr-reference.xml` using the repository scripts that match the host environment. Avoid other commands for git status or diffs.
* Check local scripts in `./scripts/dev-tools/` first, then fall back to the VS Code extension path `~/.vscode/extensions/ise-hve-essentials.hve-core-*/scripts/dev-tools/`.
* Locate extension scripts when needed using the following commands:

  ```bash
  # Find PowerShell script
  pwsh -c '$SCRIPT = Get-ChildItem -Path "$HOME/.vscode/extensions" -Filter "Generate-PrReference.ps1" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName; Write-Host "Found: $SCRIPT"'

  # Find shell script
  find ~/.vscode/extensions -name "pr-ref-gen.sh" 2>/dev/null | head -1
  ```

* For Unix-like shells, prefer `./scripts/dev-tools/pr-ref-gen.sh` when available or the extension path.
* For Windows PowerShell hosts, prefer `pwsh -File ./scripts/dev-tools/Generate-PrReference.ps1` when available or the extension path.
* Use the following command variants when needed:

  * Default: `./scripts/dev-tools/pr-ref-gen.sh`
  * Exclude markdown: `./scripts/dev-tools/pr-ref-gen.sh --no-md-diff`
  * Custom base branch: `./scripts/dev-tools/pr-ref-gen.sh --no-md-diff --base-branch ${input:branch}`
  * Default: `pwsh -File ./scripts/dev-tools/Generate-PrReference.ps1`
  * Exclude markdown: `pwsh -File ./scripts/dev-tools/Generate-PrReference.ps1 -ExcludeMarkdownDiff`
  * Custom base branch: `pwsh -File ./scripts/dev-tools/Generate-PrReference.ps1 -ExcludeMarkdownDiff -BaseBranch ${input:branch}`

* Capture the total line count from the script output and note it in the chat.

### Step 2: Discover PR templates

Search for PR templates and decide whether to use the repository template or fallback format.

* Search for template files using the `**/PULL_REQUEST_TEMPLATE.md` pattern and the `.github/PULL_REQUEST_TEMPLATE/` directory.
* Follow this location priority when choosing a single template:

  1. `.github/pull_request_template.md`
  2. `docs/pull_request_template.md`
  3. `pull_request_template.md`

* If a template is found, read the entire file, parse H2 sections, and store the structure for Step 4.
* If multiple templates exist, list them with first-line descriptions and ask the user to choose one.
* If none are found, report that the standard `pr.md` format is used.

### Step 3: Analyze pr-reference.xml

Read and analyze the entire `pr-reference.xml` file, which includes the branch name, commit history compared to `${input:branch:origin/main}`, and the detailed diff.

* Confirm the read reached the reported line count and includes `</full_diff>` and `</commit_history>` before moving on.
* Build a complete understanding of the changes before drafting any PR content.
* Use `pr-reference.xml` only for generating `pr.md`.

### Step 4: Generate the PR description

After completing the analysis, generate a Markdown PR description in `pr.md`.

* Delete `pr.md` before writing a new version if it already exists, and do not read the old file.

#### Template integration

Use this section only when a template was found in Step 2.

* Map `pr.md` content to the template in a flexible way that keeps the template structure intact.
* Use the table below as guidance for where content typically fits.

| pr.md Component       | Template Section           | Guidance                                          |
| --------------------- | -------------------------- | ------------------------------------------------- |
| H1 Title              | Document title             | Replace the existing title with the generated one |
| Summary paragraph     | ## Description             | Add after the placeholder comment if present      |
| Change bullets        | ## Description             | Append after the summary                          |
| Detected issue refs   | ## Related Issue(s)        | Replace placeholder comment if present            |
| Detected change types | ## Type of Change          | Check matching `- [ ]` boxes                      |
| Security analysis     | ## Security Considerations | Check boxes and add notes when issues exist       |
| Notes or Important    | ## Additional Notes        | Insert content                                    |

* For each detected change type, replace the matching `- [ ]` checkbox with `- [x]`.
* Extract related issues from commits and branch names using the patterns below, then replace the placeholder comment when available.
* Check the security section checkbox that confirms no secrets or sensitive data when applicable.
* Leave dependency review checkboxes unchecked.
* Preserve template formatting and remove only placeholder comments that were filled.
* Keep unfilled placeholders for manual completion.
* Report that the repository template was used once generation completes.

#### Change type detection patterns

Analyze changed files from the `<full_diff>` section of `pr-reference.xml` and extract file paths from diff headers like `diff --git a/path/to/file b/path/to/file`.

| Change Type                | File Pattern             | Branch Pattern              | Commit Pattern              |
|----------------------------|--------------------------|-----------------------------|-----------------------------|
| Bug fix                    | N/A                      | `^(fix\|bugfix\|hotfix)/` | `^fix(\(.+\))?:`          |
| New feature                | N/A                      | `^(feat\|feature)/`        | `^feat(\(.+\))?:`         |
| Breaking change            | N/A                      | N/A                         | `BREAKING CHANGE:\|^.+!:`  |
| Documentation update       | `^docs/.*\.md$`          | `^docs/`                    | `^docs(\(.+\))?:`         |
| GitHub Actions workflow    | `^\.github/workflows/.*` | N/A                         | `^ci(\(.+\))?:`           |
| Linting configuration      | `\.markdownlint.*`       | N/A                         | `^lint(\(.+\))?:`         |
| Security configuration     | `^scripts/security/.*`   | N/A                         | N/A                         |
| DevContainer configuration | `^\.devcontainer/.*`     | N/A                         | N/A                         |
| Dependency update          | `package.*\.json`        | `^deps/`                    | `^deps(\(.+\))?:`         |
| Copilot instructions       | `.*\.instructions\.md$` | N/A                         | N/A                         |
| Copilot prompt             | `.*\.prompt\.md$`       | N/A                         | N/A                         |
| Copilot agent              | `.*\.agent\.md$`       | N/A                         | N/A                         |
| Script or automation       | `.*\.(ps1\|sh\|py)$`    | N/A                         | N/A                         |

Priority rules:

* AI artifact patterns (`.instructions.md`, `.prompt.md`, `.agent.md`) take precedence over documentation updates.
* Any breaking change in commits marks the PR as breaking.
* Multiple change types can be selected.

#### Issue reference extraction

Extract issue references from commit messages and branch names using the following patterns.

| Pattern               | Source         | Output Format     |
|-----------------------|----------------|-------------------|
| `Fixes #(\d+)`        | Commit message | `Fixes #123`      |
| `Closes #(\d+)`       | Commit message | `Closes #123`     |
| `Resolves #(\d+)`     | Commit message | `Resolves #123`   |
| `#(\d+)` (standalone) | Commit message | `Related to #123` |
| `/(\d+)-`             | Branch name    | `Related to #123` |
| `AB#(\d+)`            | Commit or branch | `AB#12345` (ADO) |

Deduplicate issue numbers and preserve the action prefix from the first occurrence.

#### GHCP Maturity Detection

After detecting GHCP files from Change Type Detection, analyze frontmatter for maturity levels:

1. For each file matching `.instructions.md`, `.prompt.md`, or `.agent.md` patterns:
   * Extract file content from `<full_diff>` section (look for `+++ b/...` paths)
   * Parse YAML frontmatter between `---` delimiters in the added content
   * Read `maturity` field value (default: `stable` if not present)

2. Categorize files by maturity:

   | Maturity Level | Risk Level | Indicator | Action |
   |----------------|------------|-----------|--------|
   | stable | ✅ Low | Production-ready | Include in standard change list |
   | preview | 🔶 Medium | Pre-release feature | Flag in dedicated section |
   | experimental | ⚠️ High | May have breaking changes | Add warning banner |
   | deprecated | 🚫 Critical | Scheduled for removal | Add deprecation notice |

3. If non-stable GHCP files detected, generate "GHCP Artifact Maturity" section in `pr.md`

#### GHCP Maturity Output

If non-stable GHCP files are detected, add this section to `pr.md` before the Notes section:

##### Warning Banners

For experimental files:

```markdown
> [!WARNING]
> This PR includes **experimental** GHCP artifacts that may have breaking changes.
> - `path/to/file.prompt.md`
```

For deprecated files:

```markdown
> [!CAUTION]
> This PR includes **deprecated** GHCP artifacts scheduled for removal.
> - `path/to/legacy.agent.md`
```

##### Maturity Summary Table

Always include when any GHCP files are detected:

```markdown
## GHCP Artifact Maturity

| File | Type | Maturity | Notes |
|------|------|----------|-------|
| `new-feature.prompt.md` | Prompt | ⚠️ experimental | Pre-release only |
| `helper.agent.md` | Agent | 🔶 preview | Pre-release only |
| `coding.instructions.md` | Instructions | ✅ stable | All builds |
```

##### Maturity Checklist

If any non-stable files detected, add:

```markdown
### GHCP Maturity Acknowledgment
- [ ] I acknowledge this PR includes non-stable GHCP artifacts
- [ ] Non-stable artifacts are intentional for this change
```

### Step 5: Run security and compliance analysis

After PR generation, analyze `pr-reference.xml` for security and compliance issues and report the results in the chat.

### Step 6: Clean up

Delete `pr-reference.xml` after the analysis is complete.

## PR Content Generation Principles

### Title construction

* Use the branch name as the primary source for the title, for example `feat/add-authentication`.
* Follow the format `{type}({scope}): {concise description}`.
* Use commit messages when the branch name lacks detail.

### Accuracy and detail

* Include only changes visible in `pr-reference.xml`.
* Describe what changed without speculating on why.
* Use past tense in descriptions.
* Base conclusions on the complete `pr-reference.xml` analysis.
* Keep technical descriptions neutral and human-friendly.

### Condensation and focus

* Describe the final state of the code rather than intermediate steps.
* Combine related changes into single descriptive points.
* Use `pr-reference.xml` as the source of truth.
* Avoid excessive sub-bullets unless they add genuine clarification value.
* Consolidate information into the main bullet where possible.

### Style and structure

* Match tone and terminology from commit messages.
* Use natural, conversational language.
* Include essential context directly in the main bullet point.
* Add sub-bullets only when they add clarifying or critical context.
* Include Notes, Important, or Follow-up sections only when supported by commit messages or code comments.
* Group and order changes by significance and importance.
  * Rank significance and importance by cross-checking the branch name, commit count, and changed line volume.
  * Place the most significant changes first.

### Follow-up task guidance

* Identify follow-up tasks only when they are evidenced in `pr-reference.xml`.
* Keep follow-up tasks specific, actionable, and tied to code, files, folders, components, or blueprints.

## PR File Format (`pr.md`)

### If a template is found

Use the repository template structure with populated sections when a template is available.

* Preserve all H2 headers from the template.
* Fill sections with generated content.
* Check applicable checkboxes.
* Keep unfilled sections with placeholder comments.

### If no template is found

Prefer this standalone format when no repository template is available.

<!-- <example> -->
```markdown
# {{type}}({{scope}}): {{concise description}}

{{Summary paragraph of overall changes in natural, human-friendly language}}

- {{type}}({{scope}}): {{description of change with key context included}}

- {{type}}({{scope}}): {{description of change}}
  - {{sub-bullet only if it adds genuine clarification value}}

- {{type}}: {{description of change without scope, including essential details}}

## Notes (optional)

- Note 1 identified from code comments or commit message
- Note 2 identified from code comments or commit message

## Important (optional)

- Critical information 1 identified from code comments or commit message
- Warning 2 identified from code comments or commit message

## Follow-up Tasks (optional)

- Task 1 with file reference
- Task 2 with specific component mention

{{emoji representing the changes}} - Generated by Copilot
```
<!-- </example> -->

### Type and scope reference

Determine type and scope from commits in `pr-reference.xml`.

## Pre-generation checklist

Immediately before generating the PR, confirm the following:

* [ ] The core guidance in this prompt will be followed.
* [ ] The required steps in this prompt will be followed.
* [ ] The PR content generation principles will be followed.
* [ ] The PR content matches the PR file format.
* [ ] Markdown editing conventions in this repository are applied.

## Post-generation checklist

After generating the PR, review `pr.md` and confirm the following:

* [ ] The core guidance was followed.
* [ ] The required steps were followed.
* [ ] The PR content generation principles were followed.
* [ ] The PR description includes all significant changes and omits trivial or auto-generated ones.
* [ ] Referenced files and paths are accurate.
* [ ] Follow-up tasks are actionable and clearly scoped.

## Security Analysis Output

After PR generation, analyze `pr-reference.xml` and provide the following analysis in the chat.

1. ✅/❌ - Customer information leaks
2. ✅/❌ - Secrets or credentials
3. ✅/❌ - Non-compliant language (for example, FIXME, WIP, or to-do language in committed code)
4. ✅/❌ - Unintended changes or accidental inclusion of files
5. ✅/❌ - Missing referenced files
6. ✅/❌ - Conventional commits compliance for title and reviewed commit messages

Provide this analysis after generating the PR description at the end of the conversation.

---

Follow the required steps and create a new `pr.md` file.
