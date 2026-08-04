---
name: hve-core-installer
description: 'Decision-driven HVE-Core installer with multiple clone-based and extension install methods, environment detection, and selective component installation'
compatibility: 'Requires VS Code or VS Code Insiders. Clone-based methods require git on PATH and network access. The Bash component scripts require jq.'
license: MIT
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-08-03"
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

Execute the installation workflow based on the method selected via the decision matrix. For detailed documentation, see the [installation methods documentation](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/).

### Method Configuration

| Method         | Documentation                                                                                                 | Target Location        | Settings Path Prefix   | Best For                            |
|----------------|---------------------------------------------------------------------------------------------------------------|------------------------|------------------------|-------------------------------------|
| 1. Peer Clone  | [peer-clone.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/peer-clone.md)   | `../hve-core`          | `../hve-core`          | Local VS Code, solo developers      |
| 2. Git-Ignored | [git-ignored.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/git-ignored.md) | `.hve-core/`           | `.hve-core`            | Devcontainer, isolation             |
| 3. Mounted*    | [mounted.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/mounted.md)         | `/workspaces/hve-core` | `/workspaces/hve-core` | Devcontainer + host clone           |
| 4. Codespaces  | [codespaces.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/codespaces.md)   | `/workspaces/hve-core` | `/workspaces/hve-core` | Codespaces                          |
| 5. Multi-Root  | [multi-root.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/multi-root.md)   | Per workspace file     | Actual clone path      | Local VS Code, best IDE integration |
| 6. Submodule   | [submodule.md](https://github.com/microsoft/hve-core/blob/main/docs/getting-started/methods/submodule.md)     | `lib/hve-core`         | `lib/hve-core`         | Team version control                |

*Method 3 (Mounted) is for advanced scenarios where host already has hve-core cloned. Most devcontainer users should use Method 2.

### Common Clone Operation

Generate a script for the user's shell (PowerShell or Bash) that:

1. Determines workspace root via `git rev-parse --show-toplevel`
2. Calculates target path based on method from table
3. Checks if target already exists
4. Clones if missing: `git clone https://github.com/microsoft/hve-core.git <target>`
5. Reports success with ✅ or skip with ⏭️

<!-- <clone-reference-powershell> -->
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
<!-- </clone-reference-powershell> -->

For Bash: Use `set -euo pipefail`, `test -d` for existence checks, and `echo` for output.

### Settings Configuration

After cloning, update `.vscode/settings.json` with entries for each package subdirectory. Replace `<PREFIX>` with the settings path prefix from the method table. Do not use `**` glob patterns in paths because `chat.*Locations` settings do not support them.

Enumerate each package subdirectory under `.github/agents/`, `.github/prompts/`, `.github/instructions/`, and `.github/hooks/` from the cloned HVE-Core directory. Create one entry per subdirectory. For `.github/agents/`, also check each package folder for a `subagents/` subfolder and include it when present (e.g., `hve-core/subagents`). For `.github/skills/`, list only the package-level folders directly under `.github/skills/` (e.g., `shared`); do not enumerate deeper subfolders (individual skill directories like `shared/pr-reference/` are not listed). For `.github/hooks/`, list only the package-level folders directly under `.github/hooks/` (e.g., `shared`); the default `chat.hookFilesLocations` value only covers the workspace `.github/hooks`, so clone-based installs must add each package's hook folder explicitly. Exclude the `installer` package from `chat.agentSkillsLocations` because it is the installer skill itself and not intended for end-user settings.

Any folder named `experimental` under any artifact type (agents, prompts, instructions, or skills) must not be included without first asking the user whether they want experimental features. If the user opts in, add the `experimental` entries (and `experimental/subagents` for agents when that subfolder exists).

<!-- <settings-template> -->
```json
{
  "chat.agentFilesLocations": {
    "<PREFIX>/.github/agents/ado": true,
    "<PREFIX>/.github/agents/coding-standards": true,
    "<PREFIX>/.github/agents/data-science": true,
    "<PREFIX>/.github/agents/design-thinking": true,
    "<PREFIX>/.github/agents/github": true,
    "<PREFIX>/.github/agents/hve-core": true,
    "<PREFIX>/.github/agents/hve-core/subagents": true,
    "<PREFIX>/.github/agents/project-planning": true,
    "<PREFIX>/.github/agents/security": true
  },
  "chat.promptFilesLocations": {
    "<PREFIX>/.github/prompts/ado": true,
    "<PREFIX>/.github/prompts/coding-standards": true,
    "<PREFIX>/.github/prompts/design-thinking": true,
    "<PREFIX>/.github/prompts/github": true,
    "<PREFIX>/.github/prompts/hve-core": true,
    "<PREFIX>/.github/prompts/security": true
  },
  "chat.instructionsFilesLocations": {
    "<PREFIX>/.github/instructions/ado": true,
    "<PREFIX>/.github/instructions/coding-standards": true,
    "<PREFIX>/.github/instructions/github": true,
    "<PREFIX>/.github/instructions/hve-core": true,
    "<PREFIX>/.github/instructions/shared": true
  },
  "chat.agentSkillsLocations": {
    "<PREFIX>/.github/skills": true,
    "<PREFIX>/.github/skills/coding-standards": true,
    "<PREFIX>/.github/skills/design-thinking": true,
    "<PREFIX>/.github/skills/project-planning": true,
    "<PREFIX>/.github/skills/rai": true,
    "<PREFIX>/.github/skills/security": true,
    "<PREFIX>/.github/skills/shared": true
  },
  "chat.hookFilesLocations": {
    "<PREFIX>/.github/hooks/shared": true
  }
}
```
<!-- </settings-template> -->

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

<!-- <method-3-devcontainer-mount> -->
```jsonc
{
  "mounts": [
    "source=${localWorkspaceFolder}/../hve-core,target=/workspaces/hve-core,type=bind,readonly=true,consistency=cached"
  ]
}
```
<!-- </method-3-devcontainer-mount> -->

**Step 3:** After rebuild, validate mount exists at `/workspaces/hve-core`

#### Method 4: postCreateCommand (Codespaces)

Add to devcontainer.json:

<!-- <method-4-devcontainer> -->
```jsonc
{
  "postCreateCommand": "[ -d /workspaces/hve-core ] || git clone --depth 1 https://github.com/microsoft/hve-core.git /workspaces/hve-core",
  "customizations": {
    "vscode": {
      "settings": {
        "chat.agentFilesLocations": {
          "/workspaces/hve-core/.github/agents/ado": true,
          "/workspaces/hve-core/.github/agents/coding-standards": true,
          "/workspaces/hve-core/.github/agents/data-science": true,
          "/workspaces/hve-core/.github/agents/design-thinking": true,
          "/workspaces/hve-core/.github/agents/github": true,
          "/workspaces/hve-core/.github/agents/hve-core": true,
          "/workspaces/hve-core/.github/agents/hve-core/subagents": true,
          "/workspaces/hve-core/.github/agents/project-planning": true,
          "/workspaces/hve-core/.github/agents/security": true
        },
        "chat.promptFilesLocations": {
          "/workspaces/hve-core/.github/prompts/ado": true,
          "/workspaces/hve-core/.github/prompts/coding-standards": true,
          "/workspaces/hve-core/.github/prompts/design-thinking": true,
          "/workspaces/hve-core/.github/prompts/github": true,
          "/workspaces/hve-core/.github/prompts/hve-core": true,
          "/workspaces/hve-core/.github/prompts/security": true
        },
        "chat.instructionsFilesLocations": {
          "/workspaces/hve-core/.github/instructions/ado": true,
          "/workspaces/hve-core/.github/instructions/coding-standards": true,
          "/workspaces/hve-core/.github/instructions/github": true,
          "/workspaces/hve-core/.github/instructions/hve-core": true,
          "/workspaces/hve-core/.github/instructions/shared": true
        },
        "chat.agentSkillsLocations": {
          "/workspaces/hve-core/.github/skills": true,
          "/workspaces/hve-core/.github/skills/coding-standards": true,
          "/workspaces/hve-core/.github/skills/design-thinking": true,
          "/workspaces/hve-core/.github/skills/project-planning": true,
          "/workspaces/hve-core/.github/skills/rai": true,
          "/workspaces/hve-core/.github/skills/security": true,
          "/workspaces/hve-core/.github/skills/shared": true
        },
        "chat.hookFilesLocations": {
          "/workspaces/hve-core/.github/hooks/shared": true
        }
      }
    }
  }
}
```
<!-- </method-4-devcontainer> -->

Optional: Add `updateContentCommand` for auto-updates on rebuild.

#### Method 5: Multi-Root Workspace

Create `hve-core.code-workspace` file with folders array pointing to both project and HVE-Core.

Use the actual clone path (not the folder display name) as the settings prefix.
Folder display names in `chat.*Locations` settings do not resolve reliably.

> [!IMPORTANT]
> The dev container spec has no `workspaceFile` property. Codespaces and devcontainers always open in single-folder mode. The user must manually open the `.code-workspace` file after the container starts (`File > Open Workspace from File...` or `code <path>.code-workspace`). For Codespaces, Method 4 is usually more convenient because it configures settings automatically without requiring a workspace switch.

Local VS Code: use a relative clone path from the workspace file's directory.

<!-- <method-5-workspace-local> -->
```json
{
  "folders": [
    { "name": "My Project", "path": "." },
    { "path": "../hve-core" }
  ],
  "settings": { /* Same as settings template with ../hve-core prefix */ }
}
```
<!-- </method-5-workspace-local> -->

User opens the `.code-workspace` file instead of the folder.

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

<!-- <method-6-devcontainer> -->
```jsonc
{
  "onCreateCommand": "git submodule update --init --recursive",
  "updateContentCommand": "git submodule update --remote lib/hve-core || true"
}
```
<!-- </method-6-devcontainer> -->

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

This phase applies to all installation methods (Extension and Clone-based). Both paths converge here for consistent post-installation configuration.

### Checkpoint 4: Gitignore Configuration

🛡️ Configuring gitignore...

Check and configure gitignore entries based on the installation method. Different methods may require different gitignore entries.

#### Method-Specific Gitignore Entries

| Method          | Gitignore Entry      | Reason                            |
|-----------------|----------------------|-----------------------------------|
| 2 (Git-Ignored) | `.hve-core/`         | Excludes the local HVE-Core clone |
| All methods     | `.copilot-tracking/` | Excludes AI workflow artifacts    |

**Detection:** Check if `.gitignore` exists and contains the required entries.

**For Method 2 (Git-Ignored):** If `.hve-core/` is not in `.gitignore`, it should have been added during Phase 4 installation. Verify it exists.

**For all methods:** Check if `.copilot-tracking/` should be added to `.gitignore`. This directory stores local AI workflow artifacts (plans, changes, research notes) that are typically user-specific and not meant for version control.

* If pattern found → Skip this checkpoint silently
* If `.gitignore` missing or pattern not found → Present the prompt below

<!-- <gitignore-prompt> -->
```text
📋 Gitignore Recommendation

The `.copilot-tracking/` directory stores local AI workflow artifacts:
• Plans and implementation tracking
• Research notes and change records
• User-specific prompts and handoff logs

These files are typically not meant for version control.

Would you like to add `.copilot-tracking/` to your .gitignore? (yes/no)
```
<!-- </gitignore-prompt> -->

User input handling:

* "yes", "y" → Add entry to `.gitignore`
* "no", "n", "skip" → Skip without changes
* Unclear response → Ask for clarification

**Modification:** If user approves:

* If `.gitignore` exists: Append the following at the end of the file
* If `.gitignore` missing: Create it with the content below

<!-- <gitignore-entry> -->
```text
# HVE-Core AI workflow artifacts (local only)
.copilot-tracking/
```
<!-- </gitignore-entry> -->

Report: "✅ Added `.copilot-tracking/` to .gitignore"

After the gitignore checkpoint, proceed to Checkpoint 5 (MCP Configuration).

### Checkpoint 5: MCP Configuration Guidance

After the gitignore checkpoint (for **any** installation method), present MCP configuration guidance. This helps users who want to use agents that integrate with Azure DevOps, GitHub, or documentation services.

<!-- <mcp-guidance-prompt> -->
```text
📡 MCP Server Configuration (Optional)

Some HVE-Core capabilities integrate with external services via MCP (Model Context Protocol):

| Capability             | MCP Server               | Purpose                              |
|------------------------|--------------------------|--------------------------------------|
| ado-prd-to-wit         | ado                      | Azure DevOps work items              |
| github-backlog-manager | github                   | GitHub backlog management            |
| rpi-research           | context7, microsoft-docs | Documentation lookup                 |
| dt-coach               | figma                    | FigJam board export for DT artifacts |

⚠️ Jira agents (jira-backlog-manager, jira-prd-to-wit) use environment variables
   instead of MCP. Run /jira-setup in Copilot Chat to configure Jira credentials.

Would you like to configure MCP servers? (yes/no)
```
<!-- </mcp-guidance-prompt> -->

User input handling:

* "yes", "y" → Ask which servers to configure (see MCP Server Selection below)
* "no", "n", "skip" → Proceed to Final Completion Report
* Enter, "continue", "done" → Proceed to Final Completion Report
* Unclear response → Proceed to Final Completion Report (non-blocking)

### MCP Server Selection

If user chooses to configure MCP, present:

<!-- <mcp-server-selection> -->
```text
Which MCP servers would you like to configure?

| Server         | Purpose                   | Recommended For               |
|----------------|---------------------------|-------------------------------|
| github         | GitHub issues and repos   | GitHub-hosted repositories    |
| ado            | Azure DevOps work items   | Azure DevOps repositories     |
| context7       | SDK/library documentation | All users (optional)          |
| microsoft-docs | Microsoft Learn docs      | All users (optional)          |
| figma          | FigJam & Figma design     | Design Thinking package users |

⚠️ Suggest EITHER github OR ado based on where your repo is hosted, not both.

Enter server names separated by commas (e.g., "github, context7"):
```
<!-- </mcp-server-selection> -->

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

#### figma server (HTTP with managed auth)

```json
{
  "figma": {
    "type": "http",
    "url": "https://mcp.figma.com/mcp"
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

<!-- <mcp-combined-example> -->
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
<!-- </mcp-combined-example> -->

After creating the file, display:

```text
✅ Created .vscode/mcp.json with [server names] configuration

📖 Full documentation: https://github.com/microsoft/hve-core/blob/main/docs/getting-started/mcp-configuration.md
```

### Final Completion Report

After gitignore and MCP checkpoints complete, display the final completion message:

<!-- <final-completion-report> -->
```text
✅ Setup Complete!

▶️ Next Steps:
1. Reload VS Code (Ctrl+Shift+P → "Reload Window")
2. Open Copilot Chat (`Ctrl+Alt+I`) and click the agent picker dropdown
3. Select an agent to start working

💡 Select `RPI Agent` from the picker to explore HVE-Core capabilities
```
<!-- </final-completion-report> -->

For **Extension** installations, also include:

```text
---
📝 Want to customize HVE-Core or share with your team?
Run this skill again and choose "Clone-Based Installation" for full customization options.
```

For **Clone-based** installations, proceed to Phase 7 for optional component installation.

## Phase 7: Component Installation (Optional)

> [!IMPORTANT]
> Generated scripts in this phase require PowerShell 7+ (`pwsh`). Windows PowerShell 5.1 is not supported. The Bash scripts require `jq`.

After Phase 6 completes, offer users the option to copy HVE-Core components into their target repository. This phase ONLY applies to clone-based installation methods (1-6), NOT to extension installation.

A component is one agent, prompt, instruction, or complete skill declared by exactly one package recipe in `.github/plugin/marketplace.json`. Every Phase 7 operation resolves against a single selected package, so the package is chosen before any profile or component. Component paths use marketplace form and map to canonical target paths without flattening:

<!-- <component-kind-map> -->
| Component path                           | Target path                                                          |
|------------------------------------------|----------------------------------------------------------------------|
| `agents/<subpath>/<name>.md`             | `<TargetRoot>/.github/agents/<subpath>/<name>.agent.md`              |
| `commands/<subpath>/<name>.md`           | `<TargetRoot>/.github/prompts/<subpath>/<name>.prompt.md`            |
| `rules/<subpath>/<name>.instructions.md` | `<TargetRoot>/.github/instructions/<subpath>/<name>.instructions.md` |
| `skills/<subpath>/<name>`                | `<TargetRoot>/.github/skills/<subpath>/<name>` (whole directory)     |
<!-- </component-kind-map> -->

Hooks are never copied by this phase. Skills copy as complete directories, minus local environment and cache directories (`tests`, `.venv`, `.hypothesis`, `node_modules`, `__pycache__`, `.ruff_cache`, `.pytest_cache`).

### Skip Condition

If user selected **Extension Quick Install** (Option 1) in Phase 2, skip Phase 7 entirely. Extension installation bundles all components automatically.

### Package Selection

Before any profile or component resolution, read `.github/plugin/marketplace.json` from the HVE-Core source at `$hveCoreBasePath` and present every `plugins[].name` with its `x-hve.displayName`. The user selects exactly one package name, recorded as `$selectedPackage`.

<!-- <package-selection-prompt> -->
```text
📦 Package Selection (required)

HVE-Core publishes several packages. Component installation resolves against one.

  • hve-core-all — every package component, and the only package declaring the starter profile
  • hve-core — the focused core package
  • [remaining catalog package names with display names]

Which package? (exact name)
```
<!-- </package-selection-prompt> -->

Match the response against catalog names exactly. Reject a name that is absent from the catalog, matches more than one entry, or is a guess, and re-prompt; never substitute a default package. Reject a later component that is not declared membership of `$selectedPackage`, and offer either a different component or a package reselection. Both rejections happen before collision detection and before the first write, matching the same failures the copy scripts raise.

### Checkpoint 6: Component Selection

Present the component selection prompt:

<!-- <component-selection-prompt> -->
```text
📂 Component Installation (Optional)

HVE-Core publishes agents, prompts, instructions, and skills.
Copying them into your repository enables local customization and offline use.

🔬 Starter profile (24 components, package hve-core-all)
  • RPI Agent, Documentation, and the RPI and HVE Builder subagents
  • RPI skills: research, plan, plan-critique, implement, review, walkthrough, quick, challenger
  • HVE Builder skills: builder, builder-tester, prompt-analyze, prompt-builder, prompt-refactor, vally-tests
  • Documentation skill, the /rpi prompt, and the tracking and builder instructions

Options:
  [1] Install the starter profile from hve-core-all (recommended)
  [2] Choose components from [selected package]
  [3] Skip component installation

Your choice? (1/2/3)
```
<!-- </component-selection-prompt> -->

User input handling:

* "1", "starter", "core", "recommended" → Set `$selectedPackage` to `hve-core-all` and resolve the `starter` profile
* "2", "choose", "custom", "components" → Proceed to the Custom Selection sub-flow
* "3", "skip", "none", "no" → Skip to the final success report
* Unclear response → Ask for clarification

### Custom Selection Sub-Flow

When the user selects option 2, read `.github/plugin/marketplace.json` from the HVE-Core source at `$hveCoreBasePath` and present the `$selectedPackage` entry's components grouped by kind. Show each component's `x-hve.componentMaturity` label from that entry, defaulting to `stable` when the entry declares none. Collect the user's component paths in marketplace form and reject any path outside that entry before resolution.

### Selection Resolution

Resolve the chosen profile or component list before any confirmation or write. Run the resolver from the HVE-Core clone:

<!-- <selection-resolution> -->
```powershell
Import-Module "$hveCoreBasePath/scripts/lib/Modules/MarketplaceHelpers.psm1" -Force
$catalog = Get-MarketplaceCatalog -Path "$hveCoreBasePath/.github/plugin/marketplace.json"
$entry = @($catalog['plugins']) | Where-Object { $_['name'] -eq $selectedPackage }
$agentIndex = Get-MarketplaceAgentIndex -Catalog $catalog -RepoRoot $hveCoreBasePath

# Only hve-core-all declares the starter profile; resolve it with $selectedPackage = 'hve-core-all'.
$selection = Resolve-MarketplaceComponentSelection -Entry $entry -RepoRoot $hveCoreBasePath -AgentIndex $agentIndex -ProfileName 'starter'

# Or an explicit selection
$selection = Resolve-MarketplaceComponentSelection -Entry $entry -RepoRoot $hveCoreBasePath -AgentIndex $agentIndex -Component $chosenComponents
```
<!-- </selection-resolution> -->

The resolver requires the `PowerShell-Yaml` module. If the import fails, tell the user to run `Install-Module PowerShell-Yaml -Scope CurrentUser` and retry.

Each resolved record carries `PackagePath`, `Kind`, `SourcePath`, `Maturity`, and `Origin`. `Origin` is `selected` for a chosen component and `dependency` for a component added by agent handoff closure or a literal `#file:` reference. The resolver fails when a selection is not membership of the selected package's recipe, when that package declares no such profile, or when a visible dependency does not resolve inside the same recipe.

### Collision Detection

Run the pre-write check with the resolved component list. It validates every path, reports canonical maturity, and reports component-level collisions. A file component collides on its full target path; a skill component collides on its target directory. Nothing is written.

**PowerShell:** Run [scripts/collision-detection.ps1](scripts/collision-detection.ps1) with `-HveCoreBasePath`, `-TargetRoot`, `-PackageName` (`$selectedPackage`), and `-Component`.

**Bash:** Run [scripts/collision-detection.sh](scripts/collision-detection.sh) with the HVE-Core base path, target root, package name, and component paths as arguments, in that order.

Output lines:

<!-- <collision-detection-output> -->
```text
COMPONENT=<path>|KIND=<kind>|MATURITY=<maturity>|TARGET=<target-relative path>|EXISTS=<true|false>
COLLISIONS_DETECTED=<true|false>
COLLISION_COMPONENTS=<comma-separated component paths>
COLLISION_TARGETS=<comma-separated target-relative paths>
```
<!-- </collision-detection-output> -->

### Confirmation Prompt

Present every selected and dependency-added component with its maturity before any write. Call out non-stable components explicitly.

<!-- <component-confirmation-prompt> -->
```text
📋 Components to install

| Component        | Kind   | Maturity   | Added by   |
|------------------|--------|------------|------------|
| [component path] | [kind] | [maturity] | selected   |
| [component path] | [kind] | [maturity] | dependency |

⚠️ [N] component(s) are labeled preview or experimental. They may change or be
   removed without notice.

Proceed with installation? (yes/no)
```
<!-- </component-confirmation-prompt> -->

User input handling:

* "yes", "y" → Continue to collision resolution when collisions exist, otherwise run the copy
* "no", "n" → Return to Checkpoint 6 without writing anything
* Unclear response → Ask for clarification

### Collision Resolution Prompt

If collisions are detected, present:

<!-- <collision-prompt> -->
```text
⚠️ Existing Components Detected

The following components already exist in your project:
  • [list COLLISION_COMPONENTS with their COLLISION_TARGETS]

Options:
  [O] Overwrite with the HVE-Core version
  [K] Keep existing (skip these components)
  [C] Compare (show diff for the first file)

Or for all conflicts:
  [OA] Overwrite all
  [KA] Keep all existing

Your choice?
```
<!-- </collision-prompt> -->

User input handling:

* "o", "overwrite" → Overwrite the current component, ask about the next
* "k", "keep" → Keep the current component, ask about the next
* "c", "compare" → Show diff, then re-prompt
* "oa", "overwrite all" → Overwrite every collision
* "ka", "keep all" → Keep every existing component

Keeping a skill keeps its whole target directory.

### Component Copy Execution

After confirmation and collision resolution, execute the copy.

**PowerShell:** Run [scripts/component-copy.ps1](scripts/component-copy.ps1) with `-HveCoreBasePath`, `-TargetRoot`, `-PackageName` (`$selectedPackage`), `-SelectionName` (`starter` or `custom`), and `-Component`. Add `-KeepExisting -Collisions <component paths>` for kept components.

**Bash:** Run [scripts/component-copy.sh](scripts/component-copy.sh) with the HVE-Core base path, target root, package name, selection name, and component paths as arguments, in that order. Set `KEEP_EXISTING=true` and `COLLISIONS_FILE=<newline-delimited component paths>` for kept components.

Both implementations validate membership, path safety, and the existing manifest schema before the first write, and produce equivalent paths, hashes, manifests, and output.

### Tracking Manifest

The copy writes `.hve-tracking.json` at the target root using schema version 2:

<!-- <tracking-manifest> -->
```json
{
  "schemaVersion": 2,
  "source": "microsoft/hve-core",
  "version": "3.3.106",
  "installed": "2026-08-02T00:00:00Z",
  "selection": {
    "package": "hve-core-all",
    "profile": "starter",
    "components": ["agents/hve-core/rpi-agent.md", "skills/rpi/rpi-plan"]
  },
  "files": {
    ".github/agents/hve-core/rpi-agent.agent.md": {
      "component": "agents/hve-core/rpi-agent.md",
      "kind": "agent",
      "maturity": "stable",
      "version": "3.3.106",
      "sha256": "<hash>",
      "status": "managed"
    }
  }
}
```
<!-- </tracking-manifest> -->

Files are keyed by target-relative path. The manifest records the selected package once under `selection.package`; file entries carry component ownership only, and no absolute target root is stored. There is no version 1 compatibility layer: a missing or unsupported `schemaVersion` fails before any target change with clean-reinstall guidance.

### Component Copy Success Report

Upon successful copy, display:

<!-- <component-copy-success> -->
```text
✅ Component Installation Complete!

Copied [N] components into .github/
Created .hve-tracking.json for upgrade tracking

📄 Installed components:
  • [component path] ([kind], [maturity])

🔄 Upgrade Workflow:
  Run this installer again to check for component updates.
  Modified files will prompt before overwriting.
  Use 'eject' to take ownership of any component.

Proceeding to final success report...
```
<!-- </component-copy-success> -->

## Phase 7 Upgrade Mode

When `.hve-tracking.json` already exists, Phase 7 operates in upgrade mode.

### Upgrade Detection

At Phase 7 start, check for an existing manifest.

**PowerShell:** Run [scripts/upgrade-detection.ps1](scripts/upgrade-detection.ps1) with `-HveCoreBasePath` and optional `-TargetRoot`.

**Bash:** Run [scripts/upgrade-detection.sh](scripts/upgrade-detection.sh) with the HVE-Core base path and optional target root as arguments.

Output keys: `UPGRADE_MODE`, and when a manifest exists, `INSTALLED_VERSION`, `SOURCE_VERSION`, `VERSION_CHANGED`, `INSTALLED_PACKAGE`, `INSTALLED_PROFILE`, and `INSTALLED_COMPONENTS`. `INSTALLED_PACKAGE` is the recorded `selection.package`, and is emitted as an empty value when a schema version 2 manifest records none. An unsupported `schemaVersion` fails with clean-reinstall guidance.

Replay the upgrade against `INSTALLED_PACKAGE`: pass it as `-PackageName` or the Bash package argument for collision detection and copy, and re-resolve `INSTALLED_COMPONENTS` through that package's entry so the upgrade reflects current dependency closure and maturity. When `INSTALLED_PACKAGE` is empty, stop and run Package Selection again so the user names one exact catalog package before any replay; infer nothing from the recorded profile or components.

### Upgrade Prompt

If upgrade mode with version change:

<!-- <upgrade-prompt> -->
```text
🔄 HVE-Core Component Upgrade

Source: microsoft/hve-core v[SOURCE_VERSION]
Installed: v[INSTALLED_VERSION]
Package: [INSTALLED_PACKAGE]
Selection: [INSTALLED_PROFILE]

Checking file status...
```
<!-- </upgrade-prompt> -->

### File Status Check

Compare current files against the manifest.

**PowerShell:** Run [scripts/file-status-check.ps1](scripts/file-status-check.ps1) with optional `-TargetRoot`.

**Bash:** Run [scripts/file-status-check.sh](scripts/file-status-check.sh) with an optional target root argument.

Each line reports one tracked file:

<!-- <file-status-output> -->
```text
FILE=<path>|COMPONENT=<component path>|KIND=<kind>|MATURITY=<maturity>|STATUS=<status>|ACTION=<action>
```
<!-- </file-status-output> -->

Statuses are `managed`, `modified`, `missing`, and `ejected`. Group the lines by `COMPONENT` when presenting them.

### Upgrade Summary Display

Present upgrade summary:

<!-- <upgrade-summary> -->
```text
📋 Upgrade Summary

Components to update (managed):
  ✅ agents/hve-core/rpi-agent.md
  ✅ skills/rpi/rpi-plan

Files requiring decision (modified):
  ⚠️ .github/agents/hve-core/rpi-agent.agent.md

Components skipped (ejected):
  🔒 agents/hve-core/documentation.md

For modified files, choose:
  [A] Accept upstream (overwrite your changes)
  [K] Keep local (skip this update)
  [E] Eject (never update this component again)
  [D] Show diff

Process file: .github/agents/hve-core/rpi-agent.agent.md?
```
<!-- </upgrade-summary> -->

### Diff Display

When user requests diff:

<!-- <diff-display> -->
```text
─────────────────────────────────────
File: .github/agents/hve-core/rpi-agent.agent.md
Component: agents/hve-core/rpi-agent.md
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
<!-- </diff-display> -->

### Status Transitions

After user decision, update the manifest:

| Decision | Status Change           | Manifest Update                         |
|----------|-------------------------|-----------------------------------------|
| Accept   | `modified` → `managed`  | Re-copy the component, update hash      |
| Keep     | `modified` → `modified` | No change (pass the component to keep)  |
| Eject    | `*` → `ejected`         | Add `ejectedAt` to every component file |

### Eject Implementation

Eject operates on a component. Every file of that component is marked `ejected`, stays on disk, and becomes owned by the user. Later copies skip ejected files and preserve their manifest entries.

**PowerShell:** Run [scripts/eject.ps1](scripts/eject.ps1) with `-Component` and optional `-TargetRoot`.

**Bash:** Run [scripts/eject.sh](scripts/eject.sh) with the component path and optional target root as arguments.

### Upgrade Completion

After processing all files:

<!-- <upgrade-success> -->
```text
✅ Upgrade Complete!

Updated: [N] files
Skipped: [M] files (kept local or ejected)
Version: v[OLD] → v[NEW]

Proceeding to final success report...
```
<!-- </upgrade-success> -->

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
