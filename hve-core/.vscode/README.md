---
title: VS Code MCP Server Configuration
description: Configuration guide for GitHub MCP server integration with VS Code Copilot
author: Microsoft
ms.date: 2025-06-13
ms.topic: reference
keywords:
  - mcp
  - github copilot
  - vscode
  - configuration
estimated_reading_time: 3
---

## Overview

This workspace uses the GitHub MCP server for enhanced Copilot capabilities.

## Configuration

The MCP server is configured in `.vscode/mcp.json` to use a custom endpoint (`https://github.com/mcp`).

> **Note:** If you want to use the recommended GitHub MCP server setup, run `npx @modelcontextprotocol/server-github` and update your `.vscode/mcp.json` accordingly. See the [GitHub MCP Server Documentation](https://github.com/github/github-mcp-server) for details.

### Authentication

#### Option 1: OAuth (Recommended)

- Uses VS Code's built-in GitHub authentication
- No manual token management required
- Managed via: VS Code → Accounts menu → Manage Trusted MCP Servers

#### Option 2: Personal Access Token

- Required for GitHub Enterprise Server
- Set environment variable: `GITHUB_PERSONAL_ACCESS_TOKEN`
- Generate at: <https://github.com/settings/personal-access-tokens/new>

### Enterprise Configuration

For GitHub Enterprise Server:

1. Update `.vscode/mcp.json` with your enterprise URL:

   ```json
   {
     "servers": {
       "github": {
         "url": "https://your-github-enterprise.com/mcp"
       }
     }
   }
   ```

2. Set your PAT as an environment variable:

   ```powershell
   # PowerShell
   $env:GITHUB_PERSONAL_ACCESS_TOKEN = "your_token_here"
   ```

   ```bash
   # Bash/Linux/macOS
   export GITHUB_PERSONAL_ACCESS_TOKEN="your_token_here"
   ```

### Required Token Scopes

If using PAT authentication, your token needs:

- `repo` - Full control of private repositories
- `read:org` - Read org and team membership
- `user` - Read user profile data

### Usage

Once configured, the MCP server provides:

- Repository operations (file management, search)
- Branch management
- Issue management
- Pull request workflows
- Code search capabilities

### Security Notes

- Never commit tokens to version control
- Use OAuth when possible for automatic credential management
- Rotate PATs regularly
- Use fine-grained tokens with minimal required permissions

### Troubleshooting

**Server not connecting:**

- Check VS Code version (1.101+ recommended for OAuth)
- Verify GitHub authentication via Accounts menu
- For PAT: Verify `GITHUB_PERSONAL_ACCESS_TOKEN` is set

**Permission errors:**

- Ensure token has required scopes
- Check token hasn't expired
- Verify repository access permissions

### References

- [VS Code MCP Extension Guide](https://code.visualstudio.com/api/extension-guides/ai/mcp)
- [GitHub MCP Server Documentation](https://github.com/github/github-mcp-server)
- [GitHub Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
