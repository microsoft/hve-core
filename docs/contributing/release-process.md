---
title: Release Process
description: Release HVE Core through direct main PreRelease builds and reviewed release/stable promotions
sidebar_position: 9
ms.date: 2026-08-03
ms.topic: how-to
author: WilliamBerryiii
---

## Overview

This project uses trunk-based development with explicit channel ownership. Changes reach `main` through pull requests, and PreRelease packages an approved `main` commit directly. `release-stable.yml` opens the reviewed `main` to `release/stable` promotion after validation. After that promotion merges, `release-stable-publish.yml` runs release-please on `release/stable`. Release-please owns the managed Stable release PR and draft Stable release.

## How Releases Work

```mermaid
flowchart LR
    A[Feature PR] -->|merge| B[main branch]
    B --> C[Validate main]
    C --> D[Review main to release/stable promotion]
    D -->|merge| E[release-please updates Stable Release PR]
    E --> F[Review Stable Release PR]
    F -->|merge| G[Draft release and verified artifacts]
    G --> H[Immutable plugin snapshot]
    H --> I[Publish Stable release]
    I --> J[Review release/stable to main metadata sync]
```

When you merge a PR to `main`:

1. `release-stable.yml` validates the source and checks that the prior Stable metadata sync is complete.
2. The workflow opens or updates a non-auto-merged promotion PR from `main` to `release/stable`.
3. A reviewer merges the promotion after confirming the release boundary.
4. `release-stable-publish.yml` runs release-please against `release/stable`.
5. Release-please opens or updates its managed Stable release PR with version and changelog changes; the workflow postprocessor synchronizes every committed version field and the `plugins-v<version>` locator.
6. A reviewer merges the managed Stable release PR when the release is ready.
7. Release-please creates the draft Stable release, then the workflow builds, attests, and uploads artifacts from the released commit.
8. The workflow publishes the immutable `plugins-v<version>` snapshot, verifies provenance, and finalizes the draft release.
9. The workflow opens a non-auto-merged `release/stable` to `main` metadata synchronization PR for review.

## The Release PR

The release-please managed PR is not a deployment. It prepares version metadata and changelog changes on `release/stable`:

* Updated `package.json` version
* Updated `extension/templates/package.template.json` version
* Updated `.github/plugin/marketplace.json` version and immutable `plugins-v<version>` locator
* Updated `CHANGELOG.md`

The promoted code is already on `release/stable`. The managed PR accumulates version and changelog updates until you are ready to publish that exact Stable release. After publication, the reviewed metadata sync returns those changes to `main` before another promotion can open.

### Version Calculation

Release-please determines the version bump from commit prefixes:

| Commit Prefix                  | Version Bump | Example              |
|--------------------------------|--------------|----------------------|
| `feat:`                        | Minor        | 1.0.0 → 1.1.0        |
| `fix:`                         | Patch        | 1.0.0 → 1.0.1        |
| `feat!:` or `BREAKING CHANGE:` | Major        | 1.0.0 → 2.0.0        |
| `docs:`, `chore:`, `refactor:` | No bump      | Grouped in changelog |

> [!NOTE]
> Stable releases must have an even minor version number (e.g., `1.0`, `1.2`). Odd minor versions (e.g., `1.1`, `1.3`) are reserved for PreRelease. The promotion and publication workflows enforce this convention.

## For Contributors

Write commits using conventional commit format. This enables automated changelog generation and version bumping.

```bash
# Features (triggers minor version bump)
git commit -m "feat: add new prompt for code review"

# Bug fixes (triggers patch version bump)
git commit -m "fix: resolve parsing error in instruction files"

# Documentation (no version bump, appears in changelog)
git commit -m "docs: update installation guide"

# Breaking changes (triggers major version bump)
git commit -m "feat!: redesign configuration schema"
```

For more details, see the [commit message instructions](https://github.com/microsoft/hve-core/blob/main/.github/instructions/hve-core/commit-message.instructions.md).

## For Maintainers

### Reviewing the Stable Release

The promotion and managed release PR are separate review boundaries. When ready to release:

1. Review the `main` to `release/stable` promotion PR. Auto-merge is intentionally disabled.
2. Merge the promotion only when it represents the intended reviewed `main` state.
3. Review the release-please managed PR on `release/stable`, including its changelog, version fields, and immutable plugin locator.
4. Merge the managed PR when the release contents are correct.
5. Verify `release-stable-publish.yml` attaches the VSIX, plugin, SBOM, VEX, and provenance evidence before publication.
6. Verify the workflow publishes the immutable plugin snapshot and final Stable release.
7. Verify the published release triggers the Stable marketplace workflow.
8. Review and merge the generated `release/stable` to `main` metadata synchronization PR.

### Release Cadence

Releases are on-demand. Merge the managed Stable release PR when:

* A meaningful set of changes has accumulated
* A critical fix needs immediate release
* A scheduled release milestone is reached

There is no requirement to release after every PR merge.

## Extension Publishing

VS Code extension publishing is automated. When `release-stable-publish.yml` publishes a verified Stable release, the `release: published` event triggers [`release-marketplace-stable.yml`](https://github.com/microsoft/hve-core/blob/main/.github/workflows/release-marketplace-stable.yml), which packages and publishes the one HVE Core extension through Azure OIDC authentication.

### Manual Fallback

If the automated publish did not trigger or you need to republish, use the workflow dispatch fallback:

1. Navigate to **Actions → Stable Marketplace Publish** in the repository
2. Select **Run workflow**
3. Choose the workflow from its default branch
4. Optionally specify a version (defaults to `package.json` version)
5. Optionally enable dry-run mode to package without publishing
6. Click **Run workflow**

### When to Publish

Publish the extension after merging a Release PR that includes extension-relevant changes:

* New prompts, instructions, or custom agents
* Bug fixes affecting extension behavior
* Updated extension metadata or documentation

Documentation-only releases may not require an extension publish.

## Version Quick Reference

| Action                             | Result                                                            |
|------------------------------------|-------------------------------------------------------------------|
| Merge feature PR to main           | Validated source becomes eligible for promotion                   |
| Merge promotion PR                 | release-please prepares the Stable release PR on `release/stable` |
| Merge managed Stable release PR    | Draft release and verified artifact pipeline start                |
| Stable release published           | Stable extension marketplace workflow starts                      |
| Merge Stable metadata sync PR      | Release metadata returns to `main`                                |
| Run PreRelease for an approved SHA | Odd-minor PreRelease pipeline starts                              |

## Extension Channels and Maturity

The VS Code extension is published to two same-content channels with different cadence, versioning, and source ownership.

### Extension Channels

| Channel    | Source                                        | Included Active Labels                  | Audience       |
|------------|-----------------------------------------------|-----------------------------------------|----------------|
| Stable     | Reviewed `main` promotion in `release/stable` | `stable`, `preview`, and `experimental` | All users      |
| PreRelease | Explicit commit on `main`                     | `stable`, `preview`, and `experimental` | Early adopters |

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
