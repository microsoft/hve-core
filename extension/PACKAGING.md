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

From the hve-learning directory:

```bash
cd extension
rm -rf .github scripts learning && cp -r ../.github . && cp -r ../scripts/learning . && cp -r ../learning . && vsce package && rm -rf .github scripts learning
```

This will create a `.vsix` file in the `extension/` folder.

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
cd extension
rm -rf .github scripts learning && cp -r ../.github . && cp -r ../scripts/learning . && cp -r ../learning . && vsce publish && rm -rf .github scripts learning
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

1. Update version in `extension/package.json`
2. Package and test
3. Publish when ready

## Notes

- The `.github/` folder is temporarily copied during packaging (not permanently stored)
- `LICENSE` is a permanent copy from the root directory
- All learning content is included (agents, instructions, katas, docs, scripts)
- The extension provides a complete learning platform in VS Code
- Content follows relative path structure for proper references
