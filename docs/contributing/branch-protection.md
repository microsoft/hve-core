---
title: Branch Protection Configuration
description: Branch protection configuration for the hve-core repository
sidebar_position: 8
author: Microsoft
ms.date: 2026-11-24
ms.topic: reference
keywords:
  - branch protection
  - rulesets
  - security
  - openssf scorecard
  - codeowners
estimated_reading_time: 5
---

## Overview

The `main` branch of hve-core is governed by a GitHub repository ruleset named `main-branch-protection` (id `9453100`). It targets the default branch, is actively enforced, and has no bypass actors.

Classic branch protection is inert on this repository. The API still reports `main` as `protected`, but `protection.enabled` is `false` and its status-check enforcement level is `off`, so nothing under Settings then Branches governs `main`. If you are looking for these settings, they live under Settings then Rules then Rulesets.

> This page covers contributor-facing configuration and required status checks. For the security policy and rationale behind these controls, see [Branch Protection](../security/branch-protection).

The ruleset requires:

* One aggregate status check, `PR Validation Success`, to pass, both on the pull request and again in the merge queue against the latest `main`
* Two approving reviews, one of which satisfies Code Owner review
* Automatic dismissal of stale approvals when new commits are pushed, paired with approval of the most recent reviewable push
* Every review conversation resolved before merging
* Squash merges only, with force-pushes and branch deletion blocked

## Required Status Checks

One check context must pass before a pull request can merge. The name below is the exact context string the ruleset matches, reported by the GitHub Actions app (integration id `15368`).

| Context                 | Purpose                                                                                                      |
|-------------------------|--------------------------------------------------------------------------------------------------------------|
| `PR Validation Success` | Aggregate job in `pr-validation.yml`; passes only when every PR Validation job either succeeds or is skipped |

`PR Validation Success` depends on the full PR Validation job set, including spell check, markdown and table linting, frontmatter, PowerShell and Python linting and tests, link checks, dependency pinning, workflow security checks, secret scanning, npm audit, and CodeQL. A failure in any of those jobs fails the aggregate check and blocks the merge. Workflows outside PR Validation, such as Dependency Review, are not required.

Merges go through a merge queue. When a pull request enters the queue, GitHub builds a temporary `gh-readonly-queue` branch from the latest `main` plus that pull request, and `pr-validation.yml` runs again on the `merge_group` event. The queue merges with squash, builds and merges one entry at a time, requires every check in a group to pass, and fails an entry whose checks do not report within 60 minutes.

The ruleset does not set the strict up-to-date policy (`strict_required_status_checks_policy` is `false`). The merge queue provides the same guarantee, because every merge is validated against the latest `main`, without requiring authors to update their branch before queueing.

## Review Requirements

| Parameter                                         | Value    | Effect                                                                     |
|---------------------------------------------------|----------|----------------------------------------------------------------------------|
| `required_approving_review_count`                 | 2        | Two approvals are required before merging                                  |
| `require_code_owner_review`                       | true     | A Code Owner for the changed paths must approve                            |
| `require_last_push_approval`                      | true     | The most recent reviewable push needs approval from someone else           |
| `required_review_thread_resolution`               | true     | Every review conversation must be resolved                                 |
| `require_extra_approval_for_unattributed_changes` | true     | Adds one approval when Copilot opens a pull request under its own identity |
| `dismiss_stale_reviews_on_push`                   | true     | Clears existing approvals automatically when new commits are pushed        |
| `dismissal_restriction`                           | disabled | No actor list restricts who may dismiss a review                           |

