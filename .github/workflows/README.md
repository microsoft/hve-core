---
title: GitHub Workflows
description: Documentation for GitHub Actions workflows in the HVE Core project
author: HVE Core Team
ms.date: 2025-11-12
ms.topic: reference
keywords:
  - github actions
  - workflows
  - ci/cd
  - automation
  - validation
estimated_reading_time: 12
---

# GitHub Actions Workflows

This directory contains GitHub Actions workflow definitions for continuous integration, code quality validation, and automated checks in the HVE Core project.

## Overview

All workflows run automatically on pull requests and pushes to protected branches. They enforce code quality standards, validate documentation, and ensure consistency across the codebase.

## Workflows

### Code Quality

#### `ps-script-analyzer.yml`

**Purpose**: Static analysis of PowerShell scripts using PSScriptAnalyzer

**Triggers**:

* Pull requests modifying `*.ps1` or `*.psm1` files
* Manual workflow dispatch

**Features**:

* Analyzes only changed PowerShell files
* Creates GitHub annotations for violations
* Exports JSON results and markdown summary
* Uploads artifacts with 30-day retention

**Configuration**: `scripts/linting/PSScriptAnalyzer.psd1`

**Exit Behavior**: Fails on Error or Warning severity issues

### Documentation Validation

#### `markdown-lint.yml`

**Purpose**: Enforces markdown formatting standards using markdownlint

**Triggers**:

* Pull requests modifying `*.md` files
* Manual workflow dispatch

**Configuration**: `.markdownlint.json`

**Features**:

* Validates markdown syntax and style
* Checks heading hierarchy
* Enforces consistent list formatting

#### `frontmatter-validation.yml`

**Purpose**: Validates YAML frontmatter and footer format in markdown files

**Triggers**:

* Pull requests modifying `*.md` files
* Manual workflow dispatch

**Features**:

* Validates required frontmatter fields
* Checks footer format and copyright notice
* Creates GitHub annotations for violations
* Exports JSON results with statistics
* Uploads artifacts with 30-day retention

**Configuration**: Hardcoded in `scripts/linting/Validate-MarkdownFrontmatter.ps1`

**Required Frontmatter Fields**:

* `title`
* `description`
* `author`
* `ms.date`
* `ms.topic`
* `keywords`
* `estimated_reading_time`

**Exit Behavior**: Fails if validation errors found

#### `markdown-link-check.yml`

**Purpose**: Validates all links in markdown files using markdown-link-check

**Triggers**:

* Pull requests modifying `*.md` files
* Manual workflow dispatch

**Features**:

* Checks internal and external links
* Retries failed links
* Creates GitHub annotations for broken links
* Exports JSON results with link statistics
* Generates detailed step summary
* Uploads artifacts with 30-day retention

**Configuration**: `scripts/linting/markdown-link-check.config.json`

**Exit Behavior**: Soft-fail (continues workflow but sets failure status)

#### `link-lang-check.yml`

**Purpose**: Detects URLs with language paths that should be removed

**Triggers**:

* Pull requests modifying `*.md` files
* Manual workflow dispatch

**Features**:

* Scans for `/en-us/` and similar patterns
* Creates GitHub warning annotations
* Provides fix instructions in summary
* Uploads artifacts with 30-day retention

**Configuration**: Regex patterns in `scripts/linting/Link-Lang-Check.ps1`

**Exit Behavior**: Warning only (does not fail workflow)

### Content Quality

#### `spell-check.yml`

**Purpose**: Spell checking across all file types using cspell

**Triggers**:

* Pull requests
* Manual workflow dispatch

**Configuration**: `.cspell.json`

**Features**:

* Supports multiple languages
* Custom dictionary support
* Ignores code blocks and technical terms

**Exit Behavior**: Fails on spelling errors

#### `table-format.yml`

**Purpose**: Ensures consistent markdown table formatting

**Triggers**:

