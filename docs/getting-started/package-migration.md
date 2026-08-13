---
title: Migrate to the HVE Core Identity
description: Move retired package installations to the single HVE Core plugin or extension
sidebar_position: 4
author: Microsoft
ms.date: 2026-08-13
ms.topic: how-to
keywords:
  - migration
  - hve-core
  - copilot plugin
  - vscode extension
  - selective clone
estimated_reading_time: 6
---

HVE Core now publishes one `hve-core` plugin and one `ise-hve-essentials.hve-core` extension. `.github/plugin.json` owns the complete distributable membership, and `.github/plugin/marketplace.json` contains one relative locator to `.github`.

Choose the migration path for your host. Neither GitHub Copilot nor VS Code provides a universal automatic migration between different published identities.

## Replace Retired Identities

Remove any retired domain, utility, or `hve-core-all` plugin registration before installing `hve-core`. Remove any package-suffixed HVE Core extension before installing the single HVE Core extension.

## GitHub Copilot Plugin Selection

Changing a Copilot marketplace registration is a configuration operation. It does not delete files from your repository or modify a cloned HVE Core installation.

Use the ref-less development tip:

```bash
copilot plugin marketplace add microsoft/hve-core
```

Use a moving reviewed channel:

```bash
copilot plugin marketplace add microsoft/hve-core#release/prerelease
copilot plugin marketplace add microsoft/hve-core#release/stable
```

Use an immutable channel tag:

```bash
copilot plugin marketplace add microsoft/hve-core#prerelease-v<version>
copilot plugin marketplace add microsoft/hve-core#v<version>
```

The ref-less registration resolves current `main`. A release-branch registration resolves the current reviewed branch. An exact-tag registration fixes the catalog, manifest, and source tree together.

Refresh the marketplace before requesting an installed-plugin update:

```bash
copilot plugin marketplace update hve-core
copilot plugin update hve-core@hve-core
```

Switching registrations can require removing and re-adding the marketplace.
Do not depend on a specific outcome for duplicate same-name registrations.

## VS Code Extension Selection

The sole extension identity is `ise-hve-essentials.hve-core`. Stable and PreRelease have the same complete component set but differ in source ownership, cadence, and version.

PreRelease packages from the reviewed `release/prerelease` path and its
`prerelease-v<version>` tag. Stable packages from the reviewed
`release/stable` path and its `v<version>` tag. Stable can lag PreRelease
because each promotion and release is independently reviewed.

Select the channel offered by the HVE Core extension page in VS Code. A
published channel release carries the associated release assurance; client
channel-switch behavior must be confirmed in the installed host.

## Selective Clone Adaptation

Use clone-based selective adoption when the complete plugin is broader than your repository needs.

1. Pin or clone the HVE Core source version you intend to adopt.
2. Invoke `hve-core-installer` and choose all manifest components or a subset.
3. Review the selected components and collisions before allowing writes.
4. Review the resulting `.hve-tracking.json` manifest before committing adopted files.

The installer preserves repository-relative paths for every copied component. A selected skill includes its complete distributable directory, excluding local tests, environments, and caches. Hooks are plugin runtime configuration and are not copied into the target repository.

Schema version 2 stores `selection.profile` and `selection.components`. File records identify component ownership without package identity, and hooks are not copied.

## Historical Catalog Support

Previously issued `plugins-v` and `hve-core-v` catalogs and tags are immutable
historical records. They are not future publication targets or active
migration commands.

## Verify the Result

Confirm the plugin's agents, prompts, instructions, and skills are available in the host. For selective clones, verify `.hve-tracking.json` records the intended profile and components. Review the [HVE Core identity and channels](packages) and [installation guide](install) for the current distribution contract.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
