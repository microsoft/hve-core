---
title: Collections Overview
description: Explore the HVE collection system, compare available collections, and choose the right extension for your workflow
sidebar_position: 3
author: Microsoft
ms.date: 2026-03-22
ms.topic: overview
---

## How HVE Artifacts Are Organized

HVE distributes agents, prompts, instructions, and skills through collections, which are curated bundles of related artifacts. Each collection targets a specific domain or workflow, so you can install exactly what you need.

Two VS Code Marketplace extensions deliver these collections:

### HVE Core All (`ise-hve-essentials.hve-core-all`)

The complete bundle containing 221 artifacts across all domains. If you want access to everything without choosing individual collections, install this extension. It is the recommended starting point for most users.

### HVE Installer (`ise-hve-essentials.hve-installer`)

A selective deployment tool with 2 artifacts. Rather than installing the full bundle, the installer lets you choose specific collections and deploy them into your workspace. Use the installer when you want fine-grained control over which artifacts are available.

## Collection Relationships

Collections are additive, meaning installing multiple collections may include overlapping items, and that is expected. The `hve-core-all` extension is the superset bundle containing every artifact from every domain collection. Individual collections exist as independent units, so you can also install them separately through the installer.

Items retain their maturity annotations regardless of how they are installed. For example, design-thinking artifacts are marked "preview" even when accessed through the `hve-core-all` bundle.

The installer enables targeted deployment of specific collections into workspaces without requiring the full bundle. It is a separate tool, not a subset of `hve-core-all`.

## Available Collections

| Collection       | Description                                                                                                                                    | Agents | Prompts | Instructions | Skills | Maturity     | Marketplace                                                                                            |
|------------------|------------------------------------------------------------------------------------------------------------------------------------------------|--------|---------|--------------|--------|--------------|--------------------------------------------------------------------------------------------------------|
| ado              | Manage Azure DevOps work items, monitor builds, create pull requests, and convert requirements documents into structured work item hierarchies | 2      | 9       | 9            | 1      | Stable       | [Install](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-ado)              |
| coding-standards | Enforce language-specific coding conventions and best practices across your projects, with pre-PR code review agents                           | 3      | 2       | 15           | 1      | Stable       | [Install](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-coding-standards) |
| data-science     | Generate data specifications, Jupyter notebooks, and Streamlit dashboards from natural language descriptions                                   | 6      | 3       | 10           | 0      | Stable       | [Install](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-data-science)     |
| design-thinking  | AI-enhanced design thinking coaching across nine methods                                                                                       | 2      | 13      | 43           | 0      | Preview      | [Install](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-design-thinking)  |
| experimental     | Experimental and preview artifacts not yet promoted to stable collections                                                                      | 3      | 0       | 3            | 2      | Experimental | [Install](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-experimental)     |
| github           | Manage GitHub issue backlogs with agents for discovery, triage, sprint planning, and execution                                                 | 1      | 6       | 6            | 0      | Stable       | [Install](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-github)           |
| gitlab           | Run GitLab merge request and pipeline workflows through a focused skill package                                                                | 0      | 0       | 1            | 1      | Stable       | [Install](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-gitlab)           |
| hve-core         | Flagship collection: RPI (Research, Plan, Implement, Review) workflow for complex tasks with Git workflow prompts                              | 17     | 15      | 7            | 1      | Stable       | [Install](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core)             |
| hve-core-all     | Complete collection of all artifacts across all domains                                                                                        | 51     | 63      | 102          | 12     | Stable       | [Install](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core-all)         |
| installer        | Deploy HVE artifacts across workspace configurations with decision-driven setup                                                                | 0      | 0       | 1            | 1      | Stable       | [Install](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-installer)        |
| jira             | Manage Jira backlogs, plan PRD-driven issue hierarchies, and execute issue operations                                                          | 2      | 4       | 6            | 1      | Stable       | [Install](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-jira)             |
| project-planning | Create architecture decision records, requirements documents, and diagrams through guided AI workflows                                         | 18     | 11      | 20           | 0      | Stable       | [Install](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-project-planning) |
| rai-planning     | Assess AI systems against Responsible AI standards and capture standards-aligned backlog work                                                  | 2      | 3       | 8            | 0      | Experimental | [Install](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-rai-planning)     |
| security         | Security review, planning, incident response, risk assessment, and vulnerability analysis                                                      | 9      | 14      | 19           | 5      | Experimental | [Install](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-security)         |

## How Collections Fit Together

The following diagram shows how the domain collections relate to the two marketplace extensions.

```mermaid
graph TD
    HCA["hve#45;core#45;all<br/>(221 artifacts)"]
    INS["installer<br/>(2 artifacts)"]

    ADO["ado"]
    CS["coding#45;standards"]
    DS["data#45;science"]
    DT["design#45;thinking"]
    EXP["experimental"]
    GH["github"]
    GL["gitlab"]
    HC["hve#45;core"]
    JR["jira"]
    PP["project#45;planning"]
    RP["rai#45;planning"]
    SP["security"]

    HCA --> ADO
    HCA --> CS
    HCA --> DS
    HCA --> DT
    HCA --> EXP
    HCA --> GH
    HCA --> GL
    HCA --> HC
    HCA --> JR
    HCA --> PP
    HCA --> RP
    HCA --> SP
```

`hve-core-all` bundles every domain collection into a single extension. The `installer` operates independently as a deployment tool for selecting and installing individual collections into workspaces.

## Choosing Your Path

If you are getting started and want the simplest setup, install `hve-core-all`. You get every artifact immediately and can explore at your own pace.

If you prefer a leaner workspace or need to standardize which artifacts are available across a team, use the `installer` to deploy only the collections relevant to your workflow.

> [!TIP]
> You can always switch later. Start with `hve-core-all` to explore, then move to the installer approach when you know which collections your team needs.

## After Installing a Collection

Once a collection is installed, its artifacts activate automatically:

1. **Agents** appear in the Copilot Chat agent picker (press `Ctrl+.` or use the dropdown).
2. **Prompts** are available as slash commands (type `/` in Copilot Chat to see them).
3. **Instructions** apply automatically to matching files based on their `applyTo` patterns.
4. **Skills** extend agent capabilities without additional configuration.

To verify installation, open Copilot Chat and check that collection-specific agents appear in the agent picker. For example, installing the `hve-core` collection adds Task Researcher, Task Planner, Task Implementor, and Memory agents.

To add more collections later, search "HVE" in the VS Code Extensions marketplace or use the selective install commands from the table above.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
