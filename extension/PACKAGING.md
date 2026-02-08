---
title: Extension Packaging Guide
description: Developer guide for packaging and publishing the HVE Core VS Code extension
author: Microsoft
ms.date: 2025-12-19
ms.topic: reference
---

This folder contains the VS Code extension configuration for HVE Core.

## Structure

```plaintext
extension/
├── .github/              # Temporarily copied during packaging (removed after)
├── docs/templates/       # Temporarily copied during packaging (removed after)
├── scripts/dev-tools/    # Temporarily copied during packaging (removed after)
├── package.json          # Extension manifest with VS Code configuration
├── .vscodeignore         # Controls what gets packaged into the .vsix
├── README.md             # Extension marketplace description
├── LICENSE               # Copy of root LICENSE
├── CHANGELOG.md          # Copy of root CHANGELOG
└── PACKAGING.md          # This file
```

## Extension Configuration

### Extension Kind

The extension is configured with `"extensionKind": ["workspace", "ui"]` in `package.json` to support multiple execution contexts:

* **Workspace mode**: Extension runs in the workspace (remote) extension host. In this mode, the extension accesses its bundled files from the extension installation directory in the remote/workspace context (for example, the packaged `.github/` and `scripts/dev-tools/` folders).
* **UI mode**: Extension runs in the UI extension host on the user's local machine and accesses the same bundled extension files from the local installation directory.

Access to files in the user's project workspace always uses the standard VS Code workspace APIs and is independent of the extension kind. Both modes use the same packaged extension assets and differ only in execution context (local UI versus remote/workspace). This bundling approach ensures GitHub Copilot can reliably access instruction files and scripts regardless of cross-platform path resolution issues (for example, Windows/WSL environments).

This is a declarative extension: it contributes configuration and file paths, and VS Code (together with the GitHub Copilot extension) resolves those paths based on the selected extension host and the extension installation location; it does not implement any custom runtime fallback mechanism between workspace and bundled files.

## Prerequisites

Install the VS Code Extension Manager CLI:

```bash
npm install -g @vscode/vsce
```

Install the PowerShell-Yaml module (required for Prepare-Extension.ps1):

```powershell
Install-Module -Name PowerShell-Yaml -Scope CurrentUser
```

## Automated CI/CD Workflows

The extension is automatically packaged and published through GitHub Actions:

| Workflow                                  | Trigger           | Purpose                                     |
|-------------------------------------------|-------------------|---------------------------------------------|
| `.github/workflows/extension-package.yml` | Reusable workflow | Packages extension with flexible versioning |
| `.github/workflows/extension-publish.yml` | Release/manual    | Publishes to VS Code Marketplace            |
| `.github/workflows/main.yml`              | Push to main      | Includes extension packaging in CI          |

## Packaging the Extension

### Using the Automated Scripts (Recommended)

#### Step 1: Prepare the Extension

First, update `package.json` with discovered agents, prompts, and instructions:

```bash
# Discover components and update package.json (Stable channel)
pwsh ./scripts/extension/Prepare-Extension.ps1

# Or use npm script
npm run extension:prepare

# For PreRelease channel (includes preview and experimental artifacts)
pwsh ./scripts/extension/Prepare-Extension.ps1 -Channel PreRelease

# Or use npm script
npm run extension:prepare:prerelease
```

The preparation script automatically:

* Discovers and registers all chat agents from `.github/agents/`
* Discovers and registers all prompts from `.github/prompts/`
* Discovers and registers all instruction files from `.github/instructions/`
* Updates `package.json` with discovered components
* Uses existing version from `package.json` (does not modify it)

#### Step 2: Package the Extension

Then package the extension:

```bash
# Package using version from package.json (Stable channel)
pwsh ./scripts/extension/Package-Extension.ps1

# Or use npm script
npm run extension:package

# Package for PreRelease channel
pwsh ./scripts/extension/Package-Extension.ps1 -PreRelease

# Or use npm script
npm run extension:package:prerelease

# Package with specific version
pwsh ./scripts/extension/Package-Extension.ps1 -Version "1.0.3"

# Package with dev patch number (e.g., 1.0.2-dev.123)
pwsh ./scripts/extension/Package-Extension.ps1 -DevPatchNumber "123"

# Package with version and dev patch number
pwsh ./scripts/extension/Package-Extension.ps1 -Version "1.1.0" -DevPatchNumber "456"
```

The packaging script automatically:

* Uses version from `package.json` (or specified version)
* Optionally appends dev patch number for pre-release builds
* Copies required `.github` directory
* Copies `scripts/dev-tools` directory (developer utilities)
* Packages the extension using `vsce`
* Cleans up temporary files
* Restores original `package.json` version if temporarily modified

### Manual Packaging (Legacy)

If you need to package manually:

