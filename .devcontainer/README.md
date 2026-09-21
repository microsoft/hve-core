---
title: Dev Container
description: Pre-configured development environment for HVE Core with all required tools and extensions
author: HVE Core Team
ms.date: 2026-08-11
ms.topic: guide
keywords:
  - devcontainer
  - development environment
  - vscode
  - docker
estimated_reading_time: 3
---

A pre-configured development environment that includes all tools, extensions, and dependencies needed for HVE Core development. Ensures consistency across all development machines.

## Prerequisites

* [Docker Desktop](https://www.docker.com/products/docker-desktop)
* [Visual Studio Code](https://code.visualstudio.com/)
* [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
* Git

## Quick Start

1. Clone the repository:

   ```bash
   git clone https://github.com/microsoft/hve-core.git
   cd hve-core
   ```

2. Open in VS Code:

   ```bash
   code .
   ```

3. Reopen in container:
   * Press `F1` or `Ctrl+Shift+P`
   * Select **Dev Containers: Reopen in Container**
   * Wait for the container to build (first time takes 5-10 minutes)

## Restricted Networks and Custom Registries

Set restricted-network overrides on the host before opening VS Code, then
rebuild the container. Supported variables are:

* Build and package indexes: `HVE_DEVCONTAINER_IMAGE`,
  `NPM_CONFIG_REGISTRY`, `PIP_INDEX_URL`, and `UV_DEFAULT_INDEX`
* Setup endpoints: `HVE_GITHUB_RELEASES_URL`, `HVE_GITHUB_API_URL`,
  `HVE_PSGALLERY_REPOSITORY`, and `HVE_PSGALLERY_SOURCE_URL`

Runtime-only npm, pip, and uv overrides can instead use the user-level
`dev.containers.containerEnv` VS Code setting. This setting cannot select the
base image or configure setup endpoints because those values are resolved
during container creation.

See [Install behind a restricted network](../docs/contributing/validation.md#install-behind-a-restricted-network)
for configuration examples and restore guidance. See
[Enterprise artifact hub](../docs/customization/enterprise-artifact-hub.md)
for defaults and the complete environment contract. Keep organization-specific
endpoints and credentials out of repository files.

## Included Tools

### Languages & Runtimes

* Node.js 24
* Python 3.11
* PowerShell 7.x

### CLI Tools

* Git
* GitHub CLI (`gh`)
* GitHub Copilot CLI (`copilot`)
* Azure CLI (`az`)
* actionlint (GitHub Actions workflow linter)

### Code Quality

* Markdown: markdownlint, markdown-table-formatter
* Spelling: Code Spell Checker (VS Code extension)
* Shell: shellcheck

### Security

* Gitleaks (secret scanning)
* osv-scanner (dependency vulnerability scanning)

### PowerShell Modules

* PSScriptAnalyzer
* PowerShell-Yaml
* Pester 5.7.1

## Pre-installed VS Code Extensions

* Spell Checking: Street Side Software Spell Checker
* Markdown: markdownlint, Markdown All in One, Mermaid support
* GitHub: GitHub Pull Requests

## Common Commands

Run these commands inside the container:

```bash
# Lint Markdown files
markdownlint '**/*.md' --ignore node_modules

# Check spelling
cspell '**/*.md'

# Check shell scripts
shellcheck scripts/**/*.sh

# Security scan
gitleaks detect --source . --verbose
```

## Troubleshooting

Container won't build: Ensure Docker Desktop is running and you have sufficient disk space (5GB+).

Extensions not loading: Reload the window (`F1` → **Developer: Reload Window**).

For more help, see [SUPPORT.md](../SUPPORT.md).

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
