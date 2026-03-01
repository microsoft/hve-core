---
title: Customizing HVE Core
description: Overview of customization approaches from lightweight settings to full fork-and-extend, with role-based entry points
author: Microsoft
ms.date: 2026-02-24
ms.topic: overview
keywords:
  - customization
  - github copilot
  - hve-core
  - configuration
estimated_reading_time: 5
---

## Customization Spectrum

HVE Core supports a range of customization depths. Start with the lightest option that meets your needs, then move deeper when the situation demands it.

```mermaid
graph LR
    A["VS Code Settings"] --> B["Instructions"]
    B --> C["Agents & Prompts"]
    C --> D["Skills"]
    D --> E["Collections"]
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

* **VS Code Settings** suit individual preferences like font size, theme, and editor behavior. No files to create or share.
* **Instructions** configure Copilot behavior through `.github/copilot-instructions.md` and `.instructions.md` files. Lowest effort with the highest return for shaping AI output.
* **Agents and Prompts** define specialized workflows: agents for multi-turn interactions, prompts for single-shot tasks. Both accept tool restrictions and delegation rules.
* **Skills** package domain knowledge into self-contained bundles with optional scripts. Use when instruction files alone cannot capture the depth of a domain.
* **Collections** bundle agents, prompts, instructions, and skills into distributable packages for team or organization adoption.
* **Build System** customization lets you add validation scripts, schema checks, and plugin generation pipelines.
* **Fork and Extend** gives full control over every artifact. Fork the repository when your changes diverge significantly from upstream.

## Choose Your Approach

| Goal                                       | Approach        | Files Involved                                        | Difficulty |
|--------------------------------------------|-----------------|-------------------------------------------------------|------------|
| Set coding standards for Copilot           | Instructions    | `.github/copilot-instructions.md`, `.instructions.md` | Low        |
| Create a reusable workflow                 | Prompt          | `.github/prompts/{collection}/name.prompt.md`         | Low        |
| Build a specialized Copilot assistant      | Agent           | `.github/agents/{collection}/name.agent.md`           | Medium     |
| Package domain expertise                   | Skill           | `.github/skills/{collection}/{skill}/SKILL.md`        | Medium     |
| Share curated bundles across teams         | Collection      | `collections/*.collection.yml`                        | Medium     |
| Add custom validation or plugin generation | Build System    | `scripts/`, `package.json`                            | High       |
| Diverge from upstream entirely             | Fork and Extend | Full repository                                       | High       |

## Authoring with Prompt Builder

The [Prompt Builder](pathname://../../.github/agents/hve-core/prompt-builder.agent.md) agent streamlines creation, evaluation, and refinement of all artifact types. Three commands cover the full authoring workflow:

| Command            | Purpose                                                         |
|--------------------|-----------------------------------------------------------------|
| `/prompt-build`    | Create new artifacts or improve existing ones                   |
| `/prompt-analyze`  | Evaluate quality and produce a structured assessment report     |
| `/prompt-refactor` | Consolidate, deduplicate, or restructure related artifact files |

Each artifact guide below includes an "Accelerating with Prompt Builder" section with type-specific examples and sample invocations.

## Role-Based Entry Points

Each HVE role benefits from different customization techniques. The table below maps the nine roles to the guides most relevant to their workflow.

| Role                     | Recommended Guides                                                        | Rationale                                                                       |
|--------------------------|---------------------------------------------------------------------------|---------------------------------------------------------------------------------|
| Engineer                 | [Instructions](instructions.md), [Agents](agents.md)                      | Coding standards and specialized review agents accelerate daily development     |
| TPM                      | [Prompts](prompts.md), [Collections](collections.md)                      | Reusable planning prompts and curated bundles standardize project workflows     |
| Tech Lead / Architect    | [Instructions](instructions.md), [Agents](agents.md), [Skills](skills.md) | Standards enforcement, architecture review agents, and deep domain knowledge    |
| Security Architect       | [Skills](skills.md), [Instructions](instructions.md)                      | Compliance knowledge packages and security-focused coding conventions           |
| Data Scientist           | [Skills](skills.md), [Prompts](prompts.md)                                | Analytical domain bundles and repeatable notebook workflows                     |
| SRE / Operations         | [Instructions](instructions.md), [Environment](environment.md)            | Infrastructure conventions and DevContainer tuning                              |
| Business Program Manager | [Prompts](prompts.md), [Team Adoption](team-adoption.md)                  | Sprint-planning prompts and governance patterns for stakeholder alignment       |
| New Contributor          | [Instructions](instructions.md), [Environment](environment.md)            | Quick onboarding through conventions and a ready-to-use development environment |
| Utility                  | [Collections](collections.md), [Build System](build-system.md)            | Cross-cutting tooling assembly and validation pipeline customization            |

## File Index

1. [Customizing with Instructions](instructions.md): Configure Copilot with `copilot-instructions.md` and instruction files
2. [Creating Custom Agents](agents.md): Build specialized agents with tool restrictions and subagent delegation
3. [Creating Custom Prompts](prompts.md): Author reusable prompt templates with variables
4. [Authoring Custom Skills](skills.md): Create domain knowledge packages
5. [Managing Collections](collections.md): Bundle artifacts into distributable packages
6. [Build System and Validation](build-system.md): Plugin generation, schema validation, npm scripts
7. [Forking and Extending](forking.md): Full fork-and-extend customization
8. [Environment Customization](environment.md): DevContainers, VS Code settings, MCP servers
9. [Team Adoption and Governance](team-adoption.md): Governance, naming, onboarding, change management

## Related Resources

* [Contributing Guides](../contributing/): Detailed syntax references and contribution standards for each artifact type
* [Getting Started](../getting-started/): Installation and first workflow guides
* [Architecture](../architecture/): Technical architecture overview and design decisions

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
