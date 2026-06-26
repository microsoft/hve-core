---
title: Collection Scripts
description: PowerShell tooling for validating the canonical collection manifest and generated collection outputs
---

PowerShell tooling for validating `collections/core-manifest.yml`, generating
collection package manifests, and sharing collection helpers used by validation
and plugin generation.

## Scripts

| Script                           | npm Command                         | Description                                                   |
|----------------------------------|-------------------------------------|---------------------------------------------------------------|
| Validate-CoreManifest.ps1        | `npm run lint:collections-metadata` | Validate the canonical collection manifest source             |
| Validate-Collections.ps1         | `npm run lint:collections-metadata` | Validate generated collection manifests                       |
| Promote-Agent.ps1                | `npm run promote:agent`             | Promote an agent between maturity tiers and sync the manifest |
| Modules/CoreManifestHelpers.psm1 | (library)                           | Core manifest parsing, normalization, and generation helpers  |
| Modules/CollectionHelpers.psm1   | (library)                           | YAML parsing, frontmatter, and collection helpers             |

## Prerequisites

* PowerShell 7.0+
* PowerShell-Yaml module (`Install-Module -Name PowerShell-Yaml -RequiredVersion 0.4.7`)

## Maintainer Note: Channel Distribution

This note is for maintainers and is intentionally kept out of the generated
consumer-facing collection READMEs.

Plugins (the `plugins/<id>/` committed tree and the `.github/plugin/marketplace.json`
entry) ship the PreRelease description text only. The `.vsix` extension package
ships either Stable or PreRelease text depending on which channel was packaged.
`descriptions.prerelease` is required for any collection that ships a plugin.

## Promoting an Agent Between Maturity Tiers

`Promote-Agent.ps1` moves an agent between the `experimental`, `preview`, and
`stable` maturity tiers and keeps every dependent reference and the central
manifest aligned with the new tier.

Run it through the npm wrapper:

```bash
npm run promote:agent -- -AgentPath .github/agents/security/security-planner.agent.md -TargetMaturity preview
```

The script performs these actions in a single pass:

* Rewrites the target agent's `name:` frontmatter to use the picker-name suffix
  for the target tier (`experimental` appends `(exp)`, `preview` appends
  `(pre)`, `stable` removes the suffix).
* Rewrites every incoming reference to the agent (`agents:` list entries and
  `handoffs.agent:` values) across all `.github/agents/**/*.agent.md` files so
  the suffixed picker names stay consistent.
* Synchronizes the agent's `maturity:` field in `collections/core-manifest.yml`
  so the manifest does not retain a stale maturity tier. The update is keyed off
  the agent's manifest `path:` entry and is skipped with a warning when the
  manifest, the agent entry, or the maturity value cannot be located. Only the
  promoted agent's maturity is changed; dependent assets are not auto-promoted.

Useful switches:

* `-WhatIf` (or `-DryRun`) reports the planned file and manifest changes without
  writing anything.
* `-RewriteProse` also rewrites body-prose mentions of the previous suffixed
  name; without it, prose mentions only produce warnings.
* `-ManifestPath` overrides the manifest location (defaults to
  `collections/core-manifest.yml` under the repository root).

When the promotion changes manifest content, regenerate the collection and
extension outputs as described in the repository workflow
(`npm run plugin:generate`, `npm run extension:prepare`, and
`npm run extension:prepare:prerelease`).

## Adding a New Collection

1. Add the collection metadata to `collections/core-manifest.yml` under
   `collections:`. Include the generated manifest path, display name,
   description, tags, and item count.
2. Assign artifacts to the collection in the canonical artifact maps such as
   `agents:`, `prompts:`, `instructions:`, and `skills:`.
3. Run `npm run lint:collections-metadata` to check the core manifest and
   generated manifests.
4. Run `npm run plugin:generate` to generate collection and plugin outputs.
5. Commit the core manifest changes and the generated outputs required by the
   repository workflow.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
