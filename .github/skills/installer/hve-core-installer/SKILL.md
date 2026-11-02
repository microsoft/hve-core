---
name: hve-core-installer
description: 'Decision-driven HVE-Core installer for the Copilot harness: the plugin, a team default in repository settings, a full component copy into the repository, the VS Code extension, and clone-based storage, with environment detection, validation, and MCP setup'
compatibility: 'Requires VS Code or VS Code Insiders. Clone-based methods require git on PATH and network access. The Bash component scripts require jq.'
license: MIT
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-10-31"
---

# HVE-Core Installer Skill

Decision-driven installer for HVE-Core in VS Code's Copilot agent harness. It recommends the HVE-Core plugin first, then a team default in `.github/copilot/settings.json`, then native repository adoption, which copies every HVE-Core component into the project's own `.github` folders.

The VS Code extension remains an editor option. A clone is a storage choice that Copilot uses as a plugin from source or, for a copy inside the project's checkout, through folders declared in `.github/copilot/settings.json`. The skill also validates the result and configures MCP servers.

## Role Definition

Operate as two collaborating personas:

* The **Installer** persona detects the environment, guides route selection, and executes installation steps
* The **Validator** persona verifies installed folders and repository settings, then has the user confirm that HVE-Core agents and skills appear in Copilot Chat

The Installer persona handles all detection and execution. After installation completes, switch to the Validator persona to verify success before reporting completion.

**Re-run Behavior:** Running the installer again validates an existing installation or offers upgrade. Safe to re-run anytime.

## Required Phases

| Phase | Name                                    | Purpose                                                                                      |
|-------|-----------------------------------------|----------------------------------------------------------------------------------------------|
| 1     | Environment Detection                   | Obtain consent and check for earlier HVE-Core installs                                       |
| 2     | Install Route Selection                 | Choose the plugin, team default, native adoption, extension, or clone route                  |
| 3     | Environment Detection & Decision Matrix | For native adoption and clones: detect the environment and recommend where to keep the clone |
| 4     | Installation Methods                    | Clone HVE-Core and, for the clone route, connect the clone to Copilot                        |
| 5     | Validation                              | Verify the clone before it is used                                                           |
| 6     | Post-Installation Setup                 | Configure gitignore and MCP servers, then reload the window and check Copilot Chat           |
| 7     | Component Installation                  | Native adoption: copy every component into the project's `.github` folders                   |

Flow paths:

* Plugin, team default, and extension routes: Phase 1 → Phase 2 → Phase 6 → Complete
* Native adoption: Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 7 → Phase 6 → Complete
* Clone route: Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Complete

For native adoption from a clone the user already has, skip Phases 3 and 4 and validate that clone in Phase 5.

> [!IMPORTANT]
> Install HVE-Core through one route at a time. Installing the same content through more than one route, for example the plugin and the extension, or the plugin and a declared clone, lists agents more than once in the subagent list, and Copilot does not remove copies that arrive by different routes.

## Phase 1: Environment Detection

Before presenting options, obtain consent and check what is already installed.

### Checkpoint 1: Initial Consent

Present the following and await explicit consent:

```text
🚀 HVE-Core Installer

I'll help you install HVE-Core agents, instructions and skills.

Available content:
• Specialized agents, including RPI Agent, Documentation, and domain planners
• Technology-specific coding instructions (bash, python, markdown, etc.)
• Domain-specific skills (pr-reference, etc.)

I'll recommend an install route. If your route needs a clone, I'll ask 2-3 questions about your setup first.

Would you like to proceed?
```

If user declines, respond: "Installation cancelled. You can invoke this skill anytime to restart."

### Existing Install Check

Upon consent, look for HVE-Core content that is already installed:

* `.hve-tracking.json` at the workspace root means components were copied into the repository. Offer to upgrade them through native adoption, which runs Phase 7 in upgrade mode.
* `.github/copilot/settings.json` that enables `hve-core@hve-core` or declares folders from an HVE-Core clone means the team default or a declared clone is in place.
* Ask whether the user has installed the HVE-Core plugin or the HVE Core extension.
* VS Code settings that list HVE-Core folders come from an earlier version of this installer. Note the files that hold them. Phase 6 offers the cleanup below once the user confirms HVE-Core in a Copilot session.

When a route is already active, ask whether to keep it or replace it before installing another. Then proceed to Phase 2.

### Earlier Location Settings Cleanup

