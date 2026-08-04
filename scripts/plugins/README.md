---
title: Plugin Generation Scripts
description: PowerShell tooling for generating Copilot CLI plugins from marketplace package recipes
---

PowerShell tooling for generating Copilot CLI plugins from the marketplace
catalog and shared resolved package projection.

## Scripts

| Script                           | npm Command                | Description                                          |
|----------------------------------|----------------------------|------------------------------------------------------|
| Generate-Plugins.ps1             | `npm run plugin:generate`  | Generate plugin directories from marketplace recipes |
| Validate-Marketplace.ps1         | `npm run lint:marketplace` | Validate marketplace.json plugin manifest            |
| Assert-PluginReleaseEvidence.ps1 | `npm run plugin:evidence`  | Record or verify deterministic release evidence      |
| Modules/PluginHelpers.psm1       | (library)                  | Plugin materialization, manifest, and packaging      |

## Prerequisites

* PowerShell 7.0+
* PowerShell-Yaml module (`Install-Module -Name PowerShell-Yaml -RequiredVersion 0.4.7`)
* Git, because generation copies only git-tracked source paths

## Marketplace to Plugin Pipeline

1. Author artifacts in `.github/` (agents, prompts, instructions, skills, hooks)
2. Declare package membership and metadata in `.github/plugin/marketplace.json`
3. Run `npm run plugin:generate` to produce `plugins/`
4. Validate deterministic evidence without staging generated `plugins/`

## Generated Output

Plugin trees contain only regular files and real directories. No symbolic links
are created, so generation needs no elevated privileges and no OS-specific
configuration.

Each declared package source is materialized from the paths git currently
tracks beneath it. Working-tree bytes are copied, so locally modified tracked
files are included, while untracked content such as `.venv/`, `node_modules/`,
and Python bytecode cache directories is never ingested. Generation fails when
the combined output exceeds `-MaxTotalSizeMB` (default 40), and the failure names
the largest plugins.

A source path that git does not track produces a warning and is skipped. Stage
new artifacts before generating.

## Refreshing Plugins After Artifact Changes

```bash
npm run plugin:generate
```

This regenerates all plugins from marketplace package recipes.

## Marketplace Validation

`Validate-Marketplace.ps1` validates `.github/plugin/marketplace.json` against
its JSON schema and checks version alignment with the root `package.json` plus
the source locator of every entry.

```bash
npm run lint:marketplace
```

Parameters:

* `-OutputPath` (default: `logs/marketplace-validation-results.json`): path
  for the structured JSON report, absolute or relative to the repository root

The script writes structured JSON results to `logs/`, consistent with the rest
of the linting pipeline. Pass `-OutputPath ''` to suppress the report file.

### Entry Source Contract

Every entry uses an immutable GitHub object locator:

```json
{
  "name": "rpi",
  "source": {
    "source": "github",
    "repo": "microsoft/hve-core",
    "path": "plugins/rpi",
    "ref": "plugins-v<version>"
  }
}
```

The `repo`, `path`, and `ref` fields are required. `path` must be
`plugins/<package-name>`, and `ref` must match the package version as
`plugins-v<version>`. Bare package names, moving refs, URL locators, and commit
SHA locators are rejected.

## Locator-Aware Catalog Generation

Default generation reads the immutable object sources from the production
catalog without rewriting it. Passing an explicit release tag overrides those
sources in a separate catalog projection:

```bash
pwsh -File scripts/plugins/Generate-Plugins.ps1 \
  -ReleaseTag plugins-v<version> \
  -MarketplaceOutputPath logs/marketplace-snapshot.json
```

Locator override mode requires an explicit `-MarketplaceOutputPath` and refuses
to write the production catalog. Only the immutable `plugins-v<version>` tag
form is accepted; commit SHA locators are rejected.

## Deterministic Release Evidence

`Assert-PluginReleaseEvidence.ps1` binds the immutable source commit, package
version, catalog locator, and a digest of the generated package tree into one
invariant. The digest covers repository-relative package paths and file content
only, so it reproduces from a clean checkout of the same source commit and never
compares against committed generated output.

```bash
# Record
npm run plugin:evidence

# Verify a snapshot against recorded evidence
pwsh -File scripts/plugins/Assert-PluginReleaseEvidence.ps1 \
  -ExpectedEvidencePath logs/plugin-release-evidence.json
```

Verification fails when the source commit, version, locator, package set, or any
digest disagrees, and when the recorded document is missing, corrupt, or
incomplete. `-ExpectedPackageCount` adds a package-count precondition.

## Snapshot Publication

The `Plugin Snapshot Publish` workflow generates one snapshot from an explicit
immutable source, stages it as an orphan commit, and verifies the staged tree
from a fresh clone before any reference is written.

Its targets are constrained by `Assert-PluginSnapshotTarget`:

* Branch and tag must start with the disposable prefix `plugins-snapshot/`.
* `main`, `release/plugins`, and `plugins-v<version>` references are refused.
* An existing tag is refused rather than overwritten, and no push uses a force
  flag.

The workflow defaults to `dry-run: true`, which stages and verifies without
pushing. It never writes the production catalog, and it fails if the catalog
changed during the run.

### Publication and Recovery Contract

Publication is refused unless every precondition holds:

1. The snapshot contains the complete expected package set, asserted with
   `-ExpectedPackageCount`.
2. The source commit, version, locator, and digest agree in recorded evidence.
3. Archives and attestations match the same snapshot.
4. Both clients install from the immutable reference and pass a functional
   component check.

Failure behavior and recovery:

* Any failed precondition leaves release references untouched. Every guard fails
  before a write.
* Recovery moves forward by publishing a corrected next immutable tag or by
  re-pinning to a previously verified immutable tag. Bare sources and tracked
  generated output are never restored.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
