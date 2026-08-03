---
title: Migrate to the HVE Core Identity
description: Move from retired HVE Core package identities to the complete hve-core plugin or extension
sidebar_position: 4
author: Microsoft
ms.date: 2026-08-02
ms.topic: how-to
keywords:
  - migration
  - hve-core
  - copilot plugin
  - vscode extension
  - selective clone
estimated_reading_time: 6
---

HVE Core now distributes every active component through one `hve-core` identity. The former domain, installer, and all-content identities are retired from the repository catalog. This source change does not publish compatibility shells, deprecate marketplace listings, or mutate an installed extension or plugin.

Choose the migration path for your host. Neither GitHub Copilot nor VS Code provides a universal automatic migration between different published identities.

## GitHub Copilot Plugin Migration

Changing a Copilot marketplace registration is a configuration operation. It does not delete files from your repository or modify a cloned HVE Core installation.

Register the catalog ref selected by your organization or release instructions:

```bash
copilot plugin marketplace add microsoft/hve-core#<ref>
```

Then use `/plugin` in Copilot CLI to install `hve-core` from the registered marketplace.

The Git ref after `#` selects the marketplace catalog. Inside that catalog, the `hve-core` entry uses `source.ref` to pin the matching immutable `plugins-v<version>` plugin bytes. Treat those two refs as one release unit: the selected catalog must point to its matching plugin snapshot.

Stable and PreRelease catalogs both use the marketplace name `hve-core`. Keep one active registration at a time. To change channels, remove or replace the existing registration through Copilot's marketplace configuration, then register the other approved ref. Do not present both same-name catalogs as simultaneous channel registrations.

## VS Code Extension Migration

Stable and PreRelease use one extension identity: `ise-hve-essentials.hve-core`. Both contain the same active components. The channels differ only in cadence, version, and source commit.

If you previously installed `hve-core-all`, a domain-specific extension, or the separate installer identity, VS Code cannot transfer that installation automatically to `hve-core` because the extension IDs differ. Install HVE Core, verify the required agents and skills appear, and then uninstall the retired identity when you are ready. Review workspace files before deleting anything because clone-based or installer-based adoption may have copied files into the repository independently of the extension.

Switch between Stable and PreRelease from the HVE Core extension page in VS Code. PreRelease packages from `main`. Stable packages only after reviewed `main` content is promoted into `release/stable`, so Stable can lag newer commits on `main`.

## Selective Clone Migration

Use clone-based selective adoption when the complete extension is broader than your repository needs.

1. Pin or clone the HVE Core source version you intend to adopt.
2. Invoke the included `hve-core-installer` skill and choose the starter profile or a custom selection.
3. Review the selected components, dependency closure, and lifecycle labels before allowing writes.
4. Copy selected agents, prompts, instructions, and complete skill directories into the target repository.
5. Review the resulting `.hve-tracking.json` manifest before committing adopted files.

The installer preserves repository-relative paths for every copied component. A selected skill includes its complete directory, including scripts, references, tests, and assets. Hooks are plugin runtime configuration and are not copied into the target repository.

New selective installations use manifest schema version 2. The manifest records starter or custom selection, component kind, path, lifecycle maturity, source version, file hashes, and status without a retired package identity. Schema version 1 is not upgraded in place; perform a clean selective reinstall when the installer reports an unsupported legacy manifest.

## Lifecycle Labels After Migration

Both channels include active components labeled `stable`, `preview`, and `experimental`. Labels disclose lifecycle posture for review and governance; they do not filter channel content. Components labeled `deprecated` or `removed` are excluded from distribution.

Lifecycle labels are not Responsible AI assessment maturity ratings. Continue to apply the relevant human-review and assessment requirements to outputs regardless of a component's distribution label.

## Verify the Result

After migration:

1. Confirm only the intended `hve-core` marketplace or extension registration is active.
2. Verify required agents, prompts, instructions, and skills are available in the host.
3. For selective clones, verify paths and manifest version 2 before removing prior copied files.
4. Review the [HVE Core identity and channels](packages) and [installation guide](install) for the current distribution contract.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
