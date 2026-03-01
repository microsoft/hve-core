---
title: Your First Full Workflow
description: Hands-on tutorial using Research, Plan, Implement phases to create a validation script
sidebar_position: 5
author: Microsoft
ms.date: 2026-02-18
ms.topic: tutorial
keywords:
  - getting started
  - rpi workflow
  - github copilot
  - tutorial
  - powershell script
estimated_reading_time: 10
---

> [!NOTE]
> Step 3 of 4 in the [Getting Started Journey](./).

Build a real validation script using the Research → Plan → Implement workflow. You'll create a PowerShell script that checks that every docs subfolder has a `README.md` file.

> [!TIP]
> This tutorial uses a PowerShell script as the example task. The RPI
> methodology works identically with any language. If PowerShell isn't
> relevant to you, substitute your own small task: a utility function,
> a configuration validator, a documentation checker. The prompts
> adapt to whatever you describe.

## Prerequisites

* VS Code with GitHub Copilot Chat extension
* This repository cloned locally
* Basic familiarity with GitHub Copilot
* ~15 minutes to complete

## The Task

You'll create:

* `scripts/linting/Test-DocsReadme.ps1` - validation script
* npm script entry in `package.json`

Multiple unknowns make RPI a good fit for this task: existing script patterns, PowerShell conventions, npm integration, output format. Research first reduces guesswork.

> [!IMPORTANT]
> AI can't tell the difference between investigating and implementing. When you ask for code, it writes code. Patterns that look plausible but break your conventions. RPI's constraint system changes the goal: when AI knows it cannot implement, it stops optimizing for "plausible code" and starts optimizing for "verified truth." [Learn more about why RPI works](../rpi/why-rpi.md).

## Before You Start

> [!TIP]
> Steps 1 and 2 ([Your First Interaction](first-interaction.md) and
> [Your First Research](first-research.md)) cover the basics. If you've
> already completed them or have experience with HVE Core agents, continue
> below.

The `/clear` command resets Copilot's context between phases. Each RPI phase
should start fresh. The artifacts (research doc, plan) carry the context
forward, not the chat history.

> [!NOTE]
> Understanding why `/clear` matters (not just that you should use it) helps you recognize when context degradation affects your results. See [Context Engineering](../rpi/context-engineering.md) for the full explanation.

## Phase 1: Research

### Switch to Task Researcher

1. Open Copilot Chat (`Ctrl+Alt+I`)
1. Click the agent picker dropdown at the top
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
1. Click the agent picker dropdown
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
1. Click the agent picker dropdown
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

## Alternative: Single-Session with rpi-agent

The three-agent workflow above separates research, planning, and implementation
into distinct phases with `/clear` between each. This is the best way to learn
RPI because you see each phase produce its own artifact.

For day-to-day work, the [rpi-agent](https://github.com/microsoft/hve-core/blob/main/.github/CUSTOM-AGENTS.md#rpi-agent)
runs all three phases in a single session. It follows the same methodology but
handles the phase transitions automatically.

To compare the experience, select **rpi-agent** from the agent picker and try
this prompt:

> Create a PowerShell script that validates every subfolder under docs/ contains
> a README.md file. Place it at scripts/linting/Test-DocsReadme.ps1 and add an
> npm script entry.

The rpi-agent researches, plans, and implements without `/clear` commands
between phases.

## What You Learned

* Use `/clear` between phases to prevent context pollution through phase separation.
* Research reduces unknowns by discovering patterns before coding.
* The plan gives Implementor clear requirements, acting as a specification.
* Findings and plans bridge phases by carrying context, not chat history.

## Troubleshooting

| Issue                 | Solution                                                                                          |
|-----------------------|---------------------------------------------------------------------------------------------------|
| PowerShell not found  | Ensure `pwsh` is installed and in PATH                                                            |
| npm script not found  | Check `package.json` was saved                                                                    |
| Wrong folders checked | Verify script targets `docs/*` pattern                                                            |
| Agent skips phases    | Use `/clear` before each `/rpi` request; see [Context Engineering](../rpi/context-engineering.md) |

## Next Step

You've completed your first full RPI cycle. The methodology works the same
way for any task: research the unknowns, plan the approach, implement from
the plan.

Continue your journey through the
[New Contributor Milestones](../hve-guide/roles/new-contributor.md#milestone-3-independent-workflow),
where Milestone 3 guides you through your first independent workflow on a
task you choose yourself.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
