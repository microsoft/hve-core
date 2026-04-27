---
title: Release Process
description: Trunk-based release workflow using release-please automation and automated VS Code extension publishing
sidebar_position: 9
ms.date: 2026-04-17
ms.topic: how-to
author: WilliamBerryiii
---

## Overview

This project uses trunk-based development with automated release management. All changes go directly to `main` via pull requests, and [release-please](https://github.com/googleapis/release-please) handles version bumping, changelog generation, and GitHub releases automatically.

## How Releases Work

```mermaid
flowchart LR
    A[Feature PR] -->|merge| B[main branch]
    B --> C[release-please updates Release PR]
    C -->|you merge| D[Draft release + tag created]
    D --> E[CI attaches assets and attestations]
    E --> F[publish-release promotes to published]
    F -->|automatically| G[Extension published to marketplace]
```

When you merge a PR to `main`:

1. **release-please analyzes commits** using conventional commit messages
2. **Updates the Release PR** with version bumps and changelog entries
3. **You decide** when to merge the Release PR
4. **Merging creates** a draft GitHub Release with the changelog
5. **CI attaches assets**, then the `publish-release` job promotes the draft to published
6. **Extension publishing** triggers automatically when the release is published

## The Release PR

The Release PR is not a branch cut or deployment. It is a staging mechanism containing only version metadata changes:

* Updated `package.json` version
* Updated `extension/templates/package.template.json` version
* Updated `.github/plugin/marketplace.json` (version and plugins[*].version)
* Updated `plugins/*/.github/plugin/plugin.json` (glob across all plugin directories)
* Updated `CHANGELOG.md`

Your actual code changes are already on `main` from your feature PRs. The Release PR accumulates version and changelog updates until you are ready to release.

### Version Calculation

Release-please determines the version bump from commit prefixes:

| Commit Prefix                  | Version Bump | Example              |
|--------------------------------|--------------|----------------------|
| `feat:`                        | Minor        | 1.0.0 → 1.1.0        |
| `fix:`                         | Patch        | 1.0.0 → 1.0.1        |
| `feat!:` or `BREAKING CHANGE:` | Major        | 1.0.0 → 2.0.0        |
| `docs:`, `chore:`, `refactor:` | No bump      | Grouped in changelog |

> [!NOTE]
> Stable releases must have an even minor version number (e.g., `1.0`, `1.2`). Odd minor versions (e.g., `1.1`, `1.3`) are reserved for pre-release or unstable versions. This convention is enforced by CI (`release-stable.yml`).

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

### Reviewing the Release PR

The Release PR titled "chore(main): release X.Y.Z" updates automatically as PRs merge. When ready to release:

1. Review the accumulated changelog in the PR
2. Verify version bump is appropriate for the changes
3. Merge the Release PR (this creates a draft GitHub Release)
4. CI attaches VSIX packages, plugin ZIPs, SBOMs, and attestations to the draft release
5. The `publish-release` job promotes the draft to a published release
6. The `release: published` event triggers the marketplace publish workflow automatically

### Release Cadence

Releases are on-demand. Merge the Release PR when:

* A meaningful set of changes has accumulated
* A critical fix needs immediate release
* A scheduled release milestone is reached

There is no requirement to release after every PR merge.

## Extension Publishing

VS Code extension publishing is automated. When the `publish-release` job promotes a draft release to published, the `release: published` event triggers [`release-marketplace-stable.yml`](https://github.com/microsoft/hve-core/blob/main/.github/workflows/release-marketplace-stable.yml), which packages and publishes the extension to the VS Code Marketplace using Azure OIDC authentication.

### Manual Fallback

If the automated publish did not trigger or you need to republish, use the workflow dispatch fallback:

1. Navigate to **Actions → Stable Marketplace Publish** in the repository
2. Select **Run workflow**
3. Choose the `main` branch
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

| Action                   | Result                                                        |
|--------------------------|---------------------------------------------------------------|
| Merge feature PR to main | Release PR updates with new changelog entry                   |
| Merge Release PR         | Draft GitHub Release created, then auto-promoted to published |
| Release published        | Extension automatically published to marketplace              |
| Merge docs-only PR       | Changelog updated, no version bump                            |

## Extension Channels and Maturity

The VS Code extension is published to two channels with different stability expectations.

### Extension Channels

| Channel     | Stability        | Included Maturity Levels            | Audience       |
|-------------|------------------|-------------------------------------|----------------|
| Stable      | Production-ready | `stable` only                       | All users      |
| Pre-release | Early access     | `stable`, `preview`, `experimental` | Early adopters |

### Maturity Levels

Each prompt, instruction, agent, and skill can set `maturity` in `collections/*.collection.yml` under `items[]`:

| Level          | Description                                                                                       | Included In         |
|----------------|---------------------------------------------------------------------------------------------------|---------------------|
| `stable`       | Production-ready, fully tested                                                                    | Stable, Pre-release |
| `preview`      | Feature-complete but may have rough edges                                                         | Pre-release only    |
| `experimental` | Early development, may change significantly                                                       | Pre-release only    |
| `deprecated`   | Scheduled for removal, excluded from all builds                                                   | Neither             |
| `removed`      | Source retained for traceability; excluded from all generated plugins and extension distributions | Neither             |

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

The `removed` level is a collection-YAML-only marker. The artifact file remains in its
source location (for example, under `.github/skills/{collection-id}/`) so history and
references stay intact, but every downstream surface (collection validation, plugin
generation, and extension packaging) excludes it. Use `removed` when you want to retire
an artifact from distribution without moving it to `.github/deprecated/` or deleting it
outright. See [AI Artifacts Architecture - Removed Artifacts](../architecture/ai-artifacts.md#removed-artifacts)
for the architectural contract.

### Contributor Guidelines

| Guideline          | Action                                                                                                                                                                                                                                                                                                                                                                                                                           |
|--------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| New contributions  | Set `stable` on collection items unless explicitly targeting early adopters                                                                                                                                                                                                                                                                                                                                                      |
| Experimental work  | Set `experimental` on collection items for proof-of-concept or rapidly evolving artifacts                                                                                                                                                                                                                                                                                                                                        |
| Preview promotions | Set `preview` on collection items when core functionality is complete                                                                                                                                                                                                                                                                                                                                                            |
| Stable promotions  | Set `stable` on collection items after production validation                                                                                                                                                                                                                                                                                                                                                                     |
| Deprecation        | Set `deprecated` on collection items before removal to provide transition time. Move the artifact file to `.github/deprecated/{type}/` so the build system excludes it from all downstream surfaces automatically. See [AI Artifacts Architecture](../architecture/ai-artifacts.md#deprecated-artifacts) for the full deprecation policy.                                                                                        |
| Removal            | Set `removed` on collection items when the artifact should no longer ship in any plugin or extension build but its source should remain in place for history, references, or future reinstatement. The collection YAML is the single source of truth - no per-artifact frontmatter or file move is required. See [AI Artifacts Architecture - Removed Artifacts](../architecture/ai-artifacts.md#removed-artifacts) for details. |

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