Earlier versions of this installer added HVE-Core folders to `chat.agentFilesLocations`, `chat.instructionsFilesLocations`, `chat.agentSkillsLocations`, `chat.promptFilesLocations`, and `chat.hookFilesLocations`. Those settings are editor-only: VS Code forwards files from those locations, but Copilot CLI and the GitHub Copilot app do not read them. Kept beside a new route, they deliver the same content twice.

HVE-Core supports only the Copilot harness. VS Code's Local harness doesn't load the `skills:` preloads that HVE-Core agents depend on, and removing these settings while the user still works in Local hides the agents Local found through them. Offer the cleanup only after the user confirms both of these:

* Their chat sessions use the Copilot harness. VS Code shows the harness at the start of the chat title.
* A Copilot session shows HVE-Core, using the agent and skill checks from the final completion report in Phase 6.

When the user is still on Local, explain that HVE-Core supports only the Copilot harness and that they switch by starting a new chat and selecting **Copilot** in the **Session Target** control before the first prompt. Keep the settings until the user confirms both points, and report "⏭️ Kept earlier location settings until a Copilot session shows HVE-Core".

Look in `.vscode/settings.json`, any `.code-workspace` file, and the `customizations.vscode.settings` block of `.devcontainer/devcontainer.json` for entries whose paths point into an HVE-Core clone, such as `../hve-core`, `.hve-core`, `/workspaces/hve-core`, or `lib/hve-core`. For each file with such entries:

1. Show the user the HVE-Core entries it holds.
2. Get approval under Checkpoint 3 (see Authorization Guardrails).
3. Remove only the HVE-Core entries. Remove a setting only when it has no entries left, and leave unrelated entries alone.
4. Report "✅ Removed earlier HVE-Core location settings from [file]", or "⏭️ Kept earlier location settings in [file]" when the user declines.

After removing entries, ask the user to run **Developer: Reload Window** and repeat the agent and skill checks, so they confirm that the installed route, not the old settings, delivers HVE-Core.

## Phase 2: Install Route Selection

Present the route choice before any environment detection. The plugin, team default, and extension routes need no shell selection or environment detection.

### Checkpoint 2: Install Route Choice

Present the following choice:

<!-- <install-route-checkpoint> -->
```text
🚀 Choose How to Install HVE-Core

**Option 1: Plugin (Recommended)**
Install the HVE-Core plugin with two commands in Copilot Chat.
• 📦 All agents, skills, and instructions
• 🔄 Updates from the Plugins page

**Option 2: Team Default**
I add .github/copilot/settings.json so Copilot offers the plugin
to everyone who opens this repository.

**Option 3: Copy into This Repository**
I copy every HVE-Core agent, skill, and instruction into your
.github folders. Your repository owns the copies.

**Option 4: VS Code Extension**
Install from the VS Code Marketplace. Its agents and skills reach
Copilot sessions, but its instructions may not.

**Option 5: Clone**
Keep a pinned copy of HVE-Core in a folder you choose, then
connect it to Copilot.

Use one route at a time. Which would you prefer? (1-5)
```
<!-- </install-route-checkpoint> -->

User input handling:

* "1", "plugin" → Plugin Route
* "2", "team", "team default" → Team Default Route
* "3", "copy", "adopt", "native", "components" → Native adoption: continue to Shell Selection and Prerequisites
* "4", "extension", "vsix" → Extension Installation Execution
* "5", "clone", "submodule" → Clone route: continue to Shell Selection and Prerequisites
* Unclear response → Ask for clarification

Recommend a route other than the plugin when:

* A team wants Copilot to offer HVE-Core to everyone who opens the repository (Option 2)
* The repository should own and customize its copy of HVE-Core (Option 3)
* The user needs a pinned copy of HVE-Core or plans to edit HVE-Core itself (Option 5)

### Plugin Route

The plugin carries the full set: agents, skills, and path-specific instructions. Slash commands and editor controls need the user, so present these steps and wait for confirmation:

<!-- <plugin-install-steps> -->
```text
📦 Install the HVE-Core Plugin

In Copilot Chat with the Copilot harness, send these commands one at a time:
  /plugin marketplace add microsoft/hve-core
  /plugin install hve-core@hve-core

Or open the Agent Customizations editor, select Plugins, add the
microsoft/hve-core marketplace, and install hve-core.

With Copilot CLI, run these commands in a terminal instead:
  copilot plugin marketplace add microsoft/hve-core
  copilot plugin install hve-core@hve-core
VS Code discovers plugins that Copilot CLI installs.

Reply "done" when the plugin is installed.
```
<!-- </plugin-install-steps> -->

Run the Copilot CLI commands only when the user asks you to. After the user confirms, proceed to Phase 6.

Tell the user how to update later: select **Check for and Apply Updates** (the refresh icon) on the **Plugins** page, or run **Chat: Update Plugins**. With Copilot CLI, run `copilot plugin marketplace update hve-core`, then `copilot plugin update hve-core@hve-core`. After any update, run **Developer: Reload Window**.

### Team Default Route

A project can commit `.github/copilot/settings.json` so the Copilot harness offers HVE-Core to everyone who opens the repository. Each person can turn optional plugins off on the **Plugins** page, and enterprise-managed settings take precedence over these defaults.

Get approval under Checkpoint 3, then create `.github/copilot/settings.json` with the content below. When the file already exists, merge the two keys into it and keep its other entries.

<!-- <team-default-settings> -->
```json
{
  "extraKnownMarketplaces": {
    "hve-core": {
      "source": {
        "source": "github",
        "repo": "microsoft/hve-core"
      }
    }
  },
  "enabledPlugins": {
    "hve-core@hve-core": true
  }
}
```
<!-- </team-default-settings> -->

The marketplace key must match the marketplace name, `hve-core`. Report "✅ Added the HVE-Core plugin default to .github/copilot/settings.json", remind the user to commit the file so teammates receive it, and proceed to Phase 6.

### Extension Installation Execution

The `ise-hve-essentials.hve-core` extension is an editor option. VS Code forwards the extension's agents and skills to Copilot sessions, but its instructions may not reach them, and the extension does not carry canvases. Recommend the plugin when the user needs the instructions.

When the user selects the extension, first ask which VS Code variant they are using:

<!-- <vscode-variant-prompt> -->
```text
Which VS Code variant are you using?

  [1] VS Code (stable)
  [2] VS Code Insiders

Your choice? (1/2)
```
<!-- </vscode-variant-prompt> -->

User input handling:

* "1", "code", "stable" → Use `code` CLI
* "2", "insiders", "code-insiders" → Use `code-insiders` CLI
* Unclear response → Ask for clarification

Store the user's choice as the `code_cli` variable for use in validation scripts.

**Display progress message:**

```text
📥 Installing HVE Core extension from marketplace...

Note: You may see a trust confirmation dialog if this is your first extension from this publisher.
```

**Execute VS Code CLI command:**

```text
<code_cli> --install-extension ise-hve-essentials.hve-core
```

After command execution, proceed to Extension Validation.

### Extension Validation

Run the appropriate validation script based on the detected platform (Windows = PowerShell, macOS/Linux = Bash). Use the `code_cli` value from the user's earlier choice (`code` or `code-insiders`).

**PowerShell:** Run [scripts/validate-extension.ps1](scripts/validate-extension.ps1) with the `code_cli` variable set.

**Bash:** Run [scripts/validate-extension.sh](scripts/validate-extension.sh) with the `code_cli` variable set.

### Extension Success Report

Upon successful validation, display:

<!-- <extension-success-report> -->
```text
✅ Extension Installation Complete!

The HVE Core extension has been installed from the VS Code Marketplace.

📦 Extension: ise-hve-essentials.hve-core
📌 Version: [detected version]
🔗 Marketplace: https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core

🧪 Available Agents:
• rpi-agent, documentation, backlog-manager, and adr-creation
• code-review, security-planner, ux-ui-designer, and more!

ℹ️ VS Code forwards the extension's agents and skills to Copilot sessions.
   Its instructions may not reach Copilot sessions, and the extension does
   not carry canvases. Use the plugin when you need the instructions.

📋 Configuring optional settings...
```
<!-- </extension-success-report> -->

After displaying the extension success report, proceed to **Phase 6: Post-Installation Setup** for gitignore and MCP configuration options.

### Extension Error Recovery

If extension installation fails, provide targeted guidance:

<!-- <extension-error-recovery> -->
| Error Scenario            | User Message                                                                    | Recovery Action                             |
|---------------------------|---------------------------------------------------------------------------------|---------------------------------------------|
| Trust dialog declined     | "Installation was cancelled. You may have declined the publisher trust prompt." | Offer retry or the plugin route             |
| Network failure           | "Unable to connect to VS Code Marketplace. Check your network connection."      | Offer retry or CLI alternative              |
| Organization policy block | "Extension installation may be restricted by your organization's policies."     | Provide CLI command for manual installation |
| Unknown failure           | "Extension installation failed unexpectedly."                                   | Offer the plugin route as a fallback        |
<!-- </extension-error-recovery> -->

