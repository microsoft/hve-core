---
title: Export DT Artifacts to Mural
description: Optional workflow for exporting Design Thinking artifacts from HVE Core to Mural boards
sidebar_position: 8
author: Microsoft
ms.date: 2026-03-26
ms.topic: how-to
keywords:
  - design thinking
  - mural
  - mcp
  - workshop
estimated_reading_time: 6
---

The Design Thinking collection includes an optional Mural export prompt for teams who want to move `.copilot-tracking/dt/` artifacts onto collaborative whiteboards.

## When to Use

Use Mural export when your team wants to review or facilitate around artifacts such as:

* Method 1 stakeholder maps and constraints
* Method 3 synthesis themes and evidence clusters
* Method 4 idea clusters and convergence candidates
* Method 5 concepts and evaluation notes
* Method 6 prototype plans and testing hypotheses

The export is additive to Design Thinking coaching. It does not replace `.copilot-tracking/dt/` artifacts.

## Prerequisites

* A completed or in-progress DT project under `.copilot-tracking/dt/{project-slug}/`
* Access to a Mural workspace and room
* A `mural` MCP server configured in your workspace

HVE Core does not ship Mural as a curated MCP server because it requires user-managed OAuth credentials and local installation.

## Setup

### Repository Clone Workflow

If you are working directly in a clone of `hve-core`:

1. Copy `.mural-credentials.example` to `.mural-credentials`.
2. Add your `MURAL_CLIENT_ID` and `MURAL_CLIENT_SECRET` values.
3. Run `npm run mcp:setup:mural`.
4. Add the `mural` server entry from [MCP Server Configuration](../getting-started/mcp-configuration.md).
5. Restart VS Code.

### Extension-Only Workflow

If you use the Marketplace extension without cloning `hve-core`, follow the same Mural app and OAuth setup manually. The repository scripts are convenience helpers, not a hard dependency of the prompt itself.

## Prompt Invocation

Run the prompt from Copilot Chat:

```text
/dt-mural-export project-slug=factory-floor-maintenance
```

Optional arguments:

```text
/dt-mural-export project-slug=customer-support-ai board-title="Customer Support AI Assistant - Stakeholder Map" method=1
```

```text
/dt-mural-export project-slug=warehouse-onboarding method=3
```

## What the Prompt Does

1. Reads the DT coaching state and relevant artifacts from `.copilot-tracking/dt/{project-slug}/`
2. Verifies that the `mural` MCP server is available
3. Asks you to confirm workspace, room, and board destination when needed
4. Lays out sections, labels, and sticky notes based on method-specific artifact structure
5. Reports the board URL and export summary after creation or update

## Troubleshooting

### Mural Tools Are Unavailable

Confirm that your workspace `.vscode/mcp.json` includes the `mural` server and that VS Code shows it under MCP Servers.

### Authentication Fails

Repository-clone users SHOULD rerun `npm run mcp:setup:mural`. The setup script detects missing, invalid, and expired tokens and restarts OAuth when needed.

### No DT Artifacts Found

Confirm that `.copilot-tracking/dt/{project-slug}/coaching-state.md` exists and that the target method artifacts were generated before invoking export.

## Related Resources

* [Design Thinking Guide](README.md)
* [Using the DT Coach](dt-coach.md)
* [MCP Server Configuration](../getting-started/mcp-configuration.md)

> Brought to you by microsoft/hve-core

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->