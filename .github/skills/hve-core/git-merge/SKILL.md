---
name: git-merge
description: 'Coordinate Git merge, rebase, and rebase --onto workflows with conflict resolution, optional review pauses, and a completion summary. Use when integrating a branch locally and resolving conflicts without pushing.'
argument-hint: 'operation={merge|rebase|rebase-onto} branch=<ref> [onto=<ref>] [upstream=<ref>] [conflict-stop={true|false}]'
license: MIT
user-invocable: true
disable-model-invocation: true
---

# Git Merge and Rebase

## Goal

Run a merge, rebase, or `rebase --onto` sequence from the current branch, resolve conflicts with documented rationale, and finish with a clean tree and a summary. Follow every step even when the repository appears clean so results stay consistent and traceable.

## Inputs

* `operation` (optional, default `merge`): `merge`, `rebase`, or `rebase-onto`.
* `branch` (required): the branch or ref to merge, or the rebase target. Ask for it when it is missing.
* `onto` (required for `rebase-onto`): the new base.
* `upstream` (optional, used by `rebase-onto`): the branch or commit that bounds the commits to move.
* `conflict-stop` (optional, default `false`): when `true`, pause after each set of conflict fixes for user review before continuing.

## Flow

1. Prepare the workspace.
   * Confirm the working tree is clean with `git status --short`. Stash local changes before proceeding.
   * Fetch the latest remote refs, such as `git fetch origin <branch>` or `git fetch --all --prune`, when the branch might lag the target.
   * Record the active branch and the inputs.
2. Select the operation path.
   * `merge`: plan `git merge --no-edit <branch>` from the current branch.
   * `rebase`: plan `git rebase --empty=drop --reapply-cherry-picks <branch>`.
   * `rebase-onto`: plan `git rebase --onto <onto> <upstream> <branch>` after verifying that every referenced commit exists.
3. Execute the operation and capture its output. When Git reports conflicts, list the files from `git status --short` and use `git diff` for context. Without conflicts, continue at step 6.
4. Resolve conflicts.
   * Inspect each conflicted file individually, including automatic resolutions, using repository conventions, related instructions files, and domain knowledge. Consult authoritative documentation through available tools when more context is needed.
   * Review related code and references before choosing a resolution.
   * Apply focused edits that remove the markers, stage each file with `git add <file>`, and verify the result with `git diff --staged`.
   * After every set of fixes, describe the rationale and link each affected file.
5. Honor review pauses. When `conflict-stop` is `true`, summarize the fixes with a checklist of touched files and wait for explicit user confirmation before continuing. Answer follow-up questions and adjust resolutions from user feedback.
6. Continue or complete. Resume with `git merge --continue` or `git rebase --continue`, or back out with `git merge --abort` or `git rebase --abort` when required. When the operation finishes, confirm a clean tree with `git status --short` and list new commits with `git log --oneline -5`.
7. Summarize results.
   * Pop any stash created in step 1. When the pop conflicts, tell the user it needs their attention.
   * Summarize the operation, the conflicts, how each was resolved, and any remaining manual follow-up.
   * Remind the user that nothing was pushed and that they publish the branch when ready.

## Guardrails

* Never push, force-push, or rewrite remote history on the user's behalf.
* Do not proceed when the working tree contains unrelated staged changes; address them first.
* Document every conflict fix with a brief justification and links to the edited files.
* When a resolution is uncertain, consult official Git documentation or domain references before editing.

## Tooling

* Run Git commands in the terminal.
* Run `git status --short` after each conflict resolution cycle to confirm that only intended files are staged.
* Use `git diff`, `git diff --staged`, and `git log --merge` to surface the context behind conflicting commits.
* Check `git rebase --help` and upstream documentation for `--onto` semantics and conflict continuation.
* Use workspace tools such as Terraform, Bicep, or documentation search when a conflict needs more context.

## Success Criteria

* The operation path completed with every conflict resolved, or was aborted at the user's direction.
* `git status --short` reports no pending changes, or the summary names deliberate follow-up items.
* The user received a conflict summary with linked files and a reminder that pushing remains their responsibility.
