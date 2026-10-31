---
title: Post-Installation Setup
description: Phase 6 post-installation setup for the hve-core installer.
---
<!-- markdownlint-disable-file -->

## Phase 6: Post-Installation Setup

This phase applies to every install route. All routes converge here for consistent post-installation configuration, and the final completion report at the end of this phase is the last step of every route.

### Checkpoint 4: Gitignore Configuration

🛡️ Configuring gitignore...

Check and configure gitignore entries based on the installation method. Different methods may require different gitignore entries.

#### Method-Specific Gitignore Entries

| Method                                     | Gitignore Entry      | Reason                                     |
|--------------------------------------------|----------------------|--------------------------------------------|
| 2, 3, 4 (Git-Ignored, Mounted, Codespaces) | `.hve-core/`         | Excludes the local HVE-Core clone or mount |
| All routes                                 | `.copilot-tracking/` | Excludes AI workflow artifacts             |

**Detection:** Check if `.gitignore` exists and contains the required entries.

**For Methods 2, 3, and 4:** If `.hve-core/` is not in `.gitignore`, it should have been added during Phase 4 installation. Verify it exists.

**For all routes:** Check if `.copilot-tracking/` should be added to `.gitignore`. This directory stores local AI workflow artifacts (plans, changes, research notes) that are typically user-specific and not meant for version control.

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

### Checkpoint 5: MCP Configuration Guidance

After the gitignore checkpoint (for **any** install route), present MCP configuration guidance. This helps users who want agents that integrate with Azure DevOps, documentation services, or Figma.

<!-- <mcp-guidance-prompt> -->
```text
📡 MCP Server Configuration (Optional)

Some HVE-Core capabilities integrate with external services via MCP (Model Context Protocol):

| Capability         | MCP Server               | Purpose                              |
|--------------------|--------------------------|--------------------------------------|
| functional-planner | ado                      | Azure DevOps work items              |
| rpi-research       | context7, microsoft-docs | Documentation lookup                 |
| dt-coach           | figma                    | FigJam board export for DT artifacts |

ℹ️ Copilot includes a GitHub MCP server, so HVE-Core needs no separate
   github server.
⚠️ Jira access uses environment variables instead of MCP. Ask Copilot Chat to
   set up Jira credentials to configure them through the jira skill.

Would you like to configure MCP servers? (yes/no)
```
<!-- </mcp-guidance-prompt> -->

User input handling:

* "yes", "y" → Ask which servers to configure (see MCP Server Selection below)
* "no", "n", "skip" → Proceed to Final Completion Report
* Enter, "continue", "done" → Proceed to Final Completion Report
* Unclear response → Proceed to Final Completion Report (non-blocking)

### MCP Server Selection

If user chooses to configure MCP, present:

<!-- <mcp-server-selection> -->
```text
Which MCP servers would you like to configure?

| Server         | Purpose                   | Recommended For               |
|----------------|---------------------------|-------------------------------|
| ado            | Azure DevOps work items   | Azure DevOps repositories     |
| context7       | SDK/library documentation | All users (optional)          |
| microsoft-docs | Microsoft Learn docs      | All users (optional)          |
| figma          | FigJam & Figma design     | Design Thinking package users |

Enter server names separated by commas (e.g., "ado, context7"):
```
<!-- </mcp-server-selection> -->

Parse the user's response to determine which servers to include. When the response names `github`, explain that Copilot already includes a GitHub MCP server and leave it out.

When `ado` is selected, ask for the values that server needs. They are not secrets, so write the answers into the configuration as literal values:

<!-- <ado-details-prompt> -->
```text
Azure DevOps details for the ado server:
• Organization name (for example, contoso):
• Azure tenant ID (only for multi-tenant scenarios; leave blank to skip):
```
<!-- </ado-details-prompt> -->

### MCP Configuration Templates

Write `.mcp.json` at the workspace root using only the templates below. The file holds one top-level `mcpServers` object. Stdio servers have `command` and `args` and need no `type`; HTTP servers have `"type": "http"` and `url`.

> [!IMPORTANT]
> These are the only correct configurations. Do not use stdio/npx for servers that support HTTP.

#### ado server (stdio)

```json
{
  "mcpServers": {
    "ado": {
      "command": "npx",
      "args": ["-y", "@azure-devops/mcp", "<ORGANIZATION>", "--tenant", "<TENANT_ID>", "-d", "core", "work", "work-items", "search", "repositories", "pipelines"]
    }
  }
}
```

Replace `<ORGANIZATION>` with the organization name. Replace `<TENANT_ID>` with the tenant ID, or remove both `"--tenant"` and `"<TENANT_ID>"` when the user left the tenant blank.

