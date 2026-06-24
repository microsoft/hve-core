---
title: Plugin Generation Scripts
description: PowerShell tooling for generating Copilot CLI plugins from collection manifests
---

PowerShell tooling for generating Copilot CLI plugins from collection
manifests.

## Scripts

| Script                       | npm Command               | Description                                         |
|------------------------------|---------------------------|-----------------------------------------------------|
| Generate-Plugins.ps1         | `npm run plugin:generate` | Generate plugin directories from collections        |
| Install-LocalCopilotPlugin.sh | (direct script)           | Install generated plugin output for local CLI tests |
| Modules/PluginHelpers.psm1   | (library)                 | Plugin symlink, manifest, and packaging             |

## Prerequisites

* PowerShell 7.0+
* PowerShell-Yaml module (`Install-Module -Name PowerShell-Yaml -RequiredVersion 0.4.7`)

## Collection to Plugin Pipeline

1. Author artifacts in `.github/` (agents, prompts, skills)
2. Define collections in `collections/*.collection.yml`
3. Run `npm run plugin:generate` to produce `plugins/`
4. Commit generated `plugins/` to the repository

## Refreshing Plugins After Artifact Changes

```bash
npm run plugin:generate
```

This regenerates all plugins from their collection manifests.

## Installing a Local Plugin for CLI Development

Use the local installer when you need Copilot CLI to load generated plugin
output from the current checkout instead of the marketplace version:

```bash
scripts/plugins/Install-LocalCopilotPlugin.sh
```

The script backs up the existing installed plugin, uninstalls the current
`hve-core` plugin registration, removes stale installed plugin directories, and
runs `copilot plugin install` against the local `plugins/hve-core` directory.
Use `--generate` first when PowerShell is available and plugin outputs need
regeneration.

The installer validates the generated `task-research` command, verifies the named Task Researcher lane subagents are present, restricts plugin IDs to safe slug characters, and refuses to remove paths outside `~/.copilot/installed-plugins`.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
