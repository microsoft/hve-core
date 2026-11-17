---
name: pull-request
description: 'Prepare, create, update, or sync a GitHub pull request with targeted local checks and repair commits. Supports optional stacked pull requests through the gh stack extension. Routes Azure DevOps to backlog-management.'
argument-hint: '[base=auto] [draft=false] [action=prepare|create|update|sync] [stack=auto|off]'
license: MIT
user-invocable: true
compatibility: 'Requires git. GitHub create and update use the available GitHub integration, and sync uses the gh CLI. Azure DevOps create needs the Azure DevOps MCP server. Stacked pull requests need the optional gh stack extension.'
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0.0"
  last_updated: "2026-11-08"
---

# Pull Request

## Goal

Turn a branch into a review-ready GitHub pull request. Its title and body match the committed diff and keep the repository template, the targeted local checks that ran have passed, any repair the user asked for is committed, and nothing is published unless the request asks for it or the user says yes.

This skill doesn't create, adopt, reorder, or merge stacks. For that, point to `gh stack init <branches>`, `gh stack merge`, or the gh-stack agent skill (`gh skill install github/gh-stack`).

## Inputs

* `base`: base branch or ref. Default: the remote default branch, read from local refs without fetching.
* `draft`: whether a new pull request starts as a draft. Default: `false`.
* `action`: `prepare`, `create`, `update`, or `sync`, inferred from the request. Without a clear request to publish, use `prepare`.
* `stack`: `auto` (default) uses stack mode for a branch in a `gh stack` stack; `off` always uses the ordinary flow.

The head is the checked-out branch. Ask only for an input you can't infer that changes the result.

## Platform Routing

When the push remote is on Azure DevOps (`dev.azure.com` or `*.visualstudio.com`), or the user asks for an Azure DevOps pull request, follow the `backlog-management` skill's Azure DevOps pull request reference instead of this Flow. If that skill doesn't resolve, say so and stop before any Azure DevOps call.

Resolve `action` first. Map `base`, with this skill's default, to `baseBranch` and `draft` to `isDraft`. Azure DevOps inputs the user gives directly win over these aliases, and other inputs such as project, repository, or work item IDs pass through.

* `prepare`: run only the reference's Phase 1 and Phase 2, with its sanitization and untrusted content rules, then return the description path before any Azure DevOps call.
* `create`: run the reference's Mandatory Preflight and Required Phases with all of their destination, sanitization, and approval steps.
* `update` and `sync`: the reference only creates pull requests. Say these aren't supported, stop before any Azure DevOps call, and offer `prepare` for a manual update.

## Flow

1. Collect context with `scripts/collect-context.sh` or `scripts/Collect-Context.ps1` (`--base` or `-Base`). They only read local refs.
2. Stop if the repository, branch, base, or merge base can't be resolved, and report nothing to submit when no commits follow the merge base. Leave uncommitted files out, and ask about them only when the request seems to include them.
3. On the GitHub flow with `stack=auto`, run Stack Detection. For `action=sync`, skip steps 4 to 6.
4. Read the committed diff from the merge base, changed files and stats first, then the diffs that change what a reviewer sees. Delegate only a large diff that splits cleanly.
5. Write the title and body to `.copilot-tracking/pr/pr.md` under Templates and Description Standard. Use the repository's title convention or a short imperative title, and add closing issue references only when the branch or commits name the issue.
6. Run Local Checks, and follow Repair Commits when the user asks for a fix. Then update the title, body, and recorded check results to match the final diff.
7. Publish under Publishing, or stop with the description.
8. Return the Final Response.

## Stack Detection

Stack mode starts only when `gh extension list` lists `github/gh-stack` and `gh stack view --json` exits 0 with a `branches[]` entry whose `isCurrent` is `true`. Then read `references/stacked-pull-requests.md` and follow it, with this skill's sections, for the rest of the run.

The ordinary flow runs when `gh` or the extension is missing, when the command exits 2 and stderr says the branch is not part of a stack, or when it exits 0 without an `isCurrent` entry. Exit 6 means the branch is in more than one stack: stop and ask the user to check out a branch in one stack or pass `stack=off`. Any other result, including other exit 2 errors, stops the run, reports stderr, and offers `stack=off`. Never fall back to the ordinary flow after an error, because its diff against the stack's base would include every lower branch.

The command reads pull request state from GitHub and refreshes gh's local stack catalog, even for `prepare`, and changes nothing else.

## Templates

Use the first template that applies:

1. A template the user names
2. A repository template. Look in `<repository-root>/.github/`, then `<repository-root>/`, then `<repository-root>/docs/`, taking `pull_request_template.md` before the files in that folder's `PULL_REQUEST_TEMPLATE/`, in any letter case. The collectors list them in this order under `[templates]`.
3. A copy of this skill's `templates/pull-request.md`

When several fit equally well, ask the user to choose. Keep the template's headings, comments, and checkboxes, fill placeholders with verified content, and drop empty optional sections from this skill's template. Apply repository instructions that match the description file, such as change-type mappings.

## Description Standard

