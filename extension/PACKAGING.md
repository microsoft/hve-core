# Extension Packaging Guide

This folder contains the VS Code extension configuration for HVE Core.

## Structure

```plaintext
extension/
├── .github/              # Symlink to ../.github (contains all agents, chatmodes, prompts, instructions)
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

Alternatively, package manually:

```bash
cd extension
vsce package
```

## Publishing the Extension

**Important:** Update version in `extension/package.json` before publishing.

```bash
npm run publish:extension
```

Or manually:

```bash
cd extension
vsce publish
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

- The `.github/` folder is symlinked to avoid duplication
- `LICENSE` and `CHANGELOG.md` are copied from root during builds
- The extension package only includes necessary files for the VS Code extension
- The root `package.json` contains development scripts for the repository
