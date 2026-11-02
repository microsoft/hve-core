---
title: Customizing HVE Core
description: Overview of customization approaches from lightweight settings to full fork-and-extend, with role-based entry points
author: Microsoft
ms.date: 2026-11-02
ms.topic: overview
sidebar_position: 1
sidebar_label: Overview
sidebar_custom_props:
  accessibleName: "Overview: Customizing HVE Core"
pagination_label: Customizing HVE Core
keywords:
  - customization
  - github copilot
  - hve-core
  - configuration
estimated_reading_time: 5
---

## Before You Customize

Your installation method determines which customization options are available.

| Customization Level     |     Plugin      | Repository Copy | Clone or Fork |
|-------------------------|:---------------:|:---------------:|:-------------:|
| VS Code Settings        |       Yes       |       Yes       |      Yes      |
| copilot-instructions.md |       Yes       |       Yes       |      Yes      |
| .instructions.md files  | Yes (your repo) |       Yes       |      Yes      |
| Modify HVE Core agents  |       No        |       Yes       |      Yes      |
| Modify HVE Core skills  |       No        |       Yes       |      Yes      |
| Build system changes    |       No        |       No        |      Yes      |
| Fork and extend         |       No        |       No        |      Yes      |

The Plugin column also applies to a repository default and to the VS Code extension.

