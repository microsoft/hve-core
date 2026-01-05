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
├── scripts/dev-tools/    # Temporarily copied during packaging (removed after)
├── package.json          # Extension manifest with VS Code configuration
├── .vscodeignore         # Controls what gets packaged into the .vsix
├── README.md             # Extension marketplace description
├── LICENSE               # Copy of root LICENSE
├── CHANGELOG.md          # Copy of root CHANGELOG
└── PACKAGING.md          # This file
```

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

| Workflow                                   | Trigger           | Purpose                                     |
|--------------------------------------------|-------------------|---------------------------------------------|
| `.github/workflows/extension-package.yml`  | Reusable workflow | Packages extension with flexible versioning |
| `.github/workflows/extension-publish.yml`  | Release/manual    | Publishes to VS Code Marketplace            |
| `.github/workflows/main.yml`               | Push to main      | Includes extension packaging in CI          |

## Packaging the Extension

### Using the Automated Scripts (Recommended)

#### Step 1: Prepare the Extension

First, update `package.json` with discovered agents, chatmodes, prompts, and instructions:

```bash
# Discover components and update package.json
pwsh ./scripts/extension/Prepare-Extension.ps1

# Or use npm script
npm run extension:prepare
```

The preparation script automatically:

- Discovers and registers all chat agents from `.github/agents/`
- Discovers and registers all chatmodes from `.github/chatmodes/`
- Discovers and registers all prompts from `.github/prompts/`
- Discovers and registers all instruction files from `.github/instructions/`
- Updates `package.json` with discovered components
- Uses existing version from `package.json` (does not modify it)

#### Step 2: Package the Extension

Then package the extension:

```bash
# Package using version from package.json
pwsh ./scripts/extension/Package-Extension.ps1

# Or use npm script
npm run extension:package

# Package with specific version
pwsh ./scripts/extension/Package-Extension.ps1 -Version "1.0.3"

# Package with dev patch number (e.g., 1.0.2-dev.123)
pwsh ./scripts/extension/Package-Extension.ps1 -DevPatchNumber "123"

# Package with version and dev patch number
pwsh ./scripts/extension/Package-Extension.ps1 -Version "1.1.0" -DevPatchNumber "456"
```

The packaging script automatically:

- Uses version from `package.json` (or specified version)
- Optionally appends dev patch number for pre-release builds
- Copies required `.github` directory
- Copies `scripts/dev-tools` directory (developer utilities)
- Packages the extension using `vsce`
- Cleans up temporary files
- Restores original `package.json` version if temporarily modified

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

- `.github/agents/**` - All chat agent definitions
- `.github/chatmodes/**` - All chatmode definitions
- `.github/prompts/**` - All prompt templates
- `.github/instructions/**` - All instruction files
- `package.json` - Extension manifest
- `README.md` - Extension description
- `LICENSE` - License file
- `CHANGELOG.md` - Version history

## Testing Locally

Install the packaged extension locally:

```bash
code --install-extension hve-core-*.vsix
```

## Version Management

### Update Version in `package.json`

1. Manually update version in `extension/package.json`
2. Run `scripts/extension/Prepare-Extension.ps1` to update agents/chatmodes/prompts/instructions
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

## Notes

- The `.github` and `scripts/dev-tools` folders are temporarily copied during packaging (not permanently stored)
- `LICENSE` and `CHANGELOG.md` are copied from root during packaging and excluded from git
- Only essential extension files are included (chatmodes, prompts, instructions, dev-tools)
- Non-essential files are excluded (workflows, issue templates, agent installer, etc.)
- The root `package.json` contains development scripts for the repository