**Flow Control After Failure:**

If extension installation fails and user cannot resolve:

* Offer: "Would you like to install the HVE-Core plugin instead? (yes/no)"
* If yes: Continue to the Plugin Route
* If no: End session with manual installation instructions

### Shell Selection and Prerequisites

Native adoption and the clone route run scripts, so ask for a shell first:

* Ask: "Which shell would you prefer? (powershell/bash)"
* Shell detection rules:
  * "powershell", "pwsh", "ps1", "ps" → PowerShell
  * "bash", "sh", "zsh" → Bash
  * Unclear response → Windows = PowerShell, macOS/Linux = Bash

Before cloning, verify git is available:

* Run: `git --version`
* If fails: "Git is required to clone HVE-Core. Install git, or choose the plugin route instead."

When the user selects Bash, also verify `jq` is available:

* Run: `jq --version`
* If fails: "jq is required by the Bash component scripts. Install jq or choose PowerShell."

Then run the Environment Detection Script and continue to Phase 3.

### Environment Detection Script

Run the appropriate detection script based on the user's shell:

**PowerShell:** Run [scripts/detect-environment.ps1](scripts/detect-environment.ps1)

**Bash:** Run [scripts/detect-environment.sh](scripts/detect-environment.sh)

## Phase 3: Environment Detection & Decision Matrix

Phase 3 recommends where to keep the clone. For native adoption, first ask whether the user already has an HVE-Core clone. When they do, use its path as the copy source and skip to Phase 5.

When detection reports `IS_HVE_CORE_REPO=true`, tell the user that no install is needed. Copilot discovers the repository's own `.github/agents`, `.github/skills`, and `.github/instructions` folders, including nested package folders, without any settings.

Otherwise, ask the following questions based on the detected environment.

### Question 1: Environment Confirmation

Present options filtered by detection results:

<!-- <question-1-environment> -->
```text
### Question 1: What's your development environment?

Based on my detection, you appear to be in: [DETECTED_ENV_TYPE]

Please confirm or correct:

| Option | Description                               |
|--------|-------------------------------------------|
| **A**  | 💻 Local VS Code (no devcontainer)        |
| **B**  | 🐳 Local devcontainer (Docker Desktop)    |
| **C**  | ☁️ GitHub Codespaces only                 |
| **D**  | 🔄 Both local devcontainer AND Codespaces |

Which best describes your setup? (A/B/C/D)
```
<!-- </question-1-environment> -->

### Question 2: Team or Solo

<!-- <question-2-team> -->
```text
### Question 2: Team or solo development?

| Option   | Description                                                   |
|----------|---------------------------------------------------------------|
| **Solo** | Solo developer - no need for version control of HVE-Core      |
| **Team** | Multiple people - need reproducible, version-controlled setup |

Are you working solo or with a team? (solo/team)
```
<!-- </question-2-team> -->

### Question 3: Update Preference

Ask this question only when multiple methods match the environment + team answers:

<!-- <question-3-updates> -->
```text
### Question 3: Update preference?

| Option         | Description                                   |
|----------------|-----------------------------------------------|
| **Auto**       | Always get latest HVE-Core on rebuild/startup |
| **Controlled** | Pin to specific version, update explicitly    |

How would you like to receive updates? (auto/controlled)
```
<!-- </question-3-updates> -->

## Decision Matrix

Use this matrix to recommend where to keep the clone and how Copilot uses it. For native adoption, the clone is only the copy source, so skip the first row and ignore the last column.

<!-- <decision-matrix> -->
| Environment             | Team | Updates    | **Recommended Method**                 | Copilot Uses It Through                               |
|-------------------------|------|------------|----------------------------------------|-------------------------------------------------------|
| Any (simplest)          | Any  | -          | **Plugin** (Option 1, no clone needed) | The plugin                                            |
| Local (no container)    | Solo | -          | **Method 1: Peer Clone**               | Plugin from source                                    |
| Local (no container)    | Team | Controlled | **Method 6: Submodule**                | `.github/copilot/settings.json` or plugin from source |
| Local devcontainer      | Solo | Auto       | **Method 2: Git-Ignored**              | Plugin from source                                    |
| Local devcontainer      | Team | Controlled | **Method 6: Submodule**                | `.github/copilot/settings.json` or plugin from source |
| Codespaces only         | Solo | Auto       | **Method 4: Codespaces**               | `.github/copilot/settings.json`                       |
| Codespaces only         | Team | Controlled | **Method 6: Submodule**                | `.github/copilot/settings.json` or plugin from source |
| Both local + Codespaces | Any  | Any        | **Method 5: Multi-Root Workspace**     | Plugin from source                                    |
<!-- </decision-matrix> -->

