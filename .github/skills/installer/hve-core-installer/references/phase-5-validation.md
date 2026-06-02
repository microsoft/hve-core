---
title: 'Phase 5: Validation (Validator Persona)'
description: 'Validator persona checks and settings authorization gate executed after hve-core installation completes.'
---

# Phase 5: Validation (Validator Persona)

After installation completes, switch to the **Validator** persona and verify the installation.

> [!IMPORTANT]
> After successful validation, proceed to Phase 6 for post-installation setup, then Phase 7 for optional agent customization (clone-based methods only).

## Checkpoint 3: Settings Authorization

Before modifying settings.json, present the following:

```text
⚙️ VS Code Settings Update

I will now update your VS Code settings to add HVE-Core paths.

Changes to be made:
• [List paths based on selected method]

⚠️ Authorization Required: Do you authorize these settings changes? (yes/no)
```

If user declines: "Installation cancelled. No settings changes were made."

## Validation Workflow

Run validation based on the selected method. Set the base path variable before running:

| Method | Base Path              |
|--------|------------------------|
| 1      | `../hve-core`          |
| 2      | `.hve-core`            |
| 3, 4   | `/workspaces/hve-core` |
| 5      | Check workspace file   |
| 6      | `lib/hve-core`         |

**PowerShell:** Run [scripts/validate-installation.ps1](../scripts/validate-installation.ps1) with the `method` and `basePath` variables set.

**Bash:** Run [scripts/validate-installation.sh](../scripts/validate-installation.sh) with the method number and base path as arguments.

## Success Report

Upon successful validation, display:

<!-- <success-report> -->
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
<!-- </success-report> -->

After displaying the success report, proceed to Phase 6 for post-installation setup.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
