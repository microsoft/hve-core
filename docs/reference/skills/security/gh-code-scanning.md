---
title: gh-code-scanning
description: Retrieves and groups GitHub code scanning alerts by rule and severity using the gh CLI
sidebar_position: 1
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - security
  - gh-code-scanning
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                              |
|-------------|------------------------------------------------------------------------------------|
| Kind        | skill                                                                              |
| Source      | `.github/skills/security/gh-code-scanning`                                         |
| Invocation  | Invoked directly as `/gh-code-scanning`, or loaded on demand by referencing agents |
| Interactive | No                                                                                 |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Retrieves and groups GitHub code scanning alerts by rule and severity using the gh CLI
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill to triage existing GitHub code scanning alerts by rule, frequency,
severity, and affected paths. It retrieves findings; it does not run CodeQL or fix
the code. Supply the repository owner, repository name, and branch, which defaults
to `main`.

The supported PowerShell retrieval script requires PowerShell 7+ and an
authenticated GitHub CLI with appropriate repository access. Use JSON for
programmatic consumption. Do not substitute `gh api` for alert listing or grouping;
single-alert detail and analysis metadata are separate supported reads.

## Example usage

For a repository you are authorized to inspect, ask: `/gh-code-scanning Summarize
open alerts for example-org/sample-service on release; do not create issues or
change alert status.` Replace the illustrative repository with your own.

The expected flow uses `scripts/Get-CodeScanningAlerts.ps1` within the skill
directory with `-Owner`, `-Repo`, `-Branch release`, and `-OutputFormat Json`.
The summary should retain rule IDs, counts, alert links, and affected paths rather
than inventing one file per finding. Repository-level findings can have
`HasFilePaths: false` and an empty `AffectedPaths` array.

A useful result distinguishes a missing `SecuritySeverity` from the fallback
`Severity` and identifies the largest groups for follow-up. Authentication failure
is a prerequisite blocker, not evidence of zero alerts. Keep credentials out of
the request; issue creation is a separate write decision.
