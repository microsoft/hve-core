---
description: 'Required instructions for pull request description generation and optional PR creation using diff analysis, subagent review, and MCP tools - Brought to you by microsoft/hve-core'
applyTo: '**/.copilot-tracking/pr/**'
---

# Pull Request Instructions

Instructions for generating pull request descriptions from branch diffs using the pr-reference Skill and parallel subagent review.

## Core Guidance

* Apply git expertise when interpreting diffs.
* Avoid mentioning linting errors or auto-generated documentation.
* Ask the user for direction when progression is unclear.
* Check for PR templates before generating content; use the repository template when available.
* Check checkboxes for items the agent completed or verified during PR generation.
* Leave checkboxes requiring manual human verification unchecked.
* Evaluate template checkboxes against the diff. Check items with confident evidence from changed files. Leave unchecked when assessment requires human judgment.
* When the repository conventions file defines section-level handling modes or manual-only exceptions, those take precedence over general checkbox guidance for the specified sections.
* Preserve template structure and formatting without removing sections.

## Canonical Fallback Rules

Apply these fallback rules whenever a step references this section:

1. If no PR template is resolved, use the standard format in the PR Description Format section.
2. If a template is resolved but mapping details are ambiguous, preserve section order and map by closest semantic match.
3. If required checks cannot be discovered confidently, ask the user for direction before running commands.
4. If no issue references are discovered, use `None` in the related issues section.
5. If PR creation fails, apply Step 8 Shared Error Handling in order: branch readiness, permissions, duplicate PR handling.

## Required Steps

### Step 1: Resolve Template State

Entry criteria:

* Repository context is available and the target branch is known.

1. Resolve PR template candidates:
   1. Search tools for files are case-sensitive.
   2. Search for `pull_request_template.md`, `PULL_REQUEST_TEMPLATE.md`, `.github/pull_request_template/`, `.github/PULL_REQUEST_TEMPLATE/`.
   3. Search for any casing variation for both file names and directory names (for example, `PULL_REQUEST_TEMPLATE.md`, `Pull_Request_Template.md`, `pull_request_template.md`).
2. Apply location priority, based on location:
   1. `.github/` folder.
   2. `docs/` folder.
   3. Anywhere else found.
3. If multiple templates exist at the same priority level, list candidates and ask the user to choose one.
4. Persist template state for later steps:
   * `templatePath`: chosen template path, or `None`.
   * `templateSections`: parsed H2 section structure when a template exists.
   * `checkCommands`: Extract backtick-wrapped required check commands from template checklist sections.

When no template is resolved, apply Canonical Fallback Rules and continue.

Exit criteria:

* Template state is resolved and persisted for reuse.

### Step 2: Branch Freshness Gate

Entry criteria:

* Step 1 completed. Repository context is available and the target branch is known.

Validate that the working branch is current with the base branch before generating diffs or analysis:

1. Resolve the base branch ref, defaulting to `origin/main` if not provided. Convert plain branch names (for example, `main`) to `origin/<branch>` form.
2. Fetch the base branch ref before comparison.
3. Compute ahead/behind counts with `git rev-list --left-right --count "${baseRef}...HEAD"`.
4. If the branch is behind, ask the user whether to update using `merge` or `rebase` before proceeding.
5. Execute the selected strategy:
   * Merge: `git merge --no-edit ${baseRef}`
   * Rebase: `git rebase --empty=drop --reapply-cherry-picks ${baseRef}`
6. If conflicts occur, follow `.github/instructions/hve-core/git-merge.instructions.md` before continuing.

Exit criteria:

* Branch is current with the base branch, or the user declined the update.

### Step 3: Generate PR Reference

Generate the PR reference XML file using the pr-reference skill:

1. If `.copilot-tracking/pr/pr-reference.xml` already exists, confirm with the user whether to use it before proceeding.
2. If the user declines, delete the file before continuing.
3. Use the pr-reference skill to generate the XML file with the provided base branch and any requested options (such as excluding markdown diffs).
4. Note the size of the generated output in the chat.

### Step 4: Parallel Subagent Review

Entry criteria:

* `.copilot-tracking/pr/pr-reference.xml` exists.

Analyze the pr-reference.xml using parallel subagents:

1. Get chunk information from the PR reference XML to determine how many chunks exist and their line ranges.
2. Launch parallel subagents via `runSubagent` or `task` tools, one per chunk (or groups of chunks for very large diffs).
3. If subagent tools are unavailable, review chunks sequentially using the same protocol and output format.

Each subagent invocation provides these inputs:

