---
name: hve-core-installer
description: 'Decision-driven installer for HVE-Core with extension quick-install and 6 clone-based installation methods for local, devcontainer, and Codespaces environments - Brought to you by microsoft/hve-core'
---

# HVE-Core Installer

This skill guides installation of HVE-Core agents, prompts, and instructions into any VS Code workspace. It supports extension quick-install and six clone-based methods covering local, devcontainer, and Codespaces environments.

## Overview

The installer operates through two collaborating personas:

* The **Installer** persona detects the environment, guides method selection, and executes installation steps.
* The **Validator** persona verifies installation success by checking paths, settings, and agent accessibility.

**Re-run behavior:** Running the installer again validates an existing installation or offers an upgrade. Safe to re-run anytime.

## Prerequisites

* **VS Code** with GitHub Copilot enabled.
* **Git** (clone-based methods only). The installer detects availability automatically.
* **jq** (optional). Required by upgrade tracking scripts (`check-file-status.sh`, `eject-file.sh`). Other scripts fall back to `grep`/`sed` when `jq` is absent.

## Required Phases

| Phase | Name                                    | Purpose                                                          |
|-------|-----------------------------------------|------------------------------------------------------------------|
| 1     | Environment Detection                   | Obtain consent and detect user's environment                     |
| 2     | Installation Path Selection             | Choose between Extension (quick) or Clone-based installation     |
| 3     | Environment Detection & Decision Matrix | For clone path: detect environment and recommend method          |
| 4     | Installation Methods                    | Execute the selected installation method                         |
| 5     | Validation                              | Verify installation success and configure settings               |
| 6     | Post-Installation Setup                 | Configure gitignore and present MCP guidance                     |
| 7     | Agent Customization                     | Optional: copy agents for local customization (clone-based only) |

**Flow paths:**

* Extension path: Phase 1 → Phase 2 → Phase 6 → Complete
* Clone-based path: Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7 → Complete

---

## Phase 1: Environment Detection

Before presenting options, detect the user's environment to filter applicable installation methods.

### Checkpoint 1: Initial Consent

Present the following and await explicit consent:

```text
🚀 HVE-Core Installer

I'll help you install HVE-Core agents, prompts, and instructions.

Available content:
• 20+ specialized agents (task-researcher, task-planner, etc.)
• Reusable prompt templates for common workflows
• Technology-specific coding instructions (bash, python, markdown, etc.)

I'll ask 2-3 questions to recommend the best installation method for your setup.

Would you like to proceed?
```

If user declines, respond: "Installation cancelled. Use the `hve-core-installer` Skill anytime to restart."

Upon consent, proceed to Phase 2 to offer the installation path choice.

---

## Phase 2: Installation Path Selection

Present the installation path choice before environment detection. Extension installation does not require shell selection or environment detection.

### Checkpoint 2: Installation Path Choice

Present the following choice:

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

* Need to customize agents, prompts, or instructions
* Team requires version-controlled HVE-Core
* Offline or air-gapped environment

### Prerequisites Check

Before clone-based installation, verify git is available:

* Run: `git --version`
* If fails: "Git is required for clone-based installation. Install git or choose Extension Quick Install."

### Extension Installation Execution

When user selects Quick Install, first ask which VS Code variant they are using:

```text
Which VS Code variant are you using?

  [1] VS Code (stable)
  [2] VS Code Insiders

Your choice? (1/2)
```

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

**Install the extension** using the VS Code command `workbench.extensions.installExtension` with argument `ise-hve-essentials.hve-core`.

After command execution, proceed to Extension Validation.

### Extension Validation

Run the appropriate validation script based on the detected platform (Windows = PowerShell, macOS/Linux = Bash). Use the `code_cli` value from the user's earlier choice:

**Bash:**

```bash
scripts/validate-extension.sh <code_cli>
```

**PowerShell:**

```powershell
scripts/validate-extension.ps1 -CodeCli <code_cli>
```

### Extension Success Report

Upon successful validation, display:

