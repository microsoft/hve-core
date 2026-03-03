---
title: Environment Customization
description: Configure DevContainers, VS Code settings, MCP servers, and coding agent environments for your team
author: Microsoft
ms.date: 2026-02-24
ms.topic: how-to
keywords:
  - devcontainer
  - vs code settings
  - mcp servers
  - environment
estimated_reading_time: 6
---

## DevContainer Configuration

HVE Core uses an Ubuntu 22.04 (Jammy) base image with Node.js 20, Python 3.11,
and PowerShell 7 pre-installed. The configuration lives in
`.devcontainer/devcontainer.json` and includes extensions for Markdown editing,
spell checking, and GitHub integration.

### Default Tool Stack

The DevContainer ships with these tools:

* Node.js 20 with npm
* Python 3.11
* PowerShell 7 with PSScriptAnalyzer, PowerShell-Yaml, and Pester 5.7.1
* Git and GitHub CLI
* Azure CLI
* shellcheck for bash validation
* actionlint for GitHub Actions workflow validation
* gitleaks for secret scanning

### Customizing for Your Team

To add tools or adjust versions, modify `.devcontainer/devcontainer.json`. The
`features` section controls language runtimes and CLIs:

```json
{
  "features": {
    "ghcr.io/devcontainers/features/node:1": {
      "version": "20"
    },
    "ghcr.io/devcontainers/features/python:1": {
      "version": "3.11"
    },
    "ghcr.io/devcontainers/features/powershell:1": {}
  }
}
```

