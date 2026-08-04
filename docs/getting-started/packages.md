---
title: HVE Core Identity and Channels
description: Choose HVE Core package identities and understand their lifecycle and release channels
sidebar_position: 3
author: Microsoft
ms.date: 2026-08-03
ms.topic: overview
---

## Package Choices

`.github/plugin/marketplace.json` is the sole catalog authority. It defines ordinary active package entries, their memberships, maturity, documentation, and immutable plugin sources.

| Package choice             | Scope                                                    |
|----------------------------|----------------------------------------------------------|
| `hve-core`                 | Focused RPI, HVE Builder, Git, and code-review workflows |
| `hve-core-all`             | All active content and the only starter profile          |
| Domain or utility packages | Narrower capability sets listed by the active catalog    |

Do not install `hve-core` and `hve-core-all` together because their content overlaps.

## Stable and PreRelease

Stable and PreRelease contain the same active package-name set and the same active components and maturity for every package.

| Channel    | Source ownership                                                  | Version and cadence                              |
|------------|-------------------------------------------------------------------|--------------------------------------------------|
| PreRelease | Packages directly from an explicit commit on `main`               | Odd minor runtime version; publishes more often  |
| Stable     | Packages a reviewed `main` promotion merged into `release/stable` | Even minor release version; may lag newer `main` |

PreRelease packages directly from `main` and maintains no companion source branch. Stable promotion requires the promoted `main` tree and the merged `release/stable` tree to match before packaging.

Each catalog entry has a deterministic plugin root and extension identity. `hve-core` remains the unsuffixed HVE Core extension, `ise-hve-essentials.hve-core`. Other active entries use package-specific generated identities. A single immutable `plugins-v<version>` snapshot contains every active package root and its projected catalog.

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

Register the catalog ref selected by your organization or release instructions:

```bash
copilot plugin marketplace add microsoft/hve-core#<ref>
```

The Git ref selects the catalog. Each selected entry's `source.ref` selects matching immutable `plugins-v<version>` bytes. Use the client to select the desired catalog package after registration.

## Selective Clone Adoption

`hve-core` and `hve-core-all` each declare the telemetry hook. VS Code has no declarative hook contribution point, so extension users configure hook locations manually.

For a smaller repository-owned footprint, use the installer with an exact `PackageName`. The starter profile belongs only to `hve-core-all`; custom component selection resolves within the chosen package. Schema version 2 records `selection.package`, does not assign package ownership to individual files, and never copies hooks. A package-less schema version 2 manifest emits `INSTALLED_PACKAGE=` and requires explicit package reselection before replay.

## After Installation

Once HVE Core is installed:

1. Agents appear in the Copilot Chat agent picker.
2. Prompts are available as slash commands.
3. Instructions apply to matching files through their `applyTo` patterns.
4. Skills become available for semantic or explicit invocation.

The focused `hve-core` package includes `RPI Agent` and the `/rpi`, `/rpi-research`, `/rpi-plan`, `/rpi-implement`, and `/rpi-review` entry points.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
