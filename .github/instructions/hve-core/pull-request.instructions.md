---
description: 'Required instructions for pull request description generation and optional PR creation using diff analysis, subagent review, and MCP tools - Brought to you by microsoft/hve-core'
applyTo: '**/.copilot-tracking/pr/**'
---

# Pull Request Instructions

Instructions for generating pull request descriptions from branch diffs using the pr-reference Skill and parallel subagent review.

## Core Guidance

* Apply git expertise when interpreting diffs.
* Keep PR content grounded in pr-reference.xml only.
* Keep writing style human-readable and high quality while maintaining technical detail.
* Avoid claiming benefits unless commit messages or code comments state them explicitly.
* Avoid mentioning linting errors or auto-generated documentation.
* Ask the user for direction when progression is unclear.
* Check for PR templates before generating content; use the repository template when available.
* Leave checkboxes requiring manual verification unchecked.
* Preserve template structure and formatting without removing sections.

## Canonical Fallback Rules

Apply these fallback rules whenever a step references this section:

1. If no PR template is resolved, use the standard format in the PR Description Format section.
2. If a template is resolved but mapping details are ambiguous, preserve section order and map by closest semantic match.
3. If required checks cannot be discovered confidently, ask the user for direction before running commands.
4. If no issue references are discovered, use `None` in the related issues section.
5. If PR creation fails, apply Step 8 shared error handling in order: branch readiness, permissions, duplicate PR handling.

## Required Steps

### Step 1: Resolve Template State

Entry criteria:

* Repository context is available and the target branch is known.

1. Resolve PR template candidates once by searching `**/PULL_REQUEST_TEMPLATE.md` and `.github/PULL_REQUEST_TEMPLATE/`.
2. Apply location priority (case-insensitive match):
   1. `.github/PULL_REQUEST_TEMPLATE.md`
   2. `docs/PULL_REQUEST_TEMPLATE.md`
   3. `PULL_REQUEST_TEMPLATE.md`
3. If multiple templates exist at the same priority level, list candidates and ask the user to choose one.
4. Persist template state for later steps:
   * `templatePath`: chosen template path, or `None`.
   * `templateSections`: parsed H2 section structure when a template exists.
   * `checkCommands`: backtick-wrapped required check commands from checklist items (for example, under "Required Automated Checks").

When no template is resolved, apply Canonical Fallback Rules and continue.

Exit criteria:

* Template state is resolved and persisted for reuse.

### Step 2: Generate PR Reference

Entry criteria:

* Step 1 completed.

Generate the PR reference XML file using the pr-reference skill:

1. If `.copilot-tracking/pr/pr-reference.xml` already exists, confirm with the user whether to use it before proceeding.
2. If the user declines, delete the file before continuing.
3. If not present, run `git fetch` for the target branch.
4. Use the pr-reference skill to generate the XML file with the provided base branch and any requested options (such as excluding markdown diffs).
5. Note the size of the generated output in the chat.

Exit criteria:

* `.copilot-tracking/pr/pr-reference.xml` exists and is ready for chunk review.

### Step 3: Parallel Subagent Review

Entry criteria:

* `.copilot-tracking/pr/pr-reference.xml` exists.

Analyze the pr-reference.xml using parallel subagents:

1. Get chunk information from the PR reference XML to determine how many chunks exist and their line ranges.
2. Launch parallel subagents via `runSubagent` or `task` tools, one per chunk (or groups of chunks for very large diffs).
3. If `runSubagent` and `task` are unavailable, review chunks sequentially in the parent agent while preserving the same output contract:
   * Create `.copilot-tracking/pr/subagents/NN-pr-reference-log.md` for each chunk using the same template and numbering rules.
   * Record the same completion details expected from subagent runs, including clarifying questions when analysis is ambiguous.

Each subagent invocation provides these inputs:

* Chunk number(s) to review.
* Path to pr-reference.xml.
* Output file path: `.copilot-tracking/pr/subagents/NN-pr-reference-log.md` (where NN is the zero-padded subagent number, for example, 01, 02, 03).

Each subagent receives instructions to follow this protocol:

1. Use the pr-reference skill to read the diff content for the assigned chunk(s) from the PR reference XML.
2. Analyze the changes: identify files changed, what was added, modified, or deleted, and why (inferred from context).
3. Create the output file new at the provided path; do not read the file if it already exists.
4. Document findings following the Subagent PR Reference Log template from the Tracking File Structure section: files changed, nature of changes, technical details, notable patterns.
5. Follow writing-style conventions from `writing-style.instructions.md` when documenting findings.

