---
title: Stacked pull requests
description: How the pull-request skill describes, publishes, and syncs the branches of a gh stack stack once Stack Detection finds the checked-out branch in one
---

<!-- cspell:ignore upstack -->

## How this reference applies

A stack is a chain of branches in one repository. Each branch's pull request targets the branch below it, and the lowest one targets the stack's base, usually the default branch. Follow this reference together with the pull-request skill's sections once Stack Detection finds the checked-out branch in a stack. The skill's Publishing rule and Stop Rules apply to every `gh stack` step in a pull-request run, even when the official gh-stack agent skill is also installed.

Tested with gh-stack v0.3.0. Flags change between releases, so check `gh stack <command> --help` before relying on one.

## Read the stack

Stack Detection already ran `gh stack view --json`. It returns `trunk`, the stack's base, and `branches[]` from the bottom of the stack to the top. Each entry has `name`, `isCurrent`, `isMerged`, `isQueued`, and `needsRebase`, plus `pr` with `number`, `url`, and `state` when the branch has a pull request.

* Open branches are the entries that are neither merged nor queued. Skip the others.
* A branch's parent is the nearest lower open entry, or `trunk` when there is none.
* Stacks need every branch in one repository. When the branch pushes to a different repository than the one gh opens pull requests in, such as a fork, stop. Say stack mode can't publish from there, and offer `stack=off`, whose ordinary pull request includes every lower branch. Comparing the push remote's URL with the repository `gh repo view --json nameWithOwner` reports shows the difference.

## Scope and descriptions

* `create` covers the checked-out branch and every open branch below it that has no pull request. Branches above it stay untouched unless the user asks for the whole stack.
* `update` covers the checked-out branch's description unless the user asks for the whole stack. Its push still covers every open branch (see Publish).
* `prepare` describes the branches a create would cover.
* Collect each branch in scope with `--head <branch> --base refs/heads/<parent>`, or `--base <trunk>` for the lowest open branch (`-Head` and `-Base` in PowerShell).
* Write each description to `.copilot-tracking/pr/stack/<branch>.md`, replacing `/` in the branch name with `-`. A description covers only its own branch. A closing issue keyword goes only on the branch whose merge completes the issue.

## Local checks

Run the skill's Local Checks once, on the checked-out branch. That branch contains every branch below it, so the results cover the branches in scope at or below it. Report the other branches as not checked locally, and check a branch on its own only when the user asks and the working tree is clean.

A repair commit on a branch below the top doesn't reach the branches above it. Say so, and before publishing require `action=sync`, or the user's yes to run `gh stack rebase --upstack` and then `gh stack push`.

## Choose the remote

Use one remote for the whole run, and pass it as `--remote <name>` to every gh stack command that pushes or fetches: `push`, `submit`, `link`, `sync`, and `rebase`. Take the first one that's set, in gh stack's own order:

1. The branch's `branch.<name>.pushRemote`
2. `remote.pushDefault`
3. The branch's `branch.<name>.remote`
4. `gh-stack.remote`, gh stack's saved choice
5. The only remote

When several remotes remain, ask which one, as part of the one question when the run already needs it. Don't set `remote.pushDefault` for the user; that changes their git configuration.

## Check GitHub before pushing

`gh stack push`, `submit`, and `sync` push with `--force-with-lease`, but each one fetches the branches right before it pushes and leases against that fetch. So the lease only covers the moment between gh stack's own fetch and its push. `sync` forces only after a rebase and otherwise pushes normally, and `link` never forces. gh stack also doesn't set an upstream when it pushes, so `@{upstream}` can't find a branch's GitHub copy.

Run this check right before each gh stack command that pushes, for every branch that command will push:

1. Fetch the branch with `git fetch <remote> +refs/heads/<branch>:refs/remotes/<remote>/<branch>`. When git reports `couldn't find remote ref`, the branch isn't on GitHub, so there's nothing to protect.
2. Count the commits on each side with `git rev-list --left-right --count refs/remotes/<remote>/<branch>...refs/heads/<branch>`. It prints the commits only on GitHub, then the commits only on the local branch.
3. When GitHub has commits the branch lacks, run `git cherry refs/heads/<branch> refs/remotes/<remote>/<branch>`. A `+` line is a GitHub commit with no equivalent change on the local branch, so the push would drop it. A `-` line has an equivalent, as after a rebase.

