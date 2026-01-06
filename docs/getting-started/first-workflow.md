---
title: Your First RPI Workflow
description: Hands-on tutorial using Research, Plan, Implement phases to create a validation script
author: Microsoft
ms.date: 2025-11-26
ms.topic: tutorial
keywords:
  - getting started
  - rpi workflow
  - github copilot
  - tutorial
  - powershell script
estimated_reading_time: 10
---

Build a real validation script using the Research → Plan → Implement workflow. You'll create a PowerShell script that checks that every docs subfolder has a `README.md` file.

## Prerequisites

* VS Code with GitHub Copilot Chat extension
* This repository cloned locally
* Basic familiarity with GitHub Copilot
* ~15 minutes to complete

## The Task

You'll create:

* `scripts/linting/Test-DocsReadme.ps1` - validation script
* npm script entry in `package.json`

**Why use RPI for this?** Multiple unknowns: existing script patterns, PowerShell conventions, npm integration, output format. Research first reduces guesswork.

## Before You Start

**The `/clear` command** resets Copilot's context between phases. Each RPI phase should start fresh—the artifacts (research doc, plan) carry the context forward, not the chat history.

## Phase 1: Research

### Switch to Task Researcher

1. Open Copilot Chat (`Ctrl+Alt+I`)
1. Click the chat mode dropdown at the top
1. Select **Task Researcher**

### Your Research Prompt

Copy and paste this prompt:

```text
Research what's needed to create a PowerShell script for this repository that
validates every subfolder under docs/ contains a README.md file.

Consider:
* Existing PowerShell script patterns in scripts/linting/
* PSScriptAnalyzer conventions and settings
* How npm scripts are structured in package.json
* Expected output format (exit codes, messages)
```

### What You'll Get

Task Researcher analyzes the codebase and returns findings about:

* Existing PowerShell scripts and their patterns
* PSScriptAnalyzer settings and conventions
* Current npm scripts structure
* Recommended output format

### Key Findings to Note

From the research output, identify:

| Finding                 | Example                                       |
|-------------------------|-----------------------------------------------|
| Script location pattern | `scripts/linting/*.ps1`                       |
| Naming convention       | `Verb-Noun.ps1` (e.g., `Test-DocsReadme.ps1`) |
| npm script pattern      | `"name": "pwsh scripts/path.ps1"`             |
| Exit codes              | `exit 0` = success, `exit 1` = failure        |

## Phase 2: Plan

### Clear and Switch

1. Type `/clear` in the chat to reset context
1. Click the chat mode dropdown
1. Select **Task Planner**

### Your Planning Prompt

Copy and paste this prompt (include findings from Phase 1):

```text
Create an implementation plan to add a README validation script.

Requirements from research:
* Script location: scripts/linting/Test-DocsReadme.ps1
* Follow PowerShell conventions (Verb-Noun naming, comment-based help)
* Add npm script "check:docs-readme" to package.json
* Exit 0 on success, exit 1 on failure
* Output list of folders missing README.md
```

### Plan Output

Task Planner creates a structured plan with:

* File creation steps
* Implementation details for each file
* Validation criteria

### Your Plan Should Include

1. Create `scripts/linting/Test-DocsReadme.ps1` with:
   * Find all immediate subdirectories of `docs/`
   * Check each has `README.md`
   * Print missing folders
   * Exit with appropriate code

1. Update `package.json`:
   * Add `"check:docs-readme"` script

## Phase 3: Implement

### Clear and Switch to Implementor

1. Type `/clear` in the chat to reset context
1. Click the chat mode dropdown
1. Select **Task Implementor**

### Your Implementation Prompt

Copy and paste this prompt:

```text
Implement this plan to add README validation.

Plan:
1. Create scripts/linting/Test-DocsReadme.ps1
   - Include comment-based help
   - Find all immediate subdirectories of docs/
   - Check each has README.md
   - Print missing folders with clear messaging
   - Exit 0 if all pass, exit 1 if any missing

2. Update package.json
   - Add "check:docs-readme": "pwsh scripts/linting/Test-DocsReadme.ps1"
```

### Watch It Work

Task Implementor will:

1. Create the PowerShell script with proper structure
1. Update `package.json` with the npm script
1. Show you each file change for approval

Confirm each tool call when prompted.

## Verify Your Work

### Run the Script

```powershell
npm run check:docs-readme
```

### Expected Output (Success)

```text
Checking docs subfolders for README.md...
✓ docs/contributing/README.md
✓ docs/getting-started/README.md
✓ docs/rpi/README.md

All docs subfolders have README.md
```

### Test Failure Detection

Temporarily rename a README to see the failure case:

```powershell
Rename-Item docs/rpi/README.md README.md.bak
npm run check:docs-readme
Rename-Item docs/rpi/README.md.bak README.md
```

## What You Learned

* **Phase separation** - `/clear` between phases prevents context pollution
* **Research reduces unknowns** - You discovered patterns before coding
* **Plans are specifications** - The plan gave Implementor clear requirements
* **Artifacts bridge phases** - Findings and plans carry context, not chat history

## Troubleshooting

| Issue                 | Solution                               |
|-----------------------|----------------------------------------|
| PowerShell not found  | Ensure `pwsh` is installed and in PATH |
| npm script not found  | Check `package.json` was saved         |
| Wrong folders checked | Verify script targets `docs/*` pattern |

## Next Steps

* **Complex multi-file tasks** - See [RPI Workflow Overview](../rpi/README.md) and/or [rpi-agent](../../.github/chatmodes/README.md#rpi-agent)
* **Simple tasks** - Use [rpi-agent](../../.github/chatmodes/README.md#rpi-agent) or prompts directly
* **Contribute** - Read [Contributing Guide](../contributing/README.md)

## Resources

| Resource                                                 | Description                          |
|----------------------------------------------------------|--------------------------------------|
| [RPI Overview](../rpi/README.md)                         | Full RPI workflow documentation      |
| [Task Researcher](../rpi/task-researcher.md)             | Deep dive on research phase          |
| [Task Planner](../rpi/task-planner.md)                   | Deep dive on planning phase          |
| [Task Implementor](../rpi/task-implementor.md)           | Deep dive on implementation phase    |
| [RPI Agent](../../.github/chatmodes/README.md#rpi-agent) | Autonomous single-workflow execution |

---

*🤖 Crafted with precision by ✨GitHub Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
