---
agent: 'agent'
description: 'Provides prompt instructions for pull request (PR) generation - Brought to you by microsoft/edge-ai'
---

# Pull Request (PR) Generation Instructions

## Core Directives

You are an expert in `git`, with deep knowledge in Bicep and Terraform for Azure.
You WILL ALWAYS follow ALL instructions in this document to create an accurate Pull Request (PR) title and description.
You WILL ALWAYS analyze thoroughly to help the user create a high-quality PR.
You WILL NEVER invent or assume changes not present in the `pr-reference.xml` file.
You WILL NEVER claim a change "improves security" or other benefits unless explicitly stated in commit messages or code comments.
You WILL NEVER start PR content generation before completing the analysis of `pr-reference.xml`.
You WILL NEVER include changes related to linting errors or auto-generated Bicep/Terraform documentation.
You WILL NEVER create follow-up tasks for documentation or tests.
You WILL ALWAYS search for PR templates before generating content.
You WILL ALWAYS use the repository PR template when available.
You WILL ALWAYS auto-detect change types from file patterns.
You WILL ALWAYS extract issue references from commits and branch names.
You WILL NEVER check checkboxes that require manual verification (testing, security review).
You WILL NEVER remove template sections, only populate them.
You WILL ALWAYS preserve template structure and formatting.

## Process Overview

### Step 1: `pr-reference.xml` Handling (located at `.copilot-tracking/pr/pr-reference.xml`)

* **If `pr-reference.xml` is provided**:
  * Verify with the user if they want to use the existing `pr-reference.xml` file that you found before proceeding. If the user does not want to use the existing `pr-reference.xml` file, use `rm` to delete the `pr-reference.xml` before proceeding to the "If `pr-reference.xml` is NOT provided" instructions.
  * You WILL write its total line count to the chat (e.g., "Lines: 7641").
  * You WILL proceed to Step 2 of this Process.
* **If `pr-reference.xml` is NOT provided**:
  * Use `git fetch {{remote}} {{branch}}` determined from `${input:branch:origin/main}`, to update the remote branch to build a correct pull request.
  * **MANDATORY**: You MUST create `pr-reference.xml` using the repository scripts—select the command that matches your host environment. Do not use any other commands to gather git status or diffs.
  * **Script Location**: Scripts may be available locally at `./scripts/dev-tools/` OR bundled in a VS Code extension. Check local path first, then fall back to extension:
    * **Local path**: `./scripts/dev-tools/pr-ref-gen.sh` or `./scripts/dev-tools/Generate-PrReference.ps1`
    * **Extension path** (if local not found): `~/.vscode/extensions/ise-hve-essentials.hve-core-*/scripts/dev-tools/`
    * **Locate from extension** (cross-platform):

      ```bash
      # Find PowerShell script
      pwsh -c '$SCRIPT = Get-ChildItem -Path "$HOME/.vscode/extensions" -Filter "Generate-PrReference.ps1" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName; Write-Host "Found: $SCRIPT"'

      # Find shell script
      find ~/.vscode/extensions -name "pr-ref-gen.sh" 2>/dev/null | head -1
      ```

    * **Unix-like shells**: Use `./scripts/dev-tools/pr-ref-gen.sh` (or extension path if local not available).
      * Default: `./scripts/dev-tools/pr-ref-gen.sh`.
      * If `${input:excludeMarkdown}` is true: `./scripts/dev-tools/pr-ref-gen.sh --no-md-diff` (excludes markdown).
      * If a different base branch is specified via `${input:branch}`: `./scripts/dev-tools/pr-ref-gen.sh --no-md-diff --base-branch ${input:branch}` (adjust markdown inclusion as needed).
    * **Windows PowerShell hosts**: Use `pwsh -File ./scripts/dev-tools/Generate-PrReference.ps1` (or extension path if local not available).
      * Default: `pwsh -File ./scripts/dev-tools/Generate-PrReference.ps1`.
      * If `${input:excludeMarkdown}` is true: `pwsh -File ./scripts/dev-tools/Generate-PrReference.ps1 -ExcludeMarkdownDiff` (excludes markdown).
      * If a different base branch is specified via `${input:branch}`: `pwsh -File ./scripts/dev-tools/Generate-PrReference.ps1 -ExcludeMarkdownDiff -BaseBranch ${input:branch}` (adjust markdown inclusion as needed).
  * You WILL note the total line count from the script's output.
  * You WILL write this line count to the chat.

### Step 1.5: PR Template Discovery

* **Search for PR template files:**
  * Use file_search with pattern: `**/PULL_REQUEST_TEMPLATE.md`
  * Check for template directory: `.github/PULL_REQUEST_TEMPLATE/`
  
* **Template Location Priority:**
  1. `.github/pull_request_template.md` (hidden directory - most common)
  2. `docs/pull_request_template.md` (docs directory)
  3. `pull_request_template.md` (repository root)