Folders declared in `.github/copilot/settings.json` must sit inside the project's checkout. Methods 2, 3, 4, and 6 keep the clone there, so they can declare its folders; Methods 1 and 5 connect through a plugin from source.

For Codespaces, ask whether the user needs a pinned or customized copy before recommending Method 4. When they do not, recommend the Team Default Route (Option 2) instead: it needs no clone, and Copilot offers HVE-Core to everyone who opens the repository in a codespace.

### Method Selection Logic

After gathering answers:

1. Match answers to decision matrix
2. Present recommendation with rationale
3. Offer alternative if user prefers different approach

<!-- <recommendation-template> -->
```text
## 📋 Your Recommended Setup

Based on your answers:
* **Environment**: [answer]
* **Team**: [answer]
* **Updates**: [answer]

### ✅ Recommended: Method [N] - [Name]

**Why this fits your needs:**
* [Benefit 1 matching their requirements]
* [Benefit 2 matching their requirements]
* [Benefit 3 matching their requirements]

**How Copilot uses it:** [Plugin from source, folders declared in .github/copilot/settings.json, or copy source for native adoption]

Would you like to proceed with this method, or see alternatives?
```
<!-- </recommendation-template> -->

## Phase 4: Installation Methods

Each clone method, and both ways to connect a clone to Copilot, are documented end to end in [references/installation-methods.md](references/installation-methods.md). Follow the method resolved by the decision matrix there. For native adoption, clone the source and leave it unconnected. When that file is unavailable, warn the user that installation cannot proceed for the selected method and stop rather than improvising the steps.

## Phase 5: Validation (Validator Persona)

After installation completes, switch to the **Validator** persona and verify the clone.

> [!IMPORTANT]
> After successful validation, run Phase 7 for native adoption and then Phase 6. For the clone route, proceed to Phase 6.

### Validation Workflow

Run validation based on the selected method. Set the base path variable before running:

| Method  | Base Path            |
|---------|----------------------|
| 1       | `../hve-core`        |
| 2, 3, 4 | `.hve-core`          |
| 5       | Check workspace file |
| 6       | `lib/hve-core`       |

For a clone the user already had, use its path as the base path with method `1`, which checks only the agents, instructions, and skills folders.

**PowerShell:** Run [scripts/validate-installation.ps1](scripts/validate-installation.ps1) with the `method` and `basePath` variables set.

**Bash:** Run [scripts/validate-installation.sh](scripts/validate-installation.sh) with the method number and base path as arguments.

For the clone route, also confirm the connection: the user replied "done" after installing the clone as a plugin from source, or `.github/copilot/settings.json` declares the clone's three folders.

### Success Report

Upon successful validation, display:

<!-- <success-report> -->
```text
✅ Core Installation Complete!

Method [N]: [Name] installed successfully.

📍 Location: [path based on method]
🔌 Connected through: [plugin from source or .github/copilot/settings.json]
📖 Documentation: https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/[method-doc].md

🧪 Available Agents:
• rpi-agent, documentation, backlog-manager, and adr-creation
• code-review, security-planner, ux-ui-designer, and more!

📋 Configuring optional settings...
```
<!-- </success-report> -->

For native adoption, skip this report. Display "✅ HVE-Core source ready at [path]" and proceed to Phase 7.

After displaying the success report, proceed to Phase 6 for post-installation setup.

## Phase 6: Post-Installation Setup

Read [references/post-installation-setup.md](references/post-installation-setup.md) and perform every step it specifies before continuing. When that file is unavailable, warn the user that post-installation setup cannot be completed and stop rather than improvising the steps.

## Phase 7: Component Installation and Upgrade

Read [references/component-installation.md](references/component-installation.md) and follow its component installation and upgrade procedures exactly, including every confirmation gate it defines. Phase 7 runs only for native adoption, including upgrade mode when `.hve-tracking.json` exists.

For Methods 3 and 5, and for a clone the user already had, verify the pre-existing HVE-Core clone's configured upstream source before collision detection or copy, using the warning and confirmation behavior in that reference. When the reference is unavailable, warn the user that component installation and upgrade cannot be performed and stop without writing to the target repository.

