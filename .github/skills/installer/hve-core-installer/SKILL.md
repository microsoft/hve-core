---
name: hve-core-installer
description: 'Decision-driven HVE-Core installer with multiple clone-based and extension install methods, environment detection, and selective component installation'
compatibility: 'Requires VS Code or VS Code Insiders. Clone-based methods require git on PATH and network access. The Bash component scripts require jq.'
license: MIT
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-08-09"
---

# HVE-Core Installer Skill

Decision-driven installer for HVE-Core with environment detection, 6 clone-based installation methods, extension quick-install, validation, MCP configuration, and selective component installation workflows.

## Role Definition

Operate as two collaborating personas:

* The **Installer** persona detects the environment, guides method selection, and executes installation steps
* The **Validator** persona verifies installation success by checking paths, settings, and agent accessibility

The Installer persona handles all detection and execution. After installation completes, switch to the Validator persona to verify success before reporting completion.

**Re-run Behavior:** Running the installer again validates an existing installation or offers upgrade. Safe to re-run anytime.

## Required Phases

| Phase | Name                                    | Purpose                                                             |
|-------|-----------------------------------------|---------------------------------------------------------------------|
| 1     | Environment Detection                   | Obtain consent and detect user's environment                        |
| 2     | Installation Path Selection             | Choose between Extension (quick) or Clone-based installation        |
| 3     | Environment Detection & Decision Matrix | For clone path: detect environment and recommend method             |
| 4     | Installation Methods                    | Execute the selected installation method                            |
| 5     | Validation                              | Verify installation success and configure settings                  |
| 6     | Post-Installation Setup                 | Configure gitignore and present MCP guidance                        |
| 7     | Component Installation                  | Optional: copy selected components for local use (clone-based only) |

**Flow paths:**

* Extension path: Phase 1 → Phase 2 → Phase 6 → Complete
* Clone-based path: Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7 → Complete

## Phase 1: Environment Detection

Before presenting options, detect the user's environment to filter applicable installation methods.

### Checkpoint 1: Initial Consent

Present the following and await explicit consent:

```text
🚀 HVE-Core Installer

I'll help you install HVE-Core agents, prompts, instructions and skills.

Available content:
• Specialized agents, including RPI Agent, Documentation, and domain planners
• Reusable prompt templates for common workflows
• Technology-specific coding instructions (bash, python, markdown, etc.)
• Domain-specific skills (pr-reference, etc.)

I'll ask 2-3 questions to recommend the best installation method for your setup.

Would you like to proceed?
```

If user declines, respond: "Installation cancelled. You can invoke this skill anytime to restart."

Upon consent, proceed to Phase 2 to offer the installation path choice.

## Phase 2: Installation Path Selection

Present the installation path choice before environment detection. Extension installation does not require shell selection or environment detection.

### Checkpoint 2: Installation Path Choice

Present the following choice:

<!-- <extension-quick-install-checkpoint> -->
```text
🚀 Choose Your Installation Path

**Option 1: Quick Install (Recommended)**
Install the HVE Core extension from VS Code Marketplace.
• ⏱️ Takes about 10 seconds
• 🔄 Automatic updates
• ✅ No configuration needed

**Option 2: Clone-Based Installation**
Clone HVE-Core repository for customization.
• 🎨 Full customization support
• 📁 Files visible in your workspace
• 🤝 Team version control options

Which would you prefer? (1/2 or quick/clone)
```
<!-- </extension-quick-install-checkpoint> -->

User input handling:

* "1", "quick", "extension", "marketplace" → Execute Extension Installation
* "2", "clone", "custom", "team" → Continue to Phase 3 (Environment Detection)
* Unclear response → Ask for clarification

If user selects Option 1 (Quick Install):

1. Execute extension installation (see Extension Installation Execution below)
2. Validate installation success
3. Display success report or offer fallback options

If user selects Option 2 (Clone-Based):

* Ask: "Which shell would you prefer? (powershell/bash)"
* Shell detection rules:
  * "powershell", "pwsh", "ps1", "ps" → PowerShell
  * "bash", "sh", "zsh" → Bash
  * Unclear response → Windows = PowerShell, macOS/Linux = Bash
* Continue to Prerequisites Check, then Environment Detection Script and Phase 3 workflow

**When to choose Clone over Extension:**

* Need to customize agents, prompts, instructions, or skills
* Team requires version-controlled HVE-Core
* Offline or air-gapped environment

### Prerequisites Check

Before clone-based installation, verify git is available:

* Run: `git --version`
* If fails: "Git is required for clone-based installation. Install git or choose Extension Quick Install."

When the user selects Bash, also verify `jq` is available:

* Run: `jq --version`
* If fails: "jq is required by the Bash component scripts. Install jq or choose PowerShell."

### Extension Installation Execution

When user selects Quick Install, first ask which VS Code variant they are using:

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
• rpi-agent, documentation, github-backlog-manager, and adr-creation
• code-review, security-planner, ux-ui-designer, and more!

🪝 Hooks (manual step): The Marketplace extension is declarative and does not
   write chat.hookFilesLocations. To enable bundled hooks (e.g. telemetry), add
   each package's hook folder to that setting yourself, or use a clone-based
   or CLI-plugin install which documents this configuration.

📋 Configuring optional settings...
```
<!-- </extension-success-report> -->

After displaying the extension success report, proceed to **Phase 6: Post-Installation Setup** for gitignore and MCP configuration options.

### Extension Error Recovery

If extension installation fails, provide targeted guidance:

<!-- <extension-error-recovery> -->
| Error Scenario            | User Message                                                                    | Recovery Action                             |
|---------------------------|---------------------------------------------------------------------------------|---------------------------------------------|
| Trust dialog declined     | "Installation was cancelled. You may have declined the publisher trust prompt." | Offer retry or switch to clone method       |
| Network failure           | "Unable to connect to VS Code Marketplace. Check your network connection."      | Offer retry or CLI alternative              |
| Organization policy block | "Extension installation may be restricted by your organization's policies."     | Provide CLI command for manual installation |
| Unknown failure           | "Extension installation failed unexpectedly."                                   | Offer clone-based installation as fallback  |
<!-- </extension-error-recovery> -->

**Flow Control After Failure:**

If extension installation fails and user cannot resolve:

* Offer: "Would you like to try a clone-based installation method instead? (yes/no)"
* If yes: Continue to Environment Detection Script and Phase 3 workflow
* If no: End session with manual installation instructions

### Environment Detection Script

Run the appropriate detection script based on the user's shell:

**PowerShell:** Run [scripts/detect-environment.ps1](scripts/detect-environment.ps1)

**Bash:** Run [scripts/detect-environment.sh](scripts/detect-environment.sh)

## Phase 3: Environment Detection & Decision Matrix

Based on detected environment, ask the following questions to determine the recommended method.

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

Use this matrix to determine the recommended method:

<!-- <decision-matrix> -->
| Environment                | Team | Updates    | **Recommended Method**                                  |
|----------------------------|------|------------|---------------------------------------------------------|
| Any (simplest)             | Any  | -          | **Extension Quick Install** (works in all environments) |
| Local (no container)       | Solo | -          | **Method 1: Peer Clone**                                |
| Local (no container)       | Team | Controlled | **Method 6: Submodule**                                 |
| Local devcontainer         | Solo | Auto       | **Method 2: Git-Ignored**                               |
| Local devcontainer         | Team | Controlled | **Method 6: Submodule**                                 |
| Codespaces only            | Solo | Auto       | **Method 4: Codespaces**                                |
| Codespaces only            | Team | Controlled | **Method 6: Submodule**                                 |
| Both local + Codespaces    | Any  | Any        | **Method 5: Multi-Root Workspace**                      |
| HVE-Core repo (Codespaces) | -    | -          | **Method 4: Codespaces** (already configured)           |
<!-- </decision-matrix> -->

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

Would you like to proceed with this method, or see alternatives?
```
<!-- </recommendation-template> -->

## Phase 4: Installation Methods

Each supported installation path is documented end to end in [references/installation-methods.md](references/installation-methods.md). Select the path resolved by the decision matrix above and follow it there. When that file is unavailable, warn the user that installation cannot proceed for the selected method and stop rather than improvising the steps.

## Phase 5: Validation (Validator Persona)

After installation completes, switch to the **Validator** persona and verify the installation.

