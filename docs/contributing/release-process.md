---
title: Release Process
description: Release HVE Core through reviewed PreRelease metadata and Stable promotion workflows
sidebar_position: 9
ms.date: 2026-08-10
ms.topic: how-to
author: WilliamBerryiii
---

## Overview

This project uses a one-way reviewed branch ladder:
`main` to `release/prerelease` to `release/stable`. Each hop uses two pull
requests. A target-based promotion PR moves source changes into the release
branch and creates no tag. Its merge runs release-please in PR-only mode. The
later release-please managed PR owns version and changelog metadata. Its merge
creates `prerelease-v<version>` for PreRelease or `v<version>` for Stable.

`main` is not a release-please target. It is a ref-less development-tip channel and does not receive release metadata or changelog updates when a channel is published. An explicit marketplace refresh and plugin update are required for the ref-less main catalog, whose bytes have no release gate, SBOM, or attestation. Release branches, tags, and published GitHub releases own release state and history.

The ref-less `microsoft/hve-core` registration follows `main`. Main bytes have
no release gate, SBOM, or attestation. Release channels remain the reviewed
path through moving branch registrations and exact `prerelease-v<version>` or
`v<version>` refs: they are release-gated, SBOM-covered, and attested.

Workflow ownership is explicit:

* `release-prerelease-prepare.yml` opens the reviewed `main` to
    `release/prerelease` promotion.
* `release-prerelease.yml` runs release-please and publishes PreRelease.
* `release-stable.yml` opens the reviewed `release/prerelease` to
    `release/stable` promotion.
* `release-stable-publish.yml` runs release-please and publishes Stable from a
    reviewed draft.

## How Releases Work

```mermaid
flowchart TD
    subgraph PRE[PreRelease]
        P1[Review main to PreRelease promotion PR] -->|merge, no tag| P2[Review managed PreRelease PR]
        P2 -->|merge| P3[Draft odd-minor tag at managed merge]
        P3 --> P4[Package and attest release assets]
        P4 --> P5[Publish prerelease with App token]
        P5 --> P6[Pre-Release Marketplace Publish]
    end
    subgraph STABLE[Stable]
        S1[Published PreRelease] --> S2[Review PreRelease to Stable promotion PR]
        S2 -->|merge, no tag| S3[Review managed Stable PR]
        S3 -->|merge| S4[Draft Stable release at merge commit]
        S4 --> S5[Package and attest release assets]
        S5 --> S6[Publish Stable release with App token]
        S6 --> S7[Stable Marketplace Publish]
    end
```

| Channel    | Promotion head                                                            | Managed head                                   | Promotion mode | Managed mode |
|------------|---------------------------------------------------------------------------|------------------------------------------------|----------------|--------------|
| PreRelease | `release-promotion--main--to--release-prerelease`                         | `release-please--branches--release/prerelease` | PR-only        | Tag-only     |
| Stable     | `release-promotion--release-prerelease--to--release-stable--<source-tag>` | `release-please--branches--release/stable`     | PR-only        | Tag-only     |

### PreRelease Flow

1. `Pre-Release Promotion Preparation` runs after an eligible merged PR to
   `main`, or through its input-free recovery dispatch.
2. It refreshes the target-based promotion head from `release/prerelease`,
   merges current `main`, restores channel-owned release state, writes the
   exact `release-as`, and opens a reviewed PR to `release/prerelease`.
3. Review `PR Validation Success`, the odd-minor intent, and the promoted tree.
   Merge the promotion PR. This merge creates no tag or GitHub release.
4. `Pre-Release Pipeline` runs release-please in PR-only mode with
   `release-please-prerelease-config.json` and
   `.release-please-prerelease-manifest.json`.
5. Review the managed PR. It carries the synchronized version fields,
   changelog, and manifest; postprocessing removes the consumed `release-as`.
6. Merge the managed PR. Release-please uses forced tag creation to create the
    draft odd-minor `prerelease-v<version>` release at that merge commit.
7. The workflow proves event SHA, PR merge SHA, release-please SHA, tag SHA,
   and `release/prerelease` ancestry are consistent.
8. It packages from the validated release SHA, sets every release catalog
    entry to the exact `prerelease-v<version>` ref, and attaches and attests
    `plugin-release-evidence.json`. The evidence is derived from the declared
    canonical tracked sources and verifies package non-vacuity and digests
    against the release SHA.
9. A release GitHub App token publishes the prerelease with
   `gh release edit --prerelease --draft=false`. The event triggers
   `Pre-Release Marketplace Publish`.
10. Release publication does not update `main`. The release branch, immutable
    tag, and published GitHub release retain the channel release state and
    history.

### Stable Flow

