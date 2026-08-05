---
title: Extension Scripts
description: PowerShell scripts for marketplace-driven VS Code extension preparation and packaging
author: HVE Core Team
ms.date: 2026-08-02
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

The extension packaging pipeline follows one marketplace projection:

1. `Get-MarketplacePackageMatrix.ps1` emits the one `hve-core` package ID
2. `Modules/ExtensionIdentity.psm1` maps it to the HVE Core extension identity
3. `Prepare-Extension.ps1` resolves the complete recipe through shared handoff closure
4. `Package-Extension.ps1` stages tracked projection files and creates a `.vsix`

Marketplace metadata, membership, maturity, and display names come from
`.github/plugin/marketplace.json`. No extension script reads a secondary package
definition.

## Scripts

### `Prepare-Extension.ps1`

Prepares extension contents from one resolved marketplace package recipe.

Purpose: Gather and filter artifacts for inclusion in the extension package.

#### Features

* Resolves agents, prompts, instructions, and skills from marketplace membership
* Applies shared lifecycle policy and transitive agent handoff closure
* Supports explicit `hve-core` package-ID preparation
* Dry-run mode for previewing changes

#### Parameters

* `-ChangelogPath` - Path to the changelog file
* `-Channel` - Release channel: `Stable` or `PreRelease`
* `-DryRun` (switch) - Preview changes without modifying files
* `-PackageId` - Marketplace package ID for scoped preparation

#### Usage

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

Purpose: Produce a distributable extension package from prepared contents.

#### Features

* Sets version from parameters or changelog
* Supports pre-release and dev patch builds
* One-identity marketplace packaging
* Git-tracked path staging with explicit shared resources
* Repository-pinned `vsce` only, with no installer fallback
* Dry-run mode for validation

#### Parameters

* `-Version` - Explicit version string
* `-DevPatchNumber` - Development patch number for dev builds
* `-ChangelogPath` - Path to the changelog file
* `-PreRelease` (switch) - Mark as pre-release build
* `-PackageId` - Marketplace package ID for scoped packaging
* `-DryRun` (switch) - Preview changes without producing a package

#### Usage

```powershell
# Package the extension
./scripts/extension/Package-Extension.ps1

# Package a pre-release build
./scripts/extension/Package-Extension.ps1 -PreRelease

# Package a specific marketplace package
./scripts/extension/Package-Extension.ps1 -PackageId hve-core
```

### `Get-MarketplacePackageMatrix.ps1`

Builds a package matrix and package-name output from the marketplace catalog.

Purpose: Emit the one HVE Core package for either release channel.

#### Features

* Reads `.github/plugin/marketplace.json`
* Verifies the `hve-core` entry is eligible for the selected channel
* Outputs sorted matrix rows containing only `id`
* Outputs a sorted JSON `names` array for packaging workflows

### `Modules/ExtensionIdentity.psm1`

Maps marketplace package IDs to VS Code extension identities and exact VSIX
asset patterns.

Purpose: Keep package matrix, release download, and VSIX selection behavior on
one `hve-core` identity contract.

#### Parameters

* `-Channel` - Release channel filter: `Stable` or `PreRelease`
* `-CatalogPath` - Path to the marketplace catalog

#### Usage

```powershell
# Discover stable packages
./scripts/extension/Get-MarketplacePackageMatrix.ps1 -Channel Stable

# Discover pre-release packages
./scripts/extension/Get-MarketplacePackageMatrix.ps1 -Channel PreRelease
```

### `Resolve-VsixFile.ps1`

Resolves the single `.vsix` file within a directory.

Purpose: Return the one VSIX path in a directory, failing when zero or multiple
`.vsix` files are present. Used by the `extension-provenance.yml` reusable
workflow to locate the built VSIX before signing and attestation.

#### Parameters

* `-DirectoryPath` - Directory to search for a `.vsix` file (defaults to `$env:VSIX_DIRECTORY`)

#### Usage

```powershell
# Resolve the VSIX in a directory
./scripts/extension/Resolve-VsixFile.ps1 -DirectoryPath ./extension
```

### `Select-PackageVsix.ps1`

Selects the package-specific VSIX from a set of candidate assets.

Purpose: Pick the `.vsix` matching a package ID from a directory of release
assets. Used by the `extension-marketplace-publish.yml` reusable workflow to
choose the correct package artifact before publishing.

#### Parameters

* `-AssetDirectory` - Directory containing candidate assets (defaults to `$env:ASSET_DIRECTORY`)
* `-PackageId` - Package ID to match (defaults to `$env:PACKAGE_ID`)

#### Usage

```powershell
# Select the VSIX for a package
./scripts/extension/Select-PackageVsix.ps1 -AssetDirectory ./dist -PackageId hve-core
```

### `Export-AttestationBundle.ps1`

Exports attestation files from an attestation bundle.

Purpose: Extract the Sigstore and in-toto attestation files from a bundle to
local paths. Used in the provenance flow to materialize attestation artifacts
for verification and release upload.

#### Parameters

* `-BundlePath` - Path to the attestation bundle (defaults to `$env:BUNDLE_PATH`)
* `-SigstorePath` - Output path for the Sigstore attestation (defaults to `$env:SIGSTORE_PATH`)
* `-IntotoPath` - Output path for the in-toto attestation (defaults to `$env:INTOTO_PATH`)

#### Usage

```powershell
# Export attestation files from a bundle
./scripts/extension/Export-AttestationBundle.ps1 -BundlePath ./bundle.json -SigstorePath ./out.sigstore.json -IntotoPath ./out.intoto.jsonl
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

1. `Get-MarketplacePackageMatrix.ps1` produces a one-row package-ID matrix
2. `Prepare-Extension.ps1` projects the complete HVE Core contributions
3. `Package-Extension.ps1` produces the one `.vsix` file

See [Build Workflows](../../docs/architecture/workflows.md) for pipeline
details.

## Related Documentation

* [PACKAGING.md](../../extension/PACKAGING.md) for packaging conventions
* [Scripts README](../README.md) for overall script organization

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
