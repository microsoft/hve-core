---
description: "Git integration and explicit ordinary-push authorization. Use when merging, rebasing, resolving conflicts, or pushing a branch."
---

# Git Merge and Rebase Conventions

<!-- cspell:ignore refspec -->

Execute the Git operations the user requests or approves, within the limits below;
do not ask for the same approval again.
Authorization covers the agreed task and its expected result, not unrelated actions.

Apply Prepare through Finish only to integration work. A push-only request does not start integration
or require a clean working tree. The `/git-merge` skill adds guided inputs and optional review pauses.

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

## Push Authorization

* Execute an explicitly requested or approved ordinary push. A request to integrate then push
  authorizes both; integration, conflict resolution, commits, or PR preparation alone do not.
* Use the established repository, source, push endpoint, and destination branch. Ask only for
  genuinely missing or materially changed scope; other remotes or accounts alone are not ambiguity.
* Keep the push to the authorized branch and endpoint. Check effective configuration for extra refs,
  tags, mirrors, or destinations; do not silently expand scope or change configuration.
* Never force-push or rewrite remote history here, including `--force-with-lease` or a leading-plus
  refspec. Do not delete remote refs or bypass hooks or repository protections.
* On rejection, report the result and stop unless recovery is already authorized. Rejection grants
  no permission for a stronger push, extra integration, another destination, or an account change.

## Account Changes

* Change accounts or authentication configuration only at the user's direction. GitHub CLI account
  selection does not establish Git transport identity.
* For a temporary switch, establish the original account/host and requested target before switching.
  Restore the original in unconditional cleanup (`try`/`finally` or equivalent), checking native
  results, even if switching or pushing fails or is cancelled.
* Verify restoration and report it separately from the push. If cleanup or verification cannot
  complete, report incomplete restoration and the known or unknown remaining account state.

## Execution Evidence

* Report an attempt only after Git launches, and publication only when results confirm the intended
  ref changed. An up-to-date result is not new publication.
* Distinguish instruction/tool restrictions and unavailable tooling from observed authentication,
  network, or repository failures. Report only supported causes, preserve uncertainty, and keep
  credentials and secret-bearing URLs out of reports.
