---
title: Copilot CLI Plugins
description: Install HVE Core agents, prompts, and skills as Copilot CLI plugins
sidebar_position: 2
author: Microsoft
ms.date: 2026-03-23
ms.topic: how-to
---

Install HVE Core collections as Copilot CLI plugins for terminal-based
AI-assisted development workflows.

## Prerequisites

* GitHub Copilot CLI installed and authenticated
* Git symlink support enabled (Windows: Developer Mode +
  `git config --global core.symlinks true`)

## Register hve-core as a Plugin Marketplace

```bash
copilot plugin marketplace add microsoft/hve-core
```

## Browse Available Plugins

Type `/plugin` in a Copilot CLI chat session to browse available plugins.

## Install a Plugin

```bash
copilot plugin install hve-core@hve-core
copilot plugin install hve-core-all@hve-core
```

## Available Plugins

| Plugin           | Description                                                                                                                                                               |
|------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| hve-core         | Research, Plan, Implement, Review lifecycle                                                                                                                               |
| github           | GitHub issue management                                                                                                                                                   |
| ado              | Azure DevOps integration                                                                                                                                                  |
| coding-standards | Language-specific coding guidelines                                                                                                                                       |
| project-planning | PRDs, BRDs, ADRs, architecture diagrams                                                                                                                                   |
| data-science     | Data specs, notebooks, dashboards                                                                                                                                         |
| design-thinking  | Design thinking coaching and methodology                                                                                                                                  |
| security         | Security and incident response                                                                                                                                            |
| installer        | Installer skill for guided workspace setup and MCP auto-configuration ([Extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-installer)) |
| experimental     | Experimental and preview artifacts                                                                                                                                        |
| hve-core-all     | Full HVE Core bundle                                                                                                                                                      |

## Plugin Contents

Each plugin includes:

| Component    | CLI Discovery | Description                                        |
|--------------|---------------|----------------------------------------------------|
| Agents       | Yes           | Custom chat agents for specialized workflows       |
| Commands     | Yes           | Task prompts accessible via the CLI                |
| Skills       | Yes           | Self-contained skill packages (hve-core-all only)  |
| Instructions | No            | Included for `#file:` references, not auto-applied |

Artifacts are symlinked from the plugin directory to the source repository,
enabling zero-copy installation.

## Limitations

### Instructions are not auto-applied from plugins

The Copilot CLI [plugin spec](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference)
recognizes `agents`, `skills`, `commands`, `hooks`, `mcpServers`, and
`lspServers` as component types. There is no `instructions` component type.

The CLI loads path-specific instructions exclusively from
`.github/instructions/**/*.instructions.md` in the
[project repo](https://docs.github.com/en/copilot/reference/custom-instructions-support#copilot-cli).
Instruction files in plugin directories are **not** auto-applied via `applyTo`
pattern matching.

Instruction files are still included in plugin output because agents and
prompts reference them via `#file:` directives. Those cross-file references
resolve correctly within the plugin directory tree. The difference is between
explicit inclusion (an agent pulls in instruction content at execution time)
and automatic application (the CLI matches `applyTo` patterns against the
files you are editing).

For full path-specific instruction behavior, copy instruction files into your
project's `.github/instructions/` directory.

### Other limitations

* Skills require skill-compatible agent environments

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
