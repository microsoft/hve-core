---
title: MCP Scripts
description: Optional local setup and launcher scripts for workspace MCP integrations
author: HVE Core Team
ms.date: 2026-03-26
ms.topic: reference
keywords:
  - mcp
  - mural
  - powershell
estimated_reading_time: 2
---

This directory contains optional helper scripts for workspace-level MCP integrations that require local installation or authentication outside the published HVE Core extension.

## Available Scripts

| Script | Purpose |
|--------|---------|
| `Setup-MuralMcp.ps1` | Clone, build, and authenticate the upstream `mural-mcp` server for local use |
| `Start-MuralMcp.ps1` | Launch the built Mural MCP server for `.vscode/mcp.json` |

## Mural MCP Workflow

1. Copy `.mural-credentials.example` to `.mural-credentials` in the repository root.
2. Fill in your `MURAL_CLIENT_ID` and `MURAL_CLIENT_SECRET` values.
3. Run `npm run mcp:setup:mural`.
4. Add the `mural` server entry shown in [docs/getting-started/mcp-configuration.md](../../docs/getting-started/mcp-configuration.md).
5. Restart VS Code and verify the server appears under MCP Servers.

## Notes

* These scripts are convenience helpers for repository-clone workflows.
* Marketplace extension users can follow the same manual steps from the documentation without cloning `hve-core`.

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
