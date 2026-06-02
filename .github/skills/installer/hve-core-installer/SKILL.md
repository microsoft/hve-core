---
name: hve-core-installer
description: 'Decision-driven installer for HVE-Core with 6 clone-based installation methods, extension quick-install, environment detection, and agent customization workflows - Brought to you by microsoft/hve-core'
compatibility: 'Requires VS Code or VS Code Insiders. Clone-based methods require git on PATH and network access.'
license: MIT
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-04-01"
---

# HVE-Core Installer Skill

Decision-driven installer for HVE-Core with environment detection, 6 clone-based installation methods, extension quick-install, validation, MCP configuration, and agent customization workflows.

## Role Definition

Operate as two collaborating personas:

* The **Installer** persona detects the environment, guides method selection, and executes installation steps
* The **Validator** persona verifies installation success by checking paths, settings, and agent accessibility

The Installer persona handles all detection and execution. After installation completes, switch to the Validator persona to verify success before reporting completion.

**Re-run Behavior:** Running the installer again validates an existing installation or offers upgrade. Safe to re-run anytime.

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

## Phase 1: Environment Detection

Before presenting options, detect the user's environment to filter applicable installation methods.

### Checkpoint 1: Initial Consent

Present the following and await explicit consent:

```text
🚀 HVE-Core Installer

I'll help you install HVE-Core agents, prompts, instructions and skills.

Available content:
• 25+ specialized agents (task-researcher, task-planner, etc.)
• Reusable prompt templates for common workflows
• Technology-specific coding instructions (bash, python, markdown, etc.)
• Domain-specific skills (pr-reference, etc.)

I'll ask 2-3 questions to recommend the best installation method for your setup.

Would you like to proceed?
```

If user declines, respond: "Installation cancelled. You can invoke this skill anytime to restart."

Upon consent, proceed to Phase 2 to offer the installation path choice.

## Phase 2: Installation Path Selection

Present Checkpoint 2 to let the user choose between Extension Quick Install (Option 1) and Clone-Based Installation (Option 2). Option 1 collects the VS Code variant, runs the marketplace install via `code` or `code-insiders --install-extension ise-hve-essentials.hve-core`, validates, then jumps to Phase 6. Option 2 collects shell preference, verifies `git --version`, runs the environment detection script, and continues to Phase 3.

See [references/phase-2-installation-paths.md](references/phase-2-installation-paths.md) for the full Checkpoint 2 prompt, shell detection rules, prerequisites check, extension execution and validation scripts, success report, error recovery table, and environment detection script invocation.

## Phase 3: Environment Detection & Decision Matrix

Ask up to three questions to determine the recommended installation method: environment confirmation (A/B/C/D), team or solo, and (when more than one method matches) update preference. Match answers to the decision matrix, present the recommended method with rationale, and offer alternatives before proceeding to Phase 4.

See [references/phase-3-decision-matrix.md](references/phase-3-decision-matrix.md) for the full question prompts, decision matrix mapping environments to Methods 1-6, and the recommendation template.

## Phase 4: Installation Methods

Execute the selected method (1-6) from the decision matrix. Each method clones `https://github.com/microsoft/hve-core.git` to a method-specific target path and updates `.vscode/settings.json` (or the workspace file for Method 5, or devcontainer customizations for Method 4) with collection-specific entries under `chat.agentFilesLocations`, `chat.promptFilesLocations`, `chat.instructionsFilesLocations`, and `chat.agentSkillsLocations`. Exclude the `installer` collection from `chat.agentSkillsLocations` and prompt before adding any `experimental` folders.

See [references/phase-4-installation-methods.md](references/phase-4-installation-methods.md) for the method configuration table, common clone operation scripts, full settings template, and method-specific instructions for Peer Clone, Git-Ignored, Mounted, Codespaces postCreateCommand, Multi-Root Workspace, and Submodule.

## Phase 5: Validation (Validator Persona)

Switch to the **Validator** persona. Present Checkpoint 3 (Settings Authorization) before modifying `settings.json`, then run the method-specific validation script with the appropriate base path (`../hve-core`, `.hve-core`, `/workspaces/hve-core`, workspace file, or `lib/hve-core`). On success, display the Success Report and proceed to Phase 6.

See [references/phase-5-validation.md](references/phase-5-validation.md) for the Checkpoint 3 authorization prompt, base-path table, validation script invocations, and the success report template.

## Phase 6: Post-Installation Setup

Applies to all installation paths (Extension and Clone-based). Present Checkpoint 4 (Gitignore) to add `.copilot-tracking/` (and `.hve-core/` for Method 2) to `.gitignore`, then Checkpoint 5 (MCP Configuration) to optionally create `.vscode/mcp.json` from the github, ado, context7, microsoft-docs, and figma templates. Finish with the Final Completion Report. For Extension installations, append the customization hint and end. For Clone-based installations, continue to Phase 7.

See [references/phase-6-post-installation.md](references/phase-6-post-installation.md) for the gitignore detection logic and entries, MCP server selection prompts, all five MCP configuration templates, file generation rules, and final completion report variants.

## Phase 7: Agent Customization (Optional)

> [!IMPORTANT]
> Generated scripts in this phase require PowerShell 7+ (`pwsh`). Windows PowerShell 5.1 is not supported.

Applies only to clone-based installations (Methods 1-6); skip entirely for Extension Quick Install. If `.hve-tracking.json` already exists at Phase 7 start, run the upgrade workflow described in the section below instead of the initial copy flow. Otherwise present Checkpoint 6 (Agent Copy Decision) offering RPI Core, Collection Selection, or Skip; resolve any collisions; copy the selected agents; and write `.hve-tracking.json` for future upgrades.

See [references/phase-7-agent-customization.md](references/phase-7-agent-customization.md) for the Checkpoint 6 prompt, collection selection sub-flow, agent bundle definitions, collision detection and resolution prompts, agent copy execution scripts, and copy success report.

## Phase 7 Upgrade Mode

When `.hve-tracking.json` exists at Phase 7 start, Phase 7 operates in upgrade mode. Run the upgrade detection script, present the version-change prompt, compare files against the manifest, display the upgrade summary categorizing files as managed, modified, or ejected, and resolve each modified file with Accept / Keep / Eject / Diff. Update the manifest per status transitions and display the Upgrade Completion report.

See [references/phase-7-upgrade-mode.md](references/phase-7-upgrade-mode.md) for the upgrade detection invocation, version prompt, file-status check, upgrade summary template, diff display, status-transition table, eject script invocation, and upgrade success report.

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

If you used Phase 7 agent copy, also delete `.hve-tracking.json` and optionally `.github/agents/` if you no longer need copied agents.

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

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