* Chunk number(s) to review.
* Path to pr-reference.xml.
* Output file path: `.copilot-tracking/pr/subagents/NN-pr-reference-log.md` (where NN is the zero-padded subagent number, for example, 01, 02, 03).

Each subagent follows the Subagent Review Protocol section below.

Each subagent returns: output file path, completion status, and any clarifying questions when analysis is ambiguous.

* Repeat subagent invocations with answers to clarifying questions until all chunks are reviewed.
* Wait for all subagents to complete before proceeding.

Exit criteria:

* All chunks are reviewed and each subagent produced an output file or a resolved clarification.

### Step 5: Merge and Verify Findings

Entry criteria:

* Step 4 outputs exist for all assigned chunk ranges.

Merge subagent findings into a unified analysis:

1. Create `.copilot-tracking/pr/pr-reference-log.md`.
2. Read each `.copilot-tracking/pr/subagents/NN-pr-reference-log.md` file.
3. Merge findings into the primary `pr-reference-log.md`, organizing by significance.
4. While merging, verify findings using search and file-read tools, especially when details are unclear or conflicting across subagent reports.
5. Progressively update `pr-reference-log.md` with any additional findings from verification.
6. The finished `pr-reference-log.md` serves as the single source of truth for PR generation.

Exit criteria:

* `.copilot-tracking/pr/pr-reference-log.md` is complete and verified as the source of truth.

### Step 6: Generate PR Description

Entry criteria:

* `.copilot-tracking/pr/pr-reference-log.md` is complete.

Create `.copilot-tracking/pr/pr.md` from interpreting `pr-reference-log.md`:

1. If `templatePath` from Step 1 is set, apply repo-specific conventions from the attached instructions file matching `pull-request.instructions.md` to populate all template sections from pr-reference-log.md analysis. If no repo-specific conventions file exists, fill the PR template by semantic match to section headings. Apply these generic principles:
   * Check checkboxes when the diff provides confident evidence.
   * Leave checkboxes unchecked when human judgment is required.
   * Preserve placeholder comments in sections that cannot be auto-populated.
   * Process sections in document order.
2. If `templatePath` is `None`, apply Canonical Fallback Rules and use the PR Description Format defined below.
3. Delete `pr.md` before writing a new version if it already exists; do not read the old file.

Title:

* Use the branch name as the primary source (for example, `feat/add-authentication`).
* Format as `{type}({scope}): {concise description}`.
* Use commit messages when the branch name lacks detail.
* The title is the only place where conventional commit format appears.

Extract and place issue references following the Issue Reference Extraction section.

Follow the PR Writing Standards section for description style and content principles.

After generating pr.md, run the security analysis, post-generation checklist, and assessable required checks defined below.

#### Security Analysis

Analyze pr-reference-log.md for security concerns using two approaches:

Checkbox-mapped analysis:

* When the PR template contains security-related checkboxes, analyze the diff for security concerns including sensitive data exposure, dependency vulnerabilities, and privilege escalation.
* Check matching security checkboxes based on semantic match between the checkbox label and the analysis result.
* Leave checkboxes unchecked when assessment is uncertain.

Supplementary analysis:

* Non-compliant language: Flag terms that violate inclusive language guidelines.
* Unintended changes: Identify files modified without clear intent from commits or branch context.
* Missing referenced files: Verify that files referenced in code or documentation exist in the repository.
* Conventional commits compliance: Confirm commit messages follow the conventional commits format.

Report supplementary findings in chat and note issues in Additional Notes.

#### Post-generation Checklist

Review pr.md against these criteria as an internal self-audit. Do not insert this checklist into pr.md or the pull request body:

1. PR description preserves all template sections.
2. pr-reference-log.md analysis is accurately reflected in the description.
3. Description uses past tense and follows writing-style conventions.
4. All significant changes from the diff are included.
5. Referenced files are accurate and exist in the repository.
6. Follow-up tasks are actionable and tied to specific code, files, or components.

Report any failed criteria in chat for user awareness. Correct issues in pr.md before proceeding.

#### Assessable Required Checks

Assess non-automated checklist items from the template using diff analysis. For each assessable item, verify the claim against changed files. Check items where the diff provides confident evidence. Leave items unchecked when confident assessment is not possible.

Exit criteria:

* `.copilot-tracking/pr/pr.md` exists with title and body aligned to template mapping or fallback format.
* Security analysis, post-generation checklist, and assessable required checks are complete. Post-generation checklist findings are addressed in pr.md without inserting the checklist itself.

### Step 7: Validate PR Readiness

Entry criteria:

* `.copilot-tracking/pr/pr.md` exists.

Run PR-readiness validation even when the user has not explicitly requested direct PR creation.

