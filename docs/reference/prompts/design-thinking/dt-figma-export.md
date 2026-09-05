---
title: Dt Figma Export
description: Export Design Thinking artifacts to a FigJam board or Figma Design file via the Figma MCP server
sidebar_position: 2
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - design-thinking
  - dt-figma-export
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                       |
|-------------|-------------------------------------------------------------|
| Kind        | prompt                                                      |
| Source      | `.github/prompts/design-thinking/dt-figma-export.prompt.md` |
| Invocation  | Slash command `/dt-figma-export`                            |
| Interactive | Yes                                                         |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Export Design Thinking artifacts to a FigJam board or Figma Design file via the Figma MCP server
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt to publish existing Design Thinking artifacts to a FigJam board or Figma Design file for collaboration. Use the canonical artifact workflow first when the project content is incomplete or unverified.

## How to use it

Before running the prompt, confirm these prerequisites:

* The DT project artifacts exist under `.copilot-tracking/dt/{project-slug}/`.
* The `figma` MCP server is configured in your workspace. Add `{"figma": {"type": "http", "url": "https://mcp.figma.com/mcp"}}` to the `servers` object in `.vscode/mcp.json`, then restart VS Code.
* You have a Figma account with a Dev or Full seat on a Professional, Organization, or Enterprise plan for sustained usage. Starter plans are limited to 6 tool calls per month.
* Authentication happens through browser OAuth on first use, so no credential files or API keys are required.

Provide the `project-slug` and optionally choose a board title, method, and output type. Confirm the destination and authorization before the prompt creates or changes an external Figma file, then review the exported content for fidelity.

## Example usage

```text
/dt-figma-export project-slug=factory-floor-maintenance method=3 output-type=figjam
```

After confirmation, the prompt exports the recorded Method 3 artifacts to a FigJam board without inventing missing content.