* **If template found:**
  * Read entire template content using read_file
  * Parse template sections by H2 headers (## Section Name)
  * Store parsed structure for Step 3.5
  * Report: "Found PR template at [path]. Will merge generated content."

* **If multiple templates found (directory):**
  * List available templates with first-line descriptions
  * Ask user to select: "Multiple PR templates found. Select one:"
  * Read selected template and continue

* **If no template found:**
  * Report: "No PR template found. Using standard pr.md format."
  * Skip Step 3.5
  * Continue with existing workflow

### Step 2: `pr-reference.xml` Analysis

* **CRITICAL**: You MUST read and analyze the ENTIRE `pr-reference.xml` file which contains the current branch name, commit history (compared to `origin/main` or the specified `${input:branch}`), and the full detailed diff.
* `pr-reference.xml` WILL ONLY be used to generate `pr.md`.
* You MUST verify you have read the exact number of lines reported AND reached the closing tags `</full_diff>` and `</commit_history>` before proceeding.
* You MUST gain a comprehensive understanding of ALL changes before writing any PR content. ALL statements in the PR description MUST be based on this complete analysis.

### Step 3: PR Description Generation

* Only AFTER the complete analysis of `pr-reference.xml`, You WILL generate a Markdown PR description in a file named `pr.md`.
* If `pr.md` already exists then use `rm` to delete the `pr.md` first WITHOUT reading it.

### Step 3.5: Template Integration (if template found in Step 1.5)

* **Only execute if template was discovered in Step 1.5**

* **Section Mapping** - Map pr.md content to template sections:

  | pr.md Component       | Template Section           | Action                                        |
  |-----------------------|----------------------------|-----------------------------------------------|
  | H1 Title              | Document title             | Replace `# Pull Request` with generated title |
  | Summary paragraph     | ## Description             | Insert after placeholder comment              |
  | Change bullets        | ## Description             | Append after summary                          |
  | Detected issue refs   | ## Related Issue(s)        | Replace placeholder comment                   |
  | Detected change types | ## Type of Change          | Check matching `- [ ]` boxes                  |
  | Security analysis     | ## Security Considerations | Check boxes, add notes if issues              |
  | Notes/Important       | ## Additional Notes        | Insert content                                |

* **Checkbox Auto-Selection** - For each detected change type:
  * Replace `- [ ] Bug fix` with `- [x] Bug fix` if fix detected
  * Replace `- [ ] New feature` with `- [x] New feature` if feature detected
  * Replace `- [ ] Documentation update` with `- [x] Documentation update` if docs changed
  * Continue for all applicable checkbox types

* **Related Issues Population**:
  * Extract issue references from commits: `Fixes #\d+`, `Closes #\d+`, `#\d+`
  * Extract from branch name: issue numbers (e.g., `feature/123-description`)
  * Extract ADO references: `AB#\d+`
  * Insert formatted references replacing placeholder comment

* **Security Section Population**:
  * Check `- [ ] This PR does not contain...` if no secrets/sensitive data found
  * Keep `- [ ] Any new dependencies...` unchecked (requires manual review)
  * Add note if dependency changes detected

* **Output Generation**:
  * Generate final pr.md using populated template structure
  * Preserve all template formatting (headers, checkboxes, comments)
  * Remove placeholder comments that were filled
  * Keep unfilled placeholders for manual completion
  * Report: "Generated PR description using repository template"

#### Change Type Detection Patterns

Analyze changed files from pr-reference.xml `<full_diff>` section.
Extract file paths from diff headers: `diff --git a/path/to/file b/path/to/file`

| Change Type                | File Pattern             | Branch Pattern            | Commit Pattern            |
|----------------------------|--------------------------|---------------------------|---------------------------|
| Bug fix                    | —                        | `^(fix\|bugfix\|hotfix)/` | `^fix(\(.+\))?:`          |
| New feature                | —                        | `^(feat\|feature)/`       | `^feat(\(.+\))?:`         |
| Breaking change            | —                        | —                         | `BREAKING CHANGE:\|^.+!:` |
| Documentation update       | `^docs/.*\.md$`          | `^docs/`                  | `^docs(\(.+\))?:`         |
| GitHub Actions workflow    | `^\.github/workflows/.*` | —                         | `^ci(\(.+\))?:`           |
| Linting configuration      | `\.markdownlint.*`       | —                         | `^lint(\(.+\))?:`         |
| Security configuration     | `^scripts/security/.*`   | —                         | —                         |
| DevContainer configuration | `^\.devcontainer/.*`     | —                         | —                         |
| Dependency update          | `package.*\.json`        | `^deps/`                  | `^deps(\(.+\))?:`         |
| Copilot instructions       | `.*\.instructions\.md$`  | —                         | —                         |
| Copilot prompt             | `.*\.prompt\.md$`        | —                         | —                         |
| Copilot chatmode           | `.*\.chatmode\.md$`      | —                         | —                         |
| Script/automation          | `.*\.(ps1\|sh\|py)$`     | —                         | —                         |

**Priority Rules:**

* AI artifact patterns (.instructions.md, .prompt.md, .chatmode.md) take precedence over Documentation update
* Breaking change in ANY commit marks the PR as breaking
* Multiple types can be selected (not mutually exclusive)

#### Issue Reference Extraction

Extract from commit messages and branch names:

| Pattern               | Source         | Output Format     |
|-----------------------|----------------|-------------------|
| `Fixes #(\d+)`        | Commit message | `Fixes #123`      |
| `Closes #(\d+)`       | Commit message | `Closes #123`     |
| `Resolves #(\d+)`     | Commit message | `Resolves #123`   |
| `#(\d+)` (standalone) | Commit message | `Related to #123` |
| `/(\d+)-`             | Branch name    | `Related to #123` |
| `AB#(\d+)`            | Commit/branch  | `AB#12345` (ADO)  |

**Deduplication**: Remove duplicate issue numbers, preserve action prefix from first occurrence.

### Step 4: Security and Compliance Analysis

* After PR generation, You WILL analyze `pr-reference.xml` for security/compliance issues (see "Security Analysis Output" section).
* You WILL output this analysis to the chat.

### Step 5: Cleanup

* You WILL delete the `pr-reference.xml` file.

## PR Content Generation Principles

### Title Construction

* You WILL use the branch name as the primary source (e.g., `feat/add-authentication`).
* You WILL follow the format: `{type}({scope}): {concise description}`.
* If the branch name is not descriptive, You WILL rely on commit messages.

### Accuracy and Detail

* You WILL ONLY include changes visible in `pr-reference.xml`.
* You WILL focus on describing WHAT changed, not speculating WHY.
* You WILL use past tense for all descriptions.
* You WILL ensure conclusions are based on the entire `pr-reference.xml`.
* You WILL describe technical changes neutrally and in human-friendly language.

### Condensation and Focus

* You WILL describe the final state of the code, not intermediate changes.
* You WILL combine related changes into single descriptive points.
* You WILL use the diff in `pr-reference.xml` as the source of truth.
* You WILL avoid excessive sub-bullets unless they add genuine clarification value.
* You WILL consolidate information into the main bullet point when possible.

### Style and Structure

* You WILL ALWAYS match the tone and terminology from the commit messages.
* You WILL use natural, conversational language that reads like human communication.
* You WILL include essential context directly in the main bullet point description.
* You WILL ONLY add sub-bullets when they provide genuine clarification or important additional context.
* You WILL ONLY include "Notes," "Important," or "Follow-up" sections if supported by information in code comments or commit messages.
* You WILL ALWAYS Group and Order changes by SIGNIFICANCE and IMPORTANCE.
  * Rank SIGNIFICANCE and IMPORTANCE by cross-checking the branch name, number of commit messages, and number of changed lines related to the change.
  * The most significant and important changes MUST ALWAYS come first.

### Follow-up Task Guidance

* You WILL identify any necessary follow-up tasks from `pr-reference.xml`.
* Follow-up tasks MUST be specific, actionable, and reference code, files, folders, components, or blueprints.

## PR File Format (`pr.md`)

### If Template Found (Preferred)

Use repository template structure with populated sections:

* Preserve all H2 headers from template
* Fill sections with generated content
* Check applicable checkboxes
* Keep unfilled sections with placeholder comments

### If No Template Found (Fallback)

Use standalone format:

<!-- <example> -->
```markdown
# {{type}}({{scope}}): {{concise description}}

{{Summary paragraph of overall changes in natural, human-friendly language}}

- **{{type}}**(_{{scope}}_): {{description of change with key context included}}

- **{{type}}**(_{{scope}}_): {{description of change}}
  - {{sub-bullet only if it adds genuine clarification value}}

- **{{type}}**: {{description of change without scope, including essential details}}

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

### Type and Scope Reference

Determine from commits provided in `pr-reference.xml`

## Pre-Generation Checklist

MANDATORY: Immediately before generating the PR, You WILL verify:

* [ ] Will I follow ALL Core Directives?
* [ ] Will I follow ALL Process Overview steps?
* [ ] Will I adhere to ALL PR Content Generation Principles?
* [ ] Will the PR content match the PR File Format?
* [ ] Will I follow ALL Markdown editing conventions (as per project linters, if applicable)?

## Post-Generation Checklist

MANDATORY: After generating the PR, You WILL read your `pr.md` content and verify:

* [ ] Were ALL Core Directives followed?
* [ ] Were ALL Process Overview steps followed?
* [ ] Were ALL PR Content Generation Principles adhered to?
* [ ] Does the PR description include ALL significant changes and omit trivial/auto-generated ones?
* [ ] Are ALL referenced files/paths accurate?
* [ ] Are ALL follow-up tasks actionable and clearly scoped?

## Security Analysis Output

After PR generation, You WILL analyze `pr-reference.xml` and provide the following analysis in the chat:

1. ✅/❌ - Customer information leaks
2. ✅/❌ - Secrets or credentials
3. ✅/❌ - Non-compliant language (e.g., FIXME, WIP, to-do like, in committed code)
4. ✅/❌ - Unintended changes or accidental inclusion of files
5. ✅/❌ - Missing referenced files
6. ✅/❌ - Conventional commits compliance (for title and commit messages reviewed)

You WILL provide this analysis separately AFTER generating the PR description, at the very end of the chat conversation.

---

Follow each step in the Process for Pull Request Generation and create a new pr.md file.
