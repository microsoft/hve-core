---
title: Environment Customization
description: Configure DevContainers, VS Code settings, MCP servers, and coding agent environments for your team
author: Microsoft
ms.date: 2026-11-02
ms.topic: how-to
keywords:
  - devcontainer
  - vs code settings
  - mcp servers
  - mcp.json
  - environment
estimated_reading_time: 6
---

## DevContainer Configuration

HVE Core uses an Ubuntu 22.04 (Jammy) base image with Node.js 24.21.0, Python 3.12.15,
and PowerShell 7.4 pre-installed. The configuration lives in
`.devcontainer/devcontainer.json` and includes extensions for Markdown editing,
spell checking, and GitHub integration.

### Default Tool Stack

The DevContainer ships with these tools:

* Node.js 24.21.0 with npm (from `.node-version`)
* Python 3.12.15 (from `.python-version`)
* PowerShell 7.4 with PSScriptAnalyzer 1.25.0, PowerShell-Yaml 0.4.7, and Pester 6.2.0
* Git and GitHub CLI
* GitHub Copilot CLI (`copilot`)
* Azure CLI
* shellcheck 0.11.0 for bash and workflow `run:` script validation
* zizmor 1.30.1 for GitHub Actions security auditing
* cosign for artifact signing and verification
* gitleaks for secret scanning

### Customizing for Your Team

To add tools or adjust versions, modify `.devcontainer/devcontainer.json`. The
`features` section controls language runtimes and CLIs:

```json
{
  "features": {
    "ghcr.io/devcontainers/features/node:1": {
      "version": "24.21.0",
      "pnpmVersion": "none"
    },
    "ghcr.io/devcontainers/features/python:1": {
      "version": "3.12.15",
      "installTools": false
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

### Lockfile

When the dev container builds, it generates a `devcontainer-lock.json` file in
the same directory as `devcontainer.json`. This lockfile pins each feature to an
exact version and OCI SHA-256 digest, providing reproducible builds and
supply-chain integrity verification. The lockfile is committed to source control
and validated by CI.

After modifying features in `devcontainer.json`, rebuild the dev container to
regenerate `devcontainer-lock.json` and commit both files together. PR validation
fails if the lockfile is missing or out of sync with `devcontainer.json`.

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

* `onCreateCommand` runs `.devcontainer/scripts/on-create.sh` to install
  shellcheck, zizmor, gitleaks, cosign, osv-scanner, and uv, each pinned and
  SHA-256 verified against digests that
  `npm run lint:tool-version-consistency` keeps equal to
  `scripts/security/tool-checksums.json`, plus the version-pinned PowerShell
  modules from `scripts/security/ps-module-versions.json`
* `updateContentCommand` runs `npm ci` at the repository root and
  `npm ci --prefix scripts/linting/workflow-validator --ignore-scripts` for the
  workflow validator
* `postCreateCommand` runs `.devcontainer/scripts/post-create.sh` for final
  configuration

Add custom setup steps to these scripts or create new scripts referenced from
`devcontainer.json`.

## VS Code Settings

Workspace-level settings in `.vscode/settings.json` configure editor behavior,
schema validation, and commit message generation. These settings apply to
everyone who opens the workspace in VS Code.

### Key Settings

The workspace sets these editor behaviors:

```json
{
  "editor.formatOnSave": true,
  "[markdown]": {
    "editor.defaultFormatter": "davidanson.vscode-markdownlint"
  },
  "search.followSymlinks": false
}
```

### Copilot Discovery

Copilot finds agents under `.github/agents/`, skills under `.github/skills/`, and
instructions under `.github/instructions/` at any folder depth. A new package
folder needs no settings for Copilot sessions:

```text
.github/
  agents/{package-id}/{name}.agent.md
  instructions/{package-id}/{name}.instructions.md
  skills/{package-id}/{skill-name}/SKILL.md
