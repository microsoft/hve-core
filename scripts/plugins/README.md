---
title: Plugin Manifest Scripts
description: PowerShell tooling for synchronizing and validating the HVE Core plugin manifest
---

PowerShell tooling for synchronizing root `plugin.json` with the complete distributable HVE Core component set and validating the one-entry marketplace locator. Discovery remains limited to tracked package-scoped artifacts under `.github`.

## Scripts

| Script                         | npm Command                    | Description                                       |
|--------------------------------|--------------------------------|---------------------------------------------------|
| Sync-PluginManifest.ps1        | `npm run plugin:sync`          | Write deterministic membership and locator parity |
| Sync-PluginManifest.ps1 -Check | `npm run lint:plugin-manifest` | Fail on manifest or marketplace locator drift     |
| Aggregate validation           | `npm run plugin:validate`      | Check the manifest and locator                    |

## Prerequisites

* PowerShell 7.4+
* Git, because membership is derived from tracked source paths

## Source to Manifest Pipeline

1. Author artifacts in `.github/` (agents, prompts, instructions, skills)
2. Run `npm run plugin:sync` to derive root `plugin.json`
3. Run `npm run plugin:validate` for non-mutating manifest validation
4. Prepare or package the single extension separately when VSIX output is in scope

## Manifest Output

The script discovers these git-tracked paths beneath `.github` and emits repository-relative `.github/...` component paths:

* `agents/<package>/**/*.agent.md`
* `prompts/<package>/**/*.prompt.md`
* `instructions/<package>/**/*.instructions.md`
* `skills/<package>/<skill>/SKILL.md`, unless the top-level license has a noncommercial qualifier

Artifacts without a package segment are excluded from discovery. Paths are unique and ordinal-sorted. Metadata is preserved and the version follows root `package.json`. The manifest declares no `hooks`: support for it was removed with the telemetry hook, so a committed `hooks` field (or any other field the manifest cannot derive) is reported as drift rather than preserved. Validation also requires tracked, regular, non-empty root `plugin.json`, `README.md`, and `LICENSE` files.

## Synchronizing After Artifact Changes

```bash
npm run plugin:sync
npm run plugin:validate
```

To run the writer or check directly:

```powershell
pwsh -NoProfile -File scripts/plugins/Sync-PluginManifest.ps1
pwsh -NoProfile -File scripts/plugins/Sync-PluginManifest.ps1 -Check
```

Check mode writes nothing and exits nonzero on manifest or locator drift.

## Locator Validation

Check mode requires `.github/plugin/marketplace.json` to contain exactly one `hve-core` entry whose relative source is `.github`. It verifies parity for every retained manifest metadata field, source containment, manifest existence, component coverage, and the absence of recipe fields such as `agents`, `commands`, `rules`, `skills`, `hooks`, or `x-hve` on the locator entry.

The moving registrations `microsoft/hve-core#release/prerelease` and `microsoft/hve-core#release/stable` select reviewed branch state. Exact `prerelease-v<version>` and `v<version>` registrations select immutable release state. The catalog always locates the plugin root relative to the selected repository ref.

## Release Boundary

Plugin validation produces no package archive or release evidence document. Release workflows package, attest, and publish one VSIX separately. The Copilot CLI installs the plugin directly from the repository root at the selected ref.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