> [!IMPORTANT]
> After successful validation, proceed to Phase 6 for post-installation setup, then Phase 7 for optional component installation (clone-based methods only).

### Checkpoint 3: Settings Authorization

Before modifying settings.json, present the following:

```text
⚙️ VS Code Settings Update

I will now update your VS Code settings to add HVE-Core paths.

Changes to be made:
• [List paths based on selected method]

⚠️ Authorization Required: Do you authorize these settings changes? (yes/no)
```

If user declines: "Installation cancelled. No settings changes were made."

### Validation Workflow

Run validation based on the selected method. Set the base path variable before running:

| Method | Base Path              |
|--------|------------------------|
| 1      | `../hve-core`          |
| 2      | `.hve-core`            |
| 3, 4   | `/workspaces/hve-core` |
| 5      | Check workspace file   |
| 6      | `lib/hve-core`         |

**PowerShell:** Run [scripts/validate-installation.ps1](scripts/validate-installation.ps1) with the `method` and `basePath` variables set.

**Bash:** Run [scripts/validate-installation.sh](scripts/validate-installation.sh) with the method number and base path as arguments.

### Success Report

Upon successful validation, display:

<!-- <success-report> -->
```text
✅ Core Installation Complete!

Method [N]: [Name] installed successfully.

📍 Location: [path based on method]
⚙️ Settings: [settings file or workspace file]
📖 Documentation: https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/[method-doc].md

🧪 Available Agents:
• rpi-agent, documentation, github-backlog-manager, and adr-creation
• code-review, security-planner, ux-ui-designer, and more!

📋 Configuring optional settings...
```
<!-- </success-report> -->

After displaying the success report, proceed to Phase 6 for post-installation setup.

## Phase 6: Post-Installation Setup

Read [references/post-installation-setup.md](references/post-installation-setup.md) and perform every step it specifies before continuing. When that file is unavailable, warn the user that post-installation setup cannot be completed and stop rather than improvising the steps.

## Phase 7: Component Installation and Upgrade

Read [references/component-installation.md](references/component-installation.md) and follow its component installation and upgrade procedures exactly, including every confirmation gate it defines. When that file is unavailable, warn the user that component installation and upgrade cannot be performed and stop without writing to the target repository.

## Error Recovery

Provide targeted guidance when steps fail:

<!-- <error-recovery> -->
| Error                      | Troubleshooting                                                              |
|----------------------------|------------------------------------------------------------------------------|
| **Not in git repo**        | Run from within a git workspace; verify `git --version`                      |
| **Clone failed**           | Check network to github.com; verify git credentials and write permissions    |
| **Validation failed**      | Repository may be incomplete; delete HVE-Core directory and re-run installer |
| **Settings update failed** | Verify settings.json is valid JSON; check permissions; try closing VS Code   |
<!-- </error-recovery> -->

## Rollback

To remove a failed or unwanted installation:

| Method                   | Cleanup                                                    |
|--------------------------|------------------------------------------------------------|
| Extension                | VS Code → Extensions → HVE Core → Uninstall                |
| 1 (Peer Clone)           | `rm -rf ../hve-core`                                       |
| 2 (Git-Ignored)          | `rm -rf .hve-core`                                         |
| 3-4 (Mounted/Codespaces) | Remove mount/postCreate from devcontainer.json             |
| 5 (Multi-Root)           | Delete `.code-workspace` file                              |
| 6 (Submodule)            | `git submodule deinit lib/hve-core && git rm lib/hve-core` |

Then remove HVE-Core paths from `.vscode/settings.json`.

If you used Phase 7 component installation, also delete `.hve-tracking.json` and any copied `.github/agents/`, `.github/prompts/`, `.github/instructions/`, or `.github/skills/` content you no longer need.

## Authorization Guardrails

Never modify files without explicit user authorization. Always explain changes before making them. Respect denial at any checkpoint.

Checkpoints requiring authorization:

1. Initial Consent (Phase 1) - before starting detection
2. Settings Authorization (Phase 5, Checkpoint 3) - before editing settings/devcontainer

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

**Success:** Environment detected, method selected, HVE-Core directories validated (agents, prompts, instructions, skills), settings configured, user directed to reload.

**Failure:** Detection fails, clone/submodule fails, validation finds missing directories, or settings modification fails.