#### Step 7A: Discover Required Checks

1. Start with `checkCommands` captured from the selected PR template in Step 1.
2. Expand required checks by reading instruction files whose `applyTo` patterns match the changed files, looking for validation commands or required check references.
3. Build one de-duplicated ordered command list and record the source for each command (template or instruction).
4. If required checks cannot be discovered confidently, ask the user for direction before running commands.

Exit criteria:

* Required checks are either confidently discovered, or user direction is requested before continuing.

#### Step 7B: Run and Triage Validation

1. Run all discovered required checks.
2. Record each check result as `Passed`, `Failed`, or `Skipped` (with reason).
3. For failures, categorize as `blocking` or `non-blocking` and note the root-cause area and recommended next action.
4. Update the pr.md checklist checkboxes to reflect results: for each check that passed, replace the matching `- [ ]` with `- [x]` in pr.md.

Exit criteria:

* Validation results are captured and failed checks are triaged.

#### Step 7C: Remediation Routing

1. If fixes are bounded and localized, implement accurate direct fixes and rerun relevant failed checks.
2. If fixes require broader rewrites or refactors (cross-cutting changes, multi-area redesign, or architecture-impacting updates), stop direct remediation and recommend the RPI workflow (Research, Plan, Implement) for larger scope work.

Exit criteria:

* Validation failures are either resolved with direct fixes, or RPI is recommended for larger scope.

#### Step 7D: Readiness Outcome

1. Confirm all checklist checkbox updates in pr.md are complete. If required checks pass, continue to Step 7E when PR creation was requested.
2. If required checks remain unresolved, do not proceed with direct PR creation.
3. When PR creation was not requested, report readiness status and next actions without creating a PR.

Exit criteria:

* PR readiness status is explicit and next actions are clear.

#### Step 7E: PR Creation Approval

Entry criteria:

* Step 7D completed with passing checks and user requested PR creation.

1. Present the PR title and a link to `.copilot-tracking/pr/pr.md` in conversation.
2. When an `ask questions` tool is available, use it to present "Continue to create the pull request" (recommended) and "Cancel creating pull request" options. Otherwise, ask the user inline to confirm or cancel.
3. If Continue: proceed to Step 8.
4. If Cancel: skip to Step 9.

Exit criteria:

* User confirmed or declined PR creation.

### Step 8: Create Pull Request When Requested by User

Entry criteria:

* `.copilot-tracking/pr/pr.md` exists.
* User explicitly requested PR creation.
* Step 7 completed with required checks passing.
* User confirmed PR creation via Step 7E approval.

Create a pull request using MCP tools. Skip this step when the user has not requested PR creation or declined via the Step 7E approval, and proceed to Step 9.

#### Step 8A: Branch Pushed Readiness

1. Check whether the current branch is pushed to the remote.
2. If not pushed, push the current branch before continuing.

#### Step 8B: Approval Loop

1. Extract the PR title and body from `pr.md` following the format defined in Step 6.
2. Present the PR title and a summary of the body inline in chat. Reference [pr.md](../../../.copilot-tracking/pr/pr.md) for full content and ask the user to confirm or request changes.
3. If the user requests updates, apply changes to `pr.md` and repeat until approved.

#### Step 8C: PR Creation and Error Handling

1. Prepare the base branch reference by stripping any remote prefix (for example, `origin/main` becomes `main`).
2. Create the pull request by calling `mcp_github_create_pull_request` with these parameters:
   * `owner`: Repository owner derived from the git remote URL.
   * `repo`: Repository name derived from the git remote URL.
   * `title`: Extracted title without the leading `#`.
   * `body`: Full pr.md content.
   * `head`: Current branch name.
   * `base`: Target branch with remote prefix stripped.
   * `draft`: Set when the user requests a draft PR.
3. If creation fails, apply Step 8 Shared Error Handling below.
4. Share the PR URL after successful creation.

#### Step 8 Shared Error Handling

Apply this ordered error handling when PR creation fails:

1. Branch not found: verify Step 8A completed and the branch is present on remote.
2. Permission denied: inform the user about required repository permissions.
3. Duplicate PR: check for an existing PR on the same branch and offer to update it with `mcp_github_update_pull_request`.

### Step 9: Cleanup

1. Delete `.copilot-tracking/pr/pr-reference.xml` after the analysis is complete.
2. Delete the `.copilot-tracking/pr/subagents/` directory and its contents.
3. The `pr-reference-log.md` and `pr.md` files persist for user reference.

## Issue Reference Extraction

Extract issue references from commit messages and branch names using these patterns:

