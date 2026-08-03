---
title: Managing the Marketplace Recipe
description: Maintain the complete hve-core Copilot plugin and VSIX recipe through the marketplace catalog
author: Microsoft
ms.date: 2026-08-02
ms.topic: how-to
keywords:
  - marketplace
  - packages
  - plugins
  - vsix
estimated_reading_time: 6
---

## Recipe Authority

`.github/plugin/marketplace.json` is the only operational distribution definition. Its one `hve-core` entry uses standard fields for component membership:

* `agents` for custom agents
* `commands` for prompts
* `rules` for instructions
* `skills` for skill directories
* `hooks` for the plugin-only hook manifest

The `x-hve` object contains repository metadata only: `displayName`, component lifecycle maturity, documentation path, and the selective-adoption starter profile. It never appears in generated `plugin.json` files.

## Add Or Change A Component

1. Add canonical artifacts under their `.github/<kind>/<package>/` source directories.
2. Add recipe-relative component paths to the `hve-core` marketplace entry.
3. Set component maturity in `x-hve.componentMaturity` only when it differs from `stable` or records a removed tombstone.
4. Update the durable inventory page at `docs/plugins/hve-core.md`.
5. Run marketplace validation, plugin generation, extension preparation, and focused tests.

A recipe path maps deterministically to a canonical source path. Do not add a fallback reader, duplicate manifest, or manually copy generated output.

## Dependency Closure

`MarketplaceHelpers.psm1` resolves transitive agent handoffs from catalog-declared agents. Unresolved or ambiguous handoffs fail. The same resolved canonical source set feeds plugin and VSIX packaging before each channel maps sources to its destination layout.

The HVE Core output remains self-contained. Do not introduce plugin dependencies, `extensionPack`, or `extensionDependencies` as a substitute for recipe contents.

## Maturity And Channels

Supported maturity values, from least to most restrictive, are:

1. `stable`
2. `preview`
3. `experimental`
4. `deprecated`
5. `removed`

Stable and PreRelease both include active `stable`, `preview`, and `experimental` components. Deprecated and removed entries are never distributed. Lifecycle labels disclose support posture and do not filter channels. Removed component tombstones may remain in `x-hve.componentMaturity` after active membership is deleted so policy checks retain the retirement record.

## Generated Outputs

Plugin generation writes ignored materialized packages under `plugins/`. Extension preparation writes `extension/package*.json` and `extension/README*.md`. Generated outputs are never package-definition authority and are not edited by hand.

Use these checks for package changes:

```bash
npm run lint:marketplace
npm run plugin:generate
npm run plugin:evidence
npm run extension:prepare
npm run extension:prepare:prerelease
npm run test:ps -- -TestPath scripts/tests/plugins/
npm run test:ps -- -TestPath scripts/tests/extension/
```

## Selective Adoption Profile

The starter profile is a validated subset of the `hve-core` recipe for selective clone adoption. It does not define distribution membership. Custom selection can include agents, prompts, instructions, and complete skills; shared dependency closure adds only components that separately belong to the recipe. Hooks remain plugin-only and are not copied.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
