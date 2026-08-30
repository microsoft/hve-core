---
title: Extension Scripts
description: PowerShell scripts for manifest-driven VS Code extension preparation and packaging
author: HVE Core Team
ms.date: 2026-08-19
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

The extension packaging pipeline follows the one plugin manifest:

1. `Prepare-Extension.ps1` maps root `plugin.json` to one extension manifest and README
2. `Package-Extension.ps1` stages tracked contribution files and creates one `.vsix`
3. `Resolve-VsixFile.ps1` requires exactly one VSIX for provenance workflows
4. `Export-AttestationBundle.ps1` writes Sigstore and in-toto sidecars

Membership comes from root `plugin.json`. Stable and PreRelease preparation use the same component set. Repository-relative `.github/...` declarations become extension contribution paths without adding plugin-root README or license files.

## Scripts

### `Prepare-Extension.ps1`

Prepares extension contents from root `plugin.json`.

Purpose: Gather and filter artifacts for inclusion in the extension package.

#### Features

* Maps agents, prompts, instructions, and skills from plugin manifest membership
* Writes the single `extension/package.json` and `extension/README.md`
* Produces channel-neutral component membership before packaging
* Dry-run mode for previewing changes

#### Parameters

* `-DryRun` (switch) - Preview changes without modifying files

#### Usage

```powershell
# Prepare channel-neutral extension resources
./scripts/extension/Prepare-Extension.ps1

# Dry run to preview
./scripts/extension/Prepare-Extension.ps1 -DryRun
```

### `Package-Extension.ps1`

Packages the VS Code extension into a `.vsix` file using `vsce`.

Purpose: Produce a distributable extension package from prepared contents.

#### Features

* Sets version from parameters or changelog
* Supports pre-release and dev patch builds
* One-identity extension packaging
* Git-tracked path staging with explicit shared resources
* Repository-pinned `vsce` only, with no installer fallback
* Dry-run mode for validation

#### Parameters

* `-Version` - Explicit version string
* `-DevPatchNumber` - Development patch number for dev builds
* `-ChangelogPath` - Path to the changelog file
* `-PreRelease` (switch) - Mark as pre-release build
* `-DryRun` (switch) - Preview changes without producing a package

#### Usage

```powershell
# Package the extension
./scripts/extension/Package-Extension.ps1

# Package a pre-release build
./scripts/extension/Package-Extension.ps1 -PreRelease
```

### `Resolve-VsixFile.ps1`

Resolves the single `.vsix` file within a directory.

Purpose: Return the one VSIX path in a directory, failing when zero or multiple
`.vsix` files are present. Used by the `extension-provenance.yml` reusable
workflow to locate the downloaded VSIX before signing and attestation.

#### Parameters

* `-DirectoryPath` - Directory to search for a `.vsix` file (defaults to `$env:VSIX_DIRECTORY`)

#### Usage

```powershell
# Resolve the VSIX in a directory
./scripts/extension/Resolve-VsixFile.ps1 -DirectoryPath ./extension
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

| npm Script                     | Description                                               |
|--------------------------------|-----------------------------------------------------------|
| `extension:prepare`            | Prepare channel-neutral resources                         |
| `extension:prepare:prerelease` | Prepare the same resources for the PreRelease entry point |
| `extension:package`            | Package extension                                         |
| `extension:package:prerelease` | Package pre-release extension                             |

## GitHub Actions Integration

The `extension-package.yml` reusable workflow has one `package` job. It checks
out the requested source, prepares the complete HVE Core contributions, and
packages one `.vsix` file.

It runs under `contents: read` only. The separate `extension-provenance.yml`
workflow holds the signing scopes, downloads the built VSIX, and never installs
dependencies.

See [Build Workflows](../../docs/architecture/workflows.md) for pipeline
details.

## Related Documentation

* [PACKAGING.md](../../extension/PACKAGING.md) for packaging conventions
* [Scripts README](../README.md) for overall script organization

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
