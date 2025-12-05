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
rm -rf .github && cp -r ../.github . && vsce package && rm -rf .github
```

This will create a `.vsix` file in the `extension/` folder.

## Publishing the Extension

**Important:** Update version in `extension/package.json` before publishing.

```bash
cd extension
rm -rf .github && cp -r ../.github . && vsce publish && rm -rf .github
```

## What Gets Included

The `.vscodeignore` file controls what gets packaged. Currently included:

- `.github/agents/**` - All AI learning coach agent definitions
- `.github/instructions/**` - All learning content instruction files
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
- Only essential extension files are included (agents, instructions)
- The extension focuses on AI learning coaches and content creation guidelines