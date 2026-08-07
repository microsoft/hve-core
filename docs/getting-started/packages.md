---
title: HVE Core Identity and Channels
description: Choose HVE Core package identities and understand their lifecycle and release channels
sidebar_position: 3
author: Microsoft
ms.date: 2026-08-06
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

Stable and PreRelease contain the same active package-name set and the same active components and maturity for every package.

| Channel    | Source ownership                                                          | Version and cadence                             |
|------------|---------------------------------------------------------------------------|-------------------------------------------------|
| PreRelease | Managed release PR merge on `release/prerelease`, packaged by release tag | Odd minor runtime version; publishes more often |
| Stable     | Managed release PR merge on `release/stable`, packaged by release tag     | Even minor release version; may lag PreRelease  |

Source moves in one direction through reviewed target-based promotion PRs:
`main` to `release/prerelease` to `release/stable`. A promotion merge creates
no tag. Release-please opens a separate managed PR on the target branch, and
merging that PR creates the channel's `hve-core-v<version>` tag and draft
release. Both channels package from that immutable release tag.

`main` is not a release-please target. After successful PreRelease publication,
a reviewed PR advances package metadata and `CHANGELOG.md` on `main`. Every
main entry sources canonical content from `.github` and omits `source.ref`, so
a marketplace refresh followed by a plugin update resolves current `main`
content. Stable never synchronizes metadata back to `main`.

Each catalog entry has a deterministic plugin root and extension identity. `hve-core` remains the unsuffixed HVE Core extension, `ise-hve-essentials.hve-core`. Other active entries use package-specific generated identities.

PreRelease and Stable catalogs instead set every entry to the exact
`hve-core-v<version>` release ref. These channels remain reviewed,
release-gated, SBOM-covered, attested, and immutable. The moving `#main`
channel intentionally provides current main bytes after refresh without a
release gate, SBOM, or attestation covering those bytes.

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

Register the moving development catalog:

```bash
copilot plugin marketplace add microsoft/hve-core#main
```

Register a fixed release instead when you need immutable catalog selection:

```bash
copilot plugin marketplace add microsoft/hve-core#hve-core-v<version>
```

Both refs use the marketplace name `hve-core`; keep one active registration at
a time rather than depending on simultaneous same-name registrations. Ref
omission does not update an installed plugin by itself. You can opt a
self-added marketplace into session-start updates by setting `autoUpdate: true`
on its `extraKnownMarketplaces` entry in your personal Copilot CLI settings.
Otherwise, after `main` advances, refresh the marketplace and then update the
installed plugin explicitly:

```bash
copilot plugin marketplace update hve-core
copilot plugin update hve-core@hve-core
```

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
