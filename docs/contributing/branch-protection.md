---
title: Branch Protection Configuration
description: Branch protection configuration for the hve-core repository
sidebar_position: 8
author: Microsoft
ms.date: 2026-01-16
ms.topic: reference
keywords:
  - branch protection
  - security
  - openssf scorecard
  - codeowners
estimated_reading_time: 3
---

## Overview

Guidelines and configuration for GitHub branch protection rules in hve-core.

Branch protection rules ensure code quality and security by requiring:

* Status checks to pass before merging
* Code review approval
* Protection against post-approval malicious commits

## Required Status Checks

The following CI jobs must pass before a PR can be merged:

| Check Name                  | Purpose                           |
|-----------------------------|-----------------------------------|
| Spell Check                 | Validates spelling in markdown    |
| Markdown Lint               | Enforces markdown formatting      |
| Table Format Check          | Validates table formatting        |
| PowerShell Lint             | PSScriptAnalyzer validation       |
| Frontmatter Validation      | Validates YAML frontmatter        |
| Validate Dependency Pinning | Ensures dependencies are pinned   |
| npm Security Audit          | Scans for vulnerable dependencies |
| CodeQL Security Analysis    | Security vulnerability scanning   |

**Note**: `Markdown Link Check` uses soft-fail and is not a required check.

## Review Requirements

| Setting               | Value   | Rationale                                     |
|-----------------------|---------|-----------------------------------------------|
| Required reviewers    | 1       | Team size decision                            |
| Dismiss stale reviews | Enabled | Prevents post-approval malicious commits      |
| Last push approval    | Enabled | Requires non-author approval of final changes |
| Code owner review     | Enabled | Ensures domain experts review changes         |

## CODEOWNERS

The `.github/CODEOWNERS` file defines code ownership:

* Default owner for all files: `@microsoft/edge-ai-core-dev`
* Self-protection pattern prevents unauthorized CODEOWNERS modifications
* Key directories have explicit ownership

## OpenSSF Scorecard

With this configuration, the expected OpenSSF Scorecard Branch Protection score is **~8/10**.

**Note**: Achieving 10/10 requires 2 reviewers. The current configuration prioritizes team velocity with 1 reviewer.

## Configuration Reference

### GitHub UI Settings

Navigate to: **Settings → Branches → Branch protection rules → Edit `main`**

**Require a pull request before merging**:

* [x] Require approvals (1)
* [x] Dismiss stale pull request approvals when new commits are pushed
* [x] Require approval of the most recent reviewable push
* [x] Require review from Code Owners

**Require status checks to pass before merging**:

* [x] Require branches to be up to date before merging
* Add all status checks listed in table above

**Other settings**:

* [x] Do not allow bypassing the above settings

## Future Considerations

| Item            | Details                                                       |
|-----------------|---------------------------------------------------------------|
| GitHub Rulesets | Consider migrating to Rulesets for enhanced push restrictions |
| 2 reviewers     | Can be enabled as team grows for Tier 4 (9/10) score          |

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