Each subagent returns: output file path, completion status, and any clarifying questions when analysis is ambiguous.

* Repeat subagent invocations with answers to clarifying questions until all chunks are reviewed.
* Wait for all subagents to complete before proceeding.

Exit criteria:

* All chunks are reviewed and each subagent produced an output file or a resolved clarification.

### Step 4: Merge and Verify Findings

Entry criteria:

* Step 3 outputs exist for all assigned chunk ranges.

Merge subagent findings into a unified analysis:

1. Create `.copilot-tracking/pr/pr-reference-log.md`.
2. Read each `.copilot-tracking/pr/subagents/NN-pr-reference-log.md` file.
3. Merge findings into the primary `pr-reference-log.md`, organizing by significance.
4. While merging, verify findings using search and file-read tools, especially when details are unclear or conflicting across subagent reports.
5. Progressively update `pr-reference-log.md` with any additional findings from verification.
6. Ensure what's captured represents the current state of the codebase being merged (not intermediate changes that were later replaced on the same branch).
7. The finished `pr-reference-log.md` serves as the single source of truth for PR generation.

Exit criteria:

* `.copilot-tracking/pr/pr-reference-log.md` is complete and verified as the source of truth.

### Step 5: Prepare Template Mapping

Entry criteria:

* `templatePath` and related template state from Step 1 are available.
* `.copilot-tracking/pr/pr-reference-log.md` is complete.

1. Reuse `templatePath` and `templateSections` resolved in Step 1.
2. If `templatePath` is set, confirm that template mapping data is available for Step 6.
3. If `templatePath` is `None`, apply Canonical Fallback Rules and use the PR Description Format.

Exit criteria:

* Step 6 has an explicit mapping strategy: repository template mapping or fallback format.

### Step 6: Generate PR Description

Entry criteria:

* `.copilot-tracking/pr/pr-reference-log.md` is complete.
* Template mapping strategy is set from Step 5.

Create `.copilot-tracking/pr/pr.md` from interpreting `pr-reference-log.md`:

