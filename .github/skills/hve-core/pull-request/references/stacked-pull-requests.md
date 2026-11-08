---
title: Stacked pull requests
description: How the pull-request skill describes, publishes, and syncs the branches of a gh stack stack once Stack Detection finds the checked-out branch in one
---

<!-- cspell:ignore upstack -->

## How this reference applies

A stack is a chain of branches in one repository. Each branch's pull request targets the branch below it, and the lowest one targets the stack's base, usually the default branch. Follow this reference together with the pull-request skill's sections once Stack Detection finds the checked-out branch in a stack. The skill's Publishing rule and Stop Rules apply to every `gh stack` step in a pull-request run, even when the official gh-stack agent skill is also installed.

Tested with gh-stack v0.3.0. Flags change between releases, so check `gh stack <command> --help` before relying on one.

## Read the stack

Stack Detection already ran `gh stack view --json`. It returns `trunk`, the stack's base, and `branches[]` from the bottom of the stack to the top. Each entry has `name`, `isCurrent`, `isMerged`, `isQueued`, `needsRebase`, and `pr` with `number`, `url`, and `state`.

* Open branches are the entries that are neither merged nor queued. Skip the others.
* A branch's parent is the nearest lower open entry, or `trunk` when there is none.
* Stacks need every branch in one repository. When the branch pushes to a fork, say that stack mode can't apply and continue with the ordinary flow, whose diff against the base includes the lower branches.

## Scope and descriptions

* `create` covers every open branch without a pull request, because `gh stack submit --auto` opens one for each and can't skip any.
* `update` covers the checked-out branch unless the user asks for the whole stack.
* Collect each branch in scope with `--head <branch> --base refs/heads/<parent>`, or `--base <trunk>` for the lowest open branch (`-Head` and `-Base` in PowerShell).
* Write each description to `.copilot-tracking/pr/stack/<branch>.md`, replacing `/` in the branch name with `-`. A description covers only its own branch. A closing issue keyword goes only on the branch whose merge completes the issue.

## Local checks

Run the skill's Local Checks once, on the checked-out branch. That branch contains every branch below it, so the results cover the branches in scope at or below it. Report the other branches as not checked locally, and check a branch on its own only when the user asks and the working tree is clean.

A repair commit on a branch below the top doesn't reach the branches above it. Say so, and before publishing require `action=sync`, or the user's yes to run `gh stack rebase --upstack` and then `gh stack push`.

## Publish

`gh stack push`, `submit`, and `sync` push every open branch with `--force-with-lease`, which fails when a branch on GitHub changed since the last fetch. That protection misses commits that were fetched but never merged into the local branch, so stack mode adds two rules to the skill's Publishing rule:

* Even after a clear request, ask the one question when the run would push other branches that have new or rewritten commits, or open pull requests the user didn't ask for. List every branch to push with its remote, and say these are force pushes that fail if GitHub changed since the last fetch.
* Run the overwrite check before `submit` or `push`:
  * Skip a branch with no upstream. It was never pushed, and its push requires the branch to be missing on GitHub.
  * For every other open branch, `git cherry <branch> <branch>@{upstream}` lists the commits on GitHub that the local branch lacks. A `+` line has no equivalent locally, so the push would lose it.
  * Stop on any `+` line. When that branch is only behind, recommend `action=sync`, which fast-forwards it. Otherwise show the commits and continue only when the user confirms.
  * After a squash merge, a `+` line can be a lower branch's original commit that already merged, and the message says so.

gh stack picks the remote from the branch's push remote, `remote.pushDefault`, or the branch's upstream. When several remotes leave it unable to choose, pass `--remote <name>` to `submit` and `push`. `sync` has no `--remote` flag in v0.3.0, so when it reports several remotes, stop and tell the user; setting `remote.pushDefault` changes their git configuration.

Then publish in this order:

1. Run `gh stack submit --auto` only after every branch it will open a pull request for has a description that passed the sensitive-text check. When the one question is needed, list each of those branches with its title, its draft state, and whether `gh pr ready` follows.
2. `create` runs `gh stack submit --auto`, which pushes, opens draft pull requests with generated titles for every open branch without one, sets their bases, and links the stack. `update` runs `gh stack push` when a branch needs a push and never runs `submit`, so it can't open pull requests. When branches have no pull request, `update` lists them and recommends `action=create`.
3. Read the pull request numbers from `gh stack view --json`. Check draft and closed state with `gh pr view <number> --json isDraft,state,baseRefName`, because `view --json` reports both as `OPEN`.
4. Set each title and body with `gh pr edit <number> --title <title> --body-file <file>`, following the skill's update rule for boxes and sections a person filled in. Run `gh pr ready <number>` for new pull requests when `draft=false`. A description-only update uses `gh pr edit` alone.
5. If a step fails after pull requests exist, report each one's URL and state.

