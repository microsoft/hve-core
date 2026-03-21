---
title: Entry Modes
description: Guide to the SSSC Planner's four entry modes including capture, from-PRD, from-BRD, and from-security-plan workflows
sidebar_position: 4
sidebar_label: Entry Modes
keywords:
  - sssc planner
  - entry modes
  - from-prd
  - from-brd
  - from-security-plan
  - capture
tags:
  - agents
  - security
author: Microsoft
ms.date: 2026-03-18
ms.topic: how-to
estimated_reading_time: 5
---

The SSSC Planner supports four entry modes that control how Phase 1 scoping begins. Each mode is activated through a dedicated prompt file that sets the initial state and determines how much context the agent gathers before starting the supply chain assessment.

## Capture Mode

Capture mode starts with a blank Phase 1 interview. Use this mode when no formal requirements documents exist or when you want to walk through scoping from scratch.

### How It Works

1. The agent creates the project directory under `.copilot-tracking/sssc-plans/`.
2. State is initialized with `entryMode: "capture"` and empty `referencesProcessed`.
3. Phase 1 begins with a structured interview, asking 3-5 questions per turn covering technology stack, package managers, CI platform, release strategy, and compliance targets.
4. The agent accumulates scope information across multiple turns until the user confirms Phase 1 is complete.

### Prompt File

Activate capture mode with the **SSSC Capture** prompt (`sssc-capture.prompt.md`). This prompt accepts an optional `project-slug` input parameter.

### When to Choose Capture Mode

| Situation                                        | Fit |
|--------------------------------------------------|-----|
| No PRD, BRD, or security plan available          | ✅   |
| Team wants to explore the workflow interactively | ✅   |
| Existing informal notes to incorporate           | ✅   |
| Well-documented project with formal artifacts    | ❌   |

## From-PRD Mode

From-PRD mode seeds Phase 1 from PRD artifacts already present in the workspace. Use this mode when product requirements documents exist under `.copilot-tracking/`.

### How It Works

1. The agent scans `.copilot-tracking/` for PRD files.
2. Discovered artifacts are presented with ✅/❌ markers showing which were found.
3. The agent extracts scope information: technology stack, package managers, CI platform, release strategy, and compliance targets.
4. State is initialized with `entryMode: "from-prd"` and the extracted references stored in `referencesProcessed`.
5. Phase 1 begins with a checklist of pre-filled items and 3-5 clarifying questions for gaps.

### Prompt File

Activate From-PRD mode with the **SSSC From PRD** prompt (`sssc-from-prd.prompt.md`). This prompt accepts an optional `project-slug` input parameter.

### When to Choose From-PRD Mode

| Situation                                   | Fit |
|---------------------------------------------|-----|
| PRD artifacts exist in `.copilot-tracking/` | ✅   |
| Product requirements are well-documented    | ✅   |
| Early-stage project without formal docs     | ❌   |
| Completed security plan available           | ❌   |

## From-BRD Mode

From-BRD mode seeds Phase 1 from BRD artifacts already present in the workspace. Use this mode when business requirements documents exist under `.copilot-tracking/`.

### How It Works

1. The agent scans `.copilot-tracking/` for BRD files.
2. Discovered artifacts are presented with ✅/❌ markers showing which were found.
3. The agent extracts scope information from business requirements, mapping business capabilities to technology stack and compliance targets.
4. State is initialized with `entryMode: "from-brd"` and the extracted references stored in `referencesProcessed`.
5. Phase 1 begins with a checklist of pre-filled items and 3-5 clarifying questions for gaps.

### Prompt File

Activate From-BRD mode with the **SSSC From BRD** prompt (`sssc-from-brd.prompt.md`). This prompt accepts an optional `project-slug` input parameter.

### When to Choose From-BRD Mode

| Situation                                      | Fit |
|------------------------------------------------|-----|
| BRD artifacts exist in `.copilot-tracking/`    | ✅   |
| Business requirements are well-documented      | ✅   |
| Early-stage project without formal docs        | ❌   |
| PRD is more detailed than BRD for this project | ❌   |

## From-Security-Plan Mode

From-Security-Plan mode seeds Phase 1 from an existing Security Planner state file. Use this mode when a security plan has already been completed and you want to extend the analysis with supply chain coverage.

### How It Works

1. The agent reads the Security Planner's `state.json` from `.copilot-tracking/security-plans/{project-slug}/`.
2. Scope information (technology stack, deployment model, data classification) is inherited from the security plan.
3. State is initialized with `entryMode: "from-security-plan"` and `securityPlannerLink` set to the source state file path.
4. Phase 1 begins with inherited scope pre-filled and 3-5 clarifying questions for supply-chain-specific gaps (package managers, CI platform, release strategy).

### Prompt File

Activate From-Security-Plan mode with the **SSSC From Security Plan** prompt (`sssc-from-security-plan.prompt.md`). This prompt accepts an optional `project-slug` input parameter.

### When to Choose From-Security-Plan Mode

| Situation                                          | Fit |
|----------------------------------------------------|-----|
| Completed Security Planner state file exists       | ✅   |
| Want to extend security analysis with supply chain | ✅   |
| No prior security plan                             | ❌   |
| Security plan is outdated or incomplete            | ❌   |

## Comparing the Four Modes

All four modes converge at the same Phase 1 output. The difference is how much context the agent starts with.

| Aspect               | Capture                     | From-PRD                   | From-BRD                    | From-Security-Plan                    |
|----------------------|-----------------------------|----------------------------|-----------------------------|---------------------------------------|
| Initial context      | Gathered through interview  | Extracted from PRD         | Extracted from BRD          | Inherited from security plan          |
| Number of questions  | More (full scope interview) | Fewer (gaps only)          | Fewer (gaps only)           | Fewest (supply-chain gaps only)       |
| Time to Phase 2      | Slower but more thorough    | Faster                     | Faster                      | Fastest                               |
| State initialization | `entryMode: "capture"`      | `entryMode: "from-prd"`    | `entryMode: "from-brd"`     | `entryMode: "from-security-plan"`     |
| Best for             | Projects in early stages    | Projects with product docs | Projects with business docs | Projects with completed security plan |

## Switching Between Modes

Entry mode is set once during Phase 1 initialization and cannot be changed mid-plan. To switch modes, start a new chat session with the other prompt file and a different project slug (or the same slug after removing the existing state directory).

> [!NOTE]
> All four modes produce identical Phase 2-6 workflows. The choice only affects how Phase 1 scope is gathered.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
