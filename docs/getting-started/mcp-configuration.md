---
title: MCP Server Configuration
description: Optional configuration for Model Context Protocol servers used by HVE Core agents in Copilot sessions
sidebar_position: 7
author: Microsoft
ms.date: 2026-10-31
ms.topic: how-to
keywords:
  - mcp
  - configuration
  - mcp.json
  - azure devops
  - github
  - context7
  - figma
  - figjam
  - workiq
estimated_reading_time: 8
---

Some HVE Core agents use Model Context Protocol (MCP) servers to reach external services such as Azure DevOps, Microsoft Learn, or Figma. MCP configuration is optional: agents that depend on an MCP tool say so when the server is unavailable. Copilot sessions read MCP servers from `.mcp.json` at the root of your workspace and from your user file `~/.copilot/mcp-config.json`.

> [!TIP]
> The `hve-core-installer` skill included with HVE Core can write `.mcp.json` with the curated servers on this page. Ask an agent to use the skill for guided setup. The sections below cover manual configuration.

## Where Copilot Reads MCP Servers

| File                                                             | Scope                                                           | Server object |
|------------------------------------------------------------------|-----------------------------------------------------------------|---------------|
| `.mcp.json` at the workspace root                                | One project; commit it to share the servers with your team      | `mcpServers`  |
| `~/.copilot/mcp-config.json`, or `$COPILOT_HOME/mcp-config.json` | Every project you open with Copilot, in VS Code and Copilot CLI | `mcpServers`  |
| `.vscode/mcp.json`                                               | One project, forwarded to Copilot sessions by VS Code           | `servers`     |

VS Code forwards servers from `.vscode/mcp.json` except the ones that need interactive input, such as `${input:...}` or `${command:...}` variables. New configuration belongs in `.mcp.json`. Put the file in your own project, not inside an HVE Core clone: the plugin and the extension add no MCP servers.

## Choosing GitHub vs Azure DevOps

Most teams use one primary platform for repository hosting and work item management:

| Repository Hosted On    | MCP Setup                                             |
|-------------------------|-------------------------------------------------------|
| GitHub                  | Nothing to add. Copilot includes a GitHub MCP server. |
| Azure DevOps            | Add the `ado` server                                  |
| GitLab, Bitbucket, etc. | Neither; these platforms are not covered here         |

Backlog and work management does not require you to choose a platform up front. The `backlog-plan` and `backlog-execute` commands resolve the backing tracker at runtime from your workspace, so configure the server that matches the tracker you actually use. Jira and GitLab are reached through their own skills using credentials rather than an MCP server.

## Agent MCP Dependencies

| Agent or Skill              | MCP Servers Used                | Notes                                                              |
|-----------------------------|---------------------------------|--------------------------------------------------------------------|
| backlog-plan                | ado, or Copilot's GitHub server | Read-only backlog planning; server depends on the resolved tracker |
| backlog-execute             | ado, or Copilot's GitHub server | Backlog mutations; server depends on the resolved tracker          |
| Functional Planner          | ado, microsoft-docs             | PRD-to-work-item hierarchy planning                                |
| rpi-research                | context7, microsoft-docs        | Documentation lookup when available                                |
| RPI Agent                   | Varies by activated skill       | Coordinates the applicable RPI phase skills                        |
| dt-figma-export             | figma                           | DT artifact export to FigJam                                       |
| Meeting Analyst             | workiq                          | Microsoft 365 meeting transcripts for PRD requirements             |
| Engagement Report Generator | workiq                          | Microsoft 365 sources for engagement reports                       |

Agents without MCP dependencies work without any MCP configuration.

## Curated MCP Servers

HVE Core documents these MCP servers. Configure only the ones your workflow needs.

### context7

Library and SDK documentation lookup.

| Property | Value                   |
|----------|-------------------------|
| Type     | stdio                   |
| Package  | `@upstash/context7-mcp` |

### microsoft-docs

Microsoft Learn documentation access.

| Property | Value                                 |
|----------|---------------------------------------|
| Type     | http                                  |
| URL      | `https://learn.microsoft.com/api/mcp` |

### ado (Azure DevOps)

Azure DevOps work items, pipelines, and repositories.

| Property | Value                                 |
|----------|---------------------------------------|
| Type     | stdio                                 |
| Package  | `@azure-devops/mcp`                   |
| Requires | Organization name, optional tenant ID |

### figma

Figma and FigJam board creation and reading.

| Property      | Value                             |
|---------------|-----------------------------------|
| Type          | http                              |
| URL           | `https://mcp.figma.com/mcp`       |
| Auth          | Browser-based OAuth on first call |
| Local install | None                              |
| Used by       | `dt-figma-export` skill           |

The Figma MCP server requires a Figma account with a Dev or Full seat on a Professional, Organization, or Enterprise plan for sustained usage. Starter plans are limited to 6 tool calls per month. Authentication happens automatically via browser OAuth on first use.

### workiq

Microsoft 365 content such as meetings, email, and documents.

