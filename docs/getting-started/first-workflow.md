---
title: Your First Full Workflow
description: Hands-on tutorial using Research, Plan, Implement, and Review to create a validation script
sidebar_position: 6
author: Microsoft
ms.date: 2026-10-20
ms.topic: tutorial
keywords:
  - getting started
  - rpi workflow
  - github copilot
  - tutorial
  - powershell script
estimated_reading_time: 12
---

> [!NOTE]
> Step 3 of 4 in the [Getting Started Journey](./).

Build a validation script using the Research → Plan → Implement → Review
workflow. You'll create a PowerShell script that checks whether the Getting
Started journey contains its four required pages.

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
* About 20 minutes to complete

## The Task

You'll create:

* `scripts/linting/Test-GettingStartedJourney.ps1` - validation script
* npm script entry in `package.json`

Multiple unknowns make RPI a good fit for this task: existing script patterns, PowerShell conventions, npm integration, output format. Research first reduces guesswork.

> [!IMPORTANT]
> Complex changes can produce plausible code that misses repository conventions.
> RPI separates evidence gathering, planning, implementation, and acceptance so
> each stage has a clear responsibility. [Learn more about why RPI works](../rpi/why-rpi).

## Before You Start

> [!TIP]
> Steps 1 and 2 ([Your First Interaction](first-interaction) and
> [Your First Research](first-research)) cover the basics. If you've
> already completed them or have experience with HVE Core agents, continue
> below.

The `/clear` command resets Copilot's conversational context between phases.
Each phase can start fresh because dated RPI artifacts carry evidence and
decisions forward. This tutorial invokes the four phase skills separately so
you can see each responsibility and artifact.

> [!NOTE]
> A context reset is useful when a long conversation is no longer serving the
> task; it is not required between every phase. See
> [Context Engineering](../rpi/context-engineering) for the full explanation.

## Phase 1: Research

### Invoke rpi-research

1. Open Copilot Chat (`Ctrl+Alt+I` on Windows and Linux or
   `Control+Command+I` on macOS)
1. Type `/rpi-research` to activate the Research phase skill

### Your Research Prompt

Copy and paste this prompt:

```text
Research what's needed to create a PowerShell script for this repository that
validates the required Getting Started journey pages exist.

Consider:
* Existing PowerShell script patterns in scripts/linting/
* PSScriptAnalyzer conventions and settings
* How npm scripts are structured in package.json
* The journey pages linked from docs/getting-started/README.md
* Expected output format (exit codes, messages)
```

### What You'll Get

`rpi-research` analyzes the codebase and returns findings about:

* Existing PowerShell scripts and their patterns
* PSScriptAnalyzer settings and conventions
* Current npm scripts structure
* Current Getting Started journey page paths
* Recommended output format

### Key Findings to Note

From the research output, identify:

| Finding                 | Example                                                    |
|-------------------------|------------------------------------------------------------|
| Script location pattern | `scripts/linting/*.ps1`                                    |
| Naming convention       | `Verb-Noun.ps1`, such as `Test-GettingStartedJourney.ps1`  |
| npm script pattern      | `"name": "pwsh scripts/path.ps1"`                          |
| Required pages          | Overview, First Interaction, First Research, Full Workflow |
| Exit codes              | `exit 0` = success, `exit 1` = failure                     |

## Phase 2: Plan

### Clear and Invoke rpi-plan

1. Type `/clear` in the chat to reset context
1. Type `/rpi-plan` to activate the Plan phase skill

### Your Planning Prompt

Copy the research artifact path from Phase 1, then use it in this prompt:

```text
Create an implementation plan to add a Getting Started journey validation script.

Research evidence:
* .copilot-tracking/research/<date>/<task-slug>-research.md

Requirements:
* Script location: scripts/linting/Test-GettingStartedJourney.ps1
* Follow PowerShell conventions (Verb-Noun naming, comment-based help)
* Add npm script "check:getting-started" to package.json
* Exit 0 on success, exit 1 on failure
* Check README.md, first-interaction.md, first-research.md, and first-workflow.md
* Output the path of each missing journey page
```

### Plan Output

`rpi-plan` creates a structured plan with:

* A sequenced phase checklist
* Checkable requirements and dependencies
* A critique disposition unless you explicitly skip it
* Validation expectations for implementation

