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
estimated_reading_time: 3
---

An open-source library of Hypervelocity Engineering components that accelerates Azure solution development by enabling advanced conversational workflows.

[![Install HVE Core](https://img.shields.io/badge/Install_HVE_Core-007ACC?style=for-the-badge&logo=visualstudiocode&logoColor=white)](vscode:chat-agent/install?url=https%3A%2F%2Fraw.githubusercontent.com%2Fmicrosoft%2Fhve-core%2Fmain%2F.github%2Fagents%2Fhve-core-installer.agent.md) [![Install in VS Code Insiders](https://img.shields.io/badge/VS_Code_Insiders-Install-24bfa5?style=for-the-badge&logo=visualstudiocode&logoColor=white)](vscode-insiders:chat-agent/install?url=https%3A%2F%2Fraw.githubusercontent.com%2Fmicrosoft%2Fhve-core%2Fmain%2F.github%2Fagents%2Fhve-core-installer.agent.md)

**Quick Install:** Automated installation via the `hve-core-installer` agent in VS Code (~30 seconds)

## Overview

HVE Core provides a unified set of optimized GitHub Copilot and Microsoft 365 Copilot chat modes, along with curated instructions and prompt templates, to deliver intelligent, context-aware interactions for building solutions on Azure. Whether you're tackling greenfield projects or modernizing existing systems, HVE Core reduces time-to-value and simplifies complex engineering tasks.

## Quick Start

### Automated Installation

**Recommended:** Use the `hve-core-installer` agent for automated setup:

1. Open GitHub Copilot Chat in VS Code (Ctrl+Alt+I)
2. Select the `hve-core-installer` agent from the agent picker dropdown
3. Follow the guided installation (~30 seconds)

The installer will:

* Clone the hve-core repository as a sibling to your workspace
* Validate the repository structure
* Update your VS Code settings.json with chat mode, prompt, and instruction paths
* Make all HVE Core components immediately available

### Manual Installation

To use HVE Core's GitHub Copilot customizations in your project, clone this repository as a sibling to your project and configure a multi-root workspace. See the [Getting Started Guide](docs/getting-started.md) for step-by-step instructions.

### Prerequisites

* GitHub Copilot subscription
* VS Code with GitHub Copilot extension
* Git installed and available in PATH
* Node.js and npm (for development and validation)

### Using Chat Modes

Select specialized AI assistants from the agent picker dropdown in GitHub Copilot Chat:

1. Open Chat view (Ctrl+Alt+I)
2. Click the agent picker dropdown at the top
3. Select your desired agent:
   * **task-planner** - Plan new features and refactoring
   * **task-researcher** - Research Azure services and approaches
   * **prompt-builder** - Create coding instructions and prompts
   * **pr-review** - Review pull requests comprehensively

[Learn more about chat modes →](.github/chatmodes/README.md)

### Using Instructions

Repository-specific coding guidelines are automatically applied by GitHub Copilot when you edit files. Instructions ensure consistent code style, conventions, and best practices across your codebase without manual intervention.

[Learn more about instructions →](.github/instructions/README.md)

## Features

* 🤖 **Specialized Chat Modes** - Task planning, research, prompt engineering, and PR reviews
* 📋 **Coding Instructions** - Repository-specific guidelines that Copilot automatically follows
* 🚀 **Accelerated Development** - Pre-built workflows for common Azure development tasks
* 🔄 **Reusable Components** - Curated templates and patterns for consistent solutions

## Project Structure

```text
.github/
├── chatmodes/       # Specialized Copilot chat assistants
├── instructions/    # Repository-specific coding guidelines
└── workflows/       # CI/CD automation
scripts/
└── linting/         # Code quality and validation tools
```

## Contributing

We appreciate contributions! Whether you're fixing typos or adding new components:

1. Read our [Contributing Guide](CONTRIBUTING.md)
2. Check out [open issues](https://github.com/microsoft/hve-core/issues)
3. Join the [discussion](https://github.com/microsoft/hve-core/discussions)

## Resources

* [Chat Modes Documentation](.github/chatmodes/README.md)
* [Instructions Documentation](.github/instructions/README.md)
* [Contributing Guide](CONTRIBUTING.md)
* [Code of Conduct](CODE_OF_CONDUCT.md)
* [Security Policy](SECURITY.md)
* [Support](SUPPORT.md)

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