| Property | Value                                        |
|----------|----------------------------------------------|
| Type     | stdio                                        |
| Package  | `@microsoft/workiq`                          |
| Used by  | Meeting Analyst, Engagement Report Generator |

See the [WorkIQ documentation](https://learn.microsoft.com/microsoft-365-copilot/extensibility/workiq-overview) for account requirements and the license agreement the agents accept before their first query.

### GitHub

Copilot includes a GitHub MCP server that uses the GitHub account you signed in with, so HVE Core needs no `github` entry. If you add one anyway, the session gets a second set of GitHub tools.

## Complete Configuration Template

Copy this template to `.mcp.json` at your workspace root and remove the servers you don't need. HVE Core's repository root also has `.mcp.json.sample` with the WorkIQ and Figma entries.

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    },
    "microsoft-docs": {
      "type": "http",
      "url": "https://learn.microsoft.com/api/mcp"
    },
    "ado": {
      "command": "npx",
      "args": ["-y", "@azure-devops/mcp", "contoso", "-d", "core", "work", "work-items", "search", "repositories", "pipelines"]
    },
    "figma": {
      "type": "http",
      "url": "https://mcp.figma.com/mcp"
    },
    "workiq": {
      "command": "npx",
      "args": ["-y", "@microsoft/workiq@1.0.0", "mcp"]
    }
  }
}
```

Replace `contoso` with your Azure DevOps organization name. For a multi-tenant setup, add `"--tenant", "<tenant-id>"` after the organization name. Neither value is a secret, so you can write them into the file. If team members use different organizations, write `"${ADO_ORG}"` instead and have each person set `ADO_ORG`.

## Secrets and Environment Variables

The portable format has no `${input:...}` prompts. Reference environment variables instead:

* Write `${NAME}`, or `${NAME:-default}` for a non-secret default. Stdio servers can use references in `command`, `args`, and `env` values, and HTTP servers can use them in header values.
* Set the variables in the environment that runs or connects to the server. In a devcontainer or codespace, that is the container.
* Never write tokens, passwords, or populated authentication headers into `.mcp.json`. Prefer OAuth where the server supports it.

If you have servers in `.vscode/mcp.json` that use `${input:...}`, VS Code does not forward them to Copilot sessions. Move them to `.mcp.json` and replace each input with an environment variable, as described in VS Code's guide to [replacing input prompts with environment variables](https://code.visualstudio.com/docs/agent-customization/migrate-customizations#replace-input-prompts-with-environment-variables).

## Sharing and Personal Setup

* Commit `.mcp.json` when the whole team uses the same servers. With secrets in environment variables, the file holds no credentials.
* To keep a personal `.mcp.json` out of the repository, add `/.mcp.json` to `.gitignore`, or put the servers in `~/.copilot/mcp-config.json`.
* In devcontainers and Codespaces, the workspace root inside the container holds `.mcp.json`. Install each stdio server's runtime, such as Node.js for `npx`, in the container.
* `.mcp.json` follows Workspace Trust. Its servers don't start in restricted mode, so review the file before you trust a repository you haven't worked in.

## Troubleshooting

### Agent Reports MCP Tool Unavailable

1. Check that `.mcp.json` sits at the workspace root and uses a top-level `mcpServers` object. A `servers` object belongs in `.vscode/mcp.json`.
2. Run **Chat: Open Customizations**, select **MCP Servers**, and confirm the server is listed and turned on. Start or restart it from its ellipsis (**...**) menu.
3. Confirm the workspace folder is trusted.
4. If the server lives in `.vscode/mcp.json` and uses `${input:...}`, move it to `.mcp.json` as described in [Secrets and Environment Variables](#secrets-and-environment-variables).

### Authentication Errors

* GitHub: Copilot's built-in server uses the GitHub account you signed in with
* ADO: Verify the organization name and tenant ID
* Figma: OAuth launches in your browser on the first tool call. If the session expires, restart VS Code to sign in again

### MCP Server Not Starting

1. Ensure Node.js is installed and `npx` is available where the server runs, which is the container in a devcontainer or codespace.
2. Check that every environment variable the server references is set in that environment.
3. In the **MCP Servers** list of the Agent Customizations editor, open the server's ellipsis (**...**) menu and choose **Show Output** to read its errors. **MCP: List Servers** offers the same action.
4. Verify network access to external URLs.

## References

* [VS Code MCP configuration reference](https://code.visualstudio.com/docs/agents/reference/mcp-configuration)
* [GitHub MCP Server](https://github.com/github/github-mcp-server)
* [Azure DevOps MCP Server](https://learn.microsoft.com/azure/devops/mcp-server/mcp-server-overview?view=azure-devops)
* [Microsoft Learn MCP Server](https://github.com/microsoftdocs/mcp)
* [Figma MCP Server](https://mcp.figma.com)
* [WorkIQ](https://learn.microsoft.com/microsoft-365-copilot/extensibility/workiq-overview)

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