| Result                                          | Before `push`, `submit`, or `link`                                   | Before `sync`                                 |
|-------------------------------------------------|----------------------------------------------------------------------|-----------------------------------------------|
| Not on GitHub, or no commits only on GitHub     | Continue                                                             | Continue                                      |
| Behind: commits only on GitHub, none only local | Stop and recommend `action=sync`; a create syncs first (see Publish) | Continue; sync fast-forwards the branch first |
| Diverged, with no `+` lines                     | Continue; a create pushes with `gh stack push` first (see Publish)   | Continue                                      |
| Diverged, with `+` lines                        | Stop, show the commits, and continue only when the user confirms     | Same                                          |

After a lower branch is squash-merged, its original commits can show as `+` lines on the branches above it even though their changes already merged. Say so when that's the likely cause. A collaborator who pushes between this check and gh stack's own fetch can still be overwritten, which is why the check runs right before the command.

## Publish

Stack mode adds these rules to the skill's Publishing rule:

* A create request asks for the pull requests in its scope. Even after a clear request, ask the one question when the run would push other branches that have new or rewritten commits, or open pull requests outside that scope. List every branch to push with its remote and say which pushes rewrite history, and list each pull request to open with its title, its draft state, and whether `gh pr ready` follows.
* Open no pull request until every description for the run is written and has passed the sensitive-text check.
* Run Check GitHub before pushing right before each gh stack command that pushes.

`create` takes one of these paths:

* Two or more branches in scope: run `gh stack link --base <trunk> --remote <remote>` with every open branch from the bottom of the stack up to and including the checked-out branch, in stack order, including branches that already have pull requests. It pushes only those branches, without force, opens a draft for each one that has no pull request, and adds them to the stack on GitHub. Leave out merged branches. When a listed branch is queued, stop and report it.
* Only the checked-out branch, because it's the lowest open branch: push it under the skill's ordinary push rules, then run `gh pr create --base <trunk> --head <branch> --draft --title <title> --body-file <file>`. gh stack links it once a second pull request exists.
* `link` and the ordinary push never force, so first bring each branch in scope level with GitHub. When one is behind its GitHub copy or needs a rebase (`needsRebase`), run Sync. When one was rewritten locally and none needs a rebase, run `gh stack push --remote <remote>` instead, because Sync forces a push only after its own rebase. Both push every open branch, so the one-question rule above applies. Then create.
* The whole stack, only when the user asks for it: `gh stack submit --auto --remote <remote>` opens a pull request for every open branch without one.
* When `link` refuses a pull request because auto-merge is on, report which one, and suggest turning auto-merge off or creating the whole stack.

`update` runs `gh stack push --remote <remote>` when a branch needs a push. It pushes every open branch, which keeps existing pull requests current, and never opens one; never run `submit` or `link` for an update. When branches have no pull request, list them and recommend `action=create`.

Then, for each pull request in scope:

1. Read the pull request numbers from `gh stack view --json`. Check draft and closed state with `gh pr view <number> --json isDraft,state,baseRefName`, because `view --json` reports both as `OPEN`.
2. Set each title and body with `gh pr edit <number> --title <title> --body-file <file>`, following the skill's update rule for boxes and sections a person filled in. Run `gh pr ready <number>` for new pull requests when `draft=false`. A description-only update uses `gh pr edit` alone.
3. Before reporting Created, confirm every branch in scope has an open pull request. `submit` exits 0 even when one failed to open.
4. If a step fails after pull requests exist, report each one's URL and state.

## Sync

`action=sync` on a stacked branch is a clear request, so it runs without asking unless the one-question rule above applies. Before running, say what will change: pushes of every open branch, with force only for branches it rebases; a fast-forward of the local `trunk` branch; local branches for pull requests someone added to the stack on GitHub; and the stack's links on GitHub.