```text
✅ Extension Installation Complete!

The HVE Core extension has been installed from the VS Code Marketplace.

📦 Extension: ise-hve-essentials.hve-core
📌 Version: [detected version]
🔗 Marketplace: https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core

🧪 Available Agents:
• task-researcher, task-planner, task-implementor, task-reviewer
• github-backlog-manager, adr-creation, doc-ops, pr-review
• prompt-builder, memory, and more!

📋 Configuring optional settings...
```

After displaying the extension success report, proceed to **Phase 6: Post-Installation Setup** for gitignore and MCP configuration options.

### Extension Error Recovery

If extension installation fails, provide targeted guidance:

| Error Scenario            | User Message                                                                    | Recovery Action                             |
|---------------------------|---------------------------------------------------------------------------------|---------------------------------------------|
| Trust dialog declined     | "Installation was cancelled. You may have declined the publisher trust prompt." | Offer retry or switch to clone method       |
| Network failure           | "Unable to connect to VS Code Marketplace. Check your network connection."      | Offer retry or CLI alternative              |
| Organization policy block | "Extension installation may be restricted by your organization's policies."     | Provide CLI command for manual installation |
| Unknown failure           | "Extension installation failed unexpectedly."                                   | Offer clone-based installation as fallback  |

**Flow Control After Failure:**

If extension installation fails and user cannot resolve:

* Offer: "Would you like to try a clone-based installation method instead? (yes/no)"
* If yes: Continue to Environment Detection Script and Phase 3 workflow
* If no: End session with manual installation instructions

---

### Environment Detection Script

Run the appropriate detection script based on the user's shell choice:

**Bash:**

```bash
scripts/detect-environment.sh
```

**PowerShell:**

```powershell
scripts/detect-environment.ps1
```

These scripts output key-value pairs: `ENV_TYPE`, `IS_CODESPACES`, `IS_DEVCONTAINER`, `HAS_DEVCONTAINER_JSON`, `HAS_WORKSPACE_FILE`, `IS_HVE_CORE_REPO`.

---

## Phase 3: Environment Detection & Decision Matrix

Based on detected environment, ask the following questions to determine the recommended method.

### Question 1: Environment Confirmation

Present options filtered by detection results:

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

### Question 2: Team or Solo

```text
### Question 2: Team or solo development?

| Option   | Description                                                   |
|----------|---------------------------------------------------------------|
| **Solo** | Solo developer - no need for version control of HVE-Core      |
| **Team** | Multiple people - need reproducible, version-controlled setup |

Are you working solo or with a team? (solo/team)
```

### Question 3: Update Preference

Ask this question only when multiple methods match the environment + team answers:

```text
### Question 3: Update preference?

| Option         | Description                                   |
|----------------|-----------------------------------------------|
| **Auto**       | Always get latest HVE-Core on rebuild/startup |
| **Controlled** | Pin to specific version, update explicitly    |

How would you like to receive updates? (auto/controlled)
```

---

## Decision Matrix

Use this matrix to determine the recommended method:

| Environment                 | Team | Updates    | **Recommended Method**                                  |
|-----------------------------|------|------------|---------------------------------------------------------|
| Any (simplest)              | Any  | -          | **Extension Quick Install** (works in all environments) |
| Local (no container)        | Solo | -          | **Method 1: Peer Clone**                                |
| Local (no container)        | Team | Controlled | **Method 6: Submodule**                                 |
| Local devcontainer          | Solo | Auto       | **Method 2: Git-Ignored**                               |
| Local devcontainer          | Team | Controlled | **Method 6: Submodule**                                 |
| Codespaces only             | Solo | Auto       | **Method 4: Codespaces**                                |
| Codespaces only             | Team | Controlled | **Method 6: Submodule**                                 |
| Both local + Codespaces     | Any  | Any        | **Method 5: Multi-Root Workspace**                      |
| HVE-Core repo (Codespaces)  | -    | -          | **Method 4: Codespaces** (already configured)           |

### Method Selection Logic

After gathering answers:

1. Match answers to decision matrix
2. Present recommendation with rationale
3. Offer alternative if user prefers different approach

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

## Phase 4: Installation Methods

Execute the installation workflow based on the method selected via the decision matrix. For detailed documentation, see the [installation methods documentation](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/).

### Method Configuration

