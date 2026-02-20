---
title: Copilot CLI Plugins
description: Install HVE Core agents, prompts, and skills as Copilot CLI plugins
author: Microsoft
ms.date: 2026-02-12
ms.topic: how-to
---

Install HVE Core collections as Copilot CLI plugins for terminal-based
AI-assisted development workflows.

## Prerequisites

- GitHub Copilot CLI installed and authenticated
- Git symlink support enabled (Windows: Developer Mode +
  `git config --global core.symlinks true`)

## Register hve-core as a Plugin Marketplace

```bash
copilot plugin marketplace add microsoft/hve-core
```

## Browse Available Plugins

Type `/plugin` in a Copilot CLI chat session to browse available plugins.

## Install a Plugin

```bash
copilot plugin install hve-core@hve-core
copilot plugin install hve-core-all@hve-core
```

## Available Plugins

| Plugin            | Description                                 |
|-------------------|---------------------------------------------|
| hve-core          | Research, Plan, Implement, Review lifecycle |
| github            | GitHub issue management                     |
| ado               | Azure DevOps integration                    |
| coding-standards  | Language-specific coding guidelines         |
| project-planning  | PRDs, BRDs, ADRs, architecture diagrams     |
| data-science      | Data specs, notebooks, dashboards           |
| design-thinking   | Design thinking coaching and methodology    |
| security-planning | Security and incident response              |
| installer         | HVE Core installation automation            |
| experimental      | Experimental and preview artifacts          |
| hve-core-all      | Full HVE Core bundle                        |

## Plugin Contents

Each plugin includes:

- **Agents** — Custom chat agents for specialized workflows
- **Commands** — Task prompts accessible via the CLI
- **Instructions** — Coding standards and conventions
- **Skills** — Self-contained skill packages (hve-core-all only)

Artifacts are symlinked from the plugin directory to the source repository,
enabling zero-copy installation.

## Limitations

- Instructions are included but may not be natively consumed by the CLI
  plugin system
- The `copilot plugin` commands are not yet in official GitHub Copilot
  documentation
- Skills require skill-compatible agent environments

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
