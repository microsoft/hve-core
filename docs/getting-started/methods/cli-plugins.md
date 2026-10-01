---
title: Copilot CLI Plugin
description: Register an HVE Core catalog ref and install the complete hve-core plugin
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-19
ms.topic: how-to
keywords:
  - copilot cli
  - plugins
  - installation
---

Install the complete HVE Core component set as a Copilot CLI plugin for terminal-based AI-assisted development workflows.

## Prerequisites

* GitHub Copilot CLI installed and authenticated

## Register hve-core as a Plugin Marketplace

Choose a registration that matches the content you need.

Register the ref-less development tip:

```bash
copilot plugin marketplace add microsoft/hve-core
```

Register a moving reviewed release channel:

```bash
copilot plugin marketplace add microsoft/hve-core#release/prerelease
copilot plugin marketplace add microsoft/hve-core#release/stable
```

Register an immutable channel tag:

```bash
copilot plugin marketplace add microsoft/hve-core#prerelease-v<version>
copilot plugin marketplace add microsoft/hve-core#v<version>
```

`main` is the development tip. `release/prerelease` and `release/stable` are moving registrations that resolve the current reviewed branch catalog and repository-root plugin package. Exact-tag registrations freeze the catalog, root manifest, README, LICENSE, and plugin source together.

A published channel release provides release assurance for its exact tag,
including release gates, SBOMs, attestations, provenance verification, and the
configured publication path. The development tip does not provide that
published-release assurance.

## Browse Available Plugins

Type `/plugin` in a Copilot CLI chat session to browse available plugins.

## Install a Plugin

Install `hve-core` from the registered marketplace through `/plugin`. The plugin includes the complete active HVE Core component set, including the Research, Plan, Implement, Review lifecycle.

```bash
copilot plugin install hve-core@hve-core
```

## Update an Installed Plugin

Marketplace refresh and installed-plugin update are distinct actions. For a
moving registration, refresh the catalog before requesting a plugin update:

```bash
copilot plugin marketplace update hve-core
copilot plugin update hve-core@hve-core
```

Switching registrations can require removing and re-adding the marketplace.
Do not assume how the client handles duplicate same-name registrations; use
the behavior supported by your Copilot CLI version.

If you previously registered or installed a retired package identity, the
[retired package identities](../package-migration#retired-package-identities)
section of the migration guide maps each retired extension, command, skill, and
agent to its replacement.

## Plugin Contents

Each plugin includes:

| Component    | CLI Discovery | Description                                        |
|--------------|---------------|----------------------------------------------------|
| Agents       | Yes           | Custom chat agents for specialized workflows       |
| Commands     | Yes           | Task prompts accessible via the CLI                |
| Skills       | Yes           | Self-contained skill packages                      |
| Instructions | No            | Included for `#file:` references, not auto-applied |

The one marketplace entry resolves the repository root. Root `plugin.json` declares the complete agents, commands, rules, skills, and hook membership as repository-relative `.github/...` paths. The client resolves the root README and LICENSE; no generated plugin tree or plugin ZIP participates in Git-source installation.

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

| Mode          | Command                     | Behavior                                                     |
|---------------|-----------------------------|--------------------------------------------------------------|
| Named Command | `/git-commit`               | Executes a predefined workflow, then returns to default mode |
| Skill         | `/rpi-research`             | Activates one reusable RPI phase capability                  |
| Agent Mode    | `/agent hve-core:rpi-agent` | Switches to the coordinated RPI lifecycle                    |

Named commands (prompts) run a specific workflow and produce structured output. Agent mode enables freeform conversation with a specialized agent until you exit.

> [!IMPORTANT]
> The CLI does not switch to a custom agent on behalf of an agent-bound
> prompt. Select `hve-core:rpi-agent` when you want lifecycle coordination, or invoke a
> direct phase skill such as `/rpi-research`:
>
> ```text
> /agent hve-core:rpi-agent
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

After installing the hve-core plugin, these agents are available via `/agent <qualified-name>`:

* `hve-core:rpi-agent` coordinates Research, Plan, Implement, Review, and Follow-up
* `hve-core:documentation` audits, authors, and validates documentation

Start an interactive scripted invocation with the same qualified identifier:

```bash
copilot --agent hve-core:rpi-agent
```

For the complete list, run `/help` in a CLI session to see all available commands and agents.

### When to Use Each Mode

* Use **named commands** (`/git-commit-message`, `/git-merge`) directly from default mode for workflows that do not require a custom agent.
* Use direct skills (`/rpi-research`, `/rpi-plan`, `/rpi-implement`, `/rpi-review`) for one bounded RPI responsibility.
* Use **agent mode** with `/agent hve-core:rpi-agent` for lifecycle coordination.
* Stay in **agent mode** for exploratory conversations, follow-up questions, or tasks that don't fit a predefined prompt.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
