---
title: HVE Core
description: Hypervelocity Engineering prompt library for GitHub Copilot with constraint-based AI workflows and validated artifacts
author: Microsoft
ms.date: 2026-01-22
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
[![CI Status](https://github.com/microsoft/hve-core/actions/workflows/main.yml/badge.svg)](https://github.com/microsoft/hve-core/actions/workflows/main.yml)
[![CodeQL](https://github.com/microsoft/hve-core/actions/workflows/codeql-analysis.yml/badge.svg)](https://github.com/microsoft/hve-core/actions/workflows/codeql-analysis.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/microsoft/hve-core/badge)](https://scorecard.dev/viewer/?uri=github.com/microsoft/hve-core)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/11795/badge)](https://www.bestpractices.dev/projects/11795)
[![License](https://img.shields.io/github/license/microsoft/hve-core)](./LICENSE)
<!-- markdownlint-enable MD013 -->

Hypervelocity Engineering (HVE) Core is an enterprise-ready prompt engineering framework for GitHub Copilot. Constraint-based AI workflows, validated artifacts, and structured methodologies that scale from solo developers to large teams.

**Quick Install:** Automated installation via the `hve-core-installer` agent in VS Code (~30 seconds)

## Overview

HVE Core provides 18 specialized agents, 18 reusable prompts, and 17+ instruction sets with JSON schema validation. The framework separates AI concerns into distinct artifact types with clear boundaries, preventing runaway behavior through constraint-based design.

The RPI (Research → Plan → Implement) methodology structures complex engineering tasks into phases where AI knows what it cannot do, changing optimization targets from "plausible code" to "verified truth."

## Quick Start

### VS Code Extension (Simplest)

**Recommended for most users:** Install HVE Core directly from the VS Code Marketplace for zero-configuration setup:

[![Install from Marketplace](https://img.shields.io/badge/Install_from_Marketplace-007ACC?style=for-the-badge&logo=visualstudiocode&logoColor=white)](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core)

See [Extension Installation Guide](docs/getting-started/methods/extension.md) for details.

### Copilot CLI Plugin Installation

Register the hve-core marketplace source (one-time), then install collections:

```bash
# Register marketplace (one-time setup)
copilot plugin marketplace add microsoft/hve-core

# Install the full HVE Core suite
copilot plugin install hve-core-all@hve-core

# Or install individual collections
copilot plugin install rpi@hve-core
copilot plugin install ado@hve-core
copilot plugin install prompt-engineering@hve-core
```

See [CLI Plugin Installation Guide](docs/getting-started/methods/cli-plugins.md) for available collections and usage.

### Automated Agent Installation

For customization or team version control, use the `hve-core-installer` agent:

[![Install HVE Core](https://img.shields.io/badge/Install_HVE_Core-007ACC?style=for-the-badge&logo=visualstudiocode&logoColor=white)](https://aka.ms/install-hve-core) [![Install in VS Code Insiders](https://img.shields.io/badge/VS_Code_Insiders-Install-24bfa5?style=for-the-badge&logo=visualstudiocode&logoColor=white)](https://aka.ms/install-hve-core-insiders)

After installing the agent:

1. Open GitHub Copilot Chat in VS Code (Ctrl+Alt+I)
2. Select `hve-core-installer` from the agent list
3. Enter: "Install HVE Core into my project"
4. Follow the guided installation

The installer will:

* Clone the hve-core repository as a sibling to your workspace
* Validate the repository structure
* Update your VS Code settings.json with custom agent, prompt, and instruction paths
* Make all HVE Core components immediately available

### Manual Installation

For manual setup or alternative installation methods, see the [Getting Started Guide](docs/getting-started/README.md) which covers:

* [VS Code Extension](docs/getting-started/methods/extension.md) ⭐ - Marketplace install, zero config
* [Copilot CLI Plugins](docs/getting-started/methods/cli-plugins.md) - Terminal-based CLI workflows
* [Multi-Root Workspace](docs/getting-started/methods/multi-root.md) - Cross-environment portability
* [Submodule](docs/getting-started/methods/submodule.md) - Team version control
* [Peer Clone](docs/getting-started/methods/peer-clone.md) - Local VS Code, solo developers
* [Git-Ignored Clone](docs/getting-started/methods/git-ignored.md) - Devcontainer ephemeral setup
* [Mounted Directory](docs/getting-started/methods/mounted.md) - Advanced container sharing
* [GitHub Codespaces](docs/getting-started/methods/codespaces.md) - Cloud development

### Prerequisites

* GitHub Copilot subscription
* VS Code with GitHub Copilot extension
* Git installed and available in PATH
* Node.js and npm (for development and validation)

### Try the RPI Workflow

AI coding assistants are brilliant at simple tasks. Ask for a function that reverses a string, and you'll get working code in seconds. Ask for a feature that touches twelve files across three services, and you'll get something that looks right, compiles cleanly, and breaks everything it touches.

The root cause: AI can't tell the difference between investigating and implementing. When you ask for code, it writes code. It doesn't stop to verify that the patterns it chose match your existing modules. AI generally writes first and thinks never.

HVE Core's RPI (Research → Plan → Implement) framework solves this by separating concerns into distinct phases. When AI knows it cannot implement during research, it stops optimizing for "plausible code" and starts optimizing for "verified truth." The constraint changes the goal.

Get started with RPI:

* [Why the RPI Workflow Works](docs/rpi/why-rpi.md): the psychology behind constraint-based AI workflows
* [Your First RPI Workflow](docs/getting-started/first-workflow.md): 15-minute hands-on tutorial
* [rpi-agent](.github/agents/rpi-agent.agent.md): autonomous mode for simpler tasks that don't need strict phase separation

## What's Included

| Component    | Count | Description                                                          | Documentation                                  |
|--------------|-------|----------------------------------------------------------------------|------------------------------------------------|
| Agents       | 18    | Specialized AI assistants for research, planning, and implementation | [Agents](.github/CUSTOM-AGENTS.md)             |
| Instructions | 17+   | Repository-specific coding guidelines applied automatically          | [Instructions](.github/instructions/README.md) |
| Prompts      | 18    | Reusable templates for common tasks like commits and PRs             | [Prompts](.github/prompts/README.md)           |
| Skills       | 1     | Self-contained packages with cross-platform scripts and guidance     | [Skills](.github/skills/)                      |
| Scripts      | N/A   | Validation tools for linting, security, and quality                  | [Scripts](scripts/README.md)                   |

## Prompt Engineering Framework

HVE Core provides a structured approach to prompt engineering with four artifact types, each serving a distinct purpose:

| Artifact         | Purpose                                               | Activation                   |
|------------------|-------------------------------------------------------|------------------------------|
| **Instructions** | Passive reference guidance applied by file pattern    | Automatic via `applyTo` glob |
| **Prompts**      | Task-specific procedures with input variables         | Manual via `/` command       |
| **Agents**       | Specialized personas with tool access and constraints | Manual via agent picker      |
| **Skills**       | Executable utilities with cross-platform scripts      | Read by Copilot on demand    |

**Key capabilities:**

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
├── linting/         # Markdown, frontmatter, YAML validation
└── security/        # Dependency pinning and SHA checks
```

## Contributing

We appreciate contributions! Whether you're fixing typos or adding new components:

1. Read our [Contributing Guide](CONTRIBUTING.md)
2. Check out [open issues](https://github.com/microsoft/hve-core/issues)
3. Join the [discussion](https://github.com/microsoft/hve-core/discussions)

## Documentation

| Guide                                                    | Description                                     |
|----------------------------------------------------------|-------------------------------------------------|
| [Getting Started](docs/getting-started/README.md)        | Setup and first workflow tutorial               |
| [RPI Workflow](docs/rpi/README.md)                       | Deep dive into Research, Plan, Implement        |
| [Contributing](docs/contributing/README.md)              | Create custom agents, instructions, and prompts |
| [Agents Reference](.github/CUSTOM-AGENTS.md)             | All available agents                            |
| [Instructions Reference](.github/instructions/README.md) | All coding instructions                         |

## Responsible AI

Microsoft encourages customers to review its Responsible AI Standard when developing AI-enabled systems to ensure ethical, safe, and inclusive AI practices. Learn more at [Microsoft's Responsible AI](https://www.microsoft.com/ai/responsible-ai).

## Legal

This project is licensed under the [MIT License](./LICENSE).

**Security:** See [SECURITY.md](./SECURITY.md) for security policy and reporting vulnerabilities.

**Governance:** See [GOVERNANCE.md](./GOVERNANCE.md) for the project governance model.

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
