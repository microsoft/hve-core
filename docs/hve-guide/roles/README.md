---
title: Role Guides
description: Find your role-specific guide for AI-assisted engineering with HVE Core tooling
author: Microsoft
ms.date: 2026-02-18
ms.topic: concept
keywords:
  - roles
  - guides
  - AI-assisted engineering
  - collections
estimated_reading_time: 5
---

HVE Core provides role-specific tooling through collections of agents, prompts, instructions, and skills. Each role guide covers recommended collections, stage walkthroughs, starter prompts, and collaboration patterns tailored to how you work.

## Role Overview

| Role                     | Dedicated Assets | Total Addressable | Primary Stages                        | Guide                                                        |
|--------------------------|------------------|-------------------|---------------------------------------|--------------------------------------------------------------|
| Engineer                 | 26               | 28+               | Stage 2, Stage 3, Stage 6, Stage 7, Stage 8 | [Engineer](engineer.md)                                      |
| TPM                      | 24               | 32+               | Stage 2, Stage 3, Stage 4, Stage 5, Stage 8 | [TPM](tpm.md)                                               |
| Tech Lead / Architect    | 19               | 23+               | Stage 2, Stage 3, Stage 6, Stage 7, Stage 9 | [Tech Lead](tech-lead.md)                                   |
| Security Architect       | 3                | 9                 | Stage 2, Stage 3, Stage 7, Stage 9    | [Security Architect](security-architect.md)                  |
| Data Scientist           | 6                | 13                | Stage 2, Stage 3, Stage 6, Stage 7, Stage 8 | [Data Scientist](data-scientist.md)                          |
| SRE / Operations         | 8                | 13+               | Stage 1, Stage 3, Stage 6, Stage 8, Stage 9 | [SRE / Operations](sre-operations.md)                       |
| Business Program Manager | N/A              | N/A               | Stage 2, Stage 3, Stage 4, Stage 5    | [Business Program Manager](business-program-manager.md)      |
| New Contributor          | 2                | 10                | Stage 1, Stage 2, Stage 6, Stage 7    | [New Contributor](new-contributor.md)                         |
| Utility                  | N/A              | 13                | All                                   | [Utility](utility.md)                                        |

## Find Your Role

| I want to...                                                    | Recommended Role Guide                                          |
|-----------------------------------------------------------------|-----------------------------------------------------------------|
| Write code, implement features, or fix bugs                     | [Engineer](engineer.md)                                         |
| Plan projects, manage requirements, or track work               | [TPM](tpm.md)                                                   |
| Design architecture, review code, or set standards              | [Tech Lead](tech-lead.md)                                       |
| Assess security, create threat models, or review compliance     | [Security Architect](security-architect.md)                     |
| Analyze data, build notebooks, or create dashboards             | [Data Scientist](data-scientist.md)                             |
| Manage infrastructure, handle incidents, or deploy              | [SRE / Operations](sre-operations.md)                           |
| Define business outcomes or manage stakeholder alignment        | [Business Program Manager](business-program-manager.md)         |
| Get started contributing to the project                         | [New Contributor](new-contributor.md)                            |
| Use cross-cutting utilities (memory, docs, media)               | [Utility](utility.md)                                           |

## Collection Quick Reference

| Collection         | Primary Roles              | Install                                              |
|--------------------|----------------------------|------------------------------------------------------|
| hve-core-all       | All                        | Full install                                         |
| rpi                | Engineer, Tech Lead        | `@hve-core-installer install rpi`                    |
| ado                | TPM, Engineer              | `@hve-core-installer install ado`                    |
| github             | TPM, Engineer              | `@hve-core-installer install github`                 |
| coding-standards   | Engineer, Tech Lead, SRE   | `@hve-core-installer install coding-standards`       |
| data-science       | Data Scientist             | `@hve-core-installer install data-science`           |
| project-planning   | TPM, BPM, Tech Lead        | `@hve-core-installer install project-planning`       |
| prompt-engineering | Tech Lead, Prompt Engineers | `@hve-core-installer install prompt-engineering`     |
| security-planning  | Security Architect, SRE    | `@hve-core-installer install security-planning`      |

## Collaboration Patterns

Roles frequently collaborate across workflows. These scenarios illustrate common multi-role interactions:

* Engineers and tech leads collaborate on feature development with architecture review, coding standards enforcement, and implementation guidance. See the [Engineer](engineer.md) and [Tech Lead](tech-lead.md) guides.
* TPMs and security architects coordinate secure product launches combining requirements gathering, threat modeling, and compliance verification. See the [TPM](tpm.md) and [Security Architect](security-architect.md) guides.
* Data scientists and engineers bridge analytics pipeline development with data specification, notebook prototyping, and production integration. See the [Data Scientist](data-scientist.md) and [Engineer](engineer.md) guides.
* New contributors progress to engineers through onboarding from guided workflows to full autonomous engineering. See the [New Contributor](new-contributor.md) and [Engineer](engineer.md) guides.

## Next Steps

> [!TIP]
> See the full project lifecycle at [AI-Assisted Project Lifecycle](../lifecycle/) to understand how stages connect across roles. Each stage guide maps available HVE Core tools and role-specific guidance for that phase of work.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