Add new features by referencing published DevContainer features from the
[DevContainers feature registry](https://containers.dev/features). For example,
to add Terraform:

```json
{
  "features": {
    "ghcr.io/devcontainers/features/terraform:1": {
      "version": "1.6"
    }
  }
}
```

### Adding VS Code Extensions

Include team-specific extensions in the `customizations.vscode.extensions`
array. Each entry uses the `publisher.extensionId` format:

```json
{
  "customizations": {
    "vscode": {
      "extensions": [
        "streetsidesoftware.code-spell-checker",
        "davidanson.vscode-markdownlint",
        "ms-python.python"
      ]
    }
  }
}
```

### Lifecycle Scripts

Three lifecycle hooks execute during container setup:

* `onCreateCommand` runs `.devcontainer/scripts/on-create.sh` to install system
  dependencies (shellcheck, actionlint, PowerShell modules, gitleaks)
* `updateContentCommand` runs `npm ci` to install JavaScript dependencies
* `postCreateCommand` runs `.devcontainer/scripts/post-create.sh` for final
  configuration

Add custom setup steps to these scripts or create new scripts referenced from
`devcontainer.json`.

## VS Code Settings

Workspace-level settings in `.vscode/settings.json` configure editor behavior,
Copilot customization discovery, and validation tools. These settings apply to
everyone who opens the workspace.

### Key Settings

The workspace configures several critical behaviors:

```json
{
  "editor.formatOnSave": true,
  "[markdown]": {
    "editor.defaultFormatter": "davidanson.vscode-markdownlint"
  },
  "search.followSymlinks": false
}
```

### Copilot Discovery Paths

VS Code discovers customization files through `chat.*FilesLocations` settings.
Each entry maps a directory path to `true` to enable scanning:

```json
{
  "chat.instructionsFilesLocations": {
    ".github/instructions/hve-core": true,
    ".github/instructions/coding-standards": true
  },
  "chat.agentFilesLocations": {
    ".github/agents/hve-core": true,
    ".github/agents/hve-core/subagents": true
  },
  "chat.promptFilesLocations": {
    ".github/prompts/hve-core": true
  },
  "chat.agentSkillsLocations": {
    ".github/skills": true,
    ".github/skills/shared": true
  }
}
```

When you add a new collection directory, register it in these settings so Copilot
discovers your customizations.

### YAML Schema Validation

The workspace maps YAML schemas to frontmatter validation:

```json
{
  "yaml.schemas": {
    "./scripts/linting/schemas/docs-frontmatter.schema.json": [
      "docs/**/*.md"
    ]
  }
}
```

This setup provides in-editor validation for frontmatter fields when the Red Hat
YAML extension (`redhat.vscode-yaml`) is installed.

### Commit Message Instructions

Copilot uses a dedicated instructions file for generating commit messages:

```json
{
  "github.copilot.chat.commitMessageGeneration.instructions": [
    {
      "file": ".github/instructions/hve-core/commit-message.instructions.md"
    }
  ]
}
```

You can add your own commit message instructions file or replace this reference
to match your team's commit conventions.

## MCP Server Integration

Model Context Protocol (MCP) servers extend Copilot's capabilities by connecting
it to external tools and data sources. MCP servers run alongside VS Code and
provide additional context, actions, or integrations that Copilot can invoke
during conversations.

### Configuration

MCP servers are configured in `.vscode/mcp.json` at the workspace level:

```json
{
  "servers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/"
    }
  }
}
```

### Adding Team-Specific MCP Servers

To integrate your team's tools, add server entries to the `servers` object.
Each server needs a unique key, a type, and connection details:

```json
{
  "servers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/"
    },
    "contoso-api": {
      "type": "http",
      "url": "https://mcp.contoso.com/v1/"
    }
  }
}
```

MCP servers enable agents to interact with issue trackers, CI/CD pipelines,
databases, and other systems your team relies on.

## Coding Agent Environment

The GitHub Copilot coding agent runs in a cloud-based GitHub Actions environment,
separate from the local DevContainer. The
`.github/workflows/copilot-setup-steps.yml` workflow pre-installs tools before
the agent begins work.

### Pre-Installed Tools

The coding agent environment includes:

* Node.js 20 with npm dependencies from `package.json`
* Python 3.11
* PowerShell 7 with PSScriptAnalyzer, PowerShell-Yaml, and Pester 5.7.1
* shellcheck (pre-installed on ubuntu-latest)
* actionlint for GitHub Actions workflow validation

### Adding Tools for the Coding Agent

Add installation steps to `copilot-setup-steps.yml`. Each tool should include
SHA-verified downloads for security:

```yaml
- name: Install custom tool
  env:
    TOOL_VERSION: '1.0.0'
    TOOL_SHA256: 'abc123...'
  run: |
    curl -sLO "https://example.com/tool_${TOOL_VERSION}.tar.gz"
    echo "${TOOL_SHA256}  tool_${TOOL_VERSION}.tar.gz" | sha256sum -c -
    tar -xzf "tool_${TOOL_VERSION}.tar.gz" tool
    sudo install tool /usr/local/bin/tool
```

### Validation

The workflow supports manual execution through `workflow_dispatch`, allowing you
to test setup changes before the coding agent encounters them.

## Environment Synchronization

The DevContainer (`on-create.sh`) and coding agent (`copilot-setup-steps.yml`)
share most tools but differ intentionally in a few areas.

### Shared Tools

| Tool             | DevContainer | Coding Agent |
|------------------|--------------|--------------|
| Node.js 20       | Yes          | Yes          |
| Python 3.11      | Yes          | Yes          |
| PowerShell 7     | Yes          | Yes          |
| PSScriptAnalyzer | Yes          | Yes          |
| Pester 5.7.1     | Yes          | Yes          |
| shellcheck       | Yes          | Yes          |
| actionlint       | Yes          | Yes          |

### Intentional Differences

| Tool     | DevContainer | Coding Agent | Reason                                         |
|----------|--------------|--------------|------------------------------------------------|
| gitleaks | Yes          | No           | Secret scanning is relevant for local dev only |

### Keeping Environments Aligned

When adding or removing tools in either environment, evaluate whether both need
the change and update accordingly. Follow this checklist:

1. Determine if the tool is needed for local development, coding agent work,
   or both.
2. Update `.devcontainer/scripts/on-create.sh` for DevContainer changes.
3. Update `.github/workflows/copilot-setup-steps.yml` for coding agent changes.
4. Pin dependency versions and verify checksums in both locations.
5. Test the DevContainer rebuild and run the setup workflow via
   `workflow_dispatch`.

## Role Scenarios

### SRE/Operations

An SRE team at Fabrikam needs Terraform and kubectl available in both
environments for infrastructure-as-code workflows.

Steps to customize:

1. Add the Terraform DevContainer feature to `devcontainer.json`
2. Add a kubectl installation step to `on-create.sh`
3. Mirror both installations in `copilot-setup-steps.yml`
4. Add the Terraform VS Code extension to the DevContainer extensions list
5. Register any IaC-specific instruction paths in `.vscode/settings.json`

### Engineer

A development team at Northwind Traders uses a custom API testing tool and wants
Copilot to reference their internal MCP server during code reviews.

Steps to customize:

1. Add the API testing tool to `on-create.sh` and `copilot-setup-steps.yml`
2. Configure the internal MCP server in `.vscode/mcp.json`
3. Add workspace settings for any new extensions the team requires
4. Create an instructions file that teaches Copilot about the team's API
   conventions

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
