---
title: Copilot Plugin
description: Install the complete hve-core plugin in VS Code's Copilot harness or in Copilot CLI
sidebar_position: 1
author: Microsoft
ms.date: 2026-11-07
ms.topic: how-to
keywords:
  - copilot plugin
  - agent plugins
  - copilot cli
  - plugins
  - installation
estimated_reading_time: 6
---

The `hve-core` plugin installs the complete HVE Core component set: agents, skills, and instructions, plus canvases in VS Code. VS Code's Copilot harness and Copilot CLI both install it from the same `microsoft/hve-core` marketplace.

## When to Use This Method

✅ **Use this when:**

* You want every HVE Core agent, skill, and instruction from one install
* You work in VS Code, in Copilot CLI, or in both
* You want canvases such as the [RPI Workflow canvas](../../rpi/rpi-workflow-canvas)
* You are comfortable with content that follows `main`

❌ **Consider alternatives when:**

* Your team needs a pinned version → [Git Submodule](submodule)
* Your repository should own and customize its copy → [Copy HVE Core Into Your Repository](../install#copy-hve-core-into-your-repository)
* You want Marketplace release channels → [VS Code Extension](extension)

## Prerequisites

* VS Code with GitHub Copilot, or GitHub Copilot CLI installed and authenticated

## Install in VS Code

1. Run **Chat: Open Customizations** from the Command Palette to open the Agent Customizations editor.
2. Select **Browse**, open the source menu, and select **Configure Marketplaces**.
3. Select **Add Marketplace** and enter `microsoft/hve-core`.
4. Return to **Browse**, choose the `hve-core` marketplace from the source menu, and install the `hve-core` plugin. The first install from a new marketplace asks you to trust it.

If your editor has no **Browse** page, select **Plugins** and then **Browse Marketplace** instead. In a Copilot chat session, the same install takes two commands:

```text
/plugin marketplace add microsoft/hve-core
/plugin install hve-core@hve-core
```

To offer the plugin to everyone who opens a repository, commit the defaults described in [Offer the Plugin to Your Team](../install#offer-the-plugin-to-your-team).

## Install in Copilot CLI

Register the repository as a plugin marketplace:

```bash
copilot plugin marketplace add microsoft/hve-core
```

The registration tracks the `main` branch, which has no release gate or release attestation. Each push to `main` publishes an unattested dependency SBOM, described in [Continuous Main SBOM](../../contributing/release-process.md#continuous-main-sbom).

List the plugins in the registered marketplace, or type `/plugin` in a Copilot CLI chat session to browse them:

```bash
copilot plugin marketplace browse hve-core
```

Install `hve-core`, which includes the Research, Plan, Implement, Review lifecycle:

```bash
copilot plugin install hve-core@hve-core
```

VS Code also picks up plugins that Copilot CLI installs, so a CLI install covers both clients.

## Update an Installed Plugin

In VS Code, select **Check for and Apply Updates** on the **Plugins** page of the Agent Customizations editor, or run **Chat: Update Plugins**.

In Copilot CLI, refreshing the marketplace catalog and updating the installed plugin are separate actions. Because the registration tracks `main`, refresh the catalog first:

```bash
copilot plugin marketplace update hve-core
copilot plugin update hve-core@hve-core
```

After an update, run **Developer: Reload Window** in VS Code so new chat sessions pick up changed instructions.

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

## Install From a Clone or Branch

To try a branch or your own changes, install a clone as a plugin from source. In the Agent Customizations editor, select **Plugins**, select the add (`+`) button next to **User** or **Workspace**, and enter a Git repository URL or the clone's root folder path. **Chat: Install Plugin from Source** in the Command Palette does the same. For a Git URL, VS Code clones the repository and installs the plugin. A plugin installed this way can be updated or uninstalled, but not enabled or disabled.

[Peer Directory Clone](peer-clone) walks through this setup for a clone that sits next to your project.

## Plugin Contents

| Component    | Loaded by Copilot | Description                                                              |
|--------------|-------------------|--------------------------------------------------------------------------|
| Agents       | Yes               | Custom chat agents for specialized workflows                             |
| Skills       | Yes               | Self-contained skill packages, including the RPI phase entry points      |
| Instructions | Yes               | Guidelines that Copilot applies to files matching each `applyTo` pattern |
| Canvases     | VS Code           | Interactive panels such as the RPI Workflow canvas and the Session Log   |

The marketplace has one entry, which resolves to the repository root. Root `plugin.json` lists the plugin's agents, skills, rules (instruction files), and canvas extension as repository-relative `.github/...` paths. The client also reads the root README and LICENSE; no generated plugin tree or plugin ZIP is involved.

## Limitations

* The registration follows `main`. It has no PreRelease or Stable channel and no published-release assurance.
* Installing the plugin next to another route, such as the extension or a declared clone, lists each agent more than once. Keep one route.
* In VS Code, plugin skills carry the plugin name as a prefix, such as `/hve-core:rpi-research`.

## Using Agents After Installation

After you install the plugin, its agents and skills are available in new chat sessions.

### Skills vs Agent Mode

The plugin offers two ways to work:

| Mode  | VS Code                                | Copilot CLI                 | Behavior                                                |
|-------|----------------------------------------|-----------------------------|---------------------------------------------------------|
| Skill | `/hve-core:rpi-research`               | `/rpi-research`             | Activates one reusable capability from the default mode |
| Agent | Select `RPI Agent` in the agent picker | `/agent hve-core:rpi-agent` | Switches to the coordinated RPI lifecycle               |

Skills run a specific workflow and produce structured output. Agent mode keeps the conversation with a specialized agent until you switch away.

> [!IMPORTANT]
> Copilot does not switch to a custom agent on behalf of a skill. For lifecycle
> coordination, run `/rpi` (`/hve-core:rpi` in VS Code) from the default mode,
> or select `RPI Agent` (`hve-core:rpi-agent` in Copilot CLI), which preloads
> the same `rpi` skill:
>
> ```text
> /agent hve-core:rpi-agent
> Research API authentication patterns before deciding whether planning is ready.
> ```
>
> Invoke a direct phase skill such as `/rpi-research` for one phase. Skills that
> do not require an agent context work directly from the default mode.

Manual-only skills such as `git-commit`, `git-merge`, and `git-setup` set
`disable-model-invocation: true`, so agents never start them for you. For their
status in Copilot CLI, see
[github/copilot-cli#4438](https://github.com/github/copilot-cli/issues/4438).

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

In Copilot CLI, these agents are available through `/agent <qualified-name>`:

* `hve-core:rpi-agent` coordinates Research, Plan, Implement, Review, and Follow-up
* `hve-core:documentation` audits, authors, and validates documentation

Start an interactive scripted invocation with the same qualified identifier:

```bash
copilot --agent hve-core:rpi-agent
```

Run `/help` in a CLI session to see every available command and agent. In VS Code, the agent picker lists the same agents by display name, such as `RPI Agent` and `Documentation`.

### When to Use Each Mode

* Use direct skills (`/rpi-research`, `/rpi-plan`, `/rpi-implement`, `/rpi-review`) from the default mode for one bounded responsibility that does not require a custom agent.
* Use `/rpi` from the default mode, or **agent mode** with `RPI Agent`, for lifecycle coordination.
* Stay in **agent mode** for exploratory conversations, follow-up questions, or tasks that don't fit a predefined skill.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