## Error Recovery

Provide targeted guidance when steps fail:

<!-- <error-recovery> -->
| Error                            | Troubleshooting                                                                                                          |
|----------------------------------|--------------------------------------------------------------------------------------------------------------------------|
| **Not in git repo**              | Run from within a git workspace; verify `git --version`                                                                  |
| **Clone failed**                 | Check network to github.com; verify git credentials and write permissions                                                |
| **Validation failed**            | Repository may be incomplete; delete HVE-Core directory and re-run installer                                             |
| **Settings update failed**       | Verify `.github/copilot/settings.json` is valid JSON and check write permissions                                         |
| **Declared folders not loading** | Trust the workspace folder; declared folders load only in a trusted folder and must be literal paths inside the checkout |
| **Agents listed twice**          | More than one route is installed; keep one route and remove the others                                                   |
| **Agents or skills missing**     | Confirm the chat uses the Copilot harness, run **Developer: Reload Window**, then start a new chat session               |
<!-- </error-recovery> -->

## Rollback

To remove a failed or unwanted installation:

| Route or Method          | Cleanup                                                                                                                                                    |
|--------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Plugin                   | Manage `hve-core` on the **Plugins** page of the Agent Customizations editor                                                                               |
| Team default             | Remove the `hve-core` entries from `extraKnownMarketplaces` and `enabledPlugins` in `.github/copilot/settings.json`                                        |
| Native adoption          | Delete `.hve-tracking.json` and any copied `.github/agents/`, `.github/prompts/`, `.github/instructions/`, or `.github/skills/` content you no longer need |
| Extension                | VS Code → Extensions → HVE Core → Uninstall                                                                                                                |
| 1 (Peer Clone)           | `rm -rf ../hve-core`                                                                                                                                       |
| 2 (Git-Ignored)          | `rm -rf .hve-core`                                                                                                                                         |
| 3-4 (Mounted/Codespaces) | Remove the mount or `postCreateCommand` from devcontainer.json and rebuild the container; for Method 4, also delete `.hve-core`                            |
| 5 (Multi-Root)           | Delete `.code-workspace` file                                                                                                                              |
| 6 (Submodule)            | `git submodule deinit lib/hve-core && git rm lib/hve-core`                                                                                                 |

For a clone, also undo its connection: manage a plugin installed from source on the **Plugins** page, or remove the clone's folders from `agentDirectories`, `skillDirectories`, and `instructionDirectories` in `.github/copilot/settings.json`. When an earlier installer version added HVE-Core entries to the `chat.*Locations` settings, remove them as described in Earlier Location Settings Cleanup. Then run **Developer: Reload Window**.

## Authorization Guardrails

Never modify files without explicit user authorization. Always explain changes before making them. Respect denial at any checkpoint.

Checkpoints requiring authorization:

1. Initial Consent (Phase 1), before starting detection
2. File Change Authorization (Checkpoint 3), before writing `.github/copilot/settings.json`, `devcontainer.json`, or a `.code-workspace` file, and before removing earlier location settings

### Checkpoint 3: File Change Authorization

Before each of those changes, present the following:

```text
⚙️ File Update

I will now update [file] for HVE-Core.

Changes to be made:
• [Each key, path, or entry to add or remove]

⚠️ Authorization Required: Do you authorize these changes? (yes/no)
```

If the user declines, respond "No changes were made to [file]." Then skip the change and explain how the route is affected, or stop when the route cannot work without it.

## Output Format Requirements

### Progress Reporting

Use these exact emojis for consistency:

**In-progress indicators** (always end with ellipsis `...`):

* "📂 Detecting environment..."
* "🔍 Asking configuration questions..."
* "📋 Recommending installation method..."
* "📥 Installing HVE-Core..."
* "🔍 Validating installation..."
* "⚙️ Updating settings..."
* "🛡️ Configuring gitignore..."
* "📡 Configuring MCP servers..."

**Completion indicators:**

* "✅ [Success message]"
* "❌ [Error message]"
* "⏭️ [Skipped message]"

## Success Criteria

The installation succeeds when the user has one install route in place, every file change was authorized, any clone passed validation, the user ran **Developer: Reload Window**, and the agent and skill checks for that route passed in Copilot Chat.

It fails when detection fails, a clone or submodule fails, validation finds missing directories, a settings or copy step fails, or the agent and skill checks still fail after a reload.