Start with the [plugin](../getting-started/install#install-the-plugin), which installs every agent, skill, and instruction. A [repository default](../getting-started/install#offer-the-plugin-to-your-team) in `.github/copilot/settings.json` offers the plugin to everyone who opens your repository.

When your repository should own and customize its HVE Core files, ask an agent to use the included `hve-core-installer` skill. It [copies every component](../getting-started/install#copy-hve-core-into-your-repository) (agents, instructions, and complete skill directories) into your `.github` folders with their repository-relative paths and does not copy hooks. The skill can also recommend an install route and set up MCP servers.

The [VS Code extension](../getting-started/install#use-the-vs-code-extension) is another option, but its instructions may not reach Copilot sessions. For full artifact modification, [work from a clone](../getting-started/install#work-from-a-clone) or fork the repository.

## Customization Spectrum

HVE Core supports a range of customization depths. Start with the lightest option that meets your needs, then move deeper when the situation demands it.

```mermaid
graph LR
  accTitle: HVE Core Customization Depth Spectrum
  accDescr: Customization progresses from VS Code settings through instructions, agents, skills, the plugin manifest, build-system changes, and a full fork as complexity increases.
    A["VS Code Settings"] --> B["Instructions"]
    B --> C["Agents"]
    C --> D["Skills"]
    D --> E["Plugin Manifest"]
    E --> F["Build System"]
    F --> G["Fork & Extend"]

    style A fill:#e8f5e9
    style B fill:#c8e6c9
    style C fill:#a5d6a7
    style D fill:#81c784
    style E fill:#66bb6a
    style F fill:#4caf50
    style G fill:#388e3c
```

| Approach         | Description                                                                                                                                                                                             |
|------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| VS Code Settings | Individual preferences like font size, theme, and editor behavior. No files to create or share.                                                                                                         |
| Instructions     | Configure Copilot behavior through `.github/copilot-instructions.md` and `.instructions.md` files. Lowest effort with highest return for shaping AI output.                                             |
| Agents           | Specialized multi-turn workflows. An agent sets its own tools list, can preload skills, and can delegate work to subagents.                                                                             |
| Skills           | Domain knowledge in self-contained bundles with optional scripts. Use when instruction files alone cannot capture the depth of a domain. A user-invocable skill also works as a reusable slash command. |
| Plugin Manifest  | Synchronize the complete plugin and VSIX component set from tracked source.                                                                                                                             |
| Build System     | Validation scripts, schema checks, and extension packaging.                                                                                                                                             |
| Fork and Extend  | Full control over every artifact. Fork the repository when your changes diverge significantly from upstream.                                                                                            |

## Choose Your Approach

| Goal                                   | Approach        | Files Involved                                        | Difficulty |
|----------------------------------------|-----------------|-------------------------------------------------------|------------|
| Set coding standards for Copilot       | Instructions    | `.github/copilot-instructions.md`, `.instructions.md` | Low        |
| Create a reusable slash command        | Skill           | `.github/skills/{package-id}/{skill}/SKILL.md`        | Low        |
| Build a specialized Copilot assistant  | Agent           | `.github/agents/{package-id}/name.agent.md`           | Medium     |
| Package domain expertise               | Skill           | `.github/skills/{package-id}/{skill}/SKILL.md`        | Medium     |
| Change managed distribution membership | Plugin Manifest | `plugin.json`, `docs/plugins/hve-core.md`             | Medium     |
| Add custom validation or packaging     | Build System    | `scripts/`, `package.json`                            | High       |
| Diverge from upstream entirely         | Fork and Extend | Full repository                                       | High       |

## Authoring with HVE Builder

Use the `hve-builder` skill to create, improve, refactor, replace, review, or
validate instructions, agents, subagents, and skills. It resolves the
write boundary, completes known edits and local validation, then runs a review
pass against its requirements catalog and rubric. The main agent reviews the
candidate itself or dispatches the read-only `HVE Builder Reviewer` subagent for
a fresh-context review, verifies each finding, batches the required fixes,
reruns affected checks, and records the review against the reviewed revision.
It uses as few cycles as needed, stopping rather than repeating unchanged
failures or chasing advisory polish. Known target files and caller-supplied
canonical references remain bounded lifecycle reads; open-ended exploration and
decision-critical research activate `rpi-research`.

Each artifact guide below includes an "Authoring with HVE Builder" section
with type-specific examples.

## Role-Based Entry Points

Each HVE role benefits from different customization techniques. The table below maps each role to the guides most relevant to their workflow.

| Role                     | Recommended Guides                                                               | Rationale                                                                               |
|--------------------------|----------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------|
| Engineer                 | [Instructions](instructions.md), [Agents](custom-agents.md)                      | Coding standards and specialized review agents accelerate daily development             |
| TPM                      | [Slash Commands](prompts.md), [Plugin Manifest](packages.md)                     | Reusable planning slash commands and managed distribution standardize project workflows |
| Tech Lead / Architect    | [Instructions](instructions.md), [Agents](custom-agents.md), [Skills](skills.md) | Standards enforcement, architecture review agents, and deep domain knowledge            |
| Security Architect       | [Skills](skills.md), [Instructions](instructions.md)                             | Compliance knowledge packages and security-focused coding conventions                   |
| Data Scientist           | [Skills](skills.md), [Slash Commands](prompts.md)                                | Analytical domain bundles and repeatable notebook workflows                             |
| SRE / Operations         | [Instructions](instructions.md), [Environment](environment.md)                   | Infrastructure conventions and DevContainer tuning                                      |
| Platform / Observability | [Copilot OTel Metrics](copilot-otel-metrics.md)                                  | Agent usage, token cost, and latency measurement through OpenTelemetry                  |
| Business Program Manager | [Slash Commands](prompts.md), [Team Adoption](team-adoption.md)                  | Sprint-planning slash commands and governance patterns for stakeholder alignment        |
| New Contributor          | [Instructions](instructions.md), [Environment](environment.md)                   | Quick onboarding through conventions and a ready-to-use development environment         |
| Utility                  | [Plugin Manifest](packages.md), [Build System](build-system.md)                  | Cross-cutting tooling assembly and validation pipeline customization                    |

## File Index

1. [Customizing with Instructions](instructions.md): Configure Copilot with `copilot-instructions.md` and instruction files
2. [Creating Custom Agents](custom-agents.md): Build specialized agents with tool lists, preloaded skills, and subagent delegation
3. [Reusable Slash Commands](prompts.md): Build reusable slash commands as skills, since the Copilot harness does not load prompt files
4. [Authoring Custom Skills](skills.md): Create domain knowledge packages
5. [Managing the HVE Core Plugin Manifest](packages.md): Synchronize one plugin and VSIX membership
6. [Build System and Validation](build-system.md): Manifest sync, schema validation, npm scripts
7. [Forking and Extending](forking.md): Full fork-and-extend customization
8. [Environment Customization](environment.md): DevContainers, VS Code settings, MCP servers
9. [Team Adoption and Governance](team-adoption.md): Governance, naming, onboarding, change management
10. [Enterprise Artifact Hub](enterprise-artifact-hub.md): Distribute and govern artifacts across an organization
11. [Copilot OpenTelemetry Metrics](copilot-otel-metrics.md): Export Copilot OTel signals to a local Grafana stack, or to a fleet-wide Azure pipeline, and query agent, token, and latency data

## Related Resources

* [Contributing Guides](../contributing/): Detailed syntax references and contribution standards for each artifact type
* [Getting Started](../getting-started/): Installation and first workflow guides
* [Architecture](../architecture/): Technical architecture overview and design decisions

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
