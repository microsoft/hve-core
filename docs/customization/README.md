---
title: Customizing HVE Core
description: Overview of customization approaches from lightweight settings to full fork-and-extend, with role-based entry points
author: Microsoft
ms.date: 2026-08-31
ms.topic: overview
sidebar_position: 1
keywords:
  - customization
  - github copilot
  - hve-core
  - configuration
estimated_reading_time: 5
---

## Before You Customize

Your installation method determines which customization options are available.

| Customization Level       | Extension Only  | Installer Skill (Clone) | Direct Clone |
|---------------------------|:---------------:|:-----------------------:|:------------:|
| VS Code Settings          |       Yes       |           Yes           |     Yes      |
| copilot-instructions.md   |       Yes       |           Yes           |     Yes      |
| .instructions.md files    | Yes (your repo) |           Yes           |     Yes      |
| Multi-kind selection      |       No        |           Yes           |     Yes      |
| Modify agents             |       No        |           No            |     Yes      |
| Modify prompts and skills |       No        |           No            |     Yes      |
| Build system changes      |       No        |           No            |     Yes      |
| Fork and extend           |       No        |           No            |     Yes      |

The [HVE Core extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) installs the complete active component set.
For MCP guidance, installation-method selection, or selective cloning, ask an agent to use the included `hve-core-installer` skill. Its complete and custom flows select agents, prompts, instructions, and distributable skill directories while preserving repository-relative paths. Hooks are not copied.
For full artifact modification, use a [clone-based installation method](../getting-started/methods/).

## Customization Spectrum

HVE Core supports a range of customization depths. Start with the lightest option that meets your needs, then move deeper when the situation demands it.

```mermaid
graph LR
  accTitle: HVE Core Customization Depth Spectrum
  accDescr: Customization progresses from VS Code settings through instructions, agents and prompts, skills, the plugin manifest, build-system changes, and a full fork as complexity increases.
    A["VS Code Settings"] --> B["Instructions"]
    B --> C["Agents & Prompts"]
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

| Approach           | Description                                                                                                                                                 |
|--------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------|
| VS Code Settings   | Individual preferences like font size, theme, and editor behavior. No files to create or share.                                                             |
| Instructions       | Configure Copilot behavior through `.github/copilot-instructions.md` and `.instructions.md` files. Lowest effort with highest return for shaping AI output. |
| Agents and Prompts | Specialized workflows: agents for multi-turn interactions, prompts for single-shot tasks. Both accept tool restrictions and delegation rules.               |
| Skills             | Domain knowledge in self-contained bundles with optional scripts. Use when instruction files alone cannot capture the depth of a domain.                    |
| Plugin Manifest    | Synchronize the complete plugin and VSIX component set from tracked source.                                                                                 |
| Build System       | Validation scripts, schema checks, and extension packaging.                                                                                                 |
| Fork and Extend    | Full control over every artifact. Fork the repository when your changes diverge significantly from upstream.                                                |

## Choose Your Approach

| Goal                                   | Approach        | Files Involved                                        | Difficulty |
|----------------------------------------|-----------------|-------------------------------------------------------|------------|
| Set coding standards for Copilot       | Instructions    | `.github/copilot-instructions.md`, `.instructions.md` | Low        |
| Create a reusable workflow             | Prompt          | `.github/prompts/{package-id}/name.prompt.md`         | Low        |
| Build a specialized Copilot assistant  | Agent           | `.github/agents/{package-id}/name.agent.md`           | Medium     |
| Package domain expertise               | Skill           | `.github/skills/{package-id}/{skill}/SKILL.md`        | Medium     |
| Change managed distribution membership | Plugin Manifest | `plugin.json`, `docs/plugins/hve-core.md`             | Medium     |
| Add custom validation or packaging     | Build System    | `scripts/`, `package.json`                            | High       |
| Diverge from upstream entirely         | Fork and Extend | Full repository                                       | High       |

## Authoring with HVE Builder

Use the `hve-builder` skill to create, improve, refactor, replace, review, or
validate prompts, instructions, agents, subagents, and skills. It resolves the
write boundary, completes known edits, independent static review, and local
validation, then freezes the candidate before one final behavior decision. Major
mutations and behavior-bearing review targets invoke HVE Builder Tester at most
once; eligible no-runtime review targets and Minor or Medium mutations are
satisfied-and-skipped. A behavior finding ends the current run instead of
starting an edit-and-retest loop. Known target files and caller-supplied canonical
references remain bounded lifecycle reads; open-ended exploration and
decision-critical research activate `rpi-research`.

The retained `prompt-builder`, `prompt-analyze`, and `prompt-refactor` skills
remain compatibility aliases for legacy requests. They route to `hve-builder`
and do not own separate authoring workflows.

Each artifact guide below includes an "Authoring with HVE Builder" section
with type-specific examples.

## Role-Based Entry Points

Each HVE role benefits from different customization techniques. The table below maps each role to the guides most relevant to their workflow.

| Role                     | Recommended Guides                                                               | Rationale                                                                        |
|--------------------------|----------------------------------------------------------------------------------|----------------------------------------------------------------------------------|
| Engineer                 | [Instructions](instructions.md), [Agents](custom-agents.md)                      | Coding standards and specialized review agents accelerate daily development      |
| TPM                      | [Prompts](prompts.md), [Plugin Manifest](packages.md)                            | Reusable planning prompts and managed distribution standardize project workflows |
| Tech Lead / Architect    | [Instructions](instructions.md), [Agents](custom-agents.md), [Skills](skills.md) | Standards enforcement, architecture review agents, and deep domain knowledge     |
| Security Architect       | [Skills](skills.md), [Instructions](instructions.md)                             | Compliance knowledge packages and security-focused coding conventions            |
| Data Scientist           | [Skills](skills.md), [Prompts](prompts.md)                                       | Analytical domain bundles and repeatable notebook workflows                      |
| SRE / Operations         | [Instructions](instructions.md), [Environment](environment.md)                   | Infrastructure conventions and DevContainer tuning                               |
| Platform / Observability | [Copilot OTel Metrics](copilot-otel-metrics.md)                                  | Agent usage, token cost, and latency measurement through OpenTelemetry           |
| Business Program Manager | [Prompts](prompts.md), [Team Adoption](team-adoption.md)                         | Sprint-planning prompts and governance patterns for stakeholder alignment        |
| New Contributor          | [Instructions](instructions.md), [Environment](environment.md)                   | Quick onboarding through conventions and a ready-to-use development environment  |
| Utility                  | [Plugin Manifest](packages.md), [Build System](build-system.md)                  | Cross-cutting tooling assembly and validation pipeline customization             |

## File Index

1. [Customizing with Instructions](instructions.md): Configure Copilot with `copilot-instructions.md` and instruction files
2. [Creating Custom Agents](custom-agents.md): Build specialized agents with tool restrictions and subagent delegation
3. [Creating Custom Prompts](prompts.md): Author reusable prompt templates with variables
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