* Pull requests modifying `*.md` files
* Manual workflow dispatch

**Features**:

* Aligns table columns
* Validates table structure
* Checks for consistent pipe usage

**Exit Behavior**: Fails on formatting issues

## Common Patterns

### Workflow Structure

All validation workflows follow a consistent pattern:

```yaml
name: Workflow Name
on:
  pull_request:
    paths:
      - '**/*.ext'
  workflow_dispatch:

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4.2.2
      - name: Setup environment
        # Install dependencies
      - name: Run validation
        # Execute validation script
      - name: Upload artifacts
        if: always()
        uses: actions/upload-artifact@v4
```

### Artifact Handling

* **Retention**: 30 days for all artifacts
* **Naming**: `{workflow-name}-results`
* **Contents**: JSON results, markdown summaries, logs
* **Condition**: `if: always()` to upload even on failure

### GitHub Annotations

All workflows create annotations in the format:

```text
::error file={file},line={line}::{message}
::warning file={file},line={line}::{message}
```

These appear in:

* PR files changed view
* Workflow run summary
* Checks tab

### Step Summaries

Workflows generate markdown summaries displayed in the workflow run:

* Overall status (passed/failed)
* Statistics (files checked, issues found)
* Tables of violations with file paths
* Links to artifacts

## Local Testing

All validation scripts can be tested locally before pushing:

```powershell
# PowerShell analysis
.\scripts\linting\Invoke-PSScriptAnalyzer.ps1 -ChangedFilesOnly

# Frontmatter validation
.\scripts\linting\Validate-MarkdownFrontmatter.ps1 -ChangedFilesOnly

# Link validation
.\scripts\linting\Markdown-Link-Check.ps1

# Language path check
.\scripts\linting\Invoke-LinkLanguageCheck.ps1
```

```bash
# Markdown linting
npm run lint:md

# Spell checking
npm run spell-check

# Table formatting
npm run format:tables
```

## Configuration Files

| File                                                 | Purpose                         | Used By                     |
|------------------------------------------------------|---------------------------------|-----------------------------|
| `scripts/linting/PSScriptAnalyzer.psd1`              | PowerShell linting rules        | ps-script-analyzer.yml      |
| `.markdownlint.json`                                 | Markdown formatting rules       | markdown-lint.yml           |
| `scripts/linting/markdown-link-check.config.json`    | Link checking configuration     | markdown-link-check.yml     |
| `.cspell.json`                                       | Spell checking configuration    | spell-check.yml             |
| `.github/instructions/markdown.instructions.md`      | Markdown style guide            | All markdown workflows      |
| `.github/instructions/commit-message.instructions.md` | Commit message standards        | All workflows (informative) |

## Adding New Workflows

To add a new validation workflow:

1. **Create workflow file** in `.github/workflows/` using consistent naming
2. **Follow common patterns** from existing workflows
3. **Add appropriate triggers** (pull_request paths, workflow_dispatch)
4. **Implement artifact uploads** with 30-day retention
5. **Create GitHub annotations** for violations
6. **Generate step summary** with results
7. **Support local testing** with corresponding script
8. **Document** in this README
9. **Test thoroughly** before merging

## Troubleshooting

### Workflow Fails But Local Test Passes

* Check environment differences (Node.js version, PowerShell version)
* Verify all dependencies are installed in workflow
* Review workflow logs for specific error messages

### Artifacts Not Uploading

* Ensure `if: always()` condition is present
* Verify artifact path exists before upload
* Check for file permission issues

### Annotations Not Appearing

* Verify annotation format: `::error file={file},line={line}::{message}`
* Ensure file paths are relative to repository root
* Check that workflow has write permissions

## Related Documentation

* [Linting Scripts Documentation](../../scripts/linting/README.md)
* [Scripts Documentation](../../scripts/README.md)
* [Contributing Guidelines](../../CONTRIBUTING.md)

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
