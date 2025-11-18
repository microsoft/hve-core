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

## Overview

HVE Core provides a unified set of optimized GitHub Copilot and Microsoft 365 Copilot chat modes, along with curated instructions and prompt templates, to deliver intelligent, context-aware interactions for building solutions on Azure. Whether you're tackling greenfield projects or modernizing existing systems, HVE Core reduces time-to-value and simplifies complex engineering tasks.

## Quick Start

### Prerequisites

* GitHub Copilot subscription
* VS Code with GitHub Copilot extension
* Node.js and npm (for development and validation)

### Setup

To use HVE Core's GitHub Copilot customizations in your project, clone this repository as a sibling to your project and configure a multi-root workspace. See the [Getting Started Guide](docs/getting-started.md) for step-by-step instructions.

### Using Chat Modes

Invoke specialized AI assistants directly in GitHub Copilot Chat:

```text
@task-planner Create a plan for adding authentication to the API
@task-researcher Research Azure service options for document processing
@prompt-builder Create instructions for Terraform infrastructure files
@pr-review Review this pull request for security and design issues
```

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
