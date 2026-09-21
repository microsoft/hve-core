---
title: hve-core-installer
description: "Decision-driven HVE-Core installer with multiple clone-based and extension install methods, environment detection, and selective component installation"
sidebar_position: 1
author: Microsoft
ms.date: 2026-09-09
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
Decision-driven HVE-Core installer with multiple clone-based and extension install methods, environment detection, and selective component installation
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill to choose and validate an HVE-Core installation for VS Code or
VS Code Insiders. The extension route suits a quick managed installation;
clone-based methods suit customization, shared version control, or controlled
updates. Re-running can validate an existing setup or offer an upgrade rather
than assuming a new installation is needed.

Clone-based methods need Git and network access; Bash component scripts also
need `jq`. Detection begins with consent, and settings or devcontainer changes
require explicit authorization. This is not permission to replace local customizations.

## Example usage

Ask: `/hve-core-installer Help a team using local VS Code select a clone-based
setup with controlled updates. Explain proposed changes before applying them.`
After initial consent, confirm the shell, environment, and team/update preferences.
The decision matrix should recommend the submodule method for that combination,
then wait for the selected-method and settings authorizations.

Success is verified artifact directories and configuration for the chosen method,
with actual paths and any reload action reported. Missing prerequisites or denied
authorization stop the relevant step; they are not a completed installation.

For the quick route instead, choose Extension and the correct stable/Insiders
variant, then expect installation validation rather than clone-method questions.
Post-installation options and selective component copying remain separate choices;
component collisions and upgrades require their prescribed confirmations. Keep
credentials private and never treat rollback guidance as permission to delete an
existing repository or customized files.
