---
title: Shared Library
description: Shared utility scripts and modules used across hve-core automation
author: HVE Core Team
ms.date: 2025-11-05
ms.topic: reference
keywords:
  - powershell
  - utilities
  - ci
  - downloads
estimated_reading_time: 3
---

This directory contains shared utility scripts and modules used across the
`hve-core` automation scripts.

## Scripts

### `Get-VerifiedDownload.ps1`

Downloads and verifies artifacts using SHA256 checksums.

**Purpose**: Provide tamper-evident file downloads for CI tooling.

**Features**:

* Downloads files from a URL and verifies against an expected SHA256 hash
* Supports optional extraction of archives
* Exposes `Get-FileHashValue` and `Test-HashMatch` functions for reuse

**Parameters**:

* `-Url` - Download URL
* `-ExpectedSHA256` - Expected SHA256 hash for verification
* `-OutputPath` - Local file path for the download
* `-Extract` (switch) - Extract the downloaded archive after verification
* `-ExtractPath` - Destination path for extraction

**Usage**:

```powershell
# Download and verify a tool
./scripts/lib/Get-VerifiedDownload.ps1 -Url "https://example.com/tool.zip" `
    -ExpectedSHA256 "abc123..." -OutputPath "./tools/tool.zip"

# Download, verify, and extract
./scripts/lib/Get-VerifiedDownload.ps1 -Url "https://example.com/tool.zip" `
    -ExpectedSHA256 "abc123..." -OutputPath "./tools/tool.zip" `
    -Extract -ExtractPath "./tools/"
```

## Modules

### `Modules/CIHelpers.psm1`

Shared CI platform detection and output utilities imported by scripts across
the repository.

| Function                         | Purpose                                                |
|----------------------------------|--------------------------------------------------------|
| `ConvertTo-GitHubActionsEscaped` | Escapes strings for GitHub Actions workflow commands   |
| `ConvertTo-AzureDevOpsEscaped`   | Escapes strings for Azure DevOps logging commands      |
| `Get-CIPlatform`                 | Returns the current CI platform (GitHub, AzureDevOps)  |
| `Test-CIEnvironment`             | Detects whether the script runs in a CI environment    |
| `Set-CIOutput`                   | Sets output variables for the current CI platform      |
| `Set-CIEnv`                      | Sets environment variables for the current CI platform |
| `Write-CIStepSummary`            | Appends content to the GitHub Actions step summary     |
| `Write-CIAnnotation`             | Writes a single CI warning or error annotation         |
| `Write-CIAnnotations`            | Writes multiple CI annotations from a violations array |
| `Set-CITaskResult`               | Sets the CI task result (succeeded, failed)            |
| `Publish-CIArtifact`             | Publishes a file as a CI artifact                      |

## Related Documentation

* [Scripts README](../README.md) for overall script organization

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
