---
title: Branch Protection
description: Main branch protection requirements for the hve-core repository
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-23
ms.topic: reference
keywords:
  - branch protection
  - rulesets
  - codeowners
  - security
  - pull requests
estimated_reading_time: 4
---

## Overview

The main branch for hve-core is protected to reduce the risk of unreviewed or unauthorized changes to workflow and release automation.

That protection comes from a GitHub repository ruleset named `main-branch-protection` (id `9453100`), which targets the default branch and is actively enforced with no bypass actors. Classic branch protection is inert on this repository: the GitHub API reports `main` as `protected`, but `protection.enabled` is `false` and its status-check enforcement level is `off`. The ruleset is the mechanism that matters.

> This page describes the security policy and rationale for branch protection. For contributor-facing configuration steps, required status checks, and OpenSSF Scorecard guidance, see [Branch Protection Configuration](../contributing/branch-protection.md).

## Required Controls

The `main-branch-protection` ruleset enforces the following on the default branch:

* Require a pull request before merging, with two approving reviews
* Require review from a Code Owner before merging
* Require approval of the most recent reviewable push, so a final commit cannot merge on an earlier reviewer's approval alone
* Require an extra approval on pull requests that Copilot opens under its own identity rather than on behalf of a person
* Require every review conversation to be resolved before merging
* Require six status checks to pass, with the branch up to date with `main` first
* Restrict merges to squash only
* Block force-pushes and any other non-fast-forward update
* Block deletion of the branch
* Apply the repository code-quality rule at `errors` severity

The Copilot control above is the ruleset parameter `require_extra_approval_for_unattributed_changes`, which GitHub documents as
[additional approval for unattributed Copilot pull requests](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets#additional-approval-for-unattributed-copilot-pull-requests).
When Copilot opens a pull request that is not attributed to a person, the ruleset requires one approval more than the configured count.
GitHub enables this rule by default on new and existing rulesets, so its presence here is not by itself evidence of a deliberate choice,
and GitHub lists it as public preview and subject to change. Re-check this description when the ruleset is next revised or when the
feature leaves preview.

For the exact status-check contexts and per-parameter values, see [Branch Protection Configuration](../contributing/branch-protection.md).

## Accepted Gap: Stale Review Dismissal

Stale-review dismissal is not currently enforced. The ruleset sets `dismiss_stale_reviews_on_push` to `false`, so an existing approval is not automatically cleared when a contributor pushes new commits.

The compensating control is `require_last_push_approval`, which is enabled. The most recent reviewable push must itself be approved by someone other than the person who pushed it, so an approval cannot silently carry forward onto commits nobody reviewed. Two other controls narrow the window further: the strict status-check policy re-runs every required check against the final commit, and unresolved review conversations block merging.

This gap was assessed and accepted in [issue #2461](https://github.com/microsoft/hve-core/issues/2461), where the corresponding OpenSSF Scorecard alert was dismissed as *Won't fix* with a documented rationale.

Two conditions should reopen that decision:

* `require_last_push_approval` is relaxed or disabled. It is the entire basis for accepting the gap, so the two settings must never both be off.
* The `main-branch-protection` ruleset is revised for any other reason, which is the natural moment to enable stale-review dismissal and close the gap outright.

Verify the current value at any time:

```bash
gh api repos/microsoft/hve-core/rules/branches/main \
  --jq '.[] | select(.type=="pull_request") | .parameters.dismiss_stale_reviews_on_push'
```

## CODEOWNERS Coverage

The repository's `CODEOWNERS` file assigns ownership for repository configuration and workflow definitions under the `.github/` path to the core team. That ownership is the review path that supports the ruleset requirement for Code Owner approval.

## Rationale

These controls strengthen the repository's supply-chain posture by ensuring that changes to workflows, automation, and release logic are reviewed by the appropriate maintainers before they can merge. Requiring two approvals with Code Owner coverage raises the cost of a single compromised or careless account, and the squash-only, no-force-push, no-deletion rules keep the history of `main` append-only and auditable.

---

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
