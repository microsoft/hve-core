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

Hypervelocity Engineering (HVE) Core gives you specialized agents, auto-applied coding instructions, reusable prompts, and validated skills for GitHub Copilot. Turn Copilot into a constraint-based engineering workflow that scales from solo developers to enterprise teams.

> [!TIP]
> Install from the VS Code Marketplace in under 30 seconds. See the [Installation Guide](docs/getting-started/install.md) for all options.

## Quick Start

1. Install the [HVE Core extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) from the VS Code Marketplace.
2. Open any project and launch GitHub Copilot Chat (`Ctrl+Alt+I`).
3. Select an agent from the picker (try **rpi-agent**, **task-researcher**, or **memory**) and start a conversation.

That's it. Agents, instructions, and prompts activate automatically once the extension is installed.

Ready for more? Follow the [Getting Started Guide](docs/getting-started/README.md).

## Choose Your Extension

Two VS Code extensions serve different needs:

| Extension                                                                                             | What it includes                                                | Best for                                                                |
|-------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------|-------------------------------------------------------------------------|
| [HVE Core](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core)           | Every collection: all agents, prompts, instructions, and skills | Individual developers and teams that want the full library              |
| [HVE Installer](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-installer) | Selective installation of specific collections                  | Teams that want to pick only the collections relevant to their workflow |

Not sure which to choose? Start with HVE Core. You can switch to HVE Installer later if you need finer control over which collections are active. See the [Collections Overview](docs/getting-started/collections.md) for a comparison of all available bundles.

## What's Included

| Component    | Count | Description                                                          | Documentation                                  |
|--------------|-------|----------------------------------------------------------------------|------------------------------------------------|
| Agents       | 34    | Specialized AI assistants for research, planning, and implementation | [Agents](.github/CUSTOM-AGENTS.md)             |
| Instructions | 68    | Repository-specific coding guidelines applied automatically          | [Instructions](.github/instructions/README.md) |
| Prompts      | 40    | Reusable templates for common tasks like commits and PRs             | [Prompts](.github/prompts/README.md)           |
| Skills       | 3     | Self-contained packages with cross-platform scripts and guidance     | [Skills](.github/skills/)                      |
| Scripts      | N/A   | Validation tools for linting, security, and quality                  | [Scripts](scripts/README.md)                   |

## Documentation

Full documentation is available at **<https://microsoft.github.io/hve-core/>**.

| Guide                                                            | Description                                     |
|------------------------------------------------------------------|-------------------------------------------------|
| [Getting Started](docs/getting-started/README.md)                | Setup and first workflow tutorial               |
| [Collections](docs/getting-started/collections.md)               | Available bundles and selection guide           |
| [RPI Workflow](docs/rpi/README.md)                               | Deep dive into Research, Plan, Implement        |
| [Contributing](docs/contributing/README.md)                      | Create custom agents, instructions, and prompts |
| [Agents Reference](.github/CUSTOM-AGENTS.md)                     | All available agents                            |
| [Instructions Reference](.github/instructions/README.md)         | All coding instructions                         |
| [AI Artifacts Architecture](docs/architecture/ai-artifacts.md)   | Prompt engineering framework and artifact types |
| [Validation Standards](docs/contributing/ai-artifacts-common.md) | CI/CD validation pipeline and quality gates     |

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

1. Read our [Contributing Guide](CONTRIBUTING.md).
2. Check out [open issues](https://github.com/microsoft/hve-core/issues).
3. Join the [discussion](https://github.com/microsoft/hve-core/discussions).

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