| Pattern                              | Source           | Output Format     |
|--------------------------------------|------------------|-------------------|
| `Fixes #(\d+)`                       | Commit message   | `Fixes #123`      |
| `Closes #(\d+)`                      | Commit message   | `Closes #123`     |
| `Resolves #(\d+)`                    | Commit message   | `Resolves #123`   |
| `#(\d+)` (standalone)                | Commit message   | `Related to #123` |
| `/(\d+)-`                            | Branch name      | `Related to #123` |
| `AB#(\d+)` (Azure DevOps convention) | Commit or branch | `AB#12345` (ADO)  |

Deduplicate issue numbers and preserve the action prefix from the first occurrence.

## PR Writing Standards

Apply these standards when writing PR descriptions in Step 6 and when subagents document findings in Step 4. Follow `writing-style.instructions.md` for general voice and tone, targeting "Medium" formality from the Adaptability table: conversational yet technical, matching how engineers naturally describe their work to peers.

* Ground all content in the pr-reference-log.md analysis; include only verified changes.
* Describe what changed without speculating on why.
* Avoid claiming benefits unless commit messages or code comments state them explicitly.
* Use past tense in descriptions.
* Write for people familiar with the codebase in neutral, conversational language that unfamiliar readers also understand.
* Match tone and terminology from commit messages.
* Do not use conventional commit style lists (for example, `feat(scope): description`) in the body.
* Bold is permitted throughout the PR body for emphasizing key terms, file paths, components, or outcomes within natural prose. This overrides the writing-style prohibition on bolded-prefix list items for PR descriptions specifically. Use emphasis naturally (for example, "Updated **skill validation** to handle nested references"), not the `**Term:** description` glossary pattern.
* Use *italics* for file names, technical terms, and qualitative descriptors.
* Use blockquotes for motivation, context, or key decisions when they add clarity for reviewers.
* Include brief prose paragraphs between groups to provide narrative transitions.
* Include high-level context that helps reviewers understand scope and impact.
* Describe the final state of the code rather than intermediate steps.
* For focused PRs, combine related changes into single descriptive points. For multi-area PRs, group related changes under thematic sub-headings with concise bullets rather than condensing into fewer dense points.
* When a PR spans multiple distinct areas, use `###` sub-headings within the Description section to group changes by category. Use judgment based on the scope and variety of changes rather than a fixed threshold. Small, focused PRs keep flat lists.
* Detected change types from the Change Type Detection Patterns table inform the organizational structure of the Description section. When multiple distinct types are detected, use them as category labels for sub-headings or thematic groupings.
* Group changes by significance; place the most significant changes first.
* Rank significance by cross-checking branch name, commit count, and changed line volume.
* Include essential context directly in the main bullet point.
* Use sub-bullets for clarifying details, related file references, or supporting context.
* Include Notes, Important, or Follow-up sections only when supported by commit messages or code comments.
* Identify follow-up tasks only when evidenced in the analysis; keep them specific, actionable, and tied to code, files, folders, components, or blueprints.

## PR Description Format

When no PR template is found in the repository, use this format:

```markdown
# {type}({scope}): {concise description}

{Summary paragraph in natural, conversational language. Explain what this PR does and its impact on the codebase. Write for both familiar and unfamiliar readers.}

## Changes

<!-- Focused PRs: use a flat bullet list. Multi-area PRs: replace with ### sub-headings grouping changes by category. -->

- {Most significant change with **bold emphasis** on key terms}
- {Next change referencing *file names* or technical terms}
  - {Sub-bullet for clarifying details or related references}
- {Additional changes}

### {Category Name} (for multi-area PRs)

{Brief prose paragraph providing context for this group of changes.}

- {Change in this category}
- {Another related change}

### {Another Category}

> {Optional blockquote for motivation or key decisions}

- {Changes in this area}

## Related Issues

{Issue references extracted from commits and branch names, or "None" if no issues found}

## Notes (optional)

- {Note identified from code comments or commit messages}

## Follow-up Tasks (optional)

- {Task with specific file or component reference}
```

## Subagent Review Protocol

Each subagent follows this protocol when reviewing PR reference chunks:

1. Use the pr-reference skill to read the diff content for the assigned chunk(s) from the PR reference XML.
2. Analyze the changes: identify files changed, what was added, modified, or deleted, and why (inferred from context).
3. Create the output file new at the provided path; do not read the file if it already exists.
4. Document findings following the Subagent PR Reference Log template below: files changed, nature of changes, technical details, notable patterns.
5. Follow writing-style conventions from `writing-style.instructions.md` and PR Writing Standards when documenting findings.

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