| Method         | Documentation                                                                                                 | Target Location        | Settings Path Prefix   | Best For                       |
|----------------|---------------------------------------------------------------------------------------------------------------|------------------------|------------------------|--------------------------------|
| 1. Peer Clone  | [peer-clone.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/peer-clone.md)   | `../hve-core`          | `../hve-core`          | Local VS Code, solo developers |
| 2. Git-Ignored | [git-ignored.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/git-ignored.md) | `.hve-core/`           | `.hve-core`            | Devcontainer, isolation        |
| 3. Mounted*    | [mounted.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/mounted.md)         | `/workspaces/hve-core` | `/workspaces/hve-core` | Devcontainer + host clone      |
| 4. Codespaces  | [codespaces.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/codespaces.md)   | `/workspaces/hve-core` | `/workspaces/hve-core` | Codespaces                     |
| 5. Multi-Root  | [multi-root.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/multi-root.md)   | Per workspace file     | Per workspace file     | Best IDE integration           |
| 6. Submodule   | [submodule.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/submodule.md)     | `lib/hve-core`         | `lib/hve-core`         | Team version control           |

*Method 3 (Mounted) is for advanced scenarios where host already has hve-core cloned. Most devcontainer users should use Method 2.

### Common Clone Operation

Generate a script for the user's shell (PowerShell or Bash) that:

1. Determines workspace root via `git rev-parse --show-toplevel`
2. Calculates target path based on method from table
3. Checks if target already exists
4. Clones if missing: `git clone https://github.com/microsoft/hve-core.git <target>`
5. Reports success with ✅ or skip with ⏭️

**PowerShell reference:**

```powershell
$ErrorActionPreference = 'Stop'
$hveCoreDir = "<METHOD_TARGET_PATH>"  # Replace per method

if (-not (Test-Path $hveCoreDir)) {
    git clone https://github.com/microsoft/hve-core.git $hveCoreDir
    Write-Host "✅ Cloned HVE-Core to $hveCoreDir"
} else {
    Write-Host "⏭️ HVE-Core already exists at $hveCoreDir"
}
```

**Bash reference:** Use `set -euo pipefail`, `test -d` for existence checks, and `echo` for output.

### Settings Configuration

After cloning, update `.vscode/settings.json` with this structure. Replace `<PREFIX>` with the settings path prefix from the method table:

```json
{
  "chat.agentFilesLocations": {
    ".github/agents": true,
    "<PREFIX>/.github/agents": true
  },
  "chat.promptFilesLocations": {
    ".github/prompts": true,
    "<PREFIX>/.github/prompts": true
  },
  "chat.instructionsFilesLocations": {
    ".github/instructions": true,
    "<PREFIX>/.github/instructions": true
  }
}
```

---

### Method-Specific Instructions

#### Method 1: Peer Clone

Clone to parent directory: `Split-Path $workspaceRoot -Parent | Join-Path -ChildPath "hve-core"`

#### Method 2: Git-Ignored

Additional steps before cloning:

1. Create `.hve-core/` directory
2. Add `.hve-core/` to `.gitignore` (create if missing)
3. Clone into `.hve-core/`

#### Method 3: Mounted Directory

Requires host-side setup and container rebuild:

**Step 1:** Display pre-rebuild instructions:

```text
📋 Pre-Rebuild Setup Required

Clone hve-core on your HOST machine (not in container):
  cd <parent-of-your-project>
  git clone https://github.com/microsoft/hve-core.git
```

**Step 2:** Add mount to devcontainer.json:

```jsonc
{
  "mounts": [
    "source=${localWorkspaceFolder}/../hve-core,target=/workspaces/hve-core,type=bind,readonly=true,consistency=cached"
  ]
}
```

**Step 3:** After rebuild, validate mount exists at `/workspaces/hve-core`

#### Method 4: postCreateCommand (Codespaces)

Add to devcontainer.json:

```jsonc
{
  "postCreateCommand": "[ -d /workspaces/hve-core ] || git clone --depth 1 https://github.com/microsoft/hve-core.git /workspaces/hve-core",
  "customizations": {
    "vscode": {
      "settings": {
        "chat.agentFilesLocations": { "/workspaces/hve-core/.github/agents": true },
        "chat.promptFilesLocations": { "/workspaces/hve-core/.github/prompts": true },
        "chat.instructionsFilesLocations": { "/workspaces/hve-core/.github/instructions": true }
      }
    }
  }
}
```

