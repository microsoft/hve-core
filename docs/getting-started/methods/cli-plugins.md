---
title: Copilot CLI Plugin
description: Register the HVE Core marketplace and install the complete hve-core plugin
sidebar_position: 2
author: Microsoft
ms.date: 2026-10-07
ms.topic: how-to
keywords:
  - copilot cli
  - plugins
  - installation
---

Install the complete HVE Core component set as a Copilot CLI plugin for terminal-based AI-assisted development workflows.

## Prerequisites

* GitHub Copilot CLI installed and authenticated

## Register the HVE Core Marketplace

Register the repository as a plugin marketplace:

```bash
copilot plugin marketplace add microsoft/hve-core
```

The registration tracks the `main` branch, which has no release gate or release attestation. Each push to `main` publishes an unattested dependency SBOM, described in [Continuous Main SBOM](../../contributing/release-process.md#continuous-main-sbom). PreRelease and Stable are VS Code extension channels, so the plugin has no channel to select.

## Browse Available Plugins

List the plugins in the registered marketplace:

```bash
copilot plugin marketplace browse hve-core
```

You can also type `/plugin` in a Copilot CLI chat session to browse available plugins.

## Install the Plugin

Install `hve-core` from the registered marketplace. The plugin includes the complete HVE Core component set, including the Research, Plan, Implement, Review lifecycle.

```bash
copilot plugin install hve-core@hve-core
```

## Update an Installed Plugin

Refreshing the marketplace catalog and updating the installed plugin are separate actions. Because the registration tracks `main`, refresh the catalog before updating the plugin:

```bash
copilot plugin marketplace update hve-core
copilot plugin update hve-core@hve-core
```

## Replace an Earlier Registration

If you registered a release-channel or tag ref, such as `microsoft/hve-core#release/stable` or `microsoft/hve-core#hve-core-v<version>`, remove that registration and register the repository again to follow `main`. The repository does not publish `release/prerelease` or `release/stable` branches, so those refs no longer resolve, and a tag ref stays fixed at that tag:

```bash
copilot plugin marketplace remove hve-core --force
copilot plugin marketplace add microsoft/hve-core
copilot plugin install hve-core@hve-core
```

In some Copilot CLI versions, `--force` also uninstalls plugins installed from that marketplace. Check `copilot plugin marketplace remove --help` for your version.

If you previously registered or installed a retired package identity, the
[retired package identities](../package-migration#retired-package-identities)
section of the migration guide maps each retired extension, command, skill, and
agent to its replacement.

## Plugin Contents

The plugin includes:

| Component    | CLI Discovery | Description                                        |
|--------------|---------------|----------------------------------------------------|
| Agents       | Yes           | Custom chat agents for specialized workflows       |
| Skills       | Yes           | Self-contained skill packages                      |
| Instructions | No            | Included for `#file:` references, not auto-applied |

The marketplace has one entry, which resolves to the repository root. Root `plugin.json` lists the plugin's agents, commands, rules (instruction files), and skills as repository-relative `.github/...` paths. The client also reads the root README and LICENSE; no generated plugin tree or plugin ZIP is involved.

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

Instruction files are still included in the plugin because agents reference
them via `#file:` directives and skills link to them. Those cross-file references
resolve correctly within the plugin directory tree. The difference is between
explicit inclusion (an agent pulls in instruction content at execution time)
and automatic application (the CLI matches `applyTo` patterns against the
files you are editing).

For full path-specific instruction behavior, copy instruction files into your
project's `.github/instructions/` directory.

### Other limitations

* Skills require skill-compatible agent environments

## Using Agents After Installation

After installing a plugin, agents and skills are available in your CLI session.

### Skills vs Agent Mode

CLI plugins provide two distinct interaction patterns:

| Mode       | Command                     | Behavior                                                |
|------------|-----------------------------|---------------------------------------------------------|
| Skill      | `/rpi-research`             | Activates one reusable capability from the default mode |
| Agent Mode | `/agent hve-core:rpi-agent` | Switches to the coordinated RPI lifecycle               |

Skills run a specific workflow and produce structured output. Agent mode enables freeform conversation with a specialized agent until you exit.

> [!IMPORTANT]
> The CLI does not switch to a custom agent on behalf of a skill. Select
> `hve-core:rpi-agent` when you want lifecycle coordination, or invoke a
> direct phase skill such as `/rpi-research`:
>
> ```text
> /agent hve-core:rpi-agent
> Research API authentication patterns before deciding whether planning is ready.
> ```
>
> Skills that do not require an agent context work directly from the default mode.

Manual-only skills such as `git-commit`, `git-merge`, and `git-setup` set
`disable-model-invocation: true`. Copilot CLI does not currently run skills
with that setting
([github/copilot-cli#4438](https://github.com/github/copilot-cli/issues/4438)),
so use them from VS Code until that issue is resolved.

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

* Use direct skills (`/rpi-research`, `/rpi-plan`, `/rpi-implement`, `/rpi-review`) from default mode for one bounded responsibility that does not require a custom agent.
* Use **agent mode** with `/agent hve-core:rpi-agent` for lifecycle coordination.
* Stay in **agent mode** for exploratory conversations, follow-up questions, or tasks that don't fit a predefined skill.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
