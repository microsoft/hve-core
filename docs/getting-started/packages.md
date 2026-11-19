---
title: HVE Core Identity and Channels
description: Choose HVE Core All or focused Copilot plugins and understand the single VS Code extension's release channels
sidebar_position: 3
author: Microsoft
ms.date: 2026-11-18
ms.topic: overview
keywords:
  - packages
  - channels
  - identity
---

## Choose Your Scope

The marketplace offers `hve-core` (All) and [seven focused alternatives](../plugins/hve-core#choose-a-plugin). Install All or selected topics. You do not need a common plugin to use a focused one.

Root `plugin.json` lists every distributable component for All and remains the only input to `ise-hve-essentials.hve-core`. Each marketplace entry points to its own manifest. Focused plugins do not produce separate VSIX packages.

## Copilot Plugin

The plugin has one registration, `microsoft/hve-core`, which follows `main` in both VS Code and Copilot CLI. It has no PreRelease or Stable channels and no published-release assurance. Updating it pulls the current `main` content.

## VS Code Extension Channels

The extension is published to the VS Code Marketplace in Stable and PreRelease channels. Both carry the same components under the same identity, `ise-hve-essentials.hve-core`, and differ in version and cadence. PreRelease uses odd minor versions and Stable uses even minor versions, so Stable can lag PreRelease and newer `main` content.

This numbering describes how releases are published, not how VS Code selects or updates a channel. How VS Code behaves when you switch between channels has not been confirmed.

The release workflows are configured to promote source from `main` to a `release/prerelease` branch and then to `release/stable`. A promotion merge creates no tag; release-please then opens a managed pull request on the target branch, and merging it creates the channel's `prerelease-v<version>` or `v<version>` tag and draft release. Release branches, tags, and published releases hold release history, and PreRelease publication doesn't sync versions or `CHANGELOG.md` back into `main`.

Those two release branches don't exist in the repository right now, so the workflows that run on them can't start until the branches are created. Whether to restore or retire this promotion path is tracked in [issue #3117](https://github.com/microsoft/hve-core/issues/3117).

When the release workflow publishes a channel release, it applies review and release gates, produces one VSIX with SBOM and provenance files for that exact tag, attaches attestations, and verifies provenance. That release assurance covers the published extension only. The plugin follows `main` and has none.

## Membership Parity

Stable and PreRelease contain the same agents, instructions, and distributable skills, and choosing a channel never filters them. The component list includes tracked package-scoped artifacts at their canonical paths and excludes skills with a top-level noncommercial license qualifier.

## Copilot Marketplace Registration

[Install the Plugin](install#install-the-plugin) and [Copilot Plugin](methods/cli-plugins) have the install and update steps for VS Code and Copilot CLI. If you registered a release-channel or tag ref earlier, follow [Replace an Earlier Registration](methods/cli-plugins#replace-an-earlier-registration).

## Repository Adoption

For a repository-owned copy, use the installer to copy every manifest component. Schema version 2 records `selection.profile` and `selection.components`, does not assign package ownership, and never copies hooks.

## After Installation

With the plugin installed:

1. Agents appear in the Copilot Chat agent picker.
2. The manifest includes scoped rules. Whether the client automatically applies a rule when its `applyTo` matches depends on the host.
3. Skills become available for semantic or explicit invocation, and user-invocable skills appear as slash commands. In VS Code, plugin skills carry the plugin name as a prefix, such as `/hve-core:rpi-research`.

The VS Code extension delivers the same agents and skills as All to Copilot sessions, but its instructions may not reach them. See [Use the VS Code Extension](install#use-the-vs-code-extension).

The `hve-core` plugin includes `RPI Agent` and the `/rpi-research`, `/rpi-plan`, `/rpi-implement`, and `/rpi-review` entry points.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
