---
title: VS Code Workspace Settings and MCP Servers
description: What the repository's VS Code settings configure and how to enable the sample MCP servers for Copilot sessions
author: Microsoft
ms.date: 2026-11-18
ms.topic: reference
keywords:
  - mcp
  - github copilot
  - vscode
  - configuration
estimated_reading_time: 3
---

## Workspace settings

`settings.json` sets formatting, the YAML and JSON schemas that validate frontmatter and planner state files, and commit message generation. Generated commit messages follow `.github/plugins/sdlc-git/skills/hve-core/git-commit/references/commit-message.md`, the same conventions the `/git-commit` skill uses.

For work in this checkout, VS Code uses `chat.agentFilesLocations` for agent folders (including subagents), `chat.agentSkillsLocations` for the folders containing skill directories, and `chat.instructionsFilesLocations` for rules. The settings include the conventional directories and the neutral topic roots under `.github/plugins/`.

These are VS Code settings, not Copilot CLI settings. From outside the checkout, use `copilot --plugin-dir /absolute/path/to/hve-core/.github/plugins/rpi-builder skill list --json` to check a local topic without installing it. A mounted rule file does not establish automatic policy application. Native desktop discovery of neutral roots without an install is unverified.

When adding or renaming a collection, update its matching setting. In another workspace choose one discovery route rather than loading both a clone and an installed plugin.

## MCP servers

MCP servers are off by default. `.mcp.json.sample` at the repository root lists the servers some HVE Core agents use, in the portable format that Copilot sessions read from `.mcp.json` at the workspace root. To turn them on, copy the sample to `.mcp.json` and delete the servers you don't need. `.gitignore` excludes `.mcp.json`, so your copy stays out of commits.

| Server   | Transport                          | Used by                                                                      |
|----------|------------------------------------|------------------------------------------------------------------------------|
| `workiq` | stdio through `npx`, needs Node.js | Meeting Analyst, Engagement Report Generator, and optional RAI Planner steps |
| `figma`  | HTTP, signs in with OAuth          | The DT Coach's Figma export                                                  |

Copilot includes a GitHub MCP server, so the sample has no `github` entry. Agents whose tools lists name `github/<tool>` use the built-in server. The Azure DevOps backlog agents need an Azure DevOps MCP server that you configure yourself; see [MCP configuration](../docs/getting-started/mcp-configuration.md).

## Credentials

Keep tokens out of `.mcp.json`. When a server needs a secret, reference an environment variable as `${NAME}` in its `env` values or HTTP headers, and set the variable in the environment where VS Code runs. The portable format has no `${input:...}` prompts, and VS Code does not forward servers that use them from `.vscode/mcp.json` to Copilot sessions.

## References

* [MCP configuration reference](https://code.visualstudio.com/docs/agents/reference/mcp-configuration)
* [Migrate customizations to the Copilot harness](https://code.visualstudio.com/docs/agent-customization/migrate-customizations)
* [GitHub MCP Server](https://github.com/github/github-mcp-server)

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
