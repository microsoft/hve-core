---
title: Dev Container
description: Pre-configured development environment for HVE Core with all required tools and extensions
author: HVE Core Team
ms.date: 2025-11-05
ms.topic: guide
keywords:
  - devcontainer
  - development environment
  - vscode
  - docker
estimated_reading_time: 3
---

# Dev Container

A pre-configured development environment that includes all tools, extensions, and dependencies needed for HVE Core development. Ensures consistency across all development machines.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [Visual Studio Code](https://code.visualstudio.com/)
- [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- Git

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
   - Press `F1` or `Ctrl+Shift+P`
   - Select **Dev Containers: Reopen in Container**
   - Wait for the container to build (first time takes 5-10 minutes)

## Included Tools

### Languages & Runtimes
- Node.js (LTS)
- Python 3.11
- PowerShell 7.x

### CLI Tools
- Git
- GitHub CLI (`gh`)
- Azure CLI (`az`)

### Code Quality
- **Markdown**: markdownlint, markdown-table-formatter
- **Spelling**: Code Spell Checker (VS Code extension)
- **Shell**: shellcheck
- **Diagrams**: Mermaid CLI

### Security
- Gitleaks (secret scanning)
- Checkov (infrastructure as code scanning)

## Pre-installed VS Code Extensions

- **Spell Checking**: Street Side Software Spell Checker
- **Markdown**: markdownlint, Markdown All in One, Mermaid support
- **GitHub**: GitHub Pull Requests

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

**Container won't build**: Ensure Docker Desktop is running and you have sufficient disk space (5GB+).

**Extensions not loading**: Reload the window (`F1` → **Developer: Reload Window**).

For more help, see [SUPPORT.md](../SUPPORT.md).

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