1. A published PreRelease event runs `Stable Release Preparation`. A recovery
    dispatch must provide the published `prerelease-v<version>` tag.
2. The workflow derives a promotion head from the validated source tag,
    refreshes it from `release/stable`, validates matching canonical release
    evidence, and merges only that tag commit. It restores
    selected-source package and catalog content, projects Stable version
    fields, writes the exact `release-as`, and opens a reviewed PR. Newer
    `release/prerelease` commits and other selected tags are excluded.
3. Review `PR Validation Success`, the even-minor intent, and the promoted
    tree. Merge the promotion PR. This merge creates no tag or GitHub release.
4. `Stable Release Publish` revalidates the tag-scoped merged head and current
    Stable intent in a read-only job, then runs release-please in PR-only mode
    and opens or updates the managed Stable PR.
5. Review the managed version, changelog, manifest, and exact
    `v<stable-version>` plugin ref. The future release tag does not
    exist yet by design. Postprocessing removes the consumed `release-as`.
6. Merge the managed PR. Release-please creates the draft even-minor
    `v<version>` release at that managed merge commit.
7. The workflow proves event SHA, PR merge SHA, release-please SHA, tag SHA,
    and `release/stable` ancestry are consistent.
8. It packages from the release tag and attaches signed plugin ZIPs,
    `plugin-release-evidence.json`, SBOM, VEX, Sigstore, in-toto, provenance,
    and verification assets. Release evidence and package assets are attested
    against the immutable release identity.
9. A release GitHub App token publishes the Stable release with
    `gh release edit --draft=false`. The event triggers
    `Stable Marketplace Publish`.

Published channels do not synchronize release metadata or changelog history to
`main`.

## The Release PR

The release-please managed PR is not a deployment. Merging it is the reviewed
boundary that permits the channel's tag-only run. Both channel configs use
`draft: true`, `force-tag-creation: true`, and patch fallback. The managed PR
prepares channel version metadata and changelog changes on its release branch:

* Updated `package.json` and `package-lock.json` versions
* Updated `extension/templates/package.template.json` version
* Updated `.github/plugin/marketplace.json` version and exact channel tag ref
* Updated channel manifest
* Updated `CHANGELOG.md`

The promoted code is already on the target release branch. The exact
promotion intent is consumed from the config and removed before the managed PR
merges, so tag-only publication does not depend on stale intent.

### Version Calculation

Promotion preparation determines the exact channel version before
release-please opens its managed PR:

| Channel    | Ordinary allocation input            | Exact result                                        |
|------------|--------------------------------------|-----------------------------------------------------|
| PreRelease | Current `release/prerelease` version | Same major, minor plus two, patch zero              |
| Stable     | Promoted PreRelease version          | Promoted major, promoted minor plus one, patch zero |

For example, the ordinary sequence is `3.3.101` to `3.5.0` to `3.6.0`.
PreRelease reads only `release/prerelease`. Stable derives its candidate from
the promoted PreRelease version; the current Stable version only rejects a
candidate that does not advance it. Matching plugin packages use the identical
channel version.

> [!NOTE]
> Stable releases use an even minor version number (for example, `1.2.0`), and
> PreRelease releases use an odd minor version number (for example, `1.3.0`).
> This parity is repository policy aligned with VS Code Marketplace guidance
> and behavior. It is not a requirement of `MAJOR.MINOR.PATCH` syntax.

Ordinary release allocation has no commit classification and no automatic
patch, minor, or major release class. Stable has no release-class recovery
dispatch. A major-line transition or a Stable patch or hotfix requires a
separate explicit manifest and release-state decision.

## For Contributors

Write commits using conventional commit format to support clear changelog
entries. Commit type does not select the release version.

```bash
# Feature changelog entry
git commit -m "feat: add new prompt for code review"

# Fix changelog entry
git commit -m "fix: resolve parsing error in instruction files"

# Documentation changelog entry
git commit -m "docs: update installation guide"

# Breaking-change changelog entry
git commit -m "feat!: redesign configuration schema"
```

