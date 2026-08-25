---
title: HVE Core
description: Complete HVE Core plugin identity, distribution channels, membership policy, and capability inventory
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-19
ms.topic: reference
keywords:
  - package
  - hve core
  - foundation
---

HVE Core is the single plugin and extension identity for all distributable HVE Core content.

> [!CAUTION]
> HVE Core evolves quickly. Evaluate these assets as adaptable engineering patterns, review changes before adoption, and pin an exact release tag when reproducible source is required.

Root `plugin.json` owns complete membership. `.github/plugin/marketplace.json` contains one `hve-core` entry whose relative source is the repository root; it does not repeat component membership. The plugin details view resolves root `README.md` and `LICENSE`, while the VSIX retains its own generated README and license.

Stable and PreRelease contain the same complete agents, prompts, instructions, skills, and telemetry hook. Channel selection changes source ownership, cadence, version, release assurance, and VS Code Marketplace behavior, not membership.

The channels differ in cadence, version, and source ownership. `main` provides ref-less development-tip delivery. PreRelease follows a reviewed promotion from `main` to `release/prerelease`. Stable follows a reviewed promotion from `release/prerelease` to `release/stable`.

The moving Copilot CLI registrations are `microsoft/hve-core#release/prerelease` and `microsoft/hve-core#release/stable`. For reproducible source selection, use `prerelease-v<version>` or `v<version>`. Release workflows package one VSIX from the selected exact tag and bind it to its source SHA with SPDX and provenance attestations. Stable also publishes OpenVEX.

## Install and Select

Install the plugin from a registered marketplace:

```bash
copilot plugin install hve-core@hve-core
```

Install the extension as `ise-hve-essentials.hve-core`. For a repository-owned subset, use `hve-core-installer` to choose all manifest components or a custom selection. The installer records `selection.profile` and `selection.components` in `.hve-tracking.json` and does not copy hooks.

The full repository-relative path inventory remains machine-readable in root `plugin.json`. Agent, prompt, instruction, and skill reference pages are available under `docs/reference/`.

## Component Inventory

| Component kind | Manifest field | Source convention                                     |
|----------------|----------------|-------------------------------------------------------|
| Agents         | `agents`       | `.github/agents/<package>/**/*.agent.md`              |
| Prompts        | `commands`     | `.github/prompts/<package>/**/*.prompt.md`            |
| Instructions   | `rules`        | `.github/instructions/<package>/**/*.instructions.md` |
| Skills         | `skills`       | `.github/skills/<package>/<skill>/SKILL.md`           |

### Capability Areas

The complete plugin includes:

* RPI lifecycle coordination, research, planning, implementation, review, and walkthroughs
* HVE Builder authoring, behavior testing, validation, and Vally conformance support
* Coding standards and code review for multiple languages and infrastructure formats
* Security, TM7 threat-model generation, supply-chain security, privacy, accessibility, and Responsible AI planning and review
* Outcome hypotheses, business requirements, product requirements, architecture decisions, performance, and backlog workflows
* Azure DevOps, GitHub, GitLab, and Jira integrations
* Design Thinking, UX, data science, experimentation, diagrams, PowerPoint, voice-over, and demo media tooling
* Documentation authoring, release workflows, Git operations, and local telemetry foundations

### Membership Policy

`npm run plugin:sync` includes tracked package-scoped agents, prompts, and instructions that match their canonical suffixes. It includes a skill when `.github/skills/<package>/<skill>/SKILL.md` is tracked and its top-level license has no noncommercial qualifier.

Repository-root artifacts without a package segment are repository-specific and excluded. The manifest is unique and ordinal-sorted, and the fixed telemetry hook remains present. `npm run plugin:validate` checks this membership without writing.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
