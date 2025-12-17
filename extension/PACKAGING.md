# Extension Packaging Guide

This folder contains the VS Code extension configuration for HVE Learning Platform.

## Structure

```plaintext
extension/
├── .github/              # Temporarily copied during packaging (removed after)
├── package.json          # Extension manifest with VS Code configuration
├── .vscodeignore         # Controls what gets packaged into the .vsix
├── README.md             # Extension marketplace description
├── LICENSE               # Copy of root LICENSE
└── PACKAGING.md          # This file
```

## Prerequisites

Install the VS Code Extension Manager CLI:

```bash
npm install -g @vscode/vsce
```

## Packaging the Extension

### Using the Automated Script (Recommended)

From the repository root:

```bash
# Package with auto-incremented version
npm run extension:package

# Or use PowerShell directly
pwsh ./scripts/extension/Package-Extension.ps1

# Preview changes without packaging (dry-run)
npm run extension:package:dry-run

# Package with specific version
pwsh ./scripts/extension/Package-Extension.ps1 -Version "1.0.7"

# Package with changelog
pwsh ./scripts/extension/Package-Extension.ps1 -Version "1.0.7" -ChangelogPath "./CHANGELOG.md"
```

The script automatically:
- Auto-increments the patch version (or uses specified version)
- Discovers and registers all chat agents from `.github/agents/`
- Discovers and registers all instruction files from `.github/instructions/`
- Updates `package.json` with discovered components
- Copies required directories (`.github`, `scripts`, `learning`)
- Packages the extension using `vsce`
- Cleans up temporary files

This will create a `.vsix` file in the `extension/` folder.

### Manual Packaging (Legacy)

If you need to package manually:

```bash
cd extension
rm -rf .github scripts learning && cp -r ../.github . && cp -r ../scripts . && cp -r ../learning . && vsce package --no-dependencies && rm -rf .github scripts learning
```

## Publishing the Extension

**Important:** Update version in `extension/package.json` before publishing.

**Setup Personal Access Token (one-time):**

Set your Azure DevOps PAT as an environment variable to avoid entering it each time:

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
# Publish the packaged extension
vsce publish --packagePath "extension/hve-learning-1.0.6.vsix"

# Or use the latest .vsix file
VSIX_FILE=$(ls -t extension/hve-learning-*.vsix | head -1)
vsce publish --packagePath "$VSIX_FILE"
```

## What Gets Included

The `.vscodeignore` file controls what gets packaged. Currently included:

- `.github/agents/**` - All AI learning coach agent definitions
- `.github/instructions/**` - All learning content instruction files
- `learning/**` - Complete learning content including katas and exercises
- `docs/**` - Learning documentation, guides, and methodologies
- `scripts/**` - Learning automation tools and utilities
- `package.json` - Extension manifest
- `README.md` - Extension description
- `LICENSE` - License file

## Testing Locally

Install the packaged extension locally:

```bash
code --install-extension hve-learning-*.vsix
```

## Version Management

### Automatic Version Management

The packaging script handles versioning automatically:

```bash
# Auto-increment patch version (1.0.6 → 1.0.7)
pwsh ./scripts/extension/Package-Extension.ps1

# Specify exact version
pwsh ./scripts/extension/Package-Extension.ps1 -Version "1.1.0"
```

### Manual Version Management

1. Update version in `extension/package.json`
2. Package and test
3. Publish when ready

## Notes

- The `.github/` folder is temporarily copied during packaging (not permanently stored)
- `LICENSE` is a permanent copy from the root directory
- All learning content is included (agents, instructions, katas, docs, scripts)
- The extension provides a complete learning platform in VS Code
- Content follows relative path structure for proper references