For more details, see the [commit message instructions](https://github.com/microsoft/hve-core/blob/main/.github/instructions/hve-core/commit-message.instructions.md).

## For Maintainers

The checks in this section are authorized manual operations against GitHub and
release clients. Local documentation validation does not execute or verify
them.

### Recovering from an Occupied Candidate

Promotion preparation stops before branch mutation when the calculated exact
channel release identity already exists. The calculation is
deterministic, so rerunning preparation without reconciling channel state
selects the same occupied version and fails again.

1. Inspect the tag, the GitHub release, its target commit, and available
    canonical plugin evidence. Determine whether they belong to a completed HVE
    Core release or are unrelated, manual, or abandoned state.
2. Do not delete, move, or force-update the immutable tag. Do not republish a
    completed release to make branch metadata agree with it.
3. If the identities belong to a completed release, reconcile the channel
    branch manifest and synchronized release metadata with that released commit
    through a reviewed pull request. Continue with the next ordinary channel
    release instead of recreating the occupied version.
4. If the identities must remain reserved but do not represent a completed
    channel release, make an explicit reviewed release-state decision:
    * For PreRelease, advance the `release/prerelease` manifest and synchronized
      version metadata to the occupied odd-minor baseline. Then run the
      input-free **Pre-Release Promotion Preparation** workflow dispatch. It
      calculates the following odd-minor candidate from the reviewed baseline.
    * For Stable, publish the next valid odd-minor PreRelease through the normal reviewed path. Publication starts **Stable Release Preparation** automatically. Inspect that run's outcome, including any no-op notice. If the run did not start or failed, dispatch the workflow manually with the published `prerelease-v<version>` tag. A successful preparation calculates the following even-minor candidate from the selected source.

Record the provenance finding and reviewed state change with the release. An
authentication, transport, rate-limit, or ambiguous lookup failure is not an
occupied-candidate recovery case; fix that failure and rerun the unchanged
preparation workflow.

### Reviewing the PreRelease

1. Review the target-based `main` to `release/prerelease` promotion PR and its
    `PR Validation Success` check.
2. Confirm the head is
    `release-promotion--main--to--release-prerelease`, the proposed version is
    odd-minor, and the source tree is the intended `main` state.
3. Merge the promotion and verify it creates no tag. Confirm the resulting
    `Pre-Release Pipeline` run opens the managed PR in PR-only mode.
4. Review the managed PR on `release/prerelease`, including synchronized
    versions, changelog, manifest, and immutable plugin locator.
5. Merge the managed PR and verify the draft `prerelease-v<version>` release
    targets that managed merge commit.
6. Verify packaging uses the release tag and attaches signed plugin ZIPs,
    `plugin-release-evidence.json`, SBOM, Sigstore, and in-toto assets for the
    same source SHA.
7. Verify App-token publication marks the GitHub release as a prerelease,
    and triggers `Pre-Release Marketplace Publish`.

### Reviewing the Stable Release

The promotion and managed release PR are separate review boundaries. When ready to release:

1. Review the `release/prerelease` to `release/stable` promotion PR and its
    `PR Validation Success` check. Auto-merge is intentionally disabled.
2. Confirm the head is
    `release-promotion--release-prerelease--to--release-stable--<source-tag>`,
    the suffix matches the selected published PreRelease tag, the source commit
    has matching canonical release evidence, and the proposed version is
    even-minor. A
    newer branch tip or another selected tag must not enter the promotion.
3. Merge the promotion and verify it creates no tag. Confirm the resulting
    `Stable Release Publish` run opens the managed PR in PR-only mode.
4. Review the managed PR on `release/stable`, including its changelog, version
    fields, manifest, and future exact plugin ref. The ref becomes resolvable
    when the approved merge creates the Stable `v<version>` tag.
5. Merge the managed PR and verify the draft tag targets that managed merge
    commit.
6. Verify the workflow attaches the VSIX, signed plugin ZIPs,
    `plugin-release-evidence.json`, SBOM, VEX, Sigstore, in-toto, and provenance
    assets.
7. Verify App-token publication triggers `Stable Marketplace Publish` for the
    same release tag.

### Release Cadence

Releases are on-demand. Merge the managed Stable release PR when:

* A meaningful set of changes has accumulated
* A critical fix needs immediate release
* A scheduled release milestone is reached

There is no requirement to release after every PR merge.

## Extension Publishing

VS Code extension publishing uses the channel Marketplace workflows. Both
channel release workflows publish with a release GitHub App token, so each
published event triggers its matching Marketplace workflow:

* [`release-marketplace-prerelease.yml`](https://github.com/microsoft/hve-core/blob/main/.github/workflows/release-marketplace-prerelease.yml)
* [`release-marketplace-stable.yml`](https://github.com/microsoft/hve-core/blob/main/.github/workflows/release-marketplace-stable.yml)

Both Marketplace workflows pass the validated exact release tag to the generic
publisher, which resolves the attesting workflow to the one constant both
channels sign from. The publisher downloads the release asset, verifies its
attestation against that signer, and publishes through Azure OIDC
authentication.

### Manual Fallback

If an automated publish did not trigger or you need to republish, use the
matching channel workflow dispatch fallback:

1. Navigate to **Actions**, then select the matching PreRelease or Stable
    Marketplace workflow
2. Select **Run workflow**
3. Choose the workflow from its default branch
4. Optionally specify a version; an empty value auto-detects the latest
    published release for that channel
5. Optionally enable dry-run mode to validate the version and catalog without
    publishing
6. Click **Run workflow**

### When to Publish

Publish the extension after merging a Release PR that includes extension-relevant changes:

* New prompts, instructions, or custom agents
* Bug fixes affecting extension behavior
* Updated extension metadata or documentation

Documentation-only releases may not require an extension publish.

## Historical Release Identities

Because snapshot publication has stopped, tags and catalogs remain immutable and supported only as historical records. Existing `hve-core-v<version>` and `plugins-v<version>` tags, releases, and catalogs are within that historical set. They are not active registration, publication, recovery, or compatibility namespaces. Current automation does not create, move, rewrite, delete, or migrate them.

## Version Quick Reference

| Action                                     | Result                                                            |
|--------------------------------------------|-------------------------------------------------------------------|
| Merge or dispatch PreRelease preparation   | Opens or refreshes the reviewed `main` to PreRelease promotion PR |
| Merge PreRelease promotion PR              | Opens the managed PreRelease PR; creates no tag                   |
| Merge managed PreRelease PR                | Creates the draft tag and starts the odd-minor artifact pipeline  |
| Publish PreRelease with App token          | Starts PreRelease Marketplace publication                         |
| Publish PreRelease or dispatch Stable prep | Opens or refreshes the reviewed PreRelease to Stable promotion PR |
| Merge Stable promotion PR                  | Opens the managed Stable PR; creates no tag                       |
| Merge managed Stable PR                    | Creates the draft tag and starts the even-minor artifact pipeline |
| Publish Stable with App token              | Starts Stable Marketplace publication                             |

## Extension Channels and Maturity

The VS Code extension is published to two same-content channels with different cadence, versioning, and source ownership.

### Extension Channels

| Channel    | Moving source        | Immutable source        | Included Active Labels                  |
|------------|----------------------|-------------------------|-----------------------------------------|
| Stable     | `release/stable`     | `v<version>`            | `stable`, `preview`, and `experimental` |
| PreRelease | `release/prerelease` | `prerelease-v<version>` | `stable`, `preview`, and `experimental` |

### Maturity Levels

The `hve-core` recipe declares non-stable component lifecycle labels in `x-hve.componentMaturity` under `.github/plugin/marketplace.json`:

| Level          | Description                                                                 | Included In     |
|----------------|-----------------------------------------------------------------------------|-----------------|
| `stable`       | Established component                                                       | Both channels   |
| `preview`      | Functional component still receiving compatibility work                     | Both channels   |
| `experimental` | Early development that may change significantly                             | Both channels   |
| `deprecated`   | Scheduled for removal                                                       | Neither channel |
| `removed`      | Source retained for traceability but withdrawn from generated distributions | Neither channel |

Lifecycle labels disclose support posture and inform governance. They are not channel filters and are separate from maturity classifications used in Responsible AI assessments.

### Maturity Lifecycle

```mermaid
stateDiagram-v2
    [*] --> experimental : New artifact
    experimental --> preview : Core features complete
    preview --> stable : Production tested
    stable --> deprecated : Superseded or obsolete
    deprecated --> removed : Withdrawn from distribution
    removed --> [*] : Source eventually deleted
```

The `removed` level is a marketplace tombstone. The artifact file remains in its
source location (for example, under `.github/skills/{package-id}/`) so history and
references stay intact, but every downstream surface (marketplace validation, plugin
generation, and extension packaging) excludes it. Use `removed` when you want to retire
an artifact from distribution without moving it to `.github/deprecated/` or deleting it
outright. See [AI Artifacts Architecture - Removed Artifacts](../architecture/ai-artifacts.md#removed-artifacts)
for the architectural contract.

### Contributor Guidelines

| Guideline          | Action                                                                                                                                                                                                                                                             |
|--------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| New contributions  | Omit component maturity for the default `stable` value unless targeting early adopters                                                                                                                                                                             |
| Experimental work  | Set `experimental` on the package-relative component path                                                                                                                                                                                                          |
| Preview promotions | Set `preview` when core functionality is complete                                                                                                                                                                                                                  |
| Stable promotions  | Remove the component-maturity override after production validation                                                                                                                                                                                                 |
| Deprecation        | Set `deprecated` before removal to provide transition time. Move the artifact file to `.github/deprecated/{type}/` when archival placement is intended. See [AI Artifacts Architecture](../architecture/ai-artifacts.md#deprecated-artifacts) for the full policy. |
| Removal            | Remove active standard membership and retain a `removed` tombstone in `x-hve.componentMaturity` when source should remain for history, references, or possible reinstatement. See [Removed Artifacts](../architecture/ai-artifacts.md#removed-artifacts).          |

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
