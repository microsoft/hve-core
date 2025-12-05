# Extension Packaging Guide

This folder contains the VS Code extension configuration for HVE Core.

## Structure

```plaintext
extension/
├── .github/              # Temporarily copied during packaging (removed after)
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

## Packaging the Extension

From the repository root:

```bash
npm run package:extension
```

This will create a `.vsix` file in the `extension/` folder.

Alternatively, package manually (requires manual setup):

```bash
cd extension
rm -rf .github && cp -r ../.github . && vsce package && rm -rf .github
```

## Publishing the Extension

**Important:** Update version in `extension/package.json` before publishing.

```bash
npm run publish:extension
```

Or manually (requires manual setup):

```bash
cd extension
rm -rf .github && cp -r ../.github . && vsce publish && rm -rf .github
```

## What Gets Included

The `.vscodeignore` file controls what gets packaged. Currently included:

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

1. Update version in `extension/package.json`
2. Update `CHANGELOG.md` in the root (it will be copied)
3. Package and test
4. Publish when ready

## Notes

- The `.github/` folder is temporarily copied during packaging (not permanently stored)
- `LICENSE` and `CHANGELOG.md` are permanent copies from the root directory
- Only essential extension files are included (agents, chatmodes, prompts, instructions)
- Non-essential `.github` files are excluded (workflows, issue templates, etc.)
- The root `package.json` contains development scripts for the repository
