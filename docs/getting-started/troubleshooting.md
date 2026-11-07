---
title: Troubleshooting
description: Solutions for common HVE Core plugin, extension, and repository copy installation problems
sidebar_position: 8
author: Microsoft
ms.date: 2026-11-06
ms.topic: troubleshooting
keywords: [troubleshooting, FAQ, installation, hve-core, copilot plugin, repository copy, registry, proxy]
estimated_reading_time: 7
---

This page covers common installation problems and answers frequently asked questions about the HVE Core plugin, the VS Code extension, and repository adoption.

## Common Installation Problems

### Changes Don't Show Up in Chat

You installed, updated, or edited HVE Core files, but new chat sessions still behave the old way. An instruction file you added, changed, or deleted is not reflected.

#### Solutions

1. Run the `Developer: Reload Window` command from the Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`). VS Code keeps its list of path-specific instructions for the life of the window, so new chat sessions see instruction changes only after a reload.
2. Start a new chat session after the reload, and check that Copilot appears at the start of its title. HVE Core supports only the Copilot harness.

### Plugin Not Loading After Install

The `hve-core` plugin is installed, but its agents and skills are missing from Copilot Chat.

#### Solutions

1. Run **Chat: Open Customizations** to open the Agent Customizations editor, select **Plugins**, and confirm `hve-core` is listed and turned on.
2. Confirm that agent plugins are enabled: the `chat.plugins.enabled` setting must be `true`.
3. Reload the window and start a new chat session.
4. Look for the plugin prefix. VS Code lists plugin skills with the plugin name in front, such as `/hve-core:rpi-research`.

### Extension Not Loading After Install

The extension appears in the Extensions sidebar but HVE Core agents and skills are not available in Copilot Chat.

#### Solutions

1. Run the `Developer: Reload Window` command from the Command Palette.
2. Verify that GitHub Copilot Chat is installed and active in the Extensions sidebar. HVE Core requires it.
3. Confirm your VS Code version is 1.106.1 or later under Help > About. That is the minimum the extension declares, not a guarantee that every newer Copilot feature HVE Core uses is available, so keep VS Code current.
4. The extension only declares agents, skills, and instructions. It runs no code and has no output channel of its own. If it is enabled and components are still missing, work through [Agent or Skill Not Appearing in Copilot](#agent-or-skill-not-appearing-in-copilot).

### Agent or Skill Not Appearing in Copilot

Some agents or skills are missing from the agent picker or `/` command list in Copilot Chat.

#### Solutions

1. Check the harness. VS Code shows it at the start of the chat title. HVE Core supports only Copilot, and a Local session doesn't show the agents in package folders. If the title shows Local, start a new chat and select **Copilot** in the **Session Target** control. [Use the Copilot Harness](install#use-the-copilot-harness) explains why.
2. Check the route you used. Plugin components appear on the **Plugins** page of the Agent Customizations editor. Components copied into your repository load from its `.github/agents`, `.github/skills`, and `.github/instructions` folders, at any depth.
3. Copilot Chat loads workspace-scoped agents only when a folder or workspace is open. Opening a single file does not activate workspace agents.
4. For a clone listed in `.github/copilot/settings.json`, check that each path is a literal folder inside the checkout and that the workspace folder is trusted. Copilot rejects absolute paths, `~`, environment variables, globs, and paths that leave the checkout.
5. If you copied HVE Core into your repository, inspect `.hve-tracking.json` schema version 2 and confirm that the recorded agents, instructions, and complete skills were copied.
6. Ensure your `.gitignore` does not exclude `.github/agents/` or `.github/skills/` directories.
7. Agents cannot start skills that set `disable-model-invocation: true`, such as `git-commit`. Type the skill's slash command instead.

### Instructions Not Applied

HVE Core agents and skills work, but guidelines from HVE Core instructions don't seem to apply.

#### Solutions

1. Reload the window, as described in [Changes Don't Show Up in Chat](#changes-dont-show-up-in-chat).
2. Copilot gives each session a table of path-specific instructions and their `applyTo` patterns, and the agent reads a matching instruction when it works on a matching file. Check that the file you are working on matches the instruction's `applyTo` pattern.
3. The VS Code extension's instructions may not reach Copilot sessions. Use the plugin when you rely on them.
4. For a clone listed in `.github/copilot/settings.json`, Copilot inlines instructions that have no `applyTo`. Whether it loads path-specific instructions from those folders is not confirmed, so use the plugin when you need them.

### Duplicate Agents from More Than One Install Route

Agents appear more than once in the agent picker or subagent list, or behave unexpectedly after you install HVE Core a second way.

#### Solutions

1. Copilot does not remove copies that arrive by different routes. The plugin, the extension, copied components, a clone listed in `.github/copilot/settings.json`, and `chat.*Locations` settings that point at an HVE Core copy each add their own.
2. Keep one route. Uninstall the plugin or extension you no longer want, remove HVE Core entries from `.github/copilot/settings.json`, and delete `chat.*Locations` entries that point at HVE Core.
3. Before deleting copied `.github/` files, compare them with `.hve-tracking.json` and preserve local modifications. Uninstalling the plugin or extension does not remove repository files.

### Version Compatibility Issues

Errors appear after updating VS Code or HVE Core, or agents reference features that do not exist.

#### Solutions

1. When you update VS Code, also update GitHub Copilot Chat and HVE Core. Update the plugin with **Check for and Apply Updates** on the **Plugins** page, or the extension from the Extensions view.
2. Review the [CHANGELOG](https://github.com/microsoft/hve-core/blob/main/CHANGELOG.md) for breaking changes between versions.
3. If artifacts are out of sync, remove the existing `.github/` HVE Core artifacts and reinstall using your preferred method.

### npm ci Cannot Reach the Package Registry

`npm ci` fails with `ENOTCONN`, a connection timeout, or a request error against `registry.npmjs.org`. This affects clone-based contributor setups only, not the plugin or the Marketplace extension.

#### Solutions

1. Some networks block public package registries and require installs to route through an approved feed proxy. Set the registry override in your environment, then rerun `npm ci`.
2. A user-level `~/.npmrc` has no effect here. This repository commits a project-level `.npmrc`, and npm resolves configuration in the order `cli > env > project .npmrc > user .npmrc > global`, so only an environment variable or a CLI flag takes precedence.
3. Keep the proxy address out of every tracked file, and use restore commands only. Commands that resolve dependencies write the proxy's own URLs into the lockfile.

See [Install behind a restricted network](../contributing/validation#install-behind-a-restricted-network) for per-platform setup and the rules for adding a dependency.

### RPI Workflow Canvas Not Available

The RPI Agent never opens the RPI Workflow canvas, or the canvas does not appear in your host's canvas list.

#### Solutions

1. Install the `hve-core` plugin. The VS Code extension does not carry canvases, and VS Code picks up a plugin that the Copilot CLI installed. See [Copilot Plugin](methods/cli-plugins).
2. In VS Code, turn on `chat.canvases.enabled`, start a new local session with the Copilot harness, and send a message before you open the canvas menus.
3. In the Copilot CLI, turn on experimental features with `--experimental` or `/experimental on`.
4. For problems inside the canvas, such as a Not connected page, see [Troubleshooting](../rpi/rpi-workflow-canvas#troubleshooting) in the canvas guide.

## Installation FAQ

### Which Install Route Should I Use?

| Scenario                                                | Recommended Installation                                                                                  |
|---------------------------------------------------------|-----------------------------------------------------------------------------------------------------------|
| You want everything HVE Core offers                     | The [`hve-core` plugin](methods/cli-plugins)                                                              |
| Everyone who opens a repository should get HVE Core     | [Plugin defaults](install#offer-the-plugin-to-your-team) in `.github/copilot/settings.json`               |
| You manage editor tools through the VS Code Marketplace | The [HVE Core extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) |
| You want selected repository-owned files                | Clone or pin HVE Core, then use `hve-core-installer`                                                      |
| You plan to contribute to HVE Core                      | Clone the repository directly, see [Developer Setup](install#developer-setup)                             |

### How Do I Migrate from a Retired Identity?

Follow [Migrate to the HVE Core Identity](package-migration). Copilot marketplace registration changes are non-destructive configuration operations. VS Code cannot universally transfer settings or installation state between different extension IDs, so install and verify `ise-hve-essentials.hve-core` before uninstalling a retired identity.

### Can I Use More Than One Install Route?

Installing HVE Core more than one way in the same workspace lists agents, instructions, and skills more than once. Choose one route for each workspace. See [Duplicate Agents from More Than One Install Route](#duplicate-agents-from-more-than-one-install-route) above.

### How Do I Update to the Latest Version?

* Plugin: follow [Update the Plugin](install#update-the-plugin). The plugin follows `main`.
* Extension: VS Code updates Marketplace extensions automatically. You can also check for updates in the Extensions sidebar.
* Clone: pull the latest changes with `git pull upstream main`, then rerun `npm ci` if `package.json` changed.

After any update, reload the window so new chat sessions pick up the change.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
