---
title: Adapt HVE Core Package Selections
description: Choose or switch HVE Core catalog packages while preserving the release architecture
sidebar_position: 4
author: Microsoft
ms.date: 2026-08-03
ms.topic: how-to
keywords:
  - migration
  - hve-core
  - copilot plugin
  - vscode extension
  - selective clone
estimated_reading_time: 6
---

HVE Core package selection is a forward adaptation of the catalog-defined distribution model. `.github/plugin/marketplace.json` remains the sole authority for active entries, package membership, maturity, documentation, and immutable sources.

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

Register the catalog ref selected by your organization or release instructions:

```bash
copilot plugin marketplace add microsoft/hve-core#<ref>
```

Then select the required package through the Copilot client.

The Git ref after `#` selects the marketplace catalog. Inside that catalog, the selected entry uses `source.ref` to pin the matching immutable `plugins-v<version>` plugin bytes. Treat those two refs as one release unit: the selected catalog must point to its matching plugin snapshot.

## VS Code Extension Selection

Each catalog entry has a deterministic extension identity. `hve-core` remains the unsuffixed HVE Core extension, `ise-hve-essentials.hve-core`; other entries use package-specific generated identities. Stable and PreRelease have the same active package and component projections, but differ in source ownership, cadence, and version.

Switch between Stable and PreRelease from the HVE Core extension page in VS Code. PreRelease packages from `main`. Stable packages only after reviewed `main` content is promoted into `release/stable`, so Stable can lag newer commits on `main`.

## Selective Clone Adaptation

Use clone-based selective adoption when a complete selected package is broader than your repository needs.

1. Pin or clone the HVE Core source version you intend to adopt.
2. Invoke `hve-core-installer` and select an exact `PackageName`.
3. Use `hve-core-all` for the `starter` profile, or choose components from the selected package.
4. Review the selected components, dependency closure, and lifecycle labels before allowing writes.
5. Review the resulting `.hve-tracking.json` manifest before committing adopted files.

The installer preserves repository-relative paths for every copied component. A selected skill includes its complete directory, including scripts, references, tests, and assets. Hooks are plugin runtime configuration and are not copied into the target repository.

Schema version 2 stores `selection.package`. File records identify components without per-file package ownership, and hooks are not copied. When a schema version 2 manifest has no package, upgrade detection emits `INSTALLED_PACKAGE=` and requires explicit package reselection before replay.

## Future Catalog Convergence

A future reduction in package count is catalog cleanup plus generated stale-output cleanup. It does not require a framework rewrite, compatibility shells, aggregate metadata, aliases, or package-specific workflow branches. Dynamic package matrices, equal-channel parity checks, and immutable snapshots continue to derive from the active catalog.

## Verify the Result

Confirm the selected package's agents, prompts, instructions, and skills are available in the host. For selective clones, verify `.hve-tracking.json` records the intended package and selection. Review the [HVE Core identity and channels](packages) and [installation guide](install) for the current distribution contract.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
