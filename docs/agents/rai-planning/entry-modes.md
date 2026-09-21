---
title: Entry Modes
description: Three ways to start a RAI assessment with the RAI Planner agent including capture, from-prd, and from-security-plan modes
sidebar_position: 4
sidebar_label: Entry Modes
keywords:
  - RAI Planner
  - entry modes
  - capture mode
  - from-prd
  - from-security-plan
tags:
  - rai-planning
  - how-to
author: Microsoft
ms.date: 2026-09-10
ms.topic: how-to
estimated_reading_time: 5
---

## Capture Mode

Use capture mode when starting a Responsible AI assessment from scratch with no prior artifacts. The agent conducts a full interview about the AI system, building understanding from the ground up.

### How It Works

1. Provide an optional project slug or let the agent derive one from your project name
2. The agent resolves attached-material pointers and output preferences
3. The agent creates `.copilot-tracking/rai-plans/{project-slug}/` and initializes `state.json` with `entryMode: "capture"` and `currentPhase: 1`, then enters the Phase 1 preflight
4. After preflight and reference discovery, Phase 1 begins with up to 7 questions covering: AI system purpose, technology stack, model types, stakeholder roles, data inputs and outputs, deployment model, and intended use context
5. Answer questions conversationally; use "skip" or "n/a" for items that do not apply
6. The agent summarizes findings and asks for confirmation before advancing to Phase 2

Prompt file: `.github/prompts/rai-planning/rai-capture.prompt.md`

### When to Choose Capture Mode

| Signal                                                 | Recommendation   |
|--------------------------------------------------------|------------------|
| No PRD, BRD, or security plan exists                   | Use capture mode |
| Exploring whether an AI system needs RAI assessment    | Use capture mode |
| Standalone AI project without broader security context | Use capture mode |
| Rapid prototyping with an evolving scope               | Use capture mode |

## From-PRD Mode

Use from-prd mode when product requirements documents or business requirements documents already exist in `.copilot-tracking/`. The agent extracts AI system scope, stakeholders, and technology stack from these artifacts, reducing the Phase 1 interview to confirmation and gap-filling.

### How It Works

1. The agent resolves the PRD pointer and output preferences
2. The agent creates `.copilot-tracking/rai-plans/{project-slug}/` and initializes `state.json` with `entryMode: "from-prd"` and `currentPhase: 1`, then enters the Phase 1 preflight
3. During project-material discovery in the preflight, the agent reads the PRD and extracts AI system scope, technology stack, model types, deployment model, and stakeholders
4. Phase 1 begins with pre-populated fields; the agent asks clarifying questions targeting gaps in the extracted information

Prompt file: `.github/prompts/rai-planning/rai-plan-from-prd.prompt.md`

### When to Choose From-PRD Mode

| Signal                                                               | Recommendation                          |
|----------------------------------------------------------------------|-----------------------------------------|
| PRD or BRD artifacts exist in `.copilot-tracking/`                   | Use from-prd mode                       |
| Product requirements are well-documented but no security plan exists | Use from-prd mode                       |
| Multiple stakeholders contributed to product definition              | Use from-prd mode to leverage that work |

## From-Security-Plan Mode

Use from-security-plan mode after completing a security plan with the Security Planner. This is the recommended entry mode for most assessments because it inherits AI component data, continues threat ID sequences, and provides the richest starting context.

### How It Works

1. The agent validates the security-plan pointer and resolves output preferences
2. The agent creates `.copilot-tracking/rai-plans/{project-slug}/` and initializes `state.json` with `entryMode: "from-security-plan"` and `currentPhase: 1`, then enters the Phase 1 preflight
3. During project-material discovery in the preflight, the agent reads the security plan `state.json` and extracts AI components from its `aiComponents` array
4. Threat IDs start at the next sequence after the security plan's threat count, maintaining continuity across both assessments
5. Phase 1 begins with pre-populated AI element inventory; the agent asks targeted questions about RAI-specific aspects not covered in the security plan

Prompt file: `.github/prompts/rai-planning/rai-plan-from-security-plan.prompt.md`

### When to Choose From-Security-Plan Mode

| Signal                                                            | Recommendation              |
|-------------------------------------------------------------------|-----------------------------|
| Security Planner has completed with `raiEnabled: true`            | Use from-security-plan mode |
| The security plan identified AI or ML components                  | Use from-security-plan mode |
| You want threat ID continuity across security and RAI assessments | Use from-security-plan mode |

> [!NOTE]
> The Security Planner recommends this entry mode during its Phase 6 handoff when `raiEnabled` is true. The RAI Planner reads security plan artifacts as read-only and never modifies files under `.copilot-tracking/security-plans/`.

## Comparing Entry Modes

| Aspect                 | Capture                        | From-PRD                     | From-Security-Plan                 |
|------------------------|--------------------------------|------------------------------|------------------------------------|
| Initial context        | None                           | Product requirements         | Security plan with AI components   |
| AI component discovery | Manual via interview           | Extracted from PRD artifacts | Pre-populated from security plan   |
| Threat ID continuity   | Starts at `T-RAI-001`          | Starts at `T-RAI-001`        | Continues from security plan count |
| Time to Phase 2        | Longest                        | Medium                       | Shortest                           |
| Best for               | Fresh assessments, exploratory | Projects with product docs   | Recommended post-security-plan     |

## After Choosing a Mode

Once Phase 1 completes, all three modes converge into the same workflow for Phases 2 through 6. The entry mode is recorded in `state.json` and cannot change after assessment begins.

See [Phase Reference](phase-reference) for the complete specification of each phase.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