#### context7 server (stdio)

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    }
  }
}
```

#### microsoft-docs server (HTTP)

```json
{
  "mcpServers": {
    "microsoft-docs": {
      "type": "http",
      "url": "https://learn.microsoft.com/api/mcp"
    }
  }
}
```

#### figma server (HTTP)

```json
{
  "mcpServers": {
    "figma": {
      "type": "http",
      "url": "https://mcp.figma.com/mcp"
    }
  }
}
```

### Credentials and Secrets

Never write credentials, tokens, or other secrets into `.mcp.json` or any other file. When a server needs a secret, reference an environment variable written as `${NAME}` and tell the user to set that variable outside the repository. The portable format has no input prompts, so ask the user for values that are not secrets, such as the Azure DevOps organization, and write them as literal values.

### MCP File Generation

When writing `.mcp.json`:

1. When `.mcp.json` already exists at the workspace root, read it and add the selected servers to its `mcpServers` object. Keep the existing servers, and ask before replacing a server that has the same name.
2. Otherwise, create `.mcp.json` at the workspace root with a top-level `mcpServers` object that holds only the selected servers.
3. Ask whether the user wants to share the file with the team. When they do not, offer to add the entry below to `.gitignore`. For servers the user wants in every workspace, mention the user file `~/.copilot/mcp-config.json` (or `$COPILOT_HOME/mcp-config.json`), which Copilot sessions also read and which uses the same `mcpServers` format.

<!-- <mcp-gitignore-entry> -->
```text
# Personal MCP server configuration (local only)
/.mcp.json
```
<!-- </mcp-gitignore-entry> -->

> [!NOTE]
> VS Code also forwards servers from `.vscode/mcp.json` to Copilot sessions, except servers that use `${input:...}` or `${command:...}` prompts. When that file already defines a server the user selected, tell the user before adding the same server to `.mcp.json`.

Example combined configuration for "context7, microsoft-docs":

<!-- <mcp-combined-example> -->
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
    }
  }
}
```
<!-- </mcp-combined-example> -->

After writing the file, display:

```text
✅ Added [server names] to .mcp.json

📖 Full documentation: https://github.com/microsoft/hve-core/blob/main/docs/getting-started/mcp-configuration.md
```

### Final Completion Report

After the gitignore and MCP checkpoints, display the final completion message. Opening the agent picker and the `/` menu needs the user, so ask the user to run the checks and report what they see.

When HVE-Core is installed as a plugin, from the marketplace or from source, VS Code uses the plugin name as a command prefix for its skills. Skills copied into the project's own `.github/skills` folder appear without a prefix. Fill in the checks for the route the user installed:

| Route                                                | Agent check                      | Skill check                                                            |
|------------------------------------------------------|----------------------------------|------------------------------------------------------------------------|
| Plugin, team default, or clone installed from source | `RPI Agent` is listed            | `/hve-core:rpi-research` appears                                       |
| Clone declared in `.github/copilot/settings.json`    | `RPI Agent` is listed            | A skill such as `/rpi-research` or `/hve-core:rpi-research` appears    |
| Native adoption                                      | The agents you copied are listed | The skills you copied appear without a prefix, such as `/rpi-research` |
| VS Code extension                                    | `RPI Agent` is listed            | A skill such as `/rpi-research` or `/hve-core:rpi-research` appears    |

<!-- <final-completion-report> -->
```text
✅ Setup Complete!

▶️ Next Steps:
1. Run "Developer: Reload Window" from the Command Palette (Ctrl+Shift+P)
2. Open Copilot Chat (`Ctrl+Alt+I`) with the Copilot harness and open the agent picker
3. Confirm [agent check]
4. Type / and confirm [skill check]

💡 Select an HVE-Core agent, such as `RPI Agent`, to start working
```
<!-- </final-completion-report> -->

If the user reports a missing or repeated agent or skill:

* Confirm the user reloaded the window after the last install, update, or edit. VS Code keeps the list of path-specific instructions for the life of the window, and new chat sessions pick up changes after **Developer: Reload Window**.
* For the team default, check on the **Plugins** page that `hve-core` is turned on.
* For folders declared in `.github/copilot/settings.json`, confirm that the workspace folder is trusted.
* An agent listed twice means HVE-Core arrived through more than one route. Keep one route and remove the others.

For **Extension** installations, also include:

```text
---
📝 The extension's instructions may not reach Copilot sessions.
For the full set, uninstall the extension and run this skill again
to install the plugin (Option 1). Use one route at a time.
```
