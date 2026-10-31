---
title: hve-core-installer
description: "Decision-driven HVE-Core installer for the Copilot harness: the plugin, a team default in repository settings, selective component copy into the repository, the VS Code extension, and clone-based storage, with environment detection, validation, and MCP setup"
sidebar_position: 1
author: Microsoft
ms.date: 2026-10-31
ms.topic: reference
keywords:
  - skill
  - installer
  - hve-core-installer
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                |
|-------------|--------------------------------------------------------------------------------------|
| Kind        | skill                                                                                |
| Source      | `.github/skills/installer/hve-core-installer`                                        |
| Invocation  | Invoked directly as `/hve-core-installer`, or loaded on demand by referencing agents |
| Interactive | No                                                                                   |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Decision-driven HVE-Core installer for the Copilot harness: the plugin, a team default in repository settings, selective component copy into the repository, the VS Code extension, and clone-based storage, with environment detection, validation, and MCP setup
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill to choose, set up, and check an HVE-Core installation for the
Copilot agent harness. It offers five routes in order: the plugin, a repository
default in `.github/copilot/settings.json`, copying selected components into
the repository, the VS Code extension, and a clone. Clone-based methods suit
customization, shared version control, or controlled updates. Re-running can
validate an existing setup, clean up `chat.*Locations` entries from an earlier
setup, or offer an upgrade rather than assuming a new installation is needed.

Clone-based methods need Git and network access; Bash component scripts also
need `jq`. Detection begins with consent, and changes to
`.github/copilot/settings.json`, `devcontainer.json`, or other settings
require explicit authorization. This is not permission to replace local
customizations.

## Example usage

Ask: `/hve-core-installer Help a team using local VS Code select a clone-based
setup with controlled updates. Explain proposed changes before applying them.`
After initial consent, confirm the shell, environment, and team/update preferences.
The decision matrix should recommend the submodule method for that combination,
offer to declare the submodule's folders in `.github/copilot/settings.json`,
and wait for the selected-method and settings authorizations.

Success is verified artifact directories and configuration for the chosen method,
with actual paths and any reload action reported. Missing prerequisites or denied
authorization stop the relevant step; they are not a completed installation.

For the plugin route instead, expect the exact Agent Customizations editor steps
or `/plugin` commands to run yourself, then a check that `RPI Agent` and
`/hve-core:rpi-research` appear after a reload. Post-installation options and
selective component copying remain separate choices; component collisions and
upgrades require their prescribed confirmations. Keep credentials private and
never treat rollback guidance as permission to delete an existing repository or
customized files.
