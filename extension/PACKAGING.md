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

## Automated CI/CD Workflows

The repository includes GitHub Actions workflows for automated packaging and publishing:

### CI Packaging (Automatic on Every Push)

The `.github/workflows/ci.yml` workflow automatically:

- Runs on every push to any branch
- Packages the extension with a dev version (e.g., `1.0.7-dev.123` where `123` is the workflow run number)
- Makes the `.vsix` file available as a workflow run artifact
- Allows testing pre-release versions before publishing

To download a dev build:

1. Go to the Actions tab in GitHub
2. Select a workflow run
3. Download the `extension-vsix` artifact

### Release Publishing (Automatic on GitHub Release)

The `.github/workflows/extension-publish.yml` workflow automatically:

- Triggers when a GitHub release is published
- Packages the extension using the release version (e.g., `v1.0.7`)
- Publishes directly to the VS Code Marketplace
- Uses Azure OIDC authentication for secure publishing

**Developer Responsibility:** Keep `extension/package.json` updated by running the Prepare-Extension script whenever agents or instructions are added or removed. This ensures the extension manifest reflects the current set of AI coaches and content guidelines.

## Packaging the Extension

### Using the Automated Scripts (Recommended)

#### Step 1: Prepare the Extension

First, update `package.json` with discovered agents and instructions:

```bash
# Discover agents/instructions and update package.json
pwsh ./scripts/extension/Prepare-Extension.ps1
```

The preparation script automatically:

- Discovers and registers all chat agents from `.github/agents/`
- Discovers and registers all instruction files from `.github/instructions/`
- Updates `package.json` with discovered components
- Uses existing version from `package.json` (does not modify it)

#### Step 2: Package the Extension

Then package the extension:

```bash
# Package using version from package.json
pwsh ./scripts/extension/Package-Extension.ps1

# Package with specific version
pwsh ./scripts/extension/Package-Extension.ps1 -Version "1.0.7"

# Package with dev patch number (e.g., 1.0.7-dev.123)
pwsh ./scripts/extension/Package-Extension.ps1 -DevPatchNumber "123"

# Package with version and dev patch number
pwsh ./scripts/extension/Package-Extension.ps1 -Version "1.1.0" -DevPatchNumber "456"
```

The packaging script automatically:

- Uses version from `package.json` (or specified version)
- Optionally appends dev patch number for pre-release builds
- Copies required directories (`.github`, `scripts`, `learning`)
- Packages the extension using `vsce`
- Cleans up temporary files
- Restores original `package.json` version if temporarily modified

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
# Publish the packaged extension (replace X.Y.Z with actual version)
vsce publish --packagePath "extension/hve-learning-X.Y.Z.vsix"

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

### Update Version in package.json

1. Manually update version in `extension/package.json`
2. Run Prepare-Extension.ps1 to update agents/instructions
3. Run Package-Extension.ps1 to create the `.vsix` file

### Development Builds

For pre-release or CI builds, use the dev patch number:

```bash
# Creates version like 1.0.7-dev.123
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

- The `.github/` folder is temporarily copied during packaging (not permanently stored)
- `LICENSE` is a permanent copy from the root directory
- All learning content is included (agents, instructions, katas, docs, scripts)
- The extension provides a complete learning platform in VS Code
- Content follows relative path structure for proper references
