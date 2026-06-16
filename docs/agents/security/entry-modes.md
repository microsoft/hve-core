---
title: Entry Modes
description: Detailed guide to the Security Planner's From-PRD and capture entry modes, including prompt usage and workflow differences
sidebar_position: 4
sidebar_label: Entry Modes
keywords:
  - security planner
  - entry modes
  - from-prd
  - capture
tags:
  - agents
  - security
author: Microsoft
ms.date: 2026-03-11
ms.topic: how-to
estimated_reading_time: 5
---

The Security Planner supports two entry modes that control how Phase 1 scoping begins. Each mode is activated through a dedicated prompt file that sets the initial state and determines how much context the agent gathers before starting the analysis.

## From-PRD Mode

From-PRD mode seeds Phase 1 from PRD or BRD artifacts already present in the workspace. Use this mode when formal requirements documents exist under `.copilot-tracking/`.

### How It Works

1. The agent scans `.copilot-tracking/` for PRD and BRD files.
2. Discovered artifacts are presented with ✅/❌ markers showing which were found.
3. The agent extracts six categories of scope information: project purpose, technology stack, deployment model, data classification, compliance requirements, and AI/ML components.
4. State is initialized with `entryMode: "from-prd"` and the extracted references stored in `referencesProcessed`.
5. Phase 1 begins with a checklist of pre-filled items and 3-5 clarifying questions for gaps.

### Prompt File

Activate From-PRD mode with the **Security Plan from PRD** prompt (`security-plan-from-prd.prompt.md`). This prompt accepts an optional `project-slug` input parameter.

```text
Inputs:
  project-slug (optional) - Kebab-case project identifier
```

### When to Choose From-PRD Mode

| Situation                                          | Fit |
|----------------------------------------------------|-----|
| PRD or BRD artifacts exist in `.copilot-tracking/` | ✅   |
| Product requirements are well-documented           | ✅   |
| Early-stage project without formal docs            | ❌   |
| Quick exploration of the agent's workflow          | ❌   |

## Capture Mode

Capture mode starts with a blank Phase 1 interview. Use this mode when no formal requirements documents exist or when you want to walk through scoping from scratch.

### How It Works

1. The agent creates the project directory under `.copilot-tracking/security-plans/`.
2. State is initialized with `entryMode: "capture"` and empty `referencesProcessed`.
3. Phase 1 begins with a structured interview, asking 3-5 questions per turn.
4. The agent accumulates scope information across multiple turns until the user confirms Phase 1 is complete.

### Prompt File

Activate capture mode with the **Security Capture** prompt (`security-capture.prompt.md`). This prompt also accepts an optional `project-slug` input parameter.

```text
Inputs:
  project-slug (optional) - Kebab-case project identifier
```

If the user provides existing security notes or context in the initial message, the agent incorporates them into the interview rather than asking redundant questions.

### When to Choose Capture Mode

| Situation                                        | Fit |
|--------------------------------------------------|-----|
| No PRD or BRD artifacts available                | ✅   |
| Team wants to explore the workflow interactively | ✅   |
| Existing informal notes to incorporate           | ✅   |
| Well-documented project with formal artifacts    | ❌   |

## Comparing the Two Modes

Both modes converge at the same Phase 1 output. The difference is how much context the agent starts with.

| Aspect               | From-PRD                             | Capture                     |
|----------------------|--------------------------------------|-----------------------------|
| Initial context      | Extracted from PRD/BRD               | Gathered through interview  |
| Number of questions  | Fewer (gaps only)                    | More (full scope interview) |
| Time to Phase 2      | Faster                               | Slower but more thorough    |
| State initialization | `entryMode: "from-prd"`              | `entryMode: "capture"`      |
| Best for             | Projects with existing documentation | Projects in early stages    |

## Switching Between Modes

Entry mode is set once during Phase 1 initialization and cannot be changed mid-plan. To switch modes, start a new chat session with the other prompt file and a different project slug (or the same slug after removing the existing state directory).

> [!NOTE]
> Both modes produce identical Phase 2-6 workflows. The choice only affects how Phase 1 scope is gathered.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
