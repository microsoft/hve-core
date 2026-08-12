---
title: Managing the Marketplace Recipe
description: Maintain ordinary Copilot plugin and VSIX recipes through the marketplace catalog
author: Microsoft
ms.date: 2026-08-10
ms.topic: how-to
keywords:
  - marketplace
  - packages
  - plugins
  - vsix
estimated_reading_time: 6
---

## Recipe Authority

`.github/plugin/marketplace.json` is the only operational distribution definition. Every active entry is an ordinary, self-contained recipe with standard fields for `agents`, `commands`, `rules`, `skills`, and optional `hooks`. `x-hve` holds entry metadata only: display name, lifecycle maturity, documentation path, and optional profiles. It never appears in generated `plugin.json` files.

| Package choice            | Use it for                                               |
|---------------------------|----------------------------------------------------------|
| `hve-core`                | Focused RPI, HVE Builder, Git, and code-review workflows |
| `hve-core-all`            | All active content and the only starter profile          |
| Domain or utility package | A narrower capability set defined by the active catalog  |

Do not install `hve-core` and `hve-core-all` together. Both include overlapping content and the telemetry hook.

## Add Or Change A Component

1. Add canonical artifacts under `.github/<kind>/<package>/`.
2. Add `.github`-root-relative canonical paths to applicable catalog entries:
  `agents/*.agent.md`, `prompts/*.prompt.md`,
  `instructions/*.instructions.md`, `skills/*` directories, or
  `hooks/*.json`.
3. Align lifecycle maturity for every declared membership.
4. Update `docs/plugins/<name>.md` for each affected package.
5. Run the local-safe package checks in
  [Validation and Package Staging](#validation-and-package-staging).

A recipe path maps deterministically to a canonical source path. Do not add a fallback reader, duplicate manifest, or manually copy generated output.

## Closure And Channels

`MarketplaceHelpers.psm1` resolves transitive agent handoffs from each catalog entry. Unresolved or ambiguous handoffs fail. The resolved source set feeds plugin and VSIX packaging before channel-specific destination mapping.

Stable and PreRelease have the same active package names and the same active components and maturity map per package. They differ only in source ownership, cadence, and version. Packages have no dependencies, aggregate metadata, `extensionPack`, or `extensionDependencies`.

## Hooks

Hooks are per-plugin declarations. `hve-core` and `hve-core-all` each include the telemetry hook. VS Code has no declarative hook contribution point, so extension users configure hook locations manually. Hooks are not copied during selective installation.

## Validation and Package Staging

Ordinary validation reads canonical `.github` sources and never creates a
repository-root `plugins/` tree. Extension preparation writes
`extension/package*.json` and `extension/README*.md`. Generated ZIP and VSIX
paths are host-specific package layouts, not catalog membership vocabulary.

Use these checks for package changes:

```bash
npm run lint:marketplace
npm run plugin:evidence
npm run docs:generate:check
npm run test:ps -- -TestPath scripts/tests/plugins/
npm run test:ps -- -TestPath scripts/tests/extension/
```

When explicit plugin assembly is required, supply external staging:

```bash
HVE_PLUGIN_STAGING_ROOT=/absolute/path/outside/hve-core npm run plugin:generate
```

## Selective Adoption

The installer requires an exact `PackageName` before profile or component resolution. The `starter` profile is available only from `hve-core-all`; custom selection resolves against the selected entry.

Schema version 2 records `selection.package`. A package-less schema version 2 manifest emits `INSTALLED_PACKAGE=` and requires explicit package reselection before upgrade replay. File records track selected components, not per-file package ownership. The installer copies agents, prompts, instructions, and complete skill directories while preserving source-relative paths.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
