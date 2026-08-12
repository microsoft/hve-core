---
title: Adapt HVE Core Package Selections
description: Choose or switch HVE Core catalog packages while preserving the release architecture
sidebar_position: 4
author: Microsoft
ms.date: 2026-08-08
ms.topic: how-to
keywords:
  - migration
  - hve-core
  - copilot plugin
  - vscode extension
  - selective clone
estimated_reading_time: 6
---

HVE Core package selection is a forward adaptation of the catalog-defined distribution model. `.github/plugin/marketplace.json` remains the sole authority for active entries, package membership, maturity, documentation, and sources.

Choose the migration path for your host. Neither GitHub Copilot nor VS Code provides a universal automatic migration between different published identities.

## Choose a Package

| Package choice            | Scope                                                    |
|---------------------------|----------------------------------------------------------|
| `hve-core`                | Focused RPI, HVE Builder, Git, and code-review workflows |
| `hve-core-all`            | All active content and the only starter profile          |
| Domain or utility package | A narrower capability set listed by the active catalog   |

Do not install `hve-core` and `hve-core-all` together because their content overlaps.

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

The development catalog omits `source.ref`. A release-branch registration
resolves the current catalog on that branch, whose entries pin the
corresponding exact channel tag. An exact-tag registration fixes both the
catalog and its source payloads.

Refresh the marketplace before requesting an installed-plugin update:

```bash
copilot plugin marketplace update hve-core
copilot plugin update hve-core@hve-core
```

Switching registrations can require removing and re-adding the marketplace.
Do not depend on a specific outcome for duplicate same-name registrations.

## VS Code Extension Selection

Each catalog entry has a deterministic extension identity. `hve-core` remains the unsuffixed HVE Core extension, `ise-hve-essentials.hve-core`; other entries use package-specific generated identities. Stable and PreRelease have the same active package and component projections, but differ in source ownership, cadence, and version.

PreRelease packages from the reviewed `release/prerelease` path and its
`prerelease-v<version>` tag. Stable packages from the reviewed
`release/stable` path and its `v<version>` tag. Stable can lag PreRelease
because each promotion and release is independently reviewed.

Select the channel offered by the HVE Core extension page in VS Code. A
published channel release carries the associated release assurance; client
channel-switch behavior must be confirmed in the installed host.

## Selective Clone Adaptation

Use clone-based selective adoption when a complete selected package is broader than your repository needs.

1. Pin or clone the HVE Core source version you intend to adopt.
2. Invoke `hve-core-installer` and select an exact `PackageName`.
3. Use `hve-core-all` for the `starter` profile, or choose components from the selected package.
4. Review the selected components, dependency closure, and lifecycle labels before allowing writes.
5. Review the resulting `.hve-tracking.json` manifest before committing adopted files.

The installer preserves repository-relative paths for every copied component. A selected skill includes its complete directory, including scripts, references, tests, and assets. Hooks are plugin runtime configuration and are not copied into the target repository.

Schema version 2 stores `selection.package`. File records identify components without per-file package ownership, and hooks are not copied. When a schema version 2 manifest has no package, upgrade detection emits `INSTALLED_PACKAGE=` and requires explicit package reselection before replay.

## Historical Catalog Support

Previously issued `plugins-v` and `hve-core-v` catalogs and tags are immutable
historical records. They are not future publication targets or active
migration commands.

## Verify the Result

Confirm the selected package's agents, prompts, instructions, and skills are available in the host. For selective clones, verify `.hve-tracking.json` records the intended package and selection. Review the [HVE Core identity and channels](packages) and [installation guide](install) for the current distribution contract.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
