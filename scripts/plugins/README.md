---
title: Plugin Manifest Scripts
description: PowerShell tooling for synchronizing and validating the HVE Core plugin manifest
---

PowerShell tooling for synchronizing root `plugin.json` with the complete distributable HVE Core component set and validating the one-entry marketplace locator. Discovery remains limited to tracked package-scoped artifacts under `.github`.

## Scripts

| Script                          | Invocation                      | Description                                                 |
|---------------------------------|---------------------------------|-------------------------------------------------------------|
| Install-HveCorePlugin.ps1       | Direct `pwsh` script            | Install HVE Core through a marketplace at an exact Git SHA  |
| Sync-PluginManifest.ps1         | `npm run plugin:sync`           | Write deterministic membership and locator parity          |
| Sync-PluginManifest.ps1 -Check  | `npm run lint:plugin-manifest`  | Fail on manifest or marketplace locator drift               |
| Aggregate validation            | `npm run plugin:validate`       | Check the manifest and locator                              |

## Prerequisites

* PowerShell 7.4+
* Git, because membership is derived from tracked source paths

Pinned plugin installation also requires network access and an authenticated
GitHub Copilot CLI. These prerequisites apply on Windows and macOS.

## Installing a Pinned Plugin Commit

Run the installer from a trusted HVE Core checkout. Its location is independent
of the repository where you plan to use the plugin.

```powershell
pwsh -NoProfile -File ./scripts/plugins/Install-HveCorePlugin.ps1
```

The default commit is
`0c14eea959a5ff355871205acf14807c7fa7d4a7`. Supply another full
40-character commit or preview the operation when needed:

```powershell
pwsh -NoProfile -File ./scripts/plugins/Install-HveCorePlugin.ps1 -CommitSha <full-commit-sha>
pwsh -NoProfile -File ./scripts/plugins/Install-HveCorePlugin.ps1 -WhatIf
```

The installer stores immutable pins under
`$HOME/.hve-core/copilot-plugin-pins` by default. Each pin contains the exact
checkout in `<sha>/source` and a generated `<sha>/marketplace.json`. The
generated marketplace is named `hve-core-<full-sha>` and locates its contained
checkout at `./source`.

`-WhatIf` validates parameters, prerequisites, and an existing pin without
creating files or invoking mutating Git or Copilot commands. When the pin does
not exist, remote commit and manifest verification remain pending.

The installer never removes or replaces an existing marketplace or plugin. A
marketplace collision stops with inspection guidance. If marketplace
registration succeeds but plugin installation fails, the verified registration
is retained and the error supplies the qualified `copilot plugin install`
command for recovery.

Run the isolated installer tests with:

```powershell
npm run test:ps -- -TestPath scripts/tests/plugins/Install-HveCorePlugin.Tests.ps1
```

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

Check mode requires `.github/plugin/marketplace.json` to contain exactly one
`hve-core` entry whose relative source is `.`. This canonical locator differs
from the pinned installer's generated wrapper source, `./source`. Check mode
verifies parity for every retained manifest metadata field, source containment,
manifest existence, component coverage, and the absence of recipe fields such
as `agents`, `commands`, `rules`, `skills`, `hooks`, or `x-hve` on the locator
entry.

The moving registrations `microsoft/hve-core#release/prerelease` and `microsoft/hve-core#release/stable` select reviewed branch state. Exact `prerelease-v<version>` and `v<version>` registrations select immutable release state. The catalog always locates the plugin root relative to the selected repository ref.

## Release Boundary

Plugin validation produces no package archive or release evidence document. Release workflows package, attest, and publish one VSIX separately. The Copilot CLI installs the plugin directly from the repository root at the selected ref.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
