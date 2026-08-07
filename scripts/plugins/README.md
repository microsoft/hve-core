---
title: Plugin Generation Scripts
description: PowerShell tooling for generating Copilot CLI plugins from marketplace package recipes
---

PowerShell tooling for generating Copilot CLI plugins from the marketplace
catalog and shared resolved package projection.

## Scripts

| Script                           | npm Command                | Description                                     |
|----------------------------------|----------------------------|-------------------------------------------------|
| Generate-Plugins.ps1             | `npm run plugin:generate`  | Materialize plugin packages in external staging |
| Validate-Marketplace.ps1         | `npm run lint:marketplace` | Validate marketplace.json plugin manifest       |
| Assert-PluginReleaseEvidence.ps1 | `npm run plugin:evidence`  | Record or verify canonical release evidence     |
| Modules/PluginHelpers.psm1       | (library)                  | Plugin materialization, manifest, and packaging |

## Prerequisites

* PowerShell 7.0+
* PowerShell-Yaml module (`Install-Module -Name PowerShell-Yaml -RequiredVersion 0.4.7`)
* Git, because generation copies only git-tracked source paths

## Marketplace to Plugin Pipeline

1. Author artifacts in `.github/` (agents, prompts, instructions, skills, hooks)
2. Declare package membership and metadata in `.github/plugin/marketplace.json`
3. Run `npm run lint:marketplace` for ordinary non-mutating validation
4. Materialize packages only when packaging requires them, using an absolute
  staging root outside the repository
5. Validate deterministic evidence directly from canonical tracked sources

## Generated Output

Plugin trees contain only regular files and real directories. No symbolic links
are created, so generation needs no elevated privileges and no OS-specific
configuration. Generation requires either `HVE_PLUGIN_STAGING_ROOT` or
`-StagingRoot` to name an absolute path outside the repository. No default
points to a workspace `plugins/` directory.

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
HVE_PLUGIN_STAGING_ROOT=/absolute/path/outside/hve-core npm run plugin:generate
```

To call the generator directly, pass the staging root explicitly:

```powershell
pwsh -File scripts/plugins/Generate-Plugins.ps1 -StagingRoot /absolute/path/outside/hve-core
```

These commands regenerate all plugins from marketplace package recipes in the
selected temporary staging location. Ordinary validation uses
`npm run lint:marketplace` and does not materialize packages.

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

Every entry uses the canonical `.github` source root:

```json
{
  "name": "rpi",
  "source": {
    "source": "github",
    "repo": "microsoft/hve-core",
    "path": ".github"
  }
}
```

The `repo` and `path` fields are required, and `path` must be `.github`.
Main catalog entries omit `ref`. Release catalog entries use the exact
`hve-core-v<version>` ref matching the package version. Branch refs, commit SHA
locators, URL locators, and version-mismatched release refs are rejected.

Component membership is relative to the `.github` source root:

* `agents/*.agent.md`
* `prompts/*.prompt.md` under the `commands` field
* `instructions/*.instructions.md` under the `rules` field
* `skills/*` directories
* `hooks/*.json`

Generated ZIP paths are host-specific package layout, not catalog membership
vocabulary.

## Deterministic Release Evidence

`Assert-PluginReleaseEvidence.ps1` produces canonical evidence v2 by binding
the immutable source commit, package version, exact `hve-core-v<version>` ref,
package count, per-package non-vacuity and digests, and total digest into one
invariant. It derives the file sets from declared canonical git-tracked sources,
so it needs no generated package tree or staging root and reproduces from a
clean checkout of the tagged commit.

```bash
# Record
npm run plugin:evidence

# Verify canonical evidence against recorded evidence
pwsh -File scripts/plugins/Assert-PluginReleaseEvidence.ps1 \
  -ExpectedEvidencePath logs/plugin-release-evidence.json
```

Verification fails when the source commit, version, locator, package set, or any
digest disagrees, and when the recorded document is missing, corrupt, or
incomplete. `-ExpectedPackageCount` adds a package-count precondition.

## Release Publication and Historical Snapshots

Release workflows attach `plugin-release-evidence.json` to the
`hve-core-v<version>` release and attest it alongside signed plugin ZIPs, SBOM,
Sigstore, and in-toto assets. Release and prerelease catalogs use the exact
release ref and remain reviewed, release-gated, and immutable.

Future `plugins-v` snapshot publication has stopped. Existing `plugins-v` tags
and catalogs remain immutable and supported for historical installations. They
are not deleted, moved, rewritten, or migrated by the current release process.

Remote release-asset and installed-client verification are authorized manual
actions. Local script and documentation checks do not execute or verify them.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