1. Run Check GitHub before pushing for every open branch. Before a sync, a branch that is only behind is fine, because `gh stack sync` fast-forwards it first.
2. Run `gh stack sync --remote <remote>`. Add `--prune` or `--accept-base-change` only when the user asks. `--prune` deletes local branches whose pull requests merged, and `--accept-base-change` rebases onto a new base after the old one was deleted unmerged, dropping the old base's commits.
3. Treat `Sync aborted` or `Push failed` as a failed sync, whatever the exit code; gh stack prints both on stderr. Confirm success with `gh stack view --json`, where no branch has `needsRebase`, and by fetching again: for each open branch, `git rev-parse refs/heads/<branch>` must equal `git rev-parse refs/remotes/<remote>/<branch>`.
4. Tell the user that a rewritten branch may need a fresh review approval where repository rules require approval of the latest push. GitHub keeps approvals when a rebased branch's diff is unchanged.

## Outcomes

| Result                                                   | What to do                                                                                                                                                                                                                              |
|----------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Exit 1 (general error) or 5 (invalid arguments)          | Report stderr and stop                                                                                                                                                                                                                  |
| Exit 3 from `gh stack sync` (rebase conflict)            | Sync already restored every branch. Report the conflict, suggest `gh stack rebase` to resolve it, and stop unless the user asks to resolve it                                                                                           |
| Exit 3 from `gh stack rebase` (rebase conflict)          | The rebase is still in progress. Report the conflict. Once it's resolved and staged with `git add`, run `gh stack rebase --continue`, or run `gh stack rebase --abort` to restore the branches. Stop unless the user asks to resolve it |
| Exit 4 (GitHub API failure)                              | Report it and stop                                                                                                                                                                                                                      |
| Exit 7 (a rebase is already in progress)                 | Report it and stop                                                                                                                                                                                                                      |
| Exit 8 (another gh stack process holds the lock)         | Wait briefly and retry once                                                                                                                                                                                                             |
| Exit 9 (stacks aren't available for the repository)      | Offer the ordinary flow, and say its pull request includes every lower branch                                                                                                                                                           |
| Exit 10 (an interrupted modify session)                  | Tell the user to run `gh stack modify --abort`                                                                                                                                                                                          |
| Any other nonzero exit                                   | Report stderr and stop                                                                                                                                                                                                                  |
| `Sync aborted` or `Push failed` with exit 0              | Treat it as a failed sync and report the output. When the check found a branch diverged with no `+` lines, recommend `action=update`, which pushes it with a lease                                                                      |
| Exit 0 while a branch in scope still has no pull request | Treat the create as partial, and report each pull request's URL and state                                                                                                                                                               |

## Never run

* Bare `gh stack view`, `submit`, `init`, `add`, or `checkout`, which open interactive screens
* `gh stack switch` or any `gh stack modify` command
* `gh stack submit --open` or `gh stack link --open`, which also mark existing drafts ready
* `gh pr merge` on a stack, which can't merge one
* `gh pr update-branch` on a stacked pull request, which adds a merge commit and breaks the stack's linear history
* `--prune` or `--accept-base-change` unless the user asks

## Sources

* [Stacked pull requests](https://docs.github.com/en/pull-requests/reference/stacked-pull-requests), GitHub Docs (CC BY 4.0)
* [Stacked pull requests CLI commands](https://docs.github.com/en/pull-requests/reference/stacked-prs-cli-commands), GitHub Docs (CC BY 4.0)
* [Managing stacked pull requests](https://docs.github.com/en/pull-requests/how-tos/create-pull-requests/managing-stacked-pull-requests), GitHub Docs (CC BY 4.0)
* [github/gh-stack agent skill](https://github.com/github/gh-stack/blob/main/skills/gh-stack/SKILL.md) and [command reference](https://github.com/github/gh-stack/blob/main/skills/gh-stack/references/commands.md), MIT
* github/gh-stack v0.3.0 source: [`cmd/link.go`](https://github.com/github/gh-stack/blob/v0.3.0/cmd/link.go), [`cmd/push.go`](https://github.com/github/gh-stack/blob/v0.3.0/cmd/push.go), [`cmd/sync.go`](https://github.com/github/gh-stack/blob/v0.3.0/cmd/sync.go), and [`internal/git/gitops.go`](https://github.com/github/gh-stack/blob/v0.3.0/internal/git/gitops.go), MIT
