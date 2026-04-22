---
title: Export DT Artifacts to Figma
description: Optional workflow for exporting Design Thinking artifacts from HVE Core to FigJam boards and Figma Design files
sidebar_position: 8
author: Microsoft
ms.date: 2026-03-27
ms.topic: how-to
keywords:
  - design thinking
  - figma
  - figjam
  - mcp
  - workshop
estimated_reading_time: 5
---

The Design Thinking collection includes an optional Figma export prompt for teams who want to move `.copilot-tracking/dt/` artifacts onto collaborative boards or structured design files.

## When to Use

Use Figma export when your team wants to review or facilitate around artifacts such as:

* Method 1 stakeholder maps and constraints
* Method 3 synthesis themes and evidence clusters
* Method 4 idea clusters and convergence candidates
* Method 5 concepts and evaluation notes
* Method 6 prototype plans and testing hypotheses

The export is additive to Design Thinking coaching. It does not replace `.copilot-tracking/dt/` artifacts.

## Output Types

| Type                 | Tool              | Best For                                                                                                     |
|----------------------|-------------------|--------------------------------------------------------------------------------------------------------------|
| **FigJam** (default) | FigJam board      | Collaborative whiteboarding: sticky notes, text, connectors, and diagrams. Closest to workshop facilitation. |
| **Design**           | Figma Design file | Structured frames with auto-layout for higher-fidelity visual outputs. Good for stakeholder presentations.   |
| **Both**             | One of each       | Teams that want both a working board and a polished summary.                                                 |

## Prerequisites

* A completed or in-progress DT project under `.copilot-tracking/dt/{project-slug}/`
* A Figma account with a Dev or Full seat on a Professional, Organization, or Enterprise plan (recommended for sustained usage)
* The `figma` MCP server configured in your workspace

## Setup

Add the Figma MCP server to `.vscode/mcp.json`:

```json
{
  "servers": {
    "figma": {
      "type": "http",
      "url": "https://mcp.figma.com/mcp"
    }
  }
}
```

No local installation, API keys, or credential files are required. The Figma MCP server is hosted by Figma and handles authentication via browser OAuth on first use.

After adding the configuration, restart VS Code. You can verify the connection by typing `#whoami` in GitHub Copilot Chat, which should return your Figma identity and plan details.

## Usage

### Basic export (FigJam board from latest method)

```text
/dt-figma-export project-slug=factory-floor-maintenance
```

### Export a specific method

```text
/dt-figma-export project-slug=customer-support-ai method=1 board-title="Stakeholder Map"
```

### Export as Figma Design file

```text
/dt-figma-export project-slug=warehouse-onboarding method=3 output-type=design
```

### Export both formats

```text
/dt-figma-export project-slug=incident-response output-type=both
```

## What Gets Exported

### FigJam Boards

FigJam exports create a collaborative whiteboard with:

* Header section with project name, method name, date, and status.
* Theme/category sections arranged left to right with color-coded sticky notes.
* Mermaid-generated diagrams for stakeholder relationships (M1), theme-evidence clusters (M3), and test flows (M8).
* Footer section with summary, open questions, or how-might-we prompts.

### Figma Design Files

Design file exports create structured frames with:

* Auto-layout frames with consistent spacing and alignment across all content.
* Card components where each artifact item is rendered as a styled card with background colors indicating type (evidence, insight, question, decision, constraint).
* Typography hierarchy using title (24px), body (16px), and label (12px) text.

## Rate Limits

The Figma MCP server applies rate limits based on your Figma plan:

| Plan                                                      | Limit                                     |
|-----------------------------------------------------------|-------------------------------------------|
| Starter, View, or Collab seats                            | Up to 6 tool calls per month              |
| Dev or Full seats on Professional/Organization/Enterprise | Per-minute limits (Figma REST API Tier 1) |

A typical DT export session uses 5-15 tool calls depending on the number of artifacts. Teams on Starter plans should batch their exports carefully.

## Beta Notice

The `use_figma` write capability is currently in beta and free during the beta period. Figma has indicated this will eventually become a usage-based paid feature. Read-only tools (`get_figjam`, `get_screenshot`, `generate_diagram`) are unaffected.

## Troubleshooting

| Issue                       | Solution                                                                             |
|-----------------------------|--------------------------------------------------------------------------------------|
| `figma` tools not available | Add the Figma server to `.vscode/mcp.json` and restart VS Code                       |
| Authentication fails        | Ensure your browser can reach `mcp.figma.com` and complete the OAuth flow            |
| Rate limit exceeded         | Check your Figma plan; upgrade to a Dev or Full seat for higher limits               |
| `use_figma` rejects writes  | Verify you have edit access to the target Figma file or create a new one             |
| Large exports timeout       | Break the export into per-method calls instead of exporting the full project at once |

## Next Steps

* [DT Coach Guide](dt-coach.md): Overview of the coaching agent and session workflow
* [Design Thinking Guide](README.md): All nine methods and three spaces

> Brought to you by microsoft/hve-core