Optional: Add `updateContentCommand` for auto-updates on rebuild.

#### Method 5: Multi-Root Workspace

Create `hve-core.code-workspace` file with folders array pointing to both project and HVE-Core:

```json
{
  "folders": [
    { "name": "My Project", "path": "." },
    { "name": "HVE-Core Library", "path": "../hve-core" }
  ],
  "settings": { }
}
```

Settings follow the same template with `../hve-core` prefix. User opens the `.code-workspace` file instead of the folder.

#### Method 6: Submodule

Use git submodule commands instead of clone:

```bash
git submodule add https://github.com/microsoft/hve-core.git lib/hve-core
git submodule update --init --recursive
git add .gitmodules lib/hve-core
git commit -m "Add HVE-Core as submodule"
```

Team members run `git submodule update --init --recursive` after cloning.

Optional devcontainer.json for auto-initialization:

```jsonc
{
  "onCreateCommand": "git submodule update --init --recursive",
  "updateContentCommand": "git submodule update --remote lib/hve-core || true"
}
```

---

## Phase 5: Validation (Validator Persona)

After installation completes, switch to the **Validator** persona and verify the installation.

> [!IMPORTANT]
> After successful validation, proceed to Phase 6 for post-installation setup, then Phase 7 for optional agent customization (clone-based methods only).

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

Run validation based on the selected method:

| Method | Base Path              |
|--------|------------------------|
| 1      | `../hve-core`          |
| 2      | `.hve-core`            |
| 3, 4   | `/workspaces/hve-core` |
| 5      | Check workspace file   |
| 6      | `lib/hve-core`         |

**Bash:**

```bash
scripts/validate-installation.sh <method> <base_path>
```

**PowerShell:**

```powershell
scripts/validate-installation.ps1 -Method <method> -BasePath <base_path>
```

### Success Report

Upon successful validation, display:

```text
✅ Core Installation Complete!

Method [N]: [Name] installed successfully.

📍 Location: [path based on method]
⚙️ Settings: [settings file or workspace file]
📖 Documentation: https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/[method-doc].md

🧪 Available Agents:
• task-researcher, task-planner, task-implementor, task-reviewer
• github-backlog-manager, adr-creation, doc-ops, pr-review
• prompt-builder, memory, and more!

📋 Configuring optional settings...
```

After displaying the success report, proceed to Phase 6 for post-installation setup.

---

## Phase 6: Post-Installation Setup

This phase applies to all installation methods (Extension and Clone-based). Both paths converge here for consistent post-installation configuration.

### Checkpoint 4: Gitignore Configuration

Check and configure gitignore entries based on the installation method.

#### Method-Specific Gitignore Entries

| Method          | Gitignore Entry      | Reason                            |
|-----------------|----------------------|-----------------------------------|
| 2 (Git-Ignored) | `.hve-core/`         | Excludes the local HVE-Core clone |
| All methods     | `.copilot-tracking/` | Excludes AI workflow artifacts    |

**Detection:** Check if `.gitignore` exists and contains the required entries.

**For Method 2 (Git-Ignored):** If `.hve-core/` is not in `.gitignore`, it should have been added during Phase 4 installation. Verify it exists.

**For all methods:** Check if `.copilot-tracking/` should be added to `.gitignore`. This directory stores local AI workflow artifacts that are typically user-specific and not meant for version control.

* If pattern found → Skip this checkpoint silently
* If `.gitignore` missing or pattern not found → Present the prompt below

```text
📋 Gitignore Recommendation

The `.copilot-tracking/` directory stores local AI workflow artifacts:
• Plans and implementation tracking
• Research notes and change records
• User-specific prompts and handoff logs

These files are typically not meant for version control.

Would you like to add `.copilot-tracking/` to your .gitignore? (yes/no)
```

User input handling:

* "yes", "y" → Add entry to `.gitignore`
* "no", "n", "skip" → Skip without changes
* Unclear response → Ask for clarification

**Modification:** If user approves:

* If `.gitignore` exists: Append the following at the end of the file
* If `.gitignore` missing: Create it with the content below

```text
# HVE-Core AI workflow artifacts (local only)
.copilot-tracking/
```

Report: "✅ Added `.copilot-tracking/` to .gitignore"

After the gitignore checkpoint, proceed to Checkpoint 5 (MCP Configuration).

### Checkpoint 5: MCP Configuration Guidance

After the gitignore checkpoint (for **any** installation method), present MCP configuration guidance:

```text
📡 MCP Server Configuration (Optional)

Some HVE-Core agents integrate with external services via MCP (Model Context Protocol):

| Agent                  | MCP Server               | Purpose                   |
|------------------------|--------------------------|---------------------------|
| ado-prd-to-wit         | ado                      | Azure DevOps work items   |
| github-backlog-manager | github                   | GitHub backlog management |
| task-researcher        | context7, microsoft-docs | Documentation lookup      |

Would you like to configure MCP servers? (yes/no)
```

User input handling:

* "yes", "y" → Ask which servers to configure (see MCP Server Selection below)
* "no", "n", "skip" → Proceed to Final Completion Report
* Enter, "continue", "done" → Proceed to Final Completion Report
* Unclear response → Proceed to Final Completion Report (non-blocking)

### MCP Server Selection

If user chooses to configure MCP, present:

```text
Which MCP servers would you like to configure?

| Server         | Purpose                   | Recommended For            |
|----------------|---------------------------|----------------------------|
| github         | GitHub issues and repos   | GitHub-hosted repositories |
| ado            | Azure DevOps work items   | Azure DevOps repositories  |
| context7       | SDK/library documentation | All users (optional)       |
| microsoft-docs | Microsoft Learn docs      | All users (optional)       |

⚠️ Suggest EITHER github OR ado based on where your repo is hosted, not both.

Enter server names separated by commas (e.g., "github, context7"):
```

Parse the user's response to determine which servers to include.

### MCP Configuration Templates

Create `.vscode/mcp.json` using ONLY the templates below. Use HTTP type with managed authentication where available.

> [!IMPORTANT]
> These are the only correct configurations. Do not use stdio/npx for servers that support HTTP.

#### github server (HTTP with managed auth)

```json
{
  "github": {
    "type": "http",
    "url": "https://api.githubcopilot.com/mcp/"
  }
}
```

#### ado server (stdio with inputs)

```json
{
  "inputs": [
    {
      "id": "ado_org",
      "type": "promptString",
      "description": "Azure DevOps organization name (e.g. 'contoso')",
      "default": ""
    },
    {
      "id": "ado_tenant",
      "type": "promptString",
      "description": "Azure tenant ID (required for multi-tenant scenarios)",
      "default": ""
    }
  ],
  "servers": {
    "ado": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@azure-devops/mcp", "${input:ado_org}", "--tenant", "${input:ado_tenant}", "-d", "core", "work", "work-items", "search", "repositories", "pipelines"]
    }
  }
}
```

#### context7 server (stdio)

```json
{
  "context7": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@upstash/context7-mcp"]
  }
}
```

#### microsoft-docs server (HTTP)

```json
{
  "microsoft-docs": {
    "type": "http",
    "url": "https://learn.microsoft.com/api/mcp"
  }
}
```

### MCP File Generation

When creating `.vscode/mcp.json`:

1. Create `.vscode/` directory if it does not exist
2. Combine only the selected server configurations into a single JSON object
3. Include `inputs` array only if `ado` server is selected
4. Merge all selected servers under a single `servers` object

Example combined configuration for "github, context7":

```json
{
  "servers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/"
    },
    "context7": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    }
  }
}
```

After creating the file, display:

```text
✅ Created .vscode/mcp.json with [server names] configuration

📖 Full documentation: https://github.com/microsoft/hve-core/blob/main/docs/getting-started/mcp-configuration.md
```

### Final Completion Report

After gitignore and MCP checkpoints complete, display the final completion message:

```text
✅ Setup Complete!

▶️ Next Steps:
1. Reload VS Code (Ctrl+Shift+P → "Reload Window")
2. Open Copilot Chat (`Ctrl+Alt+I`) and click the agent picker dropdown
3. Select an agent to start working

💡 Select `task-researcher` from the picker to explore HVE-Core capabilities
```

For **Extension** installations, also include:

```text
---
📝 Want to customize HVE-Core or share with your team?
Run this skill again and choose "Clone-Based Installation" for full customization options.
```

For **Clone-based** installations, proceed to Phase 7 for optional agent customization.

---

## Phase 7: Agent Customization (Optional)

> [!IMPORTANT]
> Generated scripts in this phase require PowerShell 7+ (`pwsh`). Windows PowerShell 5.1 is not supported.

After Phase 6 completes, offer users the option to copy agent files into their target repository. This phase ONLY applies to clone-based installation methods (1-6), NOT to extension installation.

### Skip Condition

If user selected **Extension Quick Install** (Option 1) in Phase 2, skip Phase 7 entirely. Extension installation bundles agents automatically.

### Checkpoint 6: Agent Copy Decision

Present the agent selection prompt:

```text
📂 Agent Customization (Optional)

HVE-Core includes specialized agents for common workflows.
Copying agents enables local customization and offline use.

🔬 RPI Core (Research-Plan-Implement workflow)
  • task-researcher - Technical research and evidence gathering
  • task-planner - Implementation plan creation
  • task-implementor - Plan execution with tracking
  • rpi-agent - RPI workflow coordinator

📋 Planning & Documentation
  • adr-creation, brd-builder, doc-ops, prd-builder, security-plan-creator

⚙️ Generators
  • arch-diagram-builder, gen-data-spec, gen-jupyter-notebook, gen-streamlit-dashboard

✅ Review & Testing
  • pr-review, prompt-builder, task-reviewer, test-streamlit-dashboard

🧠 Utilities
  • memory - Conversation memory and session continuity

🔗 Platform-Specific
  • ado-prd-to-wit (Azure DevOps)
  • github-backlog-manager (GitHub)

Options:
  [1] Install RPI Core only (recommended)
  [2] Install by collection
  [3] Skip agent installation

Your choice? (1/2/3)
```

User input handling:

* "1", "rpi", "rpi core", "core" → Copy RPI Core bundle only
* "2", "collection", "by collection" → Proceed to Collection Selection sub-flow
* "3", "skip", "none", "no" → Skip to success report
* Unclear response → Ask for clarification

### Collection Selection Sub-Flow

When the user selects option 2, read collection manifests to present available collections.

#### Step 1: Read collections and build collection agent counts

Read `collections/*.collection.yml` from the HVE-Core source (at `$hveCoreBasePath`). Derive collection options from collection `id` and `name`. For each selected collection, count agent items where `kind` equals `agent` and effective item maturity is `stable` (item `maturity` omitted defaults to `stable`; exclude `experimental` and `deprecated`).

#### Step 2: Present collection options

```text
🎭 Collection Selection

Choose one or more collections to install agents tailored to your role, more to come in the future.

| # | Collection | Agents | Description                     |
|---|------------|--------|---------------------------------|
| 1 | Developer  | [N]    | Software engineers writing code |

Enter collection number(s) separated by commas (e.g., "1"):
```

Agent counts `[N]` include agents matching the collection with `stable` maturity.

User input handling:

* Single number (e.g., "1") → Select that collection
* Multiple numbers (e.g., "1, 3") → Combine agent sets from selected collections
* Collection name (e.g., "developer") → Match by identifier
* Unclear response → Ask for clarification

#### Step 3: Build filtered agent list

For each selected collection identifier:

1. Iterate through `items` in the collection manifest
2. Include items where `kind` is `agent` AND `maturity` is `stable`
3. Deduplicate across multiple selected collections

#### Step 4: Present filtered agents for confirmation

```text
📋 Agents for [Collection Name(s)]

The following [N] agents will be copied:

  • [agent-name-1] - tags: [tag-1, tag-2]
  • [agent-name-2] - tags: [tag-1, tag-2]
  ...

Proceed with installation? (yes/no)
```

User input handling:

