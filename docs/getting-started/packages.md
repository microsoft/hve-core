---
title: HVE Core Identity and Channels
description: Understand the complete hve-core plugin and extension identity, lifecycle labels, and release channels
sidebar_position: 3
author: Microsoft
ms.date: 2026-08-02
ms.topic: overview
---

## One Complete Identity

HVE Core distributes all active agents, prompts, instructions, skills, and hooks through the `hve-core` plugin and extension identity. `.github/plugin/marketplace.json` is the catalog authority: standard component fields declare membership, while `x-hve` records display, lifecycle maturity, and documentation metadata.

The catalog produces two self-contained formats from the same resolved source set:

* A Copilot plugin published under an immutable `plugins-v<version>` tag
* A VS Code extension with the ID `ise-hve-essentials.hve-core`

The former domain-specific and all-content package identities are no longer catalog entries. See [Migrate to the HVE Core Identity](package-migration) when moving an existing installation.

## Stable and PreRelease

Stable and PreRelease contain the same active components and lifecycle map.

| Channel    | Source ownership                                                  | Version and cadence                              |
|------------|-------------------------------------------------------------------|--------------------------------------------------|
| PreRelease | Packages directly from an explicit commit on `main`               | Odd minor runtime version; publishes more often  |
| Stable     | Packages a reviewed `main` promotion merged into `release/stable` | Even minor release version; may lag newer `main` |

PreRelease packages directly from `main` and maintains no companion source branch. Stable promotion requires the promoted `main` tree and the merged `release/stable` tree to match before packaging.

The VS Code channels share one extension identity. Users switch channels on the HVE Core extension rather than installing separate extension IDs.

## Lifecycle Disclosure

| Lifecycle label | Stable | PreRelease | Meaning                                             |
|-----------------|--------|------------|-----------------------------------------------------|
| `stable`        | Yes    | Yes        | Established component                               |
| `preview`       | Yes    | Yes        | Usable component still receiving compatibility work |
| `experimental`  | Yes    | Yes        | Early component that can change significantly       |
| `deprecated`    | No     | No         | Scheduled for or undergoing retirement              |
| `removed`       | No     | No         | Excluded while its policy tombstone may remain      |

Lifecycle labels are disclosure and governance metadata, not channel filters. They are also separate from maturity classifications used in Responsible AI assessments.

## Copilot Marketplace Registration

Register one approved catalog ref at a time:

```bash
copilot plugin marketplace add microsoft/hve-core#<ref>
```

The Git ref after `#` selects the catalog. The catalog entry's `source.ref` selects matching immutable `plugins-v<version>` plugin bytes. Because Stable and PreRelease catalogs both have the marketplace name `hve-core`, do not register them side by side as same-name channels. Replace the active registration when switching catalog refs.

## Selective Clone Adoption

The complete plugin and extension are the distribution boundary. For a smaller repository-owned footprint, use the included installer skill with either its starter profile or a custom component selection.

Selective cloning supports agents, prompts, instructions, and complete skill directories. It preserves repository-relative paths, records lifecycle maturity in `.hve-tracking.json` schema version 2, and does not copy hooks. See the [installation guide](install#selective-clone-adoption) for the workflow.

## After Installation

Once HVE Core is installed:

1. Agents appear in the Copilot Chat agent picker.
2. Prompts are available as slash commands.
3. Instructions apply to matching files through their `applyTo` patterns.
4. Skills become available for semantic or explicit invocation.

The `hve-core` identity includes `RPI Agent` and the `/rpi`, `/rpi-research`,
`/rpi-plan`, `/rpi-implement`, and `/rpi-review` entry points.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
