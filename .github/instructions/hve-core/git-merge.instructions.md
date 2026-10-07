---
description: "Git merge, rebase, and rebase --onto conventions for workspace preparation, conflict resolution, and no-push guardrails. Use when merging or rebasing a branch or resolving Git conflicts."
---

# Git Merge and Rebase Conventions

Apply these conventions whenever you merge, rebase, or run `rebase --onto`, whether the user asks directly or starts the `/git-merge` skill. The skill adds guided inputs, optional review pauses, and a completion summary.

## Prepare

* Confirm a clean working tree with `git status --short`. Stash local changes first, and do not proceed while unrelated changes are staged.
* Fetch the latest remote refs when the target might lag, such as `git fetch origin <branch>` or `git fetch --all --prune`.
* Record the active branch and the target ref, and run Git commands in the terminal.

## Run the Operation

* Merge: `git merge --no-edit <branch>` from the current branch.
* Rebase: `git rebase --empty=drop --reapply-cherry-picks <branch>`.
* Rebase onto: `git rebase --onto <onto> <upstream> <branch>` after verifying that every referenced commit exists. Check `git rebase --help` for `--onto` semantics and conflict continuation.

## Resolve Conflicts

* List conflicted files with `git status --short`, and use `git diff` and `git log --merge` for the context behind each side.
* Inspect each conflicted file individually, including automatic resolutions. Use repository conventions, related instructions files, domain knowledge, and workspace tools such as Terraform, Bicep, or documentation search. Review related code and references before choosing a resolution, and consult official Git or domain documentation when a resolution is uncertain.
* Apply focused edits that remove the markers, stage each file with `git add <file>`, and confirm with `git diff --staged` and `git status --short` that only intended files are staged.
* Document every resolution with a brief rationale and a link to each edited file.

## Finish

* Continue with `git merge --continue` or `git rebase --continue`, or back out with `git merge --abort` or `git rebase --abort` when required.
* Confirm a clean tree with `git status --short`, and list the new commits with `git log --oneline -5`.
* Pop any stash created during preparation, and tell the user when the pop conflicts.

## Guardrails

* Never push, force-push, or rewrite remote history on the user's behalf. Remind the user that publishing the branch remains their decision.
