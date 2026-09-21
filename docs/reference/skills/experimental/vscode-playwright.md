---
title: vscode-playwright
description: VS Code screenshot capture using Playwright MCP with serve-web for slide decks and documentation
sidebar_position: 9
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - experimental
  - vscode-playwright
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                               |
|-------------|-------------------------------------------------------------------------------------|
| Kind        | skill                                                                               |
| Source      | `.github/skills/experimental/vscode-playwright`                                     |
| Invocation  | Invoked directly as `/vscode-playwright`, or loaded on demand by referencing agents |
| Interactive | No                                                                                  |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
VS Code screenshot capture using Playwright MCP with serve-web for slide decks and documentation
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill to capture a focused VS Code editor or Copilot Chat view for
documentation or slides. It starts a separate `serve-web` instance, configures a
temporary editor environment, and captures through Playwright MCP. It is not a
general application test suite or a way to capture the desktop editor directly.

The workflow needs the VS Code CLI, compatible Playwright tools, and `curl`.
Service startup, server downloads, license acceptance, workspace trust, and any
chat interaction are separate operational considerations, not proof of screenshot
readiness.

## Example usage

Ask: `/vscode-playwright Capture the sample repository's README in a 5.5 by 4.2
inch slide placement, with no terminal or chat panel visible. Save a PNG in the
confirmed output folder.` Use a sanitized workspace and approve the local server
setup before it starts.

Expect an ephemeral server-data directory, a readiness check, and a viewport near
1200 by 916 pixels to match the placement ratio. The agent should inspect visible
panels before closing them, use one atomic Command Palette interaction to open the
file, and adjust zoom for readability at slide size.

Success is a reviewed image with the intended content, matching aspect ratio, and
no notifications, credentials, or unrelated files exposed. The capture workflow
then closes its browser and stops its own server, cleaning up only its temporary
environment. A request for an editor screenshot does not require sending a prompt
to Copilot Chat.
