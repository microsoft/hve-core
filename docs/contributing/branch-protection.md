---
title: Branch Protection Configuration
description: Branch protection configuration for the hve-core repository
sidebar_position: 8
author: Microsoft
ms.date: 2026-08-23
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

> This page covers contributor-facing configuration and required status checks. For the security policy and rationale behind these controls, see [Branch Protection](../security/branch-protection.md).

The ruleset requires:

* Six status checks to pass, against a branch that is up to date with `main`
* Two approving reviews, one of which satisfies Code Owner review
* Approval of the most recent reviewable push, which is the control that protects against commits pushed after an approval
* Every review conversation resolved before merging
* Squash merges only, with force-pushes and branch deletion blocked

## Required Status Checks

Six check contexts must pass before a pull request can merge. The names below are the exact context strings the ruleset matches, so they can be compared directly against the checks listed on a pull request.

| Context                                                  | Purpose                         |
|----------------------------------------------------------|---------------------------------|
| `Spell Check / Spell Check`                              | Validates spelling in markdown  |
| `Frontmatter Validation / Validate Markdown Frontmatter` | Validates YAML frontmatter      |
| `Markdown Lint / Markdown Lint`                          | Enforces markdown formatting    |
| `PowerShell Lint / PowerShell Lint`                      | PSScriptAnalyzer validation     |
| `Table Format Check / Table Format Check`                | Validates table formatting      |
| `CodeQL Security Analysis / CodeQL Analysis (actions)`   | Security vulnerability scanning |

The ruleset applies a strict policy (`strict_required_status_checks_policy`), so a branch must be up to date with `main` before merging and the required checks are evaluated against the final commit.

Other CI jobs run on pull requests but are not required, including `Markdown Link Check`, `Validate Dependency Pinning`, and `npm Security Audit`. A failure in one of those does not block a merge on its own.

## Review Requirements

| Parameter                                         | Value    | Effect                                                                     |
|---------------------------------------------------|----------|----------------------------------------------------------------------------|
| `required_approving_review_count`                 | 2        | Two approvals are required before merging                                  |
| `require_code_owner_review`                       | true     | A Code Owner for the changed paths must approve                            |
| `require_last_push_approval`                      | true     | The most recent reviewable push needs approval from someone else           |
| `required_review_thread_resolution`               | true     | Every review conversation must be resolved                                 |
| `require_extra_approval_for_unattributed_changes` | true     | Adds one approval when Copilot opens a pull request under its own identity |
| `dismiss_stale_reviews_on_push`                   | false    | Not enforced; see the note below                                           |
| `dismissal_restriction`                           | disabled | No actor list restricts who may dismiss a review                           |

Stale-review dismissal is not enforced, so an approval is not automatically cleared when new commits are pushed. `require_last_push_approval` compensates: the final push must itself be approved by someone other than the person who pushed it. That gap was assessed and accepted in [issue #2461](https://github.com/microsoft/hve-core/issues/2461), and the reasoning is summarized in [Branch Protection](../security/branch-protection.md).

The `require_extra_approval_for_unattributed_changes` parameter is the ruleset field behind the feature GitHub documents as
[additional approval for unattributed Copilot pull requests](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets#additional-approval-for-unattributed-copilot-pull-requests).
It applies when Copilot opens a pull request under its own app identity rather than on behalf of a person, and it requires one approval
more than the configured count. Because `require_last_push_approval` is also enabled, at least one approval must cover the last push and
come from someone other than Copilot. GitHub enables this rule by default on new and existing rulesets and lists it as public preview and
subject to change, so re-check this description when the ruleset is next revised or when the feature leaves preview.

## Merge, History, and Quality Controls

| Rule                    | Value or state              | Effect                                                      |
|-------------------------|-----------------------------|-------------------------------------------------------------|
| `allowed_merge_methods` | `["squash"]`                | Squash is the only permitted merge method                   |
| `non_fast_forward`      | enforced                    | Force-pushes and other non-fast-forward updates are blocked |
| `deletion`              | enforced                    | The branch cannot be deleted                                |
| `code_quality`          | enforced, severity `errors` | Applied by the ruleset at `errors` severity                 |
| `bypass_actors`         | none                        | No actor is exempt from the ruleset                         |

## CODEOWNERS

The `.github/CODEOWNERS` file defines code ownership:

* Default owner for all files: `@microsoft/edge-ai-core-dev`
* Self-protection pattern prevents unauthorized CODEOWNERS modifications
* Key directories have explicit ownership

## OpenSSF Scorecard

The OpenSSF Scorecard Branch-Protection check scores this repository **9/10**.

The single remaining deduction is `'stale review dismissal' is disabled on branch 'main'`. Nothing else in the current configuration costs points, and the deduction cannot be closed by a pull request, because the setting lives in the ruleset rather than in the source tree.

Scorecard does not model `require_last_push_approval` as a substitute for stale-review dismissal, so the compensating control described above earns no credit. The delta is a scoring gap with a compensating control in place rather than an open exposure. See [issue #2461](https://github.com/microsoft/hve-core/issues/2461) for the full assessment and the dismissal rationale.

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

| Item                         | Details                                                                                                           |
|------------------------------|-------------------------------------------------------------------------------------------------------------------|
| Stale-review dismissal       | Enable it the next time the ruleset is revised; that closes the remaining Scorecard deduction                     |
| `require_last_push_approval` | Must not be relaxed while stale-review dismissal is off; it is the basis for accepting that gap                   |
| Documentation                | Update this page, [Branch Protection](../security/branch-protection.md), and issue #2461 when the ruleset changes |

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
