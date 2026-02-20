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

## Required Steps

### Step 1: Pre-requisite Validation

Run required checks before generating the PR reference. This step discovers the PR template inline to extract check commands from checklist items; the later template discovery step (Step 5) performs full parsing for PR content generation.

1. Search for the PR template: check `**/PULL_REQUEST_TEMPLATE.md` and `.github/PULL_REQUEST_TEMPLATE/` directory. Follow location priority (case-insensitive match):
   1. `.github/PULL_REQUEST_TEMPLATE.md`
   2. `docs/PULL_REQUEST_TEMPLATE.md`
   3. `PULL_REQUEST_TEMPLATE.md`
2. If a template is found, read it and extract required check commands. Parse checklist items containing backtick-wrapped commands under headings such as "Required Automated Checks."
3. If no template is found or no check commands exist in the template, proceed to Step 2.
4. Capture the current working tree state by running `git status --porcelain` and saving the output.
5. Run each extracted check command via terminal and record the result (pass or fail) along with a summary of the output.
6. Capture the working tree state again by running `git status --porcelain` after all checks complete.
7. Compare the two working tree snapshots and evaluate check results together:
   * Identify check-introduced changes: new files or modifications that were not present before checks ran (such as auto-formatting fixes).
   * Identify check failures: commands that returned a non-zero exit code.
   * If both check-introduced changes and check failures exist, report everything in a single message before blocking.
   * If check-introduced changes exist, provide remediation guidance:
     * List the specific files that changed.
     * Stage and commit only the check-introduced files: `git add <changed-files> && git commit -m "style: apply lint fixes"`
     * Re-run the failing checks to confirm they pass.
   * If check failures exist without new changes, provide:
     * Which checks failed and their output.
     * Specific remediation guidance (for example, "Run `npm run lint:md` locally and fix reported issues").
     * Instructions to stage and commit fixes before retrying.
   * After the user addresses all issues, re-run this step from the beginning.
   * If the snapshots are identical and all checks pass, proceed to Step 2.

### Step 2: Generate PR Reference

Generate the PR reference XML file using the pr-reference skill:

1. If `.copilot-tracking/pr/pr-reference.xml` already exists, confirm with the user whether to use it before proceeding.
2. If the user declines, delete the file before continuing.
3. If not present, run `git fetch` for the target branch.
4. Use the pr-reference skill to generate the XML file with the provided base branch and any requested options (such as excluding markdown diffs).
5. Note the size of the generated output in the chat.

### Step 3: Parallel Subagent Review

Analyze the pr-reference.xml using parallel subagents:

1. Get chunk information from the PR reference XML to determine how many chunks exist and their line ranges.
2. Launch parallel subagents via `runSubagent` or `task` tools, one per chunk (or groups of chunks for very large diffs).

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

### Step 4: Merge and Verify Findings

Merge subagent findings into a unified analysis:

1. Create `.copilot-tracking/pr/pr-reference-log.md`.
2. Read each `.copilot-tracking/pr/subagents/NN-pr-reference-log.md` file.
3. Merge findings into the primary `pr-reference-log.md`, organizing by significance.
4. While merging, verify findings using search and file-read tools, especially when details are unclear or conflicting across subagent reports.
5. Progressively update `pr-reference-log.md` with any additional findings from verification.
6. Ensure what's captured represents the current state of the codebase being merged (not intermediate changes that were later replaced on the same branch).
7. The finished `pr-reference-log.md` serves as the single source of truth for PR generation.

### Step 5: Discover PR Templates

Search for PR templates and decide whether to use the repository template:

1. Search for template files using `**/PULL_REQUEST_TEMPLATE.md` and check `.github/PULL_REQUEST_TEMPLATE/` directory.
2. Follow location priority (case-insensitive match):
   1. `.github/PULL_REQUEST_TEMPLATE.md`
   2. `docs/PULL_REQUEST_TEMPLATE.md`
   3. `PULL_REQUEST_TEMPLATE.md`
3. If found, read the entire template, parse H2 sections, and store the structure for Step 6.
4. If multiple templates exist, list them and ask the user to choose.
5. If none found, report that a standard format is used (see the PR Description Format section).

### Step 6: Generate PR Description

Create `.copilot-tracking/pr/pr.md` from interpreting `pr-reference-log.md`:

1. Delete `pr.md` before writing a new version if it already exists; do not read the old file.
2. If a PR template was found, map content to the template structure (follow template integration instructions from the repository's `pull-request.instructions.md` if available).
3. If no PR template was found, use the PR Description Format defined below.

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

### Step 7: Create Pull Request When Requested By User

Create a pull request using MCP tools. Skip this step when the user has not requested PR creation and proceed to Step 8.

1. Check whether the current branch is pushed to the remote. If not, push it.
2. Extract the PR title and body from `pr.md`:
   * Title is the first line of pr.md with the leading `# ` stripped (for example, `# feat(scope): description` becomes `feat(scope): description`).
   * Body is the full content of pr.md with all markdown formatting preserved, including the H1 line with `#`.
3. Present the PR title and a summary of the body inline in chat. Reference [pr.md](.copilot-tracking/pr/pr.md) for the full content and ask the user to confirm or request changes.
4. If the user requests changes to the title, body content, or styling, apply the changes to `pr.md` and re-present the updated title and summary. Repeat until the user approves.
5. Prepare the base branch reference by stripping any remote prefix (for example, `origin/main` becomes `main`).
6. Create the pull request by calling `mcp_github_create_pull_request` with these parameters:
   * `owner`: Repository owner derived from the git remote URL.
   * `repo`: Repository name derived from the git remote URL.
   * `title`: Extracted title without the leading `#`.
   * `body`: Full pr.md content.
   * `head`: Current branch name.
   * `base`: Target branch with remote prefix stripped.
   * `draft`: Set when the user requests a draft PR.
7. Handle errors during creation:
   * Branch not found: Verify the branch was pushed to the remote.
   * Permission denied: Inform the user of the permission requirements.
   * Duplicate PR: Check for an existing PR on the same branch and offer to update it using `mcp_github_update_pull_request`.
8. Share the PR URL with the user after successful creation.

### Step 8: Cleanup

1. Delete `.copilot-tracking/pr/pr-reference.xml` after the analysis is complete.
2. Delete the `.copilot-tracking/pr/subagents/` directory and its contents.

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
