---
title: 'Phase 2: Installation Path Selection'
description: 'Installation path choice presented before environment detection for the hve-core installer skill.'
---

# Phase 2: Installation Path Selection

Present the installation path choice before environment detection. Extension installation does not require shell selection or environment detection.

## Checkpoint 2: Installation Path Choice

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

## Prerequisites Check

Before clone-based installation, verify git is available:

* Run: `git --version`
* If fails: "Git is required for clone-based installation. Install git or choose Extension Quick Install."

## Extension Installation Execution

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

## Extension Validation

Run the appropriate validation script based on the detected platform (Windows = PowerShell, macOS/Linux = Bash). Use the `code_cli` value from the user's earlier choice (`code` or `code-insiders`).

**PowerShell:** Run [../scripts/validate-extension.ps1](../scripts/validate-extension.ps1) with the `code_cli` variable set.

**Bash:** Run [../scripts/validate-extension.sh](../scripts/validate-extension.sh) with the `code_cli` variable set.

## Extension Success Report

Upon successful validation, display:

<!-- <extension-success-report> -->
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
<!-- </extension-success-report> -->

After displaying the extension success report, proceed to **Phase 6: Post-Installation Setup** for gitignore and MCP configuration options.

## Extension Error Recovery

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

## Environment Detection Script

Run the appropriate detection script based on the user's shell:

**PowerShell:** Run [../scripts/detect-environment.ps1](../scripts/detect-environment.ps1)

**Bash:** Run [../scripts/detect-environment.sh](../scripts/detect-environment.sh)

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