```bash
cd extension
rm -rf .github scripts && cp -r ../.github . && mkdir -p scripts && cp -r ../scripts/dev-tools scripts/ && vsce package && rm -rf .github scripts
```

## Publishing the Extension

**Important:** Update version in `extension/package.json` before publishing.

**Setup Personal Access Token (one-time):**

Set your Azure DevOps PAT as an environment variable:

```bash
export VSCE_PAT=your-token-here
```

To get a PAT:

1. Go to <https://dev.azure.com>
2. User settings → Personal access tokens → New Token
3. Set scope to **Marketplace (Manage)**
4. Copy the token

**Publish command:**

```bash
# Publish the packaged extension (replace X.Y.Z with actual version)
vsce publish --packagePath "extension/hve-core-X.Y.Z.vsix"

# Or use the latest .vsix file
VSIX_FILE=$(ls -t extension/hve-core-*.vsix | head -1)
vsce publish --packagePath "$VSIX_FILE"
```

## What Gets Included

The `extension/.vscodeignore` file controls what gets packaged. Currently included:

* `.github/agents/**` - All custom agent definitions
* `.github/prompts/**` - All prompt templates
* `.github/instructions/**` - All instruction files
* `docs/templates/**` - Document templates used by agents (ADR, BRD, Security Plan)
* `scripts/dev-tools/**` - Developer utilities (PR reference generation)
* `package.json` - Extension manifest
* `README.md` - Extension description
* `LICENSE` - License file
* `CHANGELOG.md` - Version history

## Testing Locally

Install the packaged extension locally:

```bash
code --install-extension hve-core-*.vsix
```

## Version Management

### Update Version in `package.json`

1. Manually update version in `extension/package.json`
2. Run `scripts/extension/Prepare-Extension.ps1` to update agents/prompts/instructions
3. Run `scripts/extension/Package-Extension.ps1` to create the `.vsix` file

### Development Builds

For pre-release or CI builds, use the dev patch number:

```bash
# Creates version like 1.0.2-dev.123
pwsh ./scripts/extension/Package-Extension.ps1 -DevPatchNumber "123"
```

This temporarily modifies the version during packaging but restores it afterward.

### Override Version at Package Time

You can override the version without modifying `package.json`:

```bash
# Package as 1.1.0 without updating package.json
pwsh ./scripts/extension/Package-Extension.ps1 -Version "1.1.0"
```

## Pre-Release Channel

The extension supports dual-channel publishing to VS Code Marketplace with separate stable and pre-release tracks.

### EVEN/ODD Versioning Strategy

| Minor Version     | Channel     | Example      | Agent Maturity Included             |
|-------------------|-------------|--------------|-------------------------------------|
| EVEN (0, 2, 4...) | Stable      | 1.0.0, 1.2.0 | `stable` only                       |
| ODD (1, 3, 5...)  | Pre-Release | 1.1.0, 1.3.0 | `stable`, `preview`, `experimental` |

Users can switch between channels in VS Code via the "Switch to Pre-Release Version" button on the extension page.

### Pre-Release Packaging

Package for the pre-release channel with the `-PreRelease` switch:

```bash
# Prepare with PreRelease channel filtering
pwsh ./scripts/extension/Prepare-Extension.ps1 -Channel PreRelease
# Or use npm script
npm run extension:prepare:prerelease

# Package for pre-release channel (includes experimental agents)
pwsh ./scripts/extension/Package-Extension.ps1 -Version "1.1.0" -PreRelease
# Or use npm script for default version
npm run extension:package:prerelease
```

The `-PreRelease` switch adds `--pre-release` to the vsce command, marking the package for the Marketplace pre-release track.

### Pre-Release Workflow

Use the manual workflow for publishing pre-releases:

1. Go to **Actions** > **Publish Pre-Release Extension**
2. Enter an ODD minor version (e.g., `1.1.0`, `1.3.0`)
3. Optionally enable dry-run to test packaging without publishing
4. Run the workflow

The workflow validates the version is ODD before proceeding.

### Agent Maturity Filtering

When packaging, agents are filtered by their `maturity` frontmatter field:

| Channel    | Included Maturity Levels            |
|------------|-------------------------------------|
| Stable     | `stable`                            |
| PreRelease | `stable`, `preview`, `experimental` |

See [Agent Maturity Levels](../docs/contributing/ai-artifacts-common.md#maturity-field-requirements) for contributor guidance on setting maturity levels.

## Notes

* The `.github`, `docs/templates`, and `scripts/dev-tools` folders are temporarily copied during packaging (not permanently stored)
* `LICENSE` and `CHANGELOG.md` are copied from root during packaging and excluded from git
* Only essential extension files are included (agents, prompts, instructions, templates, dev-tools)
* Non-essential files are excluded (workflows, issue templates, agent installer, etc.)
* The root `package.json` contains development scripts for the repository

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
