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

Run a merge, rebase, or `rebase --onto` sequence from the current branch with explicit inputs, optional review pauses, and a completion summary. Follow every step even when the repository appears clean so results stay consistent and traceable.

## Conventions

The `git-merge` instructions own workspace preparation, the operation commands, conflict resolution, finishing steps, and the no-push guardrail. Apply them at every step below.

## Inputs

* `operation` (optional, default `merge`): `merge`, `rebase`, or `rebase-onto`.
* `branch` (required): the branch or ref to merge, or the rebase target. Ask for it when it is missing.
* `onto` (required for `rebase-onto`): the new base.
* `upstream` (optional, used by `rebase-onto`): the branch or commit that bounds the commits to move.
* `conflict-stop` (optional, default `false`): when `true`, pause after each set of conflict fixes for user review before continuing.

## Flow

1. Resolve the inputs. Ask for `branch` when it is missing, and for `onto` when `operation` is `rebase-onto`. Record the active branch and the inputs.
2. Prepare the workspace as the git-merge instructions define, then run the command they define for the selected `operation` and capture its output. Without conflicts, continue at step 5.
3. Resolve conflicts as the instructions define, and keep each file's resolution and rationale for the summary.
4. Honor review pauses. When `conflict-stop` is `true`, summarize the fixes with a checklist of touched files and wait for explicit user confirmation before continuing. Answer follow-up questions and adjust resolutions from user feedback.
5. Continue or complete the operation as the instructions define, or abort when the user directs it.
6. Summarize the operation, each conflict and how it was resolved with linked files, the stash state, and any remaining manual follow-up. Remind the user that nothing was pushed and that they publish the branch when ready.

## Success Criteria

* The operation path completed with every conflict resolved, or was aborted at the user's direction.
* `git status --short` reports no pending changes, or the summary names deliberate follow-up items.
* The user received a conflict summary with linked files and a reminder that pushing remains their responsibility.