* "yes", "y" → Proceed with copy using filtered agent list
* "no", "n" → Return to Checkpoint 6 for re-selection
* Unclear response → Ask for clarification

> [!NOTE]
> Collection filtering applies to agents only. Copying of related prompts, instructions, and skills based on collection is planned for a future release.

### Agent Bundle Definitions

| Bundle            | Agents                                                                   |
|-------------------|--------------------------------------------------------------------------|
| `rpi-core`        | task-researcher, task-planner, task-implementor, task-reviewer, rpi-agent |
| `collection:<id>` | Stable agents matching the collection                                    |

### Collision Detection

Before copying, check for existing agent files with matching names.

**Bash:**

```bash
scripts/detect-collision.sh <selection> <hve_core_base_path> [agent_file ...]
```

**PowerShell:**

```powershell
scripts/detect-collision.ps1 -Selection <selection> -HveCoreBasePath <path> [-CollectionAgents <files>]
```

### Collision Resolution Prompt

If collisions are detected, present:

```text
⚠️ Existing Agents Detected

The following agents already exist in your project:
  • [list collision files]

Options:
  [O] Overwrite with HVE-Core version
  [K] Keep existing (skip these files)
  [C] Compare (show diff for first file)

Or for all conflicts:
  [OA] Overwrite all
  [KA] Keep all existing

Your choice?
```

User input handling:

* "o", "overwrite" → Overwrite current file, ask about next
* "k", "keep" → Keep current file, ask about next
* "c", "compare" → Show diff, then re-prompt
* "oa", "overwrite all" → Overwrite all collisions
* "ka", "keep all" → Keep all existing files

### Agent Copy Execution

After selection and collision resolution, run the copy script:

**Bash:**

```bash
scripts/copy-agents.sh <selection> <hve_core_base_path> <collection_id> [--keep-existing] [agent_file ...]
```

**PowerShell:**

```powershell
scripts/copy-agents.ps1 -Selection <selection> -HveCoreBasePath <path> -CollectionId <id> [-KeepExisting] [-CollectionAgents <files>]
```

The script creates `.github/agents/` if needed, copies files, computes SHA256 hashes, and writes `.hve-tracking.json` for upgrade tracking.

### Agent Copy Success Report

Upon successful copy, display:

```text
✅ Agent Installation Complete!

Copied [N] agents to .github/agents/
Created .hve-tracking.json for upgrade tracking

📄 Installed Agents:
  • [list of copied agent names]

🔄 Upgrade Workflow:
  Run this installer again to check for agent updates.
  Modified files will prompt before overwriting.
  Use 'eject' to take ownership of any file.

Proceeding to final success report...
```

---

## Phase 7 Upgrade Mode

When `.hve-tracking.json` already exists, Phase 7 operates in upgrade mode.

### Upgrade Detection

At Phase 7 start, check for existing manifest:

**Bash:**

```bash
scripts/detect-upgrade.sh <hve_core_base_path>
```

**PowerShell:**

```powershell
scripts/detect-upgrade.ps1 -HveCoreBasePath <path>
```

### Upgrade Prompt

If upgrade mode with version change:

```text
🔄 HVE-Core Agent Upgrade

Source: microsoft/hve-core v[SOURCE_VERSION]
Installed: v[INSTALLED_VERSION]

Checking file status...
```

### File Status Check

Compare current files against manifest:

**Bash:**

```bash
scripts/check-file-status.sh
```

**PowerShell:**

```powershell
scripts/check-file-status.ps1
```

### Upgrade Summary Display

Present upgrade summary:

```text
📋 Upgrade Summary

Files to update (managed):
  ✅ .github/agents/task-researcher.agent.md
  ✅ .github/agents/task-planner.agent.md

Files requiring decision (modified):
  ⚠️ .github/agents/task-implementor.agent.md

Files skipped (ejected):
  🔒 .github/agents/custom-agent.agent.md

For modified files, choose:
  [A] Accept upstream (overwrite your changes)
  [K] Keep local (skip this update)
  [E] Eject (never update this file again)
  [D] Show diff

Process file: task-implementor.agent.md?
```

### Diff Display

When user requests diff:

