---
title: Copilot CLI Plugins
description: Install HVE Core agents, prompts, and skills as Copilot CLI plugins
sidebar_position: 2
author: Microsoft
ms.date: 2026-07-15
ms.topic: how-to
---

Install HVE Core collections as Copilot CLI plugins for terminal-based
AI-assisted development workflows. The plugin names below mirror the current
collection IDs published by the repository's plugin output.

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

Choose **one** of the following plugins to install. Each command installs a
different collection from the hve-core marketplace.

For the core Research, Plan, Implement, Review lifecycle:

```bash
copilot plugin install hve-core@hve-core
```

For the full bundle (includes everything in `hve-core` plus all additional
collections):

```bash
copilot plugin install hve-core-all@hve-core
```

> [!TIP]
> `hve-core-all` is a superset of `hve-core`. Install one or the other, not
> both. If you are unsure which to pick, start with `hve-core-all` for the
> complete experience.

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

## Using Agents After Installation

After installing a plugin, agents and named commands are available in your CLI session.

### Named Commands vs Agent Mode

CLI plugins provide two distinct interaction patterns:

| Mode          | Command            | Behavior                                                     |
|---------------|--------------------|--------------------------------------------------------------|
| Named Command | `/git-commit`      | Executes a predefined workflow, then returns to default mode |
| Skill         | `/rpi-research`    | Activates one reusable RPI phase capability                  |
| Agent Mode    | `/agent RPI Agent` | Switches to the coordinated RPI lifecycle                    |

Named commands (prompts) run a specific workflow and produce structured output. Agent mode enables freeform conversation with a specialized agent until you exit.

> [!IMPORTANT]
> The CLI does not switch to a custom agent on behalf of an agent-bound
> prompt. Select `RPI Agent` when you want lifecycle coordination, or invoke a
> direct phase skill such as `/rpi-research`:
>
> ```text
> /agent RPI Agent
> Research API authentication patterns before deciding whether planning is ready.
> ```
>
> Prompts that do not require an agent context (e.g., `/git-commit`,
> `/git-merge`) work directly from the default mode.

### Example: Research Workflow

Invoke the Research phase skill directly:

```text
> /rpi-research topic="API authentication patterns"
[Skill executes the research workflow and creates a research document]
```

Continue with follow-up questions in the same session:

```text
> What are common API authentication patterns for REST APIs?
[Research conversation continues]
> How do OAuth2 and API keys compare for microservices?
[Follow-up within same agent context]
```

### Available Agents

After installing the hve-core plugin, these agents are available via `/agent <name>`:

* RPI Agent - coordinates Research, Plan, Implement, Review, and Follow-up
* Documentation - audits, authors, and validates documentation

For the complete list, run `/help` in a CLI session to see all available commands and agents.

### When to Use Each Mode

* Use **named commands** (`/git-commit-message`, `/git-merge`) directly from default mode for workflows that do not require a custom agent.
* Use direct skills (`/rpi-research`, `/rpi-plan`, `/rpi-implement`, `/rpi-review`) for one bounded RPI responsibility.
* Use **agent mode** with `/agent RPI Agent` for lifecycle coordination.
* Stay in **agent mode** for exploratory conversations, follow-up questions, or tasks that don't fit a predefined prompt.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
