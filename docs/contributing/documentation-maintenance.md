---
title: Documentation Maintenance
description: How the automated ms.date freshness system detects and flags stale documentation for review
sidebar_position: 8
author: Microsoft
ms.date: 2026-03-10
ms.topic: reference
keywords:
  - documentation
  - ms.date
  - freshness
  - stale
  - maintenance
estimated_reading_time: 4
---

The automated documentation freshness system tracks the `ms.date` frontmatter field across all markdown files and alerts contributors when content becomes outdated. This page explains how the system works, how to fix staleness warnings, and how to configure thresholds for your needs.

## Overview

Every documentation file in this repository is expected to carry an `ms.date` field in its YAML frontmatter. This date reflects when the content was last meaningfully reviewed or updated. The freshness system compares this date against a configurable threshold (default: 90 days) and surfaces stale files through CI annotations, GitHub issues, and a weekly summary.

The system runs in two contexts:

* **Pull request validation** — Checks only the files changed in the PR and fails if any stale files are found.
* **Weekly scheduled scan** — Scans all documentation files on Monday mornings and opens GitHub issues for any file exceeding the threshold.

## How It Works

The `Invoke-MsDateFreshnessCheck.ps1` script reads each file's frontmatter, extracts `ms.date`, and computes the age in days. Files older than the threshold are reported as stale. Results write to:

* `logs/msdate-freshness-results.json` — machine-readable output consumed by the issue automation workflow
* `logs/msdate-summary.md` — human-readable Markdown summary uploaded to the Actions job summary

The PR check uses `changed-files-only: true` so contributors only see annotations for the files they actually touched. The weekly scan runs without this filter to find all outdated content across the repository.

## Fixing Stale Documentation

When the freshness check flags a file, take these steps:

1. Review the flagged file and verify the content is accurate and current.
2. Make any necessary content updates.
3. Update the `ms.date` frontmatter field to today's date in `YYYY-MM-DD` format.
4. Commit and push. The PR check will re-evaluate the updated date.

If a file is flagged but the content is still accurate, update `ms.date` to the current date to acknowledge the review. The date reflects the last review date, not necessarily the last time content changed.

## Configuration

The freshness check exposes these parameters:

| Parameter                  | Default | Description                                                        |
|----------------------------|---------|--------------------------------------------------------------------|
| `staleness-threshold-days` | 90      | Days since `ms.date` before a file is considered stale            |
| `changed-files-only`       | false   | When true, only checks files changed relative to the base branch  |

The PR validation workflow configures the check with `changed-files-only: true`. The weekly scan uses `changed-files-only: false` with default threshold to catch all stale files.

To adjust the threshold repository-wide, update the `staleness-threshold-days` value in both `.github/workflows/pr-validation.yml` and `.github/workflows/weekly-validation.yml`.

## Issue Automation

The weekly scan feeds into `create-stale-docs-issues.yml`, which uses idempotent issue creation to avoid duplicates. Each stale file generates at most one open issue, identified by a hidden automation marker in the issue body:

```text
<!-- automation:stale-docs:{file-path} -->
```

When the weekly scan runs again, the workflow searches for existing open issues with this marker. If one exists, it adds a comment with the updated age. If none exists, it creates a new issue labeled `documentation`, `stale-docs`, `automated`, and `needs-triage`.

Issues are not automatically closed. After updating the documentation and merging your fixes, close the corresponding issue manually or reference it in your pull request for automatic closure.

## Troubleshooting

**Frontmatter missing or malformed** — The script skips files with no frontmatter block. Stale detection requires a valid `---` delimited YAML block with a parseable `ms.date` field. Files without `ms.date` are logged but not counted as stale.

**Date format errors** — Dates must use `YYYY-MM-DD` format. Values like `January 15, 2025` or `2025/01/15` will not parse and the file will be skipped with a warning.

**PR check annotations not appearing** — If annotations are missing, check the Actions run for the `ms.date Freshness Check` job and review the uploaded job summary artifact.

**Weekly workflow not triggering** — The workflow runs on Mondays at 09:00 UTC via `cron: '0 9 * * 1'`. Use `workflow_dispatch` on the `weekly-validation.yml` workflow to trigger a manual run for testing.

## Requirements

* All documentation files under `docs/` must include a `ms.date` frontmatter field.
* Dates must follow `YYYY-MM-DD` format.
* Contributors are expected to update `ms.date` whenever they review or update a documentation file.
