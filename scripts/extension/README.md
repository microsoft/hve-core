---
title: Extension Scripts
description: PowerShell scripts for VS Code extension preparation, packaging, and collection discovery
author: HVE Core Team
ms.date: 2025-11-05
ms.topic: reference
keywords:
  - powershell
  - vscode
  - extension
  - packaging
  - vsix
estimated_reading_time: 5
---

This directory contains PowerShell scripts for preparing, packaging, and
publishing the HVE Core VS Code extension.

## Architecture

The extension packaging pipeline follows a three-stage process:

1. `Find-CollectionManifests.ps1` discovers collection manifests and builds a
   packaging matrix
2. `Prepare-Extension.ps1` gathers agents, prompts, instructions, and skills,
   filtering by maturity and channel
3. `Package-Extension.ps1` produces one `.vsix` per collection using `vsce`

All three scripts import `CIHelpers.psm1` and `CollectionHelpers.psm1` for CI
platform detection and YAML manifest parsing.

## Scripts

### `Prepare-Extension.ps1`

Prepares extension contents by auto-discovering agents, prompts, instructions,
and skills from the repository.

**Purpose**: Gather and filter artifacts for inclusion in the extension package.

**Features**:

* Auto-discovers `.agent.md`, `.prompt.md`, `.instructions.md`, and `SKILL.md`
  files
* Filters artifacts by maturity level and release channel
* Supports collection-scoped preparation
* Dry-run mode for previewing changes

**Parameters**:

* `-ChangelogPath` - Path to the changelog file
* `-Channel` - Release channel: `Stable` or `PreRelease`
* `-DryRun` (switch) - Preview changes without modifying files
* `-Collection` - Collection name for scoped preparation

**Usage**:

```powershell
# Prepare stable channel
./scripts/extension/Prepare-Extension.ps1

# Prepare pre-release channel
./scripts/extension/Prepare-Extension.ps1 -Channel PreRelease

# Dry run to preview
./scripts/extension/Prepare-Extension.ps1 -DryRun
```

### `Package-Extension.ps1`

Packages the VS Code extension into a `.vsix` file using `vsce`.

**Purpose**: Produce a distributable extension package from prepared contents.

**Features**:

* Sets version from parameters or changelog
* Supports pre-release and dev patch builds
* Collection-scoped packaging
* Dry-run mode for validation

**Parameters**:

* `-Version` - Explicit version string
* `-DevPatchNumber` - Development patch number for dev builds
* `-ChangelogPath` - Path to the changelog file
* `-PreRelease` (switch) - Mark as pre-release build
* `-Collection` - Collection name for scoped packaging
* `-DryRun` (switch) - Preview changes without producing a package

**Usage**:

```powershell
# Package the extension
./scripts/extension/Package-Extension.ps1

# Package a pre-release build
./scripts/extension/Package-Extension.ps1 -PreRelease

# Package a specific collection
./scripts/extension/Package-Extension.ps1 -Collection hve-core
```

### `Find-CollectionManifests.ps1`

Discovers collection manifests for the packaging matrix.

**Purpose**: Build a list of collections to package based on channel and
maturity rules.

**Features**:

* Scans `collections/` for `.collection.yml` files
* Filters collections by maturity and channel
* Outputs a matrix for CI workflow consumption

**Parameters**:

* `-Channel` - Release channel filter: `Stable` or `PreRelease`
* `-CollectionsDir` - Path to the collections directory

**Usage**:

```powershell
# Discover stable collections
./scripts/extension/Find-CollectionManifests.ps1 -Channel Stable

# Discover all collections for pre-release
./scripts/extension/Find-CollectionManifests.ps1 -Channel PreRelease
```

## npm Scripts

| npm Script                     | Description                   |
|--------------------------------|-------------------------------|
| `extension:prepare`            | Prepare stable channel        |
| `extension:prepare:prerelease` | Prepare pre-release channel   |
| `extension:package`            | Package extension             |
| `extension:package:prerelease` | Package pre-release extension |
| `package:extension`            | Alias for `extension:package` |

## GitHub Actions Integration

The extension packaging workflow (`extension-package.yml`) orchestrates all
three scripts:

1. `Find-CollectionManifests.ps1` produces the collection matrix
2. `Prepare-Extension.ps1` runs per collection to gather artifacts
3. `Package-Extension.ps1` runs per collection to produce `.vsix` files

See [Build Workflows](../../docs/architecture/workflows.md) for pipeline
details.

## Related Documentation

* [PACKAGING.md](../../extension/PACKAGING.md) for packaging conventions
* [Scripts README](../README.md) for overall script organization

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
