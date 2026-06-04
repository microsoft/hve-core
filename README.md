---
title: HVE Core
description: Hypervelocity Engineering prompt library for GitHub Copilot with convention-driven AI workflows and validated artifacts
author: Microsoft
ms.date: 2026-05-04
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

## Hypervelocity Engineering (HVE) Core

<!-- markdownlint-disable MD013 -->
[![CI Status](https://github.com/microsoft/hve-core/actions/workflows/release-stable.yml/badge.svg)](https://github.com/microsoft/hve-core/actions/workflows/release-stable.yml)
[![CodeQL](https://github.com/microsoft/hve-core/actions/workflows/codeql-analysis.yml/badge.svg)](https://github.com/microsoft/hve-core/actions/workflows/codeql-analysis.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/microsoft/hve-core/badge)](https://scorecard.dev/viewer/?uri=github.com/microsoft/hve-core)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/11795/badge)](https://www.bestpractices.dev/projects/11795)
[![License](https://img.shields.io/github/license/microsoft/hve-core)](./LICENSE)
[![Documentation](https://img.shields.io/badge/docs-microsoft.github.io%2Fhve--core-blue)](https://microsoft.github.io/hve-core/)
<!-- markdownlint-enable MD013 -->

HVE Core helps teams ship faster with GitHub Copilot by combining specialized agents, reusable prompts, coding instructions, and validated skills into one workflow system.

Use HVE Core when you want AI-assisted work to be repeatable, standards-aligned, and scalable across individuals and teams. HVE Core provides structured AI workflow building blocks:

* Agents for specialized tasks such as research, planning, implementation, and review
* Prompts for repeatable workflow entry points
* Instructions that apply coding standards automatically
* Skills that add reusable tool capabilities

## Where to Start

<!-- markdownlint-disable MD013 -->
[![Install HVE Core - Essentials Collection](https://img.shields.io/badge/VS%20Code-Install%20Core%20Collection-007ACC?logo=visualstudiocode&logoColor=white)](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core)
<!-- markdownlint-enable MD013 -->

1. Install the [HVE Core extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) from the VS Code Marketplace.
2. Open any project and launch GitHub Copilot Chat (`Ctrl+Alt+I`).
3. Select an agent from the picker (try **rpi-agent**, **task-researcher**, or **memory**) and start a conversation.

> [!TIP]
> Use [HVE Core All Extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core-all) when you want the full collection deployment. See [Collections Overview](docs/getting-started/collections.md).
> [!TIP]
> Using GitHub Copilot CLI? Install as a plugin instead:
>
> ```bash
> copilot plugin marketplace add microsoft/hve-core
> copilot plugin install hve-core@hve-core
> ```
>
> See [CLI Plugins](docs/getting-started/methods/cli-plugins.md) for usage details.

## Choose Your Path

* New to HVE-Core: Start with [Start Here](docs/getting-started/README.md) to complete your first workflow quickly.
* Leading a team: Use the [Team Adoption Guide](docs/customization/team-adoption.md) to roll out standards and onboarding.
* Contributing to this repo: Follow the [Contributing Guide](CONTRIBUTING.md) to add or improve agents, prompts, instructions, and skills.

## Navigate This Repository

| Goal                         | Go here                                                              |
|------------------------------|----------------------------------------------------------------------|
| Start quickly                | [docs/getting-started/start-here.md](docs/getting-started/README.md) |
| Understand all setup options | [docs/getting-started/install.md](docs/getting-started/install.md)   |
| Learn the core methodology   | [docs/rpi/README.md](docs/rpi/README.md)                             |
| Browse docs by topic         | [docs/README.md](docs/README.md)                                     |
| Explore agents               | [.github/CUSTOM-AGENTS.md](.github/CUSTOM-AGENTS.md)                 |
| Explore instructions         | [.github/instructions/README.md](.github/instructions/README.md)     |
| Explore prompts              | [.github/prompts/README.md](.github/prompts/README.md)               |
| Explore skills               | [.github/skills/](.github/skills/)                                   |

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

### Licensing

Most content in this repository is covered by the MIT License. Certain skill content
derived from OWASP Foundation publications is licensed under
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Each affected
skill identifies its license in frontmatter and includes a Third-Party Attribution
section. See [THIRD-PARTY-NOTICES](./THIRD-PARTY-NOTICES) for full details.

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
