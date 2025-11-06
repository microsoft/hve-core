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

We welcome contributions from the community. Please see our [Contributing Guide](CONTRIBUTING.md) for details on:

* Setting up your development environment
* Submitting bug reports and feature requests
* Code style and validation requirements
* Pull request process

## Resources

* [Chat Modes Documentation](.github/chatmodes/README.md)
* [Instructions Documentation](.github/instructions/README.md)
* [Contributing Guide](CONTRIBUTING.md)
* [Code of Conduct](CODE_OF_CONDUCT.md)
* [Security Policy](SECURITY.md)
* [Support](SUPPORT.md)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
