---
title: MCP Server Configuration
description: Optional configuration for Model Context Protocol servers used by HVE-Core agents
sidebar_position: 6
author: Microsoft
ms.date: 2026-01-21
ms.topic: how-to
keywords:
  - mcp
  - configuration
  - azure devops
  - github
  - context7
estimated_reading_time: 8
---

Some HVE-Core agents use Model Context Protocol (MCP) servers to integrate with external services. MCP configuration is optional; agents that depend on MCP tools indicate when the required server is unavailable.

## Overview

MCP tools extend GitHub Copilot's capabilities by connecting to external services. HVE-Core references four curated MCP servers. Configure only the servers relevant to your workflow.

## Choosing GitHub vs Azure DevOps

Most teams use one primary platform for repository hosting and work item management:

| Repository Hosted On    | Configure       | Do Not Configure |
|-------------------------|-----------------|------------------|
| GitHub                  | `github` server | `ado` server     |
| Azure DevOps            | `ado` server    | `github` server  |
| GitLab, Bitbucket, etc. | Neither         | Both             |

Configuring both is unnecessary unless you work across platforms. If you use other Git hosting or work item systems (GitLab, Jira, etc.), configuration differs and is not documented here.

## Agent MCP Dependencies

| Agent                  | MCP Servers Used         | Notes                           |
|------------------------|--------------------------|---------------------------------|
| ado-prd-to-wit         | ado, microsoft-docs      | ADO work item creation          |
| github-backlog-manager | github                   | GitHub backlog management       |
| task-researcher        | context7, microsoft-docs | Documentation lookup (optional) |
| task-planner           | context7, microsoft-docs | Documentation lookup (optional) |
| rpi-agent              | Varies by subagent       | Delegates to specialized agents |

Agents without MCP dependencies work without any MCP configuration.

## Curated MCP Servers

HVE-Core documents these four MCP servers:

### context7

Library and SDK documentation lookup.

* **Type**: stdio
* **Package**: `@upstash/context7-mcp`

### microsoft-docs

Microsoft Learn documentation access.

* **Type**: http
* **URL**: `https://learn.microsoft.com/api/mcp`

### ado (Azure DevOps)

Azure DevOps work items, pipelines, and repositories.

* **Type**: stdio
* **Package**: `@azure-devops/mcp`
* **Requires**: Organization name, optional tenant ID

### github

GitHub repository and issue management.

* **Type**: http
* **URL**: `https://api.githubcopilot.com/mcp/`

## Complete Configuration Template

Copy this template to `.vscode/mcp.json` in your workspace root. Remove servers you do not need (typically keep either `github` or `ado`, not both).

```json
{
  "inputs": [
    {
      "id": "ado_org",
      "type": "promptString",
      "description": "Azure DevOps organization name (e.g. 'contoso')",
      "default": ""
    },
    {
      "id": "ado_tenant",
      "type": "promptString",
      "description": "Azure tenant ID (required for multi-tenant scenarios)",
      "default": ""
    }
  ],
  "servers": {
    "context7": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    },
    "microsoft-docs": {
      "type": "http",
      "url": "https://learn.microsoft.com/api/mcp"
    },
    "ado": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@azure-devops/mcp", "${input:ado_org}", "--tenant", "${input:ado_tenant}", "-d", "core", "work", "work-items", "search", "repositories", "pipelines"]
    },
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/"
    }
  }
}
```

## Method-Specific Notes

### Extension Users

The VS Code extension provides agents without MCP configuration. Create `.vscode/mcp.json` in your project directory if you want to use MCP-dependent features.

### Peer Clone / Submodule / Git-Ignored Users

Create `.vscode/mcp.json` in your workspace root (not inside the hve-core folder). VS Code reads MCP configuration only from the workspace root.

### Codespaces / Devcontainer Users

Create `.vscode/mcp.json` in your repository's `.vscode/` folder. The file will be available inside the container at the workspace root.

### Multi-Root Workspace Users

MCP configuration can be placed in the `.code-workspace` file under `settings` or in the `.vscode/mcp.json` of the primary workspace folder. Workspace-level settings in the `.code-workspace` file take precedence.

## Troubleshooting

### Agent Reports MCP Tool Unavailable

1. Verify `.vscode/mcp.json` exists in workspace root
2. Check MCP server is running: View → Extensions → MCP SERVERS section
3. Trust the server when prompted by VS Code

### Authentication Errors

* **GitHub**: Uses VS Code's built-in GitHub authentication
* **ADO**: Verify organization name and tenant ID are correct

### MCP Server Not Starting

1. Ensure Node.js is installed and `npx` is available
2. Check the Output panel (View → Output → MCP Servers) for error messages
3. Verify network access to external URLs

## References

* [VS Code MCP Documentation](https://code.visualstudio.com/docs/copilot/customization/mcp-servers)
* [GitHub MCP Server](https://github.com/github/github-mcp-server)
* [Azure DevOps MCP Server](https://learn.microsoft.com/azure/devops/mcp-server/mcp-server-overview?view=azure-devops)
* [Microsoft Learn MCP Server](https://github.com/microsoftdocs/mcp)

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
