---
title: Collections Overview
description: Explore the HVE collection system, compare available collections, and choose the right extension for your workflow
sidebar_position: 3
author: Microsoft
ms.date: 2026-03-22
ms.topic: overview
---

import CollectionsTable from '@site/src/components/CollectionsTable';

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

<CollectionsTable />

## How Collections Fit Together

The following diagram shows how the domain collections relate to the two marketplace extensions.

```mermaid
graph TD
    HCA["hve-core-all<br/>(221 artifacts)"]
    INS["installer<br/>(2 artifacts)"]

    ADO["ado"]
    CS["coding-standards"]
    DS["data-science"]
    DT["design-thinking"]
    EXP["experimental"]
    GH["github"]
    GL["gitlab"]
    HC["hve-core"]
    JR["jira"]
    PP["project-planning"]
    RP["rai-planning"]
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

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
