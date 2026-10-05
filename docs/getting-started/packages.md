---
title: HVE Core Identity and Channels
description: Understand the single HVE Core identity, its Copilot CLI plugin registration, and its VS Code extension PreRelease and Stable channels
sidebar_position: 3
author: Microsoft
ms.date: 2026-10-03
ms.topic: overview
keywords:
  - packages
  - channels
  - identity
---

## One Product Identity

HVE Core publishes one plugin named `hve-core` and one VS Code extension named `ise-hve-essentials.hve-core`.

Root `plugin.json` is the deterministic membership authority for both products. `.github/plugin/marketplace.json` contains one `hve-core` locator whose relative source is the repository root; it does not repeat component membership. Plugin clients resolve root README and LICENSE, while the VSIX packages `extension/README.md` and `extension/LICENSE`.

## Copilot CLI Plugin

The Copilot CLI plugin has one registration, `microsoft/hve-core`, which tracks `main`. There are no PreRelease or Stable plugin channels. A marketplace refresh followed by a plugin update resolves current `main` content from the repository root, with artifact discovery bounded to package-scoped `.github` paths. Plugin content from `main` has no published-release assurance.

## VS Code Extension Channels

The extension's Stable and PreRelease channels contain the same complete content. They differ in source ownership, cadence, version, and immutable release tag.

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

`main` is not a release-please target. Release branches, tags, and published releases own release state and history; PreRelease publication does not synchronize versions or `CHANGELOG.md` state back into `main`.

The extension identity remains `ise-hve-essentials.hve-core` on both Marketplace channels.

A published channel release is the assurance boundary for its exact tag. The
release workflow applies review and release gates, produces one VSIX plus
SBOM and provenance sidecars, attaches attestations, verifies provenance, and uses the configured
publication path.

## Membership Parity

| Content              | Stable | PreRelease |
|----------------------|--------|------------|
| Agents               | Same   | Same       |
| Prompts              | Same   | Same       |
| Instructions         | Same   | Same       |
| Distributable skills | Same   | Same       |

The sync policy includes tracked package-scoped artifacts that match canonical paths. Skills with a top-level noncommercial license qualifier are excluded from distribution. Channel selection never filters the manifest.

## Copilot Marketplace Registration

Register the marketplace and install the plugin:

```bash
copilot plugin marketplace add microsoft/hve-core
copilot plugin install hve-core@hve-core
```

Refresh the marketplace before requesting an installed-plugin update:

```bash
copilot plugin marketplace update hve-core
copilot plugin update hve-core@hve-core
```

If you registered a release-channel or tag ref earlier, follow
[Replace an Earlier Registration](methods/cli-plugins#replace-an-earlier-registration).

## Selective Clone Adoption

For a smaller repository-owned footprint, use the installer to copy all manifest components or a selected subset. Schema version 2 records `selection.profile` and `selection.components`, does not assign package ownership, and never copies hooks.

## After Installation

With the VS Code extension installed:

1. Agents appear in the Copilot Chat agent picker.
2. Prompts are available as slash commands.
3. Instructions apply to matching files through their `applyTo` patterns.
4. Skills become available for semantic or explicit invocation.

Copilot CLI plugins expose agents, commands, and skills, but plugin-contained
instructions are not auto-applied. See [Copilot CLI Plugin](methods/cli-plugins#instructions-are-not-auto-applied-from-plugins)
for the host-specific limitation.

The `hve-core` plugin includes `RPI Agent` and the `/rpi`, `/rpi-research`, `/rpi-plan`, `/rpi-implement`, and `/rpi-review` entry points.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
