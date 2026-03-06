---
description: "Required protocol for Git merge, rebase, and rebase --onto workflows with conflict handling and stop controls."
---

# Git Merge & Rebase Instructions

Use this guidance whenever coordinating Git merge, rebase, or `rebase --onto` sequences through the companion prompt. Follow every step even when the repository appears clean to ensure consistent results and traceability.

## Required Protocol

### 1. Prepare the workspace

* Confirm the working tree is clean with `git status --short`. Stash local changes before proceeding.
* Fetch latest remote refs (`git fetch origin main`, `git fetch origin [branch]`, `git fetch --all --prune`) when the branch might lag the target.
* Record the active branch and inputs: `${input:operation}`, `${input:branch}`, and optional `${input:onto}` / `${input:upstream}`.

### 2. Select the operation path

* For `${input:operation} == "merge"`, plan to run `git merge --no-edit ${input:branch}` from the current branch.
* For `${input:operation} == "rebase"`, plan to run `git rebase --empty=drop --reapply-cherry-picks ${input:branch}`.
* For `${input:operation} == "rebase-onto"`, plan to run `git rebase --onto ${input:onto} ${input:upstream} ${input:branch}` after verifying all referenced commits exist.

### 3. Execute the operation

* Run the planned Git command and capture any immediate output.
* When Git reports conflicts, highlight the files listed by `git status --short` and `git diff` for context.
* If the command completes without conflicts, jump to Step 6.

### 4. Resolve conflicts

* Inspect each conflicted file individually, including auto-conflict resolution, using repository conventions and domain expertise, including related instructions files. Reference authoritative docs via available tooling when more context is required.
* Review related code files and references to make the correct conflict resolution.
* Apply focused edits to resolve markers, then stage changes (`git add [file]`). Re-run `git diff --staged` to verify resolutions.
* After every set of fixes, describe the rationale and include markdown links to affected files (for example, `path/to/file`).

### 5. Honor review pauses

* If `${input:conflictStop}` is `true`, pause after summarizing conflict fixes. Provide a checklist of touched files and await explicit user confirmation before continuing.
* Be prepared to answer follow-up questions or adjust resolutions based on user feedback.

### 6. Continue or complete

* Resume the workflow with `git merge --continue`, `git rebase --continue`, or, when backing out is required, `git merge --abort` / `git rebase --abort`.
* When the operation finishes, run `git status --short` to confirm a clean tree and list any new commits with `git log --oneline -5` for quick review.

### 7. Summarize results

* If changes were stashed then do a stash pop to bring back the user's changes.
  * If there are conflicts with the stash pop then inform the user that the stash pop resulted in conflict and requires their attention.
* Provide a final summary outlining the operation performed, conflicts encountered, how they were resolved, and any remaining manual follow-up.
* Remind the user that no pushes were performed and they must review and publish the branch locally when ready.

## Guardrails

* Never push, force-push, or rewrite remote history on behalf of the user.
* Do not proceed if the working tree contains unrelated staged changes; address them before the merge workflow.
* Document every conflict fix with a brief justification and markdown links to the files you edited.
* When unsure about a resolution, consult official Git documentation or domain-specific references before modifying files.

## Tooling & diagnostics

* Use `git status --short` after each conflict resolution cycle to ensure only intended files remain staged.
* `git diff`, `git diff --staged`, and `git log --merge` help surface the context behind conflicting commits.
* Review `git rebase --help` and the upstream documentation for nuanced behaviors such as `--onto` semantics and conflict continuation.
* Leverage workspace-specific tooling (terraform, bicep, microsoft-docs) whenever conflicts require more context.
* Always use terminal tools for git related commands.

## Completion checklist

* Operation path completed with all conflicts resolved.
* `git status --short` reports no pending changes or highlights deliberate follow-up items.
* User received a conflict summary with linked files and confirmation that pushing remains their responsibility.
