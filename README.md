---
title: HVE Core
description: Hypervelocity Engineering prompt library for GitHub Copilot with constraint-based AI workflows and validated artifacts
author: Microsoft
ms.date: 2026-03-10
ms.topic: overview
keywords:
  - hypervelocity engineering
  - prompt engineering
  - github copilot
  - ai workflows
  - custom agents
  - copilot instructions
  - rpi methodology
estimated_reading_time: 3
---

<!-- markdownlint-disable MD013 -->
[![CI Status](https://github.com/microsoft/hve-core/actions/workflows/release-stable.yml/badge.svg)](https://github.com/microsoft/hve-core/actions/workflows/release-stable.yml)
[![CodeQL](https://github.com/microsoft/hve-core/actions/workflows/codeql-analysis.yml/badge.svg)](https://github.com/microsoft/hve-core/actions/workflows/codeql-analysis.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/microsoft/hve-core/badge)](https://scorecard.dev/viewer/?uri=github.com/microsoft/hve-core)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/11795/badge)](https://www.bestpractices.dev/projects/11795)
[![License](https://img.shields.io/github/license/microsoft/hve-core)](./LICENSE)
[![Documentation](https://img.shields.io/badge/docs-microsoft.github.io%2Fhve--core-blue)](https://microsoft.github.io/hve-core/)
<!-- markdownlint-enable MD013 -->

Hypervelocity Engineering (HVE) Core is an enterprise-ready prompt engineering framework for GitHub Copilot. Constraint-based AI workflows, validated artifacts, and structured methodologies that scale from solo developers to large teams.

> [!TIP]
> Install via VS Code extension or Copilot CLI plugin (~30 seconds). See the [Installation Guide](docs/getting-started/install.md).

## Overview

HVE Core provides specialized agents, reusable prompts, instruction sets, and skills with JSON schema validation. The framework separates AI concerns into distinct artifact types with clear boundaries, preventing runaway behavior through constraint-based design.

The RPI (Research → Plan → Implement) methodology structures complex engineering tasks into phases where AI knows what it cannot do, changing optimization targets from "plausible code" to "verified truth."

## Quick Start

### 1. Install

Install the VS Code extension from the Marketplace:

[![Install HVE Core](https://img.shields.io/badge/Install_HVE_Core-007ACC?style=for-the-badge&logo=visualstudiocode&logoColor=white)](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core)

> **Need guided setup or the complete artifact library?** Install the [HVE Core Installer](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-installer) extension for the installer skill. It walks you through installation methods, MCP configuration, and agent bundle selection.

Need a different installation method? See the [Installation Guide](docs/getting-started/install.md) for CLI plugins, submodules, multi-root workspaces, and more.

### 2. Verify

Open GitHub Copilot Chat (`Ctrl+Alt+I`) and check that HVE Core agents appear in the agent picker. Look for **task-researcher**, **task-planner**, and **rpi-agent**.

### 3. Try It

Select the **memory** agent and type:

> Remember that I'm exploring HVE Core for the first time.

The agent creates a memory file in your workspace. You now have a working HVE Core installation that responds to natural language.

Ready to go deeper? Follow the [Getting Started Guide](docs/getting-started/README.md).

## Documentation

Full documentation is available at **<https://microsoft.github.io/hve-core/>**.

| Guide                                                    | Description                                     |
|----------------------------------------------------------|-------------------------------------------------|
| [Getting Started](docs/getting-started/README.md)        | Setup and first workflow tutorial               |
| [RPI Workflow](docs/rpi/README.md)                       | Deep dive into Research, Plan, Implement        |
| [Contributing](docs/contributing/README.md)              | Create custom agents, instructions, and prompts |
| [Agents Reference](.github/CUSTOM-AGENTS.md)             | All available agents                            |
| [Instructions Reference](.github/instructions/README.md) | All coding instructions                         |

## What's Included

| Component    | Count | Description                                                          | Documentation                                  |
|--------------|-------|----------------------------------------------------------------------|------------------------------------------------|
| Agents       | 34    | Specialized AI assistants for research, planning, and implementation | [Agents](.github/CUSTOM-AGENTS.md)             |
| Instructions | 68    | Repository-specific coding guidelines applied automatically          | [Instructions](.github/instructions/README.md) |
| Prompts      | 40    | Reusable templates for common tasks like commits and PRs             | [Prompts](.github/prompts/README.md)           |
| Skills       | 3     | Self-contained packages with cross-platform scripts and guidance     | [Skills](.github/skills/)                      |
| Scripts      | N/A   | Validation tools for linting, security, and quality                  | [Scripts](scripts/README.md)                   |

## Prompt Engineering Framework

HVE Core provides a structured approach to prompt engineering with four artifact types, each serving a distinct purpose:

| Artifact         | Purpose                                               | Activation                   |
|------------------|-------------------------------------------------------|------------------------------|
| **Instructions** | Passive reference guidance applied by file pattern    | Automatic via `applyTo` glob |
| **Prompts**      | Task-specific procedures with input variables         | Manual via `/` command       |
| **Agents**       | Specialized personas with tool access and constraints | Manual via agent picker      |
| **Skills**       | Executable utilities with cross-platform scripts      | Read by Copilot on demand    |

### Key Capabilities

* Protocol patterns support step-based (sequential) and phase-based (conversational) workflow formats
* Input variables use `${input:variableName}` syntax with defaults and VS Code integration
* Subagent delegation provides a first-class pattern for tool-heavy work via `runSubagent`
* Maturity lifecycle follows a four-stage model (`experimental` → `preview` → `stable` → `deprecated`)

Use the `prompt-builder` agent to create new artifacts following these patterns.

## Enterprise Validation Pipeline

All AI artifacts are validated through a CI/CD pipeline with JSON schema enforcement:

```text
*.instructions.md → instruction-frontmatter.schema.json
*.prompt.md       → prompt-frontmatter.schema.json
*.agent.md        → agent-frontmatter.schema.json
SKILL.md          → skill-frontmatter.schema.json
```

The validation system provides:

* Typed frontmatter validation provides structured error reporting.
* Pattern-based schema mapping enables automatic file type detection.
* Maturity enforcement ensures artifacts declare stability level.
* Link and language checks validate cross-references.

Run `npm run lint:frontmatter` locally before committing changes.

## Project Structure

```text
.github/
├── agents/          # Specialized Copilot chat assistants
├── instructions/    # Repository-specific coding guidelines
├── prompts/         # Reusable prompt templates
├── skills/          # Self-contained executable packages
└── workflows/       # CI/CD pipeline definitions
docs/
├── getting-started/ # Installation and first workflow guides
├── rpi/             # Research, Plan, Implement methodology
├── contributing/    # Artifact authoring guidelines
└── architecture/    # System design documentation
extension/           # VS Code extension source
scripts/
├── collections/     # Collection validation and helper modules
├── extension/       # Extension packaging and preparation
├── lib/             # Shared utilities
├── linting/         # Markdown, frontmatter, YAML validation
├── plugins/         # Plugin generation
├── security/        # Dependency pinning and SHA checks
└── tests/           # Pester test suites
```

## Label Management

Repository labels are declared in [`.github/labels.yml`](.github/labels.yml) and synced automatically by the [Label Sync](.github/workflows/label-sync.yml) workflow on push to `main` or via manual `workflow_dispatch`.

| Task               | How                                                                                                                                                                                                 |
|--------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Add a label**    | Add an entry with `name`, `color` (bare hex, no `#`), and `description` to `.github/labels.yml`, then push to `main`                                                                                |
| **Update a label** | Edit the existing entry's `color` or `description`                                                                                                                                                  |
| **Rename a label** | Add an `aliases` array under the new canonical name listing the old name; the sync migrates existing assignments automatically                                                                      |
| **Delete a label** | Remove it manually in the [GitHub Labels UI](https://github.com/microsoft/hve-core/labels). Deleting an entry from the file does **not** delete it from GitHub (the workflow runs in additive mode) |

## Contributing

We appreciate contributions! Whether you're fixing typos or adding new components:

1. Read our [Contributing Guide](CONTRIBUTING.md)
2. Check out [open issues](https://github.com/microsoft/hve-core/issues)
3. Join the [discussion](https://github.com/microsoft/hve-core/discussions)

## Responsible AI

Microsoft encourages customers to review its Responsible AI Standard when developing AI-enabled systems to ensure ethical, safe, and inclusive AI practices. Learn more at [Microsoft's Responsible AI](https://www.microsoft.com/ai/responsible-ai).

## Legal

This project is licensed under the [MIT License](./LICENSE).

See [SECURITY.md](./SECURITY.md) for the security policy and vulnerability reporting.

See [GOVERNANCE.md](./GOVERNANCE.md) for the project governance model.

## Trademark Notice

> This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft
> trademarks or logos is subject to and must follow Microsoft's Trademark & Brand Guidelines. Use of Microsoft trademarks or logos in
> modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or
> logos are subject to those third-party's policies.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
