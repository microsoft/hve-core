---
title: HVE Core
description: Open-source library of Hypervelocity Engineering components that accelerates Azure solution development
author: Microsoft
ms.date: 2025-11-05
ms.topic: overview
keywords:
  - hypervelocity engineering
  - azure
  - github copilot
  - m365 copilot
  - conversational workflows
  - chat modes
  - copilot instructions
estimated_reading_time: 2
---

An open-source library of Hypervelocity Engineering components that accelerates Azure solution development by enabling advanced conversational workflows.

**Quick Install:** Automated installation via the `hve-core-installer` agent in VS Code (~30 seconds)

## Overview

HVE Core provides a unified set of optimized GitHub Copilot and Microsoft 365 Copilot chat modes, along with curated instructions and prompt templates, to deliver intelligent, context-aware interactions for building solutions on Azure. Whether you're tackling greenfield projects or modernizing existing systems, HVE Core reduces time-to-value and simplifies complex engineering tasks.

## Quick Start

### Automated Installation

**Recommended:** Use the buttons below to install the `hve-core-installer` agent in your project for fully automated setup:

[![Install HVE Core](https://img.shields.io/badge/Install_HVE_Core-007ACC?style=for-the-badge&logo=visualstudiocode&logoColor=white)](https://aka.ms/install-hve-core) [![Install in VS Code Insiders](https://img.shields.io/badge/VS_Code_Insiders-Install-24bfa5?style=for-the-badge&logo=visualstudiocode&logoColor=white)](https://aka.ms/install-hve-core-insiders)

After installing the agent:

1. Open GitHub Copilot Chat in VS Code (Ctrl+Alt+I)
2. Select `hve-core-installer` from the agent list
3. Enter: "Install HVE Core into my project"
4. Follow the guided installation

The installer will:

* Clone the hve-core repository as a sibling to your workspace
* Validate the repository structure
* Update your VS Code settings.json with chat mode, prompt, and instruction paths
* Make all HVE Core components immediately available

### Manual Installation

For manual setup or alternative installation methods, see the [Getting Started Guide](docs/getting-started/README.md) which covers:

* [Peer Clone](docs/getting-started/methods/peer-clone.md) - Local VS Code, solo developers
* [Git-Ignored Clone](docs/getting-started/methods/git-ignored.md) - Devcontainer ephemeral setup
* [Mounted Directory](docs/getting-started/methods/mounted.md) - Advanced container sharing
* [Multi-Root Workspace](docs/getting-started/methods/multi-root.md) - Cross-environment portability
* [Submodule](docs/getting-started/methods/submodule.md) - Team version control
* [GitHub Codespaces](docs/getting-started/methods/codespaces.md) - Cloud development

### Prerequisites

* GitHub Copilot subscription
* VS Code with GitHub Copilot extension
* Git installed and available in PATH
* Node.js and npm (for development and validation)

### Try the RPI Workflow

Transform complex tasks into working code using Research → Plan → Implement:

1. Complete the [Your First RPI Workflow](docs/getting-started/first-workflow.md) tutorial (~15 min)
2. For simple tasks, use [prompts](.github/prompts/README.md) directly without the full workflow

## What's Included

| Component    | Description                                                          | Documentation                                  |
|--------------|----------------------------------------------------------------------|------------------------------------------------|
| Chat Modes   | Specialized AI assistants for research, planning, and implementation | [Chat Modes](.github/chatmodes/README.md)      |
| Instructions | Repository-specific coding guidelines applied automatically          | [Instructions](.github/instructions/README.md) |
| Prompts      | Reusable templates for common tasks like commits and PRs             | [Prompts](.github/prompts/README.md)           |
| Scripts      | Validation tools for linting, security, and quality                  | [Scripts](scripts/README.md)                   |

## Project Structure

```text
.github/
├── chatmodes/       # Specialized Copilot chat assistants
├── instructions/    # Repository-specific coding guidelines
└── prompts/         # Reusable prompt templates
docs/                # Learning guides and tutorials
scripts/             # Validation and development tools
```

## Contributing

We appreciate contributions! Whether you're fixing typos or adding new components:

1. Read our [Contributing Guide](CONTRIBUTING.md)
2. Check out [open issues](https://github.com/microsoft/hve-core/issues)
3. Join the [discussion](https://github.com/microsoft/hve-core/discussions)

## Documentation

| Guide                                                    | Description                                  |
|----------------------------------------------------------|----------------------------------------------|
| [Getting Started](docs/getting-started/README.md)        | Setup and first workflow tutorial            |
| [RPI Workflow](docs/rpi/README.md)                       | Deep dive into Research, Plan, Implement     |
| [Contributing](docs/contributing/README.md)              | Create chat modes, instructions, and prompts |
| [Chat Modes Reference](.github/chatmodes/README.md)      | All available chat modes                     |
| [Instructions Reference](.github/instructions/README.md) | All coding instructions                      |

## Responsible AI

Microsoft encourages customers to review its Responsible AI Standard when developing AI-enabled systems to ensure ethical, safe, and inclusive AI practices. Learn more at [Microsoft's Responsible AI](https://www.microsoft.com/ai/responsible-ai).

## Legal

This project is licensed under the [MIT License](./LICENSE).

**Security:** See [SECURITY.md](./SECURITY.md) for security policy and reporting vulnerabilities.

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
