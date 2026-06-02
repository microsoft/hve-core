---
title: 'Phase 6: Post-Installation Setup'
description: 'Post-installation gitignore configuration and convergence steps shared by extension and clone-based hve-core installs.'
---

# Phase 6: Post-Installation Setup

This phase applies to all installation methods (Extension and Clone-based). Both paths converge here for consistent post-installation configuration.

## Checkpoint 4: Gitignore Configuration

🛡️ Configuring gitignore...

Check and configure gitignore entries based on the installation method. Different methods may require different gitignore entries.

### Method-Specific Gitignore Entries

| Method          | Gitignore Entry      | Reason                            |
|-----------------|----------------------|-----------------------------------|
| 2 (Git-Ignored) | `.hve-core/`         | Excludes the local HVE-Core clone |
| All methods     | `.copilot-tracking/` | Excludes AI workflow artifacts    |

**Detection:** Check if `.gitignore` exists and contains the required entries.

**For Method 2 (Git-Ignored):** If `.hve-core/` is not in `.gitignore`, it should have been added during Phase 4 installation. Verify it exists.

**For all methods:** Check if `.copilot-tracking/` should be added to `.gitignore`. This directory stores local AI workflow artifacts (plans, changes, research notes) that are typically user-specific and not meant for version control.

* If pattern found → Skip this checkpoint silently
* If `.gitignore` missing or pattern not found → Present the prompt below

<!-- <gitignore-prompt> -->
```text
📋 Gitignore Recommendation

The `.copilot-tracking/` directory stores local AI workflow artifacts:
• Plans and implementation tracking
• Research notes and change records
• User-specific prompts and handoff logs

These files are typically not meant for version control.

Would you like to add `.copilot-tracking/` to your .gitignore? (yes/no)
```
<!-- </gitignore-prompt> -->

User input handling:

* "yes", "y" → Add entry to `.gitignore`
* "no", "n", "skip" → Skip without changes
* Unclear response → Ask for clarification

**Modification:** If user approves:

* If `.gitignore` exists: Append the following at the end of the file
* If `.gitignore` missing: Create it with the content below

<!-- <gitignore-entry> -->
```text
# HVE-Core AI workflow artifacts (local only)
.copilot-tracking/
```
<!-- </gitignore-entry> -->

Report: "✅ Added `.copilot-tracking/` to .gitignore"

After the gitignore checkpoint, proceed to Checkpoint 5 (MCP Configuration).

## Checkpoint 5: MCP Configuration Guidance

After the gitignore checkpoint (for **any** installation method), present MCP configuration guidance. This helps users who want to use agents that integrate with Azure DevOps, GitHub, or documentation services.

<!-- <mcp-guidance-prompt> -->
```text
📡 MCP Server Configuration (Optional)

Some HVE-Core agents integrate with external services via MCP (Model Context Protocol):

| Agent                  | MCP Server               | Purpose                              |
|------------------------|--------------------------|--------------------------------------|
| ado-prd-to-wit         | ado                      | Azure DevOps work items              |
| github-backlog-manager | github                   | GitHub backlog management            |
| task-researcher        | context7, microsoft-docs | Documentation lookup                 |
| dt-coach               | figma                    | FigJam board export for DT artifacts |

Would you like to configure MCP servers? (yes/no)
```
<!-- </mcp-guidance-prompt> -->

User input handling:

* "yes", "y" → Ask which servers to configure (see MCP Server Selection below)
* "no", "n", "skip" → Proceed to Final Completion Report
* Enter, "continue", "done" → Proceed to Final Completion Report
* Unclear response → Proceed to Final Completion Report (non-blocking)

## MCP Server Selection

If user chooses to configure MCP, present:

<!-- <mcp-server-selection> -->
```text
Which MCP servers would you like to configure?

| Server         | Purpose                   | Recommended For                  |
|----------------|---------------------------|----------------------------------|
| github         | GitHub issues and repos   | GitHub-hosted repositories       |
| ado            | Azure DevOps work items   | Azure DevOps repositories        |
| context7       | SDK/library documentation | All users (optional)             |
| microsoft-docs | Microsoft Learn docs      | All users (optional)             |
| figma          | FigJam & Figma design     | Design Thinking collection users |

⚠️ Suggest EITHER github OR ado based on where your repo is hosted, not both.

Enter server names separated by commas (e.g., "github, context7"):
```
<!-- </mcp-server-selection> -->

Parse the user's response to determine which servers to include.

## MCP Configuration Templates

Create `.vscode/mcp.json` using ONLY the templates below. Use HTTP type with managed authentication where available.

> [!IMPORTANT]
> These are the only correct configurations. Do not use stdio/npx for servers that support HTTP.

### github server (HTTP with managed auth)

```json
{
  "github": {
    "type": "http",
    "url": "https://api.githubcopilot.com/mcp/"
  }
}
```

### ado server (stdio with inputs)

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
    "ado": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@azure-devops/mcp", "${input:ado_org}", "--tenant", "${input:ado_tenant}", "-d", "core", "work", "work-items", "search", "repositories", "pipelines"]
    }
  }
}
```

### context7 server (stdio)

```json
{
  "context7": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@upstash/context7-mcp"]
  }
}
```

### microsoft-docs server (HTTP)

```json
{
  "microsoft-docs": {
    "type": "http",
    "url": "https://learn.microsoft.com/api/mcp"
  }
}
```

### figma server (HTTP with managed auth)

```json
{
  "figma": {
    "type": "http",
    "url": "https://mcp.figma.com/mcp"
  }
}
```

## MCP File Generation

When creating `.vscode/mcp.json`:

1. Create `.vscode/` directory if it does not exist
2. Combine only the selected server configurations into a single JSON object
3. Include `inputs` array only if `ado` server is selected
4. Merge all selected servers under a single `servers` object

Example combined configuration for "github, context7":

<!-- <mcp-combined-example> -->
```json
{
  "servers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/"
    },
    "context7": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    }
  }
}
```
<!-- </mcp-combined-example> -->

After creating the file, display:

```text
✅ Created .vscode/mcp.json with [server names] configuration

📖 Full documentation: https://github.com/microsoft/hve-core/blob/main/docs/getting-started/mcp-configuration.md
```

## Final Completion Report

After gitignore and MCP checkpoints complete, display the final completion message:

<!-- <final-completion-report> -->
```text
✅ Setup Complete!

▶️ Next Steps:
1. Reload VS Code (Ctrl+Shift+P → "Reload Window")
2. Open Copilot Chat (`Ctrl+Alt+I`) and click the agent picker dropdown
3. Select an agent to start working

💡 Select `task-researcher` from the picker to explore HVE-Core capabilities
```
<!-- </final-completion-report> -->

For **Extension** installations, also include:

```text
---
📝 Want to customize HVE-Core or share with your team?
Run this skill again and choose "Clone-Based Installation" for full customization options.
```

For **Clone-based** installations, proceed to Phase 7 for optional agent customization.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