```

VS Code keeps its list of path-specific instructions for the life of the window.
After you add or edit instruction files, run **Developer: Reload Window** so new
chat sessions pick up the change.

This workspace also lists its own `.github` package folders in the
`chat.agentFilesLocations`, `chat.instructionsFilesLocations`, and
`chat.agentSkillsLocations` settings for contributors who still use VS Code's
Local harness, which may not find nested agents and skills without them. HVE
Core supports only the Copilot harness, as
[Use the Copilot Harness](../getting-started/install#use-the-copilot-harness)
explains, so these settings serve as a bridge while contributors switch. They
are editor-only: VS Code forwards files from those folders to Copilot sessions,
which already find the folders on their own, and Copilot CLI and the GitHub
Copilot app do not read them. When you add or rename a package folder, add it to
the matching setting so Local sessions keep finding it, and list an agent
package's `subagents` folder as its own entry.

In a project that uses HVE Core, settings entries that point at an HVE Core
clone, such as `../hve-core` or `lib/hve-core`, load HVE Core a second time next
to any install route. Remove those entries after you switch to the Copilot
harness and confirm HVE Core loads there, as
[Use One Route at a Time](../getting-started/install#use-one-route-at-a-time)
describes. That advice does not apply to this repository's own folders.

To load customizations from a folder elsewhere in the checkout, such as an HVE
Core submodule, declare its folders in `.github/copilot/settings.json` as
described in [Work From a Clone](../getting-started/install#work-from-a-clone).

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

VS Code's commit message generation follows the same conventions file that the
`/git-commit` skill uses:

```json
{
  "github.copilot.chat.commitMessageGeneration.instructions": [
    {
      "file": ".github/skills/hve-core/git-commit/references/commit-message.md"
    }
  ]
}
```

Point this setting at your own file to match your team's commit conventions.

## MCP Server Integration

Model Context Protocol (MCP) servers connect Copilot to external tools and data
sources. Agents use them for extra context and to take actions in those systems
during a session.

### Configuration

Copilot reads MCP servers from `.mcp.json` at the workspace root. The file holds
one top-level `mcpServers` object. Stdio servers have `command` and `args`, and
HTTP servers have `"type": "http"` and a `url`. Copilot also reads each person's
`~/.copilot/mcp-config.json` (or `$COPILOT_HOME/mcp-config.json`), which uses the
same format, for servers that belong outside the workspace.

HVE Core ships `.mcp.json.sample` at the repository root with the WorkIQ and
Figma servers that some of its agents use. To turn them on, copy the sample to
`.mcp.json` and delete the servers you don't need. `.gitignore` excludes
`.mcp.json`, so your copy stays out of commits.

Copilot includes a GitHub MCP server, so leave `github` out of `.mcp.json`.
Agents whose tools lists name `github/<tool>` use the built-in server.

### Adding Team-Specific MCP Servers

Add an entry to the `mcpServers` object for each of your team's servers. Each
entry needs a unique key and its connection details:

```json
{
  "mcpServers": {
    "figma": {
      "type": "http",
      "url": "https://mcp.figma.com/mcp"
    },
    "contoso-api": {
      "type": "http",
      "url": "https://mcp.contoso.com/v1/"
    }
  }
}
```

The key is the server name that agents use in their `tools` lists, as
`contoso-api/<tool>` or `contoso-api/*`.

Keep tokens out of the file. When a server needs a secret, reference an
environment variable written as `${NAME}` in the server's `env` values or HTTP
headers, and set the variable outside the repository. The format has no
`${input:...}` prompts. If your team still keeps servers in `.vscode/mcp.json`,
VS Code forwards them to Copilot sessions except those that use `${input:...}`
or `${command:...}`, so move those servers to `.mcp.json`.

MCP servers let agents work with issue trackers, CI/CD pipelines, databases, and
other systems your team relies on. [MCP Server Configuration](../getting-started/mcp-configuration)
covers the servers HVE Core agents use.

## Coding Agent Environment

The GitHub Copilot coding agent runs in a cloud-based GitHub Actions environment,
separate from the local DevContainer. The
`.github/workflows/copilot-setup-steps.yml` workflow pre-installs tools before
the agent begins work.

### Pre-Installed Tools

The coding agent environment includes:

* Node.js 24.21.0 (from `.node-version`) with npm dependencies from `package.json`
* Python 3.12.15 (from `.python-version`)
* PowerShell 7.4 with PSScriptAnalyzer 1.25.0, PowerShell-Yaml 0.4.7, and Pester 6.2.0
* shellcheck 0.11.0 and zizmor 1.30.1, each pinned with per-architecture
  SHA-256 digests in `copilot-setup-steps.yml`. `npm run
  lint:tool-version-consistency` requires those versions and digests to match
  `scripts/security/tool-checksums.json` for the same architecture.
* cosign for artifact signing and verification
* osv-scanner for dependency vulnerability scanning

### Adding Tools for the Coding Agent

Add installation steps to `copilot-setup-steps.yml`. Each tool should include
SHA-verified downloads for security, and the tool must be registered in
`scripts/security/tool-checksums.json` with the same version and digests:

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

| Tool                    | DevContainer | Coding Agent |
|-------------------------|--------------|--------------|
| Node.js 24.21.0         | Yes          | Yes          |
| Python 3.12.15          | Yes          | Yes          |
| PowerShell 7.4          | Yes          | Yes          |
| PSScriptAnalyzer 1.25.0 | Yes          | Yes          |
| Pester 6.2.0            | Yes          | Yes          |
| shellcheck              | Yes          | Yes          |
| zizmor                  | Yes          | Yes          |
| cosign                  | Yes          | Yes          |
| osv-scanner             | Yes          | Yes          |

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
5. Add IaC instruction files under `.github/instructions/`, where Copilot finds
   them without any settings

### Engineer

A development team at Northwind Traders uses a custom API testing tool and wants
Copilot to reference their internal MCP server during code reviews.

Steps to customize:

1. Add the API testing tool to `on-create.sh` and `copilot-setup-steps.yml`
2. Add the internal MCP server to `.mcp.json` at the workspace root, with any
   token read from an environment variable
3. Add workspace settings for any new extensions the team requires
4. Create an instructions file that teaches Copilot about the team's API
   conventions

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