## Sync

`action=sync` on a stacked branch is a clear request, so it runs without asking unless the one-question rule above applies. Before running, say what will change: force pushes of every open branch, a fast-forward of the local `trunk` branch, and pull request links and bases on GitHub.

1. Run `git fetch <remote>` so the overwrite check sees GitHub's current state, then run the check. Before a sync, only a diverged branch with `+` lines stops the run, because `gh stack sync` fast-forwards branches that are only behind.
2. Run `gh stack sync`. Add `--prune` or `--accept-base-change` only when the user asks. `--prune` deletes local branches whose pull requests merged, and `--accept-base-change` rebases onto a new base after the old one was deleted unmerged, dropping the old base's commits.
3. Treat `Sync aborted` or `Push failed` in the output as a failed sync, whatever the exit code. Confirm success with `gh stack view --json`, where no branch has `needsRebase`, and with `push_state: current` from the collector for each open branch.
4. Tell the user that a rewritten branch may need a fresh review approval where repository rules require approval of the latest push. GitHub keeps approvals when a rebased branch's diff is unchanged.

## Outcomes

| Result                                              | What to do                                                                                                                                                                                                  |
|-----------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Exit 1 (general error) or 5 (invalid arguments)     | Report stderr and stop                                                                                                                                                                                      |
| Exit 3 (rebase conflict)                            | `gh stack sync` already restored every branch. Report the recovery path (`gh stack rebase`, resolve, `git add`, then `gh stack rebase --continue` or `--abort`) and stop unless the user asks to resolve it |
| Exit 4 (GitHub API failure)                         | Report it and stop                                                                                                                                                                                          |
| Exit 7 (a rebase is already in progress)            | Report it and stop                                                                                                                                                                                          |
| Exit 8 (another gh stack process holds the lock)    | Wait briefly and retry once                                                                                                                                                                                 |
| Exit 9 (stacks aren't available for the repository) | Offer the ordinary flow                                                                                                                                                                                     |
| Exit 10 (an interrupted modify session)             | Tell the user to run `gh stack modify --abort`                                                                                                                                                              |
| Any other nonzero exit                              | Report stderr and stop                                                                                                                                                                                      |
| `Sync aborted` or `Push failed` with exit 0         | Treat it as a failed sync and report the output                                                                                                                                                             |

## Never run

* Bare `gh stack view`, `submit`, `init`, `add`, or `checkout`, which open interactive screens
* `gh stack switch` or any `gh stack modify` command
* `gh stack submit --open`, which also marks existing drafts ready
* `gh pr merge` on a stack, which can't merge one
* `gh pr update-branch` on a stacked pull request, which adds a merge commit and breaks the stack's linear history
* `--prune` or `--accept-base-change` unless the user asks

## Creating or reshaping stacks

The pull-request skill doesn't create, adopt, reorder, or merge stacks. When asked, say so and point to `gh stack init <branches>` to create a stack or adopt existing branches, `gh stack merge` to merge one, or the official gh-stack agent skill (`gh skill install github/gh-stack`) for designing and reshaping stacks.

## Sources

* [Stacked pull requests](https://docs.github.com/en/pull-requests/reference/stacked-pull-requests), GitHub Docs (CC BY 4.0)
* [Stacked pull requests CLI commands](https://docs.github.com/en/pull-requests/reference/stacked-prs-cli-commands), GitHub Docs (CC BY 4.0)
* [Managing stacked pull requests](https://docs.github.com/en/pull-requests/how-tos/create-pull-requests/managing-stacked-pull-requests), GitHub Docs (CC BY 4.0)
* [github/gh-stack agent skill](https://github.com/github/gh-stack/blob/main/skills/gh-stack/SKILL.md) and [command reference](https://github.com/github/gh-stack/blob/main/skills/gh-stack/references/commands.md), MIT
* [github/gh-stack `cmd/sync.go`](https://github.com/github/gh-stack/blob/main/cmd/sync.go) and [`internal/git/gitops.go`](https://github.com/github/gh-stack/blob/main/internal/git/gitops.go), MIT
