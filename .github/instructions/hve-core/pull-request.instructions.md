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
3. If no required check commands are discovered, skip command execution and continue.
4. If no issue references are discovered, use `None` in the related issues section.
5. If PR creation fails, apply Step 7 shared error handling in order: branch readiness, permissions, duplicate PR handling.

## Required Steps

### Step 1: Pre-requisite Validation

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
5. Capture pre-check snapshot with `git status --porcelain`.
6. Apply sandbox-safe check execution rules when required:
   * In sandbox or no-side-effect contexts, run only checks that do not write outside the allowed workspace.
   * When a required check cannot be run safely, record it as `Not Run (sandbox-safe restriction)` with the reason and continue using available check results.
7. Run each command in `checkCommands` and record pass/fail status with a concise output summary.
8. Capture post-check snapshot with `git status --porcelain`.
9. Compute decision flags:
   * `hasNewChanges`: post-check snapshot introduced new or modified files not present before checks.
   * `hasFailures`: any check command returned a non-zero exit code.
10. Apply this decision matrix:

| hasNewChanges | hasFailures | Outcome |
|---------------|-------------|---------|
| `false`       | `false`     | Continue to Step 2 |
| `true`        | `false`     | Block and provide remediation: list changed files, stage and commit only check-introduced files with `git add <changed-files> && git commit -m "style: apply lint fixes"`, then restart Step 1 |
| `false`       | `true`      | Block and provide remediation: report failed checks with output, provide specific fix guidance, then restart Step 1 |
| `true`        | `true`      | Block and provide combined remediation for changed files and failed checks in one message, then restart Step 1 |

11. When no template is resolved or no check commands are found, apply Canonical Fallback Rules and continue.

Exit criteria:

* Template state is resolved and persisted for reuse.
* Either Step 2 is reached or a single blocking remediation message is provided and Step 1 restarts after fixes.

### Step 2: Generate PR Reference

Entry criteria:

* Step 1 completed with no blocking check outcome.

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

### Step 7: Create Pull Request When Requested by User

Entry criteria:

* `.copilot-tracking/pr/pr.md` exists.
* User explicitly requested PR creation.

Create a pull request using MCP tools. Skip this step when the user has not requested PR creation and proceed to Step 8.

#### Step 7A: Branch Readiness

1. Check whether the current branch is pushed to the remote.
2. If not pushed, push the current branch before continuing.

Exit criteria:

* The head branch exists on the remote and is ready for PR creation.

#### Step 7B: Approval Loop

1. Extract the PR title and body from `pr.md`:
   * Title is the first line of pr.md with the leading `# ` stripped (for example, `# feat(scope): description` becomes `feat(scope): description`).
   * Body is the full content of pr.md with all markdown formatting preserved, including the H1 line with `#`.
2. Present the PR title and a summary of the body inline in chat. Reference [pr.md](../../../.copilot-tracking/pr/pr.md) for full content and ask the user to confirm or request changes.
3. If the user requests updates to title, body, or style, apply changes to `pr.md` and repeat this substep until approved.

Exit criteria:

* User has approved the PR title and body.

#### Step 7C: PR Creation and Error Handling

1. Prepare the base branch reference by stripping any remote prefix (for example, `origin/main` becomes `main`).
2. Create the pull request by calling `mcp_github_create_pull_request` with these parameters:
   * `owner`: Repository owner derived from the git remote URL.
   * `repo`: Repository name derived from the git remote URL.
   * `title`: Extracted title without the leading `#`.
   * `body`: Full pr.md content.
   * `head`: Current branch name.
   * `base`: Target branch with remote prefix stripped.
   * `draft`: Set when the user requests a draft PR.
3. If creation fails, apply Canonical Fallback Rules and then apply the Step 7 Shared Error Handling subsection.
4. Share the PR URL after successful creation.

Exit criteria:

* Pull request is created successfully and URL is shared, or a clear next action is provided for a blocking error.

#### Step 7 Shared Error Handling

Apply this ordered error handling when PR creation fails:

1. Branch not found: verify Step 7A completed and the branch is present on remote.
2. Permission denied: inform the user about required repository permissions.
3. Duplicate PR: check for an existing PR on the same branch and offer to update it with `mcp_github_update_pull_request`.

### Step 8: Cleanup

Entry criteria:

* PR content generation is complete, and Step 7 is complete or skipped.

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
