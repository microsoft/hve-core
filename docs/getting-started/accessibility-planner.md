---
title: Accessibility Planner Quickstart
description: A five-minute walkthrough of starting the Accessibility Planner, selecting frameworks, mapping success criteria, and handing off a dual-format backlog
sidebar_position: 10
sidebar_label: Accessibility Planner Quickstart
keywords:
  - accessibility planner
  - quickstart
  - WCAG 2.2
  - Section 508
  - getting started
author: Microsoft
ms.date: 2026-05-28
ms.topic: tutorial
estimated_reading_time: 5
---

This quickstart walks you through a first Accessibility Planner session: starting the agent, selecting frameworks, mapping success criteria, and handing off a backlog. The full agent reference lives in [Accessibility Planner](../agents/accessibility/accessibility-planner.md).

> [!NOTE]
> The planner produces planning artifacts, not a conformance certification. Findings still require review by a qualified accessibility professional.

## Prerequisites

* The Accessibility collection installed (see [Collections](collections.md)).
* A workspace with the product surfaces you intend to assess, or a PRD, BRD, RAI plan, or security plan to seed Phase 1.

## Step 1: Start the planner

Open the chat agent picker and select **Accessibility Planner**. The agent reads or creates `state.json` under `.copilot-tracking/accessibility/{project-slug}/` and begins Phase 1 (Discovery).

If no upstream artifact exists, the planner enters capture mode and asks three to five focused questions per turn to build the surface inventory, audience scope, and regulatory drivers. If a PRD, BRD, RAI plan, or security plan exists, the matching entry mode pre-populates discovery and asks you to confirm the extracted values.

## Step 2: Select frameworks

At Phase 2, the planner presents the five supported frameworks as a multi-select, with `wcag-22@AA` and `section-508` pre-checked as defaults:

* `wcag-22`: WCAG 2.2 success criteria
* `aria-apg`: ARIA Authoring Practices
* `coga`: Cognitive Accessibility
* `section-508`: Section 508 (Revised)
* `en-301-549`: EN 301 549

Confirm the conformance level for each framework you keep, and record a reason for any framework you disable.

## Step 3: Map success criteria

In Phase 3, the planner maps your in-scope surfaces against the selected frameworks. Each success criterion resolves to a target compliance state with an evidence pointer. Criteria shared across frameworks emit cross-references so you map them once.

## Step 4: Assess risk and evidence

Phases 4 and 5 classify the plan-level risk tier and build the evidence register, tradeoff log, and work-item seeds. For each unresolved gap, you record either a mitigation or an accept-with-tradeoff decision.

## Step 5: Hand off the backlog

At Phase 6, the planner renders the work-item seeds into dual-format ADO and GitHub backlog files, attaches autonomy tiers, sanitizes content, and emits the planning disclaimer. Import the format that matches your tracking system.

## Next Steps

* [Cross-Planner Integration](cross-planner-integration.md) for how accessibility evidence flows to and from the Security, RAI, and SSSC planners.
* [Accessibility Reviewer](../agents/accessibility/accessibility-reviewer.md) to audit a codebase against the same frameworks.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