### Your Plan Should Include

1. Create `scripts/linting/Test-GettingStartedJourney.ps1` with:
   * Check the four required files under `docs/getting-started/`
   * Print missing page paths
   * Exit with appropriate code

1. Update `package.json`:
   * Add `"check:getting-started"` script

## Phase 3: Implement

### Clear and Invoke rpi-implement

1. Type `/clear` in the chat to reset context
1. Type `/rpi-implement` to activate the Implement phase skill

### Your Implementation Prompt

Copy the plan path from Phase 2, then use it in this prompt:

```text
Implement the approved Getting Started journey validation plan.

Plan:
* .copilot-tracking/plans/<date>/<task-slug>-plan.md

Follow the plan, record implementation evidence, and run its targeted checks.
```

### Watch It Work

`rpi-implement` will:

1. Follow the dependency-ready plan tasks
1. Create a dated changes record
1. Update plan completion markers only after evidence exists
1. Run and record the plan's validation checks

## Verify Your Work

### Run the Script

```powershell
npm run check:getting-started
```

### Expected Output (Success)

```text
Checking Getting Started journey pages...
Found docs/getting-started/README.md
Found docs/getting-started/first-interaction.md
Found docs/getting-started/first-research.md
Found docs/getting-started/first-workflow.md

All required Getting Started journey pages exist.
```

### Test Failure Detection

Temporarily rename one journey page to see the failure case:

```powershell
Rename-Item docs/getting-started/first-research.md first-research.md.bak
npm run check:getting-started
Rename-Item docs/getting-started/first-research.md.bak first-research.md
```

## Phase 4: Review

### Clear and Invoke rpi-review

1. Type `/clear` if the implementation conversation has accumulated unrelated context
1. Type `/rpi-review` to activate the Review phase skill

### Your Review Prompt

Copy the plan and changes paths from the preceding phases, then use them in
this prompt:

```text
Review the completed Getting Started journey validation work.

Plan:
* .copilot-tracking/plans/<date>/<task-slug>-plan.md

Changes:
* .copilot-tracking/changes/<date>/<task-slug>-changes.md

Compare the implementation and validation evidence with every plan requirement.
```

### Review Output

`rpi-review` writes a dated acceptance record under
`.copilot-tracking/reviews/logs/`. It reports review execution separately from
the outcome and routes any implementation, decision, or evidence gaps to the
appropriate next action.

## Alternative: Coordinated Lifecycle with RPI Agent

The four-skill workflow above separates research, planning, implementation, and
review. This is useful while learning RPI because you see the evidence each
phase produces.

For day-to-day work, select
[RPI Agent](https://github.com/microsoft/hve-core/blob/main/.github/CUSTOM-AGENTS.md#rpi-agent).
It coordinates the same phase skills and includes Review and Follow-up
when the task reaches those stages.

To compare the experience, select **RPI Agent** from the agent picker and try
this prompt:

> Create a PowerShell script that validates the required Getting Started journey
> pages exist. Place it at scripts/linting/Test-GettingStartedJourney.ps1, add an
> npm script entry, validate the result, and review it against the plan.

RPI Agent coordinates the applicable skills without requiring manual agent
switches between phases.

## What You Learned

* Use `/clear` when accumulated context no longer serves the next phase.
* Research reduces unknowns by discovering patterns before coding.
* The plan gives `rpi-implement` clear requirements, acting as a specification.
* The changes record gives Review implementation and validation evidence.
* Durable artifacts bridge phases without depending on chat history.

## Troubleshooting

| Issue                 | Solution                                                                                   |
|-----------------------|--------------------------------------------------------------------------------------------|
| PowerShell not found  | Ensure `pwsh` is installed and in PATH                                                     |
| npm script not found  | Check `package.json` was saved                                                             |
| Wrong folders checked | Verify script targets `docs/*` pattern                                                     |
| A phase lacks context | Name the preceding durable artifact; see [Context Engineering](../rpi/context-engineering) |

## Next Step

You've completed your first full RPI cycle. The methodology works the same
way for any task: research the unknowns, plan the approach, implement from
the plan.

Continue your journey through the
[New Contributor Milestones](../hve-guide/roles/new-contributor#milestone-3-independent-workflow),
where Milestone 3 guides you through your first independent workflow on a
task you choose yourself.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
