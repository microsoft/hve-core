---
title: Branch Protection
description: Main branch protection requirements for the hve-core repository
sidebar_position: 2
author: Microsoft
ms.date: 2026-11-24
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

> This page describes the security policy and rationale for branch protection. For contributor-facing configuration steps, required status checks, and OpenSSF Scorecard guidance, see [Branch Protection Configuration](../contributing/branch-protection).

## Required Controls

The `main-branch-protection` ruleset enforces the following on the default branch:

* Require a pull request before merging, with two approving reviews
* Require review from a Code Owner before merging
* Dismiss stale pull request approvals automatically when new commits are pushed
* Require approval of the most recent reviewable push, so a final commit cannot merge on an earlier reviewer's approval alone
* Require an extra approval on pull requests that Copilot opens under its own identity rather than on behalf of a person
* Require every review conversation to be resolved before merging
* Require the aggregate `PR Validation Success` status check to pass, and merge through a merge queue that re-runs it against the latest `main`
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

Pairing automatic stale-review dismissal (`dismiss_stale_reviews_on_push`) with last-push approval (`require_last_push_approval`)
ensures new commits clear prior approvals while preventing the person who pushed the final commit from supplying its required approval;
queue validation re-runs `PR Validation Success` against `main` without pushing to the pull request branch, retiring the earlier accepted
gap in [issue #2461](https://github.com/microsoft/hve-core/issues/2461). For the exact status-check contexts, per-parameter values, API
verification commands, and OpenSSF Scorecard status, see [Branch Protection Configuration](../contributing/branch-protection).

## CODEOWNERS Coverage

The repository's `CODEOWNERS` file assigns ownership for repository configuration and workflow definitions under the `.github/` path to the core team. That ownership is the review path that supports the ruleset requirement for Code Owner approval.

## Rationale

These controls strengthen the repository's supply-chain posture by ensuring that changes to workflows, automation, and release logic are reviewed by the appropriate maintainers before they can merge. Requiring two approvals with Code Owner coverage raises the cost of a single compromised or careless account, and the squash-only, no-force-push, no-deletion rules keep the history of `main` append-only and auditable.

---

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