```text
─────────────────────────────────────
File: .github/agents/task-implementor.agent.md
Status: modified
─────────────────────────────────────

--- Local version
+++ HVE-Core version

@@ -10,3 +10,5 @@
 ## Role Definition

-Your local modifications here
+Updated behavior with new capabilities
+
+New section added in latest version
─────────────────────────────────────

[A] Accept upstream / [K] Keep local / [E] Eject
```

### Status Transitions

After user decision, update manifest:

| Decision | Status Change           | Manifest Update           |
|----------|-------------------------|---------------------------|
| Accept   | `modified` → `managed`  | Update hash, version      |
| Keep     | `modified` → `modified` | No change (skip file)     |
| Eject    | `*` → `ejected`         | Add `ejectedAt` timestamp |

### Eject Implementation

When user ejects a file:

**Bash:**

```bash
scripts/eject-file.sh <file_path>
```

**PowerShell:**

```powershell
scripts/eject-file.ps1 -FilePath <file_path>
```

### Upgrade Completion

After processing all files:

```text
✅ Upgrade Complete!

Updated: [N] files
Skipped: [M] files (kept local or ejected)
Version: v[OLD] → v[NEW]

Proceeding to final success report...
```

---

## Scripts Reference

All scripts live under `scripts/` relative to this skill directory.

| Script                   | Bash                       | PowerShell                    | Purpose                                  |
|--------------------------|----------------------------|-------------------------------|------------------------------------------|
| Environment detection    | `detect-environment.sh`    | `detect-environment.ps1`     | Detect local, devcontainer, or Codespaces |
| Extension validation     | `validate-extension.sh`    | `validate-extension.ps1`    | Verify extension installation             |
| Installation validation  | `validate-installation.sh` | `validate-installation.ps1` | Verify clone-based installation           |
| Collision detection      | `detect-collision.sh`      | `detect-collision.ps1`      | Find existing agent files before copy     |
| Agent copy               | `copy-agents.sh`           | `copy-agents.ps1`           | Copy agents and create tracking manifest  |
| Upgrade detection        | `detect-upgrade.sh`        | `detect-upgrade.ps1`        | Check manifest version against source     |
| File status check        | `check-file-status.sh`     | `check-file-status.ps1`     | Compare files against manifest hashes     |
| Eject file               | `eject-file.sh`            | `eject-file.ps1`            | Remove file from upgrade tracking         |

---

## Error Recovery

Provide targeted guidance when steps fail:

| Error                      | Troubleshooting                                                              |
|----------------------------|------------------------------------------------------------------------------|
| **Not in git repo**        | Run from within a git workspace; verify `git --version`                      |
| **Clone failed**           | Check network to github.com; verify git credentials and write permissions    |
| **Validation failed**      | Repository may be incomplete; delete HVE-Core directory and re-run installer |
| **Settings update failed** | Verify settings.json is valid JSON; check permissions; try closing VS Code   |

---

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

If you used Phase 7 agent copy, also delete `.hve-tracking.json` and optionally `.github/agents/` if you no longer need copied agents.

---

## Authorization Guardrails

Never modify files without explicit user authorization. Always explain changes before making them. Respect denial at any checkpoint.

### Agent Reference Guidelines

**Never** use `@` syntax when referring to agents. The `@` prefix does NOT work for agents in VS Code.

**Always** instruct users to:

* Open GitHub Copilot Chat (`Ctrl+Alt+I`)
* Click the **agent picker dropdown** in the chat pane
* Select the agent from the list

**Correct:** "Select `task-researcher` from the agent picker dropdown"
**Incorrect:** ~~"Type @task-researcher"~~ or ~~"Run @task-researcher"~~

Checkpoints requiring authorization:

1. Initial Consent (Phase 1) - before starting detection
2. Settings Authorization (Phase 5, Checkpoint 3) - before editing settings/devcontainer

---

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

---

## Success Criteria

**Success:** Environment detected, method selected, HVE-Core directories validated (agents, prompts, instructions), settings configured, user directed to reload.

**Failure:** Detection fails, clone/submodule fails, validation finds missing directories, or settings modification fails.

> Brought to you by microsoft/hve-core
