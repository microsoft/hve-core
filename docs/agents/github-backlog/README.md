---
title: GitHub Backlog Manager
description: Automated issue discovery, triage, sprint planning, and execution for GitHub repositories
author: Microsoft
ms.date: 2026-02-12
ms.topic: concept
keywords:
  - github backlog manager
  - issue management
  - triage
  - sprint planning
  - github copilot
estimated_reading_time: 5
---

The GitHub Backlog Manager automates issue lifecycle management across GitHub repositories. It coordinates five specialized workflows (discovery, triage, sprint planning, execution, and quick add) through planning files and handoff artifacts, applying consistent labels, detecting duplicates, and organizing issues into milestones with configurable autonomy levels.

> Backlog management is a constraint-satisfaction problem. Each workflow handles a bounded scope, reducing errors by limiting the decisions any single step makes.

## Why Use the Backlog Manager?

* 🏷️ Consistency: Every issue receives labels, priority, and milestone assignment following the same taxonomy, eliminating drift across contributors
* 🔍 Visibility: Discovery workflows surface issues from code changes, team assignments, and cross-repository searches, so nothing falls through gaps
* ⚡ Throughput: Automated triage and sprint planning handle repetitive decisions, freeing your team for engineering work

> [!TIP]
> For the full rationale and quality comparison, see [Why the Backlog Manager Works](why-backlog-manager.md).

## The Five Workflows

### 🔍 Discovery

Discovery finds and categorizes issues from multiple sources. Three discovery paths cover different starting points: user-centric (assigned issues), artifact-driven (local code changes mapped to backlog items), and search-based (criteria-driven queries across repositories). Discovery produces issue analysis files that feed into triage.

See the [Discovery workflow guide](discovery.md) for paths, artifacts, and examples.

### 🏷️ Triage

Triage assigns labels, assesses priority, and detects duplicates for discovered issues. It applies a 17-label taxonomy organized by type, area, priority, and lifecycle categories. Conventional commit patterns in issue titles inform label suggestions. A four-aspect similarity framework flags potential duplicates before they create noise.

See the [Triage workflow guide](triage.md) for the label taxonomy and duplicate detection.

### 📋 Sprint Planning

Sprint planning organizes triaged issues into milestones with capacity awareness. A six-step milestone discovery process matches issues to existing or new milestones. The workflow assesses issue volume against team capacity and recommends distribution across sprints.

See the [Sprint Planning workflow guide](sprint-planning.md) for milestone discovery and capacity planning.

### ⚡ Execution

Execution consumes handoff files produced by earlier workflows and performs the planned operations. It creates, updates, and closes issues according to the plan, tracking each operation with checkbox-based progress and per-operation logging. Failed operations log errors without blocking the rest of the batch.

See the [Execution workflow guide](execution.md) for handoff consumption and operation logging.

### ➕ Quick Add

Quick Add is a single-issue shortcut for creating one issue without running the full pipeline. Use it when you need to file an issue quickly and apply standard labels and milestone in a single step.

## Autonomy Levels

The backlog manager operates at three autonomy tiers, controlling which operations proceed automatically and which pause for approval.

| Tier              | Create | Labels/Milestone | Close | Comment |
|-------------------|--------|------------------|-------|---------|
| Full              | Auto   | Auto             | Auto  | Auto    |
| Partial (default) | Gate   | Auto             | Gate  | Auto    |
| Manual            | Gate   | Gate             | Gate  | Gate    |

Partial autonomy is the default, applying labels and milestones automatically while gating issue creation and closure for review. Adjust the tier based on repository maturity and team trust.

## When to Use

| Use Backlog Manager When...                     | Use Manual Management When...             |
|-------------------------------------------------|-------------------------------------------|
| Managing more than 20 open issues               | Working with fewer than 10 issues         |
| Multiple contributors need consistent triage    | Single maintainer with full context       |
| Sprint planning requires milestone organization | No milestone-based planning process       |
| Cross-repository issue discovery is needed      | All issues originate from a single source |
| Label consistency matters for reporting         | Ad-hoc labeling suits the workflow        |

## Quick Start

1. Configure your MCP servers following the [MCP Configuration guide](../../getting-started/mcp-configuration.md)
2. Open a Copilot Chat session and type: `Discover open issues assigned to me`
3. Review the discovery output, then type `/clear` and start a triage session
4. Continue through sprint planning and execution as needed

> [!IMPORTANT]
> Clear context between workflows by typing `/clear`. Each workflow operates independently and mixing contexts produces unreliable results.

## Prerequisites

The GitHub Backlog Manager requires MCP server configuration for GitHub API access. See [MCP Configuration](../../getting-started/mcp-configuration.md) for setup instructions. The GitHub MCP tools (listed in the agent specification) must be available in your VS Code context.

> [!NOTE]
> The GitHub Backlog Manager replaces the deprecated `github-issue-manager` agent. If you have prompts or workflows referencing `github-issue-manager`, update them to use `github-backlog-manager` instead.

## Next Steps

* [Discovery](discovery.md) - Find and categorize issues from multiple sources
* [Triage](triage.md) - Assign labels, priorities, and detect duplicates
* [Sprint Planning](sprint-planning.md) - Organize issues into milestones
* [Execution](execution.md) - Execute planned operations from handoff files
* [Using Workflows Together](using-together.md) - End-to-end pipeline walkthrough
* [Why the Backlog Manager Works](why-backlog-manager.md) - Design rationale and quality comparison

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
