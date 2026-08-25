---
title: Managing the HVE Core Plugin Manifest
description: Maintain the single HVE Core plugin and VSIX membership through the canonical manifest
author: Microsoft
ms.date: 2026-08-19
ms.topic: how-to
keywords:
  - marketplace
  - packages
  - plugins
  - vsix
estimated_reading_time: 6
---

## Manifest Authority

Root `plugin.json` is the operational distribution definition for the one `hve-core` plugin and VSIX. Its `agents`, `commands`, `rules`, and `skills` arrays are deterministic repository-relative outputs of tracked path and license classification under `.github`. The fixed `hooks` value includes the telemetry hook.

`.github/plugin/marketplace.json` contains one `hve-core` entry with the relative source `.`. It owns locator metadata only and must not repeat component arrays or package policy.

## Add Or Change A Component

1. Add canonical artifacts under `.github/<kind>/<package>/`.
2. Run `npm run plugin:sync` to derive root `plugin.json` from tracked `.github` paths.
3. Update `docs/plugins/hve-core.md` when user-visible capabilities or identity guidance changed.
4. Run the local-safe checks in
  [Validation and Package Staging](#validation-and-package-staging).

A manifest path maps directly to canonical source beneath `.github`. Do not add a fallback reader, duplicate membership list, copied plugin tree, or package recipe.

## Closure And Channels

Manifest synchronization discovers every convention-matching tracked artifact. Plugin validation checks deterministic ordering, locator parity and containment, declared component coverage, and hooks.

Stable and PreRelease have the same complete components. They differ only in source ownership, cadence, version, and VS Code Marketplace channel behavior.

## Hooks

The plugin manifest includes the telemetry hook. VS Code has no declarative hook contribution point, so extension users configure its location manually. Hooks are not copied during selective installation.

## Validation and Package Staging

Ordinary validation reads canonical `.github` sources and never creates a repository-root `plugins/` tree. Extension preparation refreshes the single `extension/package.json` and `extension/README.md`. Packaging creates one VSIX.

Use these checks for package changes:

```bash
npm run plugin:sync
npm run plugin:validate
npm run docs:generate:check
npm run test:ps -- -TestPath scripts/tests/plugins/
npm run test:ps -- -TestPath scripts/tests/extension/
```

## Selective Adoption

The installer resolves all components from root `plugin.json`. Users can copy the complete manifest or a custom selection; the installer converts repository-relative `.github/...` declarations to its selection form without changing canonical target paths.

Schema version 2 records `selection.profile` and `selection.components`. File records track selected components without package identity. The installer copies agents, prompts, instructions, and complete distributable skill directories while preserving source-relative paths.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