1. Delete `pr.md` before writing a new version if it already exists; do not read the old file.
2. If `templatePath` is set, map content to `templateSections` (follow template integration instructions from the repository's `pull-request.instructions.md` if available).
3. If `templatePath` is `None`, apply Canonical Fallback Rules and use the PR Description Format defined below.

Title:

* Use the branch name as the primary source (for example, `feat/add-authentication`).
* Format as `{type}({scope}): {concise description}`.
* Use commit messages when the branch name lacks detail.
* The title is the only place where conventional commit format appears.

Description style:

* Write in human-like form explaining what changed and the technical details.
* Write for people familiar with the codebase, but in a style that unfamiliar readers understand what changed and what the pull request offers.
* Do not overly assume benefits or overly sell the pull request.
* Describe only the current state of what's being merged into the target branch; do not include intermediate changes that were later replaced on the same branch.
* Do not use conventional commit style lists (for example, `feat(scope): description`) in the body.
* Include executive details that are well understood.
* Group changes by significance; place the most significant changes first.
* Rank significance by cross-checking branch name, commit count, and changed line volume.
* Keep descriptions neutral and human-friendly.
* Describe the final state of the code rather than intermediate steps.
* Combine related changes into single descriptive points.

Issue references:

* Extract related issues from commits and branch names.
* Place issue references in the designated template section (for example, "Related Issue(s)") when a template exists, otherwise include them in the description.
* Deduplicate issue numbers and preserve the action prefix from the first occurrence.

Exit criteria:

* `.copilot-tracking/pr/pr.md` exists with title and body aligned to template mapping or fallback format.

### Step 7: Validate PR Readiness

Entry criteria:

* `.copilot-tracking/pr/pr.md` exists.

Run PR-readiness validation even when the user has not explicitly requested direct PR creation.

#### Step 7A: Discover Required Checks

1. Start with `checkCommands` captured from the selected PR template in Step 1.
2. Expand required checks using applicable instruction files for the current change scope.
3. Build one de-duplicated ordered command list and record the source for each command (template or instruction).
4. If required checks cannot be discovered confidently, ask the user for direction before running commands.
5. Do not invent repository-specific command mappings in this file.

Exit criteria:

* Required checks are either confidently discovered, or user direction is requested before continuing.

#### Step 7B: Run and Triage Validation

1. Run all discovered required checks.
2. Record each check result as `Passed`, `Failed`, or `Skipped` (with reason).
3. For failures, categorize findings before remediation using this taxonomy:
   * `Environment/Tooling`
   * `Lint/Format`
   * `Tests`
   * `Policy/Compliance`
   * `Unknown/Mixed`
4. Provide executive details for failed checks and identified issues, including:
   * Failed check name and category.
   * PR-readiness impact (`blocking` or `non-blocking`).
   * Most likely scope or root-cause area.
   * Recommended next action.

Exit criteria:

* Validation results are captured and failed checks are triaged with executive details.

#### Step 7C: Remediation Routing

1. If fixes are bounded and localized, implement accurate direct fixes and rerun relevant failed checks.
2. If fixes require broader rewrites or refactors (cross-cutting changes, multi-area redesign, or architecture-impacting updates), stop direct remediation and recommend `/rpi`.
3. Keep remediation guidance concise and actionable.

Exit criteria:

* Validation failures are either resolved with direct fixes, or `/rpi` is recommended for larger rewrite/refactor scope.

#### Step 7D: Readiness Outcome

1. If required checks pass, continue to Step 8 when PR creation was requested.
2. If required checks remain unresolved, do not proceed with direct PR creation.
3. When PR creation was not requested, report readiness status and next actions without creating a PR.

Exit criteria:

* PR readiness status is explicit and next actions are clear.

### Step 8: Create Pull Request When Requested by User

Entry criteria:

* `.copilot-tracking/pr/pr.md` exists.
* User explicitly requested PR creation.
* Step 7 completed with required checks passing.

Create a pull request using MCP tools. Skip this step when the user has not requested PR creation and proceed to Step 9.

#### Step 8A: Branch Freshness Gate

1. Resolve `baseRefInput` from the user-provided base branch.
2. If no base branch was provided, default `baseRefInput` to `origin/main`.
3. Resolve `baseRef` used for freshness checks:
   * If `baseRefInput` starts with `origin/`, use it unchanged.
   * If `baseRefInput` is a plain branch name (for example, `main`), convert it to `origin/<branch>`.
   * Otherwise use `baseRefInput` as provided.
4. Fetch the base branch ref before comparison:
   * When `baseRef` starts with `origin/`, run `git fetch origin <branch-name-without-origin-prefix>`.
   * Otherwise fetch the needed remote refs so `baseRef` can be compared safely.
5. Compute ahead/behind counts with `git rev-list --left-right --count "${baseRef}...HEAD"`.
6. Parse the result as `behindCount aheadCount`.
7. If `behindCount` is `0`, continue to Step 8B.
8. If `behindCount` is greater than `0`, ask the user whether to update the branch before PR creation.
9. If the user declines update, block direct PR creation and provide the next action: update the branch to include `${baseRef}` and rerun Step 8.
10. If the user confirms update, ask which strategy to use: `merge` or `rebase`.
11. Execute the selected strategy using these exact command forms:
   * Merge: `git merge --no-edit ${baseRef}`
   * Rebase: `git rebase --empty=drop --reapply-cherry-picks ${baseRef}`
12. If conflicts occur, follow `.github/instructions/hve-core/git-merge.instructions.md` before continuing.
13. After update completes, continue to Step 8B.

Exit criteria:

* The branch freshness check against the selected base ref is complete.
* The branch is either confirmed current enough for PR creation, or direct PR creation is blocked with a clear next action.

#### Step 8B: Branch Pushed Readiness

1. Check whether the current branch is pushed to the remote.
2. If not pushed, push the current branch before continuing.

Exit criteria:

* The head branch exists on the remote and is ready for PR creation.

#### Step 8C: Approval Loop

1. Extract the PR title and body from `pr.md`:
   * Title is the first line of pr.md with the leading `#` stripped (for example, `# feat(scope): description` becomes `feat(scope): description`).
   * Body is the full content of pr.md with all markdown formatting preserved, including the H1 line with `#`.
2. Present the PR title and a summary of the body inline in chat. Reference [pr.md](../../../.copilot-tracking/pr/pr.md) for full content and ask the user to confirm or request changes.
3. If the user requests updates to title, body, or style, apply changes to `pr.md` and repeat this substep until approved.

Exit criteria:

* User has approved the PR title and body.

#### Step 8D: PR Creation and Error Handling

1. Prepare the base branch reference by stripping any remote prefix from `baseRef` (for example, `origin/main` becomes `main`).
2. Create the pull request by calling `mcp_github_create_pull_request` with these parameters:
   * `owner`: Repository owner derived from the git remote URL.
   * `repo`: Repository name derived from the git remote URL.
   * `title`: Extracted title without the leading `#`.
   * `body`: Full pr.md content.
   * `head`: Current branch name.
   * `base`: Target branch with remote prefix stripped.
   * `draft`: Set when the user requests a draft PR.
3. If creation fails, apply Canonical Fallback Rules and then apply the Step 8 Shared Error Handling subsection.
4. Share the PR URL after successful creation.

Exit criteria:

* Pull request is created successfully and URL is shared, or a clear next action is provided for a blocking error.

#### Step 8 Shared Error Handling

Apply this ordered error handling when PR creation fails:

1. Branch not found: verify Step 8B completed and the branch is present on remote.
2. Permission denied: inform the user about required repository permissions.
3. Duplicate PR: check for an existing PR on the same branch and offer to update it with `mcp_github_update_pull_request`.

### Step 9: Cleanup

Entry criteria:

* PR content generation is complete, and Step 8 is complete or skipped.

1. Delete `.copilot-tracking/pr/pr-reference.xml` after the analysis is complete.
2. Delete the `.copilot-tracking/pr/subagents/` directory and its contents.

Exit criteria:

* Temporary PR analysis artifacts are removed.

## Issue Reference Extraction

Extract issue references from commit messages and branch names using these patterns:

| Pattern                 | Source           | Output Format      |
|-------------------------|------------------|--------------------|
| `Fixes #(\d+)`         | Commit message   | `Fixes #123`       |
| `Closes #(\d+)`        | Commit message   | `Closes #123`      |
| `Resolves #(\d+)`      | Commit message   | `Resolves #123`    |
| `#(\d+)` (standalone)  | Commit message   | `Related to #123`  |
| `/(\d+)-`              | Branch name      | `Related to #123`  |
| `AB#(\d+)`             | Commit or branch | `AB#12345` (ADO)   |

Deduplicate issue numbers and preserve the action prefix from the first occurrence.

## PR Content Generation Principles

### Accuracy and Detail

* Include only changes visible in the pr-reference-log.md analysis.
* Describe what changed without speculating on why.
* Use past tense in descriptions.
* Base conclusions on the complete analysis.
* Keep technical descriptions neutral and human-friendly.

### Condensation and Focus

* Describe the final state of the code rather than intermediate steps.
* Combine related changes into single descriptive points.
* Avoid excessive sub-bullets unless they add genuine clarification.
* Consolidate information into the main bullet where possible.

### Style and Structure

* Match tone and terminology from commit messages.
* Use natural, conversational language.
* Include essential context directly in the main bullet point.
* Add sub-bullets only when they add clarifying or critical context.
* Include Notes, Important, or Follow-up sections only when supported by commit messages or code comments.
* Group and order changes by significance and importance.

### Follow-up Task Guidance

* Identify follow-up tasks only when evidenced in the analysis.
* Keep follow-up tasks specific, actionable, and tied to code, files, folders, components, or blueprints.

## PR Description Format

When no PR template is found in the repository, use this format:

```markdown
# {type}({scope}): {concise description}

{Summary paragraph of overall changes in natural, human-friendly language. Explain what this pull request does and what it offers to the codebase. Write for both familiar and unfamiliar readers.}

## Changes

- {Description of the most significant change with key context}
- {Description of the next change}
  - {Sub-bullet only when it adds essential clarification}
- {Description of additional changes}

## Related Issues

{Issue references extracted from commits and branch names, or "None" if no issues found}

## Notes (optional)

- {Note identified from code comments or commit messages}

## Follow-up Tasks (optional)

- {Task with specific file or component reference}
```

## Tracking File Structure

### Subagent PR Reference Log

Each subagent creates a file at `.copilot-tracking/pr/subagents/NN-pr-reference-log.md`:

```markdown
## Chunk NN Review

### Files Changed

- `path/to/file.ext` (added/modified/deleted): Brief description of changes

### Technical Details

{Detailed analysis of the changes in this chunk}

### Notable Patterns

{Any patterns, conventions, or concerns observed}
```

### Primary PR Reference Log

The main agent creates `.copilot-tracking/pr/pr-reference-log.md`:

```markdown
## PR Reference Analysis

### Summary

{High-level summary of all changes}

### Changes by Significance

#### {Most significant area}

- {Verified finding with file references}

#### {Next significant area}

- {Verified finding with file references}

### Issue References

{Extracted issue references}

### Verification Notes

{Notes from cross-checking subagent findings}
```
