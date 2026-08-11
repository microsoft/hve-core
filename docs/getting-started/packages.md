---
title: HVE Core Identity and Channels
description: Choose HVE Core package identities and understand their lifecycle and release channels
sidebar_position: 3
author: Microsoft
ms.date: 2026-08-09
ms.topic: overview
---

## Package Choices

`.github/plugin/marketplace.json` is the sole catalog authority. It defines ordinary active package entries, their memberships, maturity, documentation, and plugin sources.

| Package choice             | Scope                                                    |
|----------------------------|----------------------------------------------------------|
| `hve-core`                 | Focused RPI, HVE Builder, Git, and code-review workflows |
| `hve-core-all`             | All active content and the only starter profile          |
| Domain or utility packages | Narrower capability sets listed by the active catalog    |

Do not install `hve-core` and `hve-core-all` together because their content overlaps.

## Stable and PreRelease

Stable and PreRelease contain the same active package-name set and component
maturity. They differ in source ownership, cadence, and immutable release tag.

| Channel    | Reviewed source path                              | Exact source tag        |
|------------|---------------------------------------------------|-------------------------|
| PreRelease | `main` promoted to `release/prerelease`           | `prerelease-v<version>` |
| Stable     | `release/prerelease` promoted to `release/stable` | `v<version>`            |

Ordinary PreRelease releases use odd minor versions and advance first.
Ordinary Stable releases use even minor versions after reviewed promotion, so
Stable can lag PreRelease and newer `main` content. This cadence describes
repository release allocation and publication, not installed-client selection
or update behavior.

Source moves in one direction through reviewed target-based promotion PRs:
`main` to `release/prerelease` to `release/stable`. A promotion merge creates
no tag. Release-please opens a separate managed PR on the target branch, and
merging that PR creates the channel's exact tag and draft release.

`main` is not a release-please target. It is a ref-less development-tip channel:
every main entry sources canonical content from `.github` and omits `source.ref`,
so a marketplace refresh followed by a plugin update resolves current `main`
content. Release branches, tags, and published releases own release state and
history; PreRelease publication does not synchronize versions or `CHANGELOG.md`
state back into `main`.

Each catalog entry has a deterministic plugin root and extension identity. `hve-core` remains the unsuffixed HVE Core extension, `ise-hve-essentials.hve-core`. Other active entries use package-specific generated identities.

Release branches are reviewed moving channels. Their catalogs pin every plugin
entry to the corresponding exact tag, so registering a branch resolves a
tag-pinned catalog while allowing the branch to advance in a later release. An
exact tag fixes both catalog selection and source content.

A published channel release is the assurance boundary for its exact tag. The
release workflow applies review and release gates, produces package assets and
SBOMs, attaches attestations, verifies provenance, and uses the configured
publication path. Ref-less main content intentionally has no published-release
assurance.

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

Register the development tip without a ref:

```bash
copilot plugin marketplace add microsoft/hve-core
```

Register moving reviewed channels:

```bash
copilot plugin marketplace add microsoft/hve-core#release/prerelease
copilot plugin marketplace add microsoft/hve-core#release/stable
```

Register immutable channel tags:

```bash
copilot plugin marketplace add microsoft/hve-core#prerelease-v<version>
copilot plugin marketplace add microsoft/hve-core#v<version>
```

Refresh the marketplace before requesting an installed-plugin update:

```bash
copilot plugin marketplace update hve-core
copilot plugin update hve-core@hve-core
```

Switching registrations can require removing and re-adding the marketplace.
Do not rely on any unverified duplicate same-name registration behavior.

## Selective Clone Adoption

`hve-core` and `hve-core-all` each declare the telemetry hook. VS Code has no declarative hook contribution point, so extension users configure hook locations manually.

For a smaller repository-owned footprint, use the installer with an exact `PackageName`. The starter profile belongs only to `hve-core-all`; custom component selection resolves within the chosen package. Schema version 2 records `selection.package`, does not assign package ownership to individual files, and never copies hooks. A package-less schema version 2 manifest emits `INSTALLED_PACKAGE=` and requires explicit package reselection before replay.

## After Installation

With the VS Code extension installed:

1. Agents appear in the Copilot Chat agent picker.
2. Prompts are available as slash commands.
3. Instructions apply to matching files through their `applyTo` patterns.
4. Skills become available for semantic or explicit invocation.

Copilot CLI plugins expose agents, commands, and skills, but plugin-contained
instructions are not auto-applied. See [Copilot CLI Plugin](methods/cli-plugins#instructions-are-not-auto-applied-from-plugins)
for the host-specific limitation.

The focused `hve-core` package includes `RPI Agent` and the `/rpi`, `/rpi-research`, `/rpi-plan`, `/rpi-implement`, and `/rpi-review` entry points.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