Write for a human reviewer in direct, neutral language: a short plain summary first, then material changes grouped by reviewer concern, most important first. Include only the impact, compatibility, security, migration, testing, and follow-up details the diff or commits support. Mention files only when they help a reviewer find their way, and leave out commit transcripts, full file lists, and the history of the work.

Check a box only when the diff or a command result proves it. Never check qualified-human review, security attestation, manual test, or hosted CI boxes.

Remove secrets, credentials, private classifications, internal-only notes, and other sensitive text from every description, following any content-policy rules the repository sets for public output. Don't quote removed text.

## Local Checks

Local checks predict CI and never stand in for a hosted check that didn't run.

* Always run `git diff --check` on the committed diff.
* Inspect the workflows whose path triggers match the changed files. From package scripts, path-scoped instructions, and those workflow steps, pick the smallest non-mutating checks that own the changed areas, such as focused tests and validators.
* Skip full validation suites and `ci:*` wrappers unless the user asks. When a matching workflow calls a `ci:*` wrapper and no equivalent local command exists, run the wrapper's locally safe, non-mutating child checks. This doesn't cover browser suites, service-dependent tests, security scans, or other CI-only setups.
* Follow the repository's dependency setup rules before commands that need installed packages.
* Record only checks that ran, with their results. Record matching steps that need CI-only setup as pending or unavailable.
* A failed required check, a missing dependency for one, or a generated file known to be stale stops publishing. Keep the description, and change source only when the user asks for a fix.

## Repair Commits

A request to fix a reported failure covers the fix and a commit that holds only the fix.

1. Record the tracked and untracked working-tree state, make the smallest in-scope fix, and rerun every check it affects.
2. After those checks pass, stage only the fix, review the staged names and patch, and commit under the repository's commit conventions, or with a short imperative subject when it has none. Give separate logical parts separate commits.
3. Confirm each commit holds only the fix, then collect context again.

Never stage earlier edits, unrelated changes, logs, or the description file. When a file mixes earlier edits with the fix, leave it unstaged and stop with what the user must separate. Don't amend, squash, rebase, or make an empty commit unless the user asks.

## Publishing

Publishing means pushing commits, creating or editing a pull request, marking it ready for review, or syncing it with its base on GitHub.

* A clear request publishes without asking: `action=create`, `action=update`, `action=sync`, or plain words such as "push this and open a pull request". `action=prepare`, or a request for only a description, publishes nothing.
* When the intent is unclear, write the description, then ask one question that lists what would be published: each branch to push, the title, the target branch, and the draft state. One yes covers all of it. Ask the same question when a clear request would publish more than it named.
* The Stop Rules always apply.

Ordinary pushes follow the Push Authorization, Account Changes, and Execution Evidence rules in the `git-merge` skill's [merge conventions](../git-merge/references/merge-conventions.md), where a push the publishing rule allows counts as requested or approved. Those rules forbid force pushes and cover ordinary pushes only; stack pushes follow the stack reference. If a push fails or can't run, report the actual result and stop before any write that depends on it.

Before creating or editing, look for an open pull request with the same head and base:

* `create`: return the URL of one that exists. Otherwise push when the branch needs it and create the pull request through the available GitHub integration with the title, body, base, and draft state.
* `update`: read the current title and body, keep boxes and sections a person filled in, update the rest, and report what changed. Without an open pull request, say so and offer `create`.
* `sync` outside a stack:
  * With every commit pushed, run `gh pr update-branch <number>`, which merges the base on GitHub (`--rebase` only when the user asks). Then run `git fetch <remote> <branch>` and, with a clean working tree, `git merge --ff-only` against the tracking branch.
  * Local commits that aren't on GitHub yet must be pushed first. The sync request didn't name that push, so ask the one question, or stop.
  * Without an open pull request, report how far the branch is behind its base and stop.
  * If `gh pr update-branch` fails or is turned off, report it and suggest a local update with the `git-merge` skill.
  * A stacked pull request never uses `gh pr update-branch`; the stack reference covers its sync.

## Stop Rules

* `Blocked`: the branch, base, merge base, template choice, commit conventions, or what to publish can't be resolved; a fix can't be separated from earlier edits; a commit fails; or stack detection stopped. Outside stack mode, a branch `behind` or `diverged` from its GitHub copy also blocks publishing, apart from `action=sync` on a branch that is only behind. Suggest `git pull --ff-only` when it's only behind, or a local merge or rebase with the `git-merge` skill when it has diverged.
* `Revise`: a required local check failed or can't run, a generated file is stale, or the description has an unsupported claim or sensitive text you can't remove. A requested repair stays `Revise` until the affected checks pass and its commit succeeds.
* `Prepared`: the description is written and checked, and nothing was published.
* `Created`, `Updated`, or `Synced`: only after returning each pull request URL with its hosted check state, or the sync result.

## Final Response

Return the outcome, title, base and head, description path (one per branch in a stack), repair commits, local checks and their results, broad checks skipped, limits, and each pull request URL or the sync result. Keep it brief and don't repeat the body.
