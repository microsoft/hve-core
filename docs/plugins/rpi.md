---
title: RPI
description: Skill-forward Research, Plan, Implement, Review, and Follow-up entry points with bounded planning and critique support.
sidebar_position: 13
author: Microsoft
ms.date: 2026-08-03
ms.topic: reference
---

Choose this package when your primary need is the Research, Plan, Implement, Review, and Follow-up workflow.

It provides skill-forward lifecycle entry points, bounded planning and critique support, and dedicated planner and researcher subagents.

Lifecycle labels are disclosure metadata. In the channel model, Stable and PreRelease have equal active content, including components labeled stable, preview, and experimental; publication cadence and source ownership can differ.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name               | Maturity | Description                                                                                                                                           |
|--------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| **rpi-planner**    | stable   | Revise one assigned RPI plan phase and matching phase details within a shared planning artifact. Use when a parent needs bounded phase authoring.     |
| **rpi-researcher** | stable   | Executes one delegated internal, external, or hybrid RPI research lane and progressively writes owned evidence. Use for independent research threads. |

### Instructions

| Name                          | Maturity | Description                                                                                    |
|-------------------------------|----------|------------------------------------------------------------------------------------------------|
| **hve-core/copilot-tracking** | stable   | Shared .copilot-tracking conventions for RPI, HVE Builder, and compatibility workflow evidence |

### Skills

| Name                  | Maturity | Description                                                                                                                                                                                                                                                                                  |
|-----------------------|----------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **rpi-challenger**    | stable   | Challenge a confirmed task, decision, plan, or artifact through adaptive skeptical questions. Use when you need to expose assumptions before acting.                                                                                                                                         |
| **rpi-implement**     | stable   | Execute an approved RPI plan, maintain current planning state, and record implementation evidence. Use when implementation is ready to begin or resume.                                                                                                                                      |
| **rpi-plan**          | stable   | Create evidence-based RPI plans and phase details from supplied context, research, drafts, and decisions. Use when implementation planning is needed.                                                                                                                                        |
| **rpi-plan-critique** | stable   | Independently critique an RPI plan and phase details against supplied evidence without editing plan sources. Use when planning credibility needs a read-only assessment.                                                                                                                     |
| **rpi-quick**         | stable   | Sequence Research, Plan, Implement, Review, and Follow-up for an RPI task. Use when one workflow should coordinate the full delivery lifecycle.                                                                                                                                              |
| **rpi-research**      | stable   | Research-only RPI playbook that gathers task evidence, writes dated research artifacts under .copilot-tracking/research/, and hands off planning-ready findings. Use when the user needs evidence, alternatives, or task framing first.                                                      |
| **rpi-review**        | stable   | Compare RPI planning and implementation evidence, record review findings, and route follow-up work. Use when an implementation needs acceptance review.                                                                                                                                      |
| **rpi-walkthrough**   | stable   | Guided, conversational walkthrough that explains code, UI, UX, features, or .copilot-tracking artifacts with navigable evidence links, deep subagent review, and a reconciled decisions-and-changes ledger. Use when the user wants to understand how something works or why it was changed. |

<!-- END AUTO-GENERATED ARTIFACTS -->

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