Stale-review dismissal and last-push approval are both enforced on `main`. Pushing new commits clears existing approvals so reviewers
evaluate the updated branch state, and `require_last_push_approval` ensures the person who pushed the final commit cannot supply its
required approval. Enabling `dismiss_stale_reviews_on_push` retired the earlier accepted gap from [issue #2461](https://github.com/microsoft/hve-core/issues/2461);
see [Branch Protection](../security/branch-protection) for the policy summary.

The `require_extra_approval_for_unattributed_changes` parameter is the ruleset field behind the feature GitHub documents as
[additional approval for unattributed Copilot pull requests](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets#additional-approval-for-unattributed-copilot-pull-requests).
It applies when Copilot opens a pull request under its own app identity rather than on behalf of a person, and it requires one approval
more than the configured count. Because `require_last_push_approval` is also enabled, at least one approval must cover the last push and
come from someone other than Copilot. GitHub enables this rule by default on new and existing rulesets and lists it as public preview and
subject to change, so re-check this description when the ruleset is next revised or when the feature leaves preview.

## Merge, History, and Quality Controls

| Rule                    | Value or state              | Effect                                                           |
|-------------------------|-----------------------------|------------------------------------------------------------------|
| `allowed_merge_methods` | `["squash"]`                | Squash is the only permitted merge method                        |
| `non_fast_forward`      | enforced                    | Force-pushes and other non-fast-forward updates are blocked      |
| `deletion`              | enforced                    | The branch cannot be deleted                                     |
| `code_quality`          | enforced, severity `errors` | Applied by the ruleset at `errors` severity                      |
| `merge_queue`           | enforced                    | Squash, all checks green, one entry at a time, 60-minute timeout |
| `bypass_actors`         | none                        | No actor is exempt from the ruleset                              |

## CODEOWNERS

The `.github/CODEOWNERS` file defines code ownership:

* Default owner for all files: `@microsoft/edge-ai-core-dev`
* Self-protection pattern prevents unauthorized CODEOWNERS modifications
* Key directories have explicit ownership

## OpenSSF Scorecard

The OpenSSF Scorecard Branch-Protection check scores this repository **10/10** under Scorecard `v5.7.0` (`.github/workflows/scorecard.yml` pinned to `ossf/scorecard-action` `v2.6.0`).

Scorecard `v5.7.0` includes [ossf/scorecard#5281](https://github.com/ossf/scorecard/pull/5281), which credits a repository ruleset
merge queue for up-to-date branch protection without enabling `strict_required_status_checks_policy`. Together with
`dismiss_stale_reviews_on_push` (`true`) on `main-branch-protection`, two required approvals, Code Owner review, last-push approval,
and blocked force-pushes and branch deletion, all Branch-Protection tier requirements are satisfied and earlier code scanning alert
[#1](https://github.com/microsoft/hve-core/security/code-scanning/1) is resolved on `main`.

## Configuration Reference

### Where the Settings Live

Navigate to Settings, then Rules, then Rulesets, then `main-branch-protection`. There is nothing to edit under Settings then Branches; classic branch protection does not govern `main`.

Editing the ruleset requires repository administrator permissions.

### Verifying This Page

Every rule and parameter value documented here can be read back from the API, though a few are stated in a friendlier form than the raw
response. For example, `deletion` and `non_fast_forward` carry no parameters and are documented as enforced because the rule is present,
and `bypass_actors` "none" corresponds to a null value. What each rule actually does is not exposed by the API at all, so where the tables
above describe behavior rather than restate a value, they are summaries. For authoritative descriptions, see GitHub's
[available rules for rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets).

```bash
# All active rules for main, with their parameters
gh api repos/microsoft/hve-core/rules/branches/main --jq '.[] | {type, parameters}'

# Ruleset identity, enforcement, and bypass actors
gh api repos/microsoft/hve-core/rulesets/9453100 \
  --jq '{name, enforcement, bypass_actors, conditions}'

# Confirm classic branch protection is inert
gh api repos/microsoft/hve-core/branches/main --jq '{protected, protection}'
```

## Change Management

| Item                     | Details                                                                                                                         |
|--------------------------|---------------------------------------------------------------------------------------------------------------------------------|
| Strict up-to-date policy | Off by design; the merge queue validates against the latest `main`, and Scorecard `v5.7.0`+ credits ruleset merge queues        |
| Documentation            | Update this page and [Branch Protection](../security/branch-protection) when the ruleset or its Scorecard configuration changes |

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
