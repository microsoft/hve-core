---
title: Troubleshooting
description: Solutions for common HVE Core extension, plugin, and selective clone installation problems
sidebar_position: 8
author: Microsoft
ms.date: 2026-08-02
ms.topic: troubleshooting
keywords: [troubleshooting, FAQ, installation, hve-core, selective clone, registry, proxy]
estimated_reading_time: 6
---

This page covers common installation problems and answers frequently asked questions about the HVE Core extension, Copilot plugin, and selective clone adoption.

## Common Installation Problems

### Extension Not Loading After Install

The extension appears in the Extensions sidebar but HVE Core agents and prompts are not available in Copilot Chat.

#### Solutions

1. Run the `Developer: Reload Window` command from the Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`).
2. Verify that GitHub Copilot Chat is installed and active in the Extensions sidebar. HVE Core requires it.
3. Open the Output panel (`Ctrl+Shift+U`) and select the HVE Core channel. Look for error messages during extension activation.
4. Confirm your VS Code version is 1.99 or later under Help > About.

### Agent or Prompt Not Appearing in Copilot

Some agents or prompts are missing from the `@` mention list or `/` command list in Copilot Chat.

#### Solutions

1. Agents and prompts load from `.github/` directories in the open workspace. Verify that `.github/agents/` and `.github/prompts/` folders exist and contain `.agent.md` or `.prompt.md` files.
2. Copilot Chat loads workspace-scoped agents only when a folder or workspace is open. Opening a single file does not activate workspace agents.
3. If you used selective clone adoption, inspect `.hve-tracking.json` schema version 2 and confirm that the selected agents, prompts, instructions, and complete skills were copied.
4. Ensure your `.gitignore` does not exclude `.github/agents/` or `.github/prompts/` directories.

### Duplicate Components from Managed and Copied Installations

Duplicate agents appear in Copilot Chat, or agents behave unexpectedly after installing both extensions.

#### Solutions

1. The HVE Core extension contributes the complete managed component set. Selective clone adoption copies chosen components into your repository. Using both can expose duplicate agents, prompts, or instructions.
2. Keep the extension when you want managed complete content. Keep the copied selection when you want repository-owned files and version control.
3. Before deleting copied `.github/` files, compare them with `.hve-tracking.json` and preserve local modifications. Uninstalling the extension does not remove repository files.

### Version Compatibility Issues

Errors appear after updating VS Code or one of the HVE extensions, or agents reference features that do not exist.

#### Solutions

1. When updating VS Code, also update GitHub Copilot, GitHub Copilot Chat, and the HVE extension to their latest versions.
2. Review the [CHANGELOG](https://github.com/microsoft/hve-core/blob/main/CHANGELOG.md) for breaking changes between versions.
3. If artifacts are out of sync, remove the existing `.github/` HVE Core artifacts and reinstall using your preferred method.

### npm ci Cannot Reach the Package Registry

`npm ci` fails with `ENOTCONN`, a connection timeout, or a request error against `registry.npmjs.org`. This affects clone-based contributor setups only, not the marketplace extensions.

#### Solutions

1. Some networks block public package registries and require installs to route through an approved feed proxy. Set the registry override in your environment, then rerun `npm ci`.
2. A user-level `~/.npmrc` has no effect here. This repository commits a project-level `.npmrc`, and npm resolves configuration in the order `cli > env > project .npmrc > user .npmrc > global`, so only an environment variable or a CLI flag takes precedence.
3. Keep the proxy address out of every tracked file, and use restore commands only. Commands that resolve dependencies write the proxy's own URLs into the lockfile.

See [Install behind a restricted network](../contributing/validation#install-behind-a-restricted-network) for per-platform setup and the rules for adding a dependency.

## Installation FAQ

### Which Extension Should I Install?

| Scenario                                 | Recommended Installation                                                                    |
|------------------------------------------|---------------------------------------------------------------------------------------------|
| You want everything HVE Core offers      | [HVE Core](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) |
| You want selected repository-owned files | Clone or pin HVE Core, then use `hve-core-installer`                                        |
| You plan to contribute to HVE Core       | Clone the repository directly, see [Developer Setup](install#developer-setup)               |

### How Do I Migrate from a Retired Identity?

Follow [Migrate to the HVE Core Identity](package-migration). Copilot marketplace registration changes are non-destructive configuration operations. VS Code cannot universally transfer settings or installation state between different extension IDs, so install and verify `ise-hve-essentials.hve-core` before uninstalling a retired identity.

### Can I Use Both Extensions Simultaneously?

Using the managed extension and copied HVE Core components in the same workspace can result in duplicate agents and prompts. Choose one source of components for each workspace. See [Duplicate Components](#duplicate-components-from-managed-and-copied-installations) above.

### How Do I Update to the Latest Version?

Marketplace extensions update automatically. When a new version is published, VS Code downloads and installs it. You can also manually check for updates in the Extensions sidebar.

For clone-based setups, pull the latest changes from the upstream repository:

```bash
git pull upstream main
```

Then reinstall dependencies with `npm ci` if `package.json` changed.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
