---
title: Managing the HVE Core Plugin Manifest
description: Maintain the single HVE Core plugin and VSIX membership through the canonical manifest
author: Microsoft
ms.date: 2026-11-04
ms.topic: how-to
keywords:
  - marketplace
  - packages
  - plugins
  - vsix
estimated_reading_time: 6
---

## Manifest Authority

Root `plugin.json` is the operational distribution definition for the one `hve-core` plugin and VSIX. Its `agents`, `commands`, `rules`, `skills`, and `extensions` arrays are deterministic repository-relative outputs of tracked path and license classification under `.github`. The manifest declares no `hooks` field.

| Field        | Lists                                                                                                      | Included in     |
|--------------|------------------------------------------------------------------------------------------------------------|-----------------|
| `agents`     | Agent files (`.agent.md`)                                                                                  | Plugin and VSIX |
| `commands`   | Prompt files (`.prompt.md`); empty, because HVE Core ships none and the Copilot harness does not load them | Plugin and VSIX |
| `rules`      | Instruction files (`.instructions.md`)                                                                     | Plugin and VSIX |
| `skills`     | Distributable skill folders                                                                                | Plugin and VSIX |
| `extensions` | Canvas extension package folders                                                                           | Plugin only     |

`.github/plugin/marketplace.json` contains one `hve-core` entry with the relative source `.`. It owns locator metadata only and must not repeat component arrays or package policy. Because a fork keeps both `plugin.json` and this locator, it can serve as its own marketplace, as described in [Distribute Your Fork](forking#distribute-your-fork).

## Add Or Change A Component

1. Add canonical artifacts under `.github/<kind>/<package>/`.
2. Run `npm run plugin:sync` to derive root `plugin.json` from tracked `.github` paths.
3. Update `docs/plugins/hve-core.md` when user-visible capabilities or identity guidance changed.
4. Run the local-safe checks in
  [Validation and Package Staging](#validation-and-package-staging).

A manifest path maps directly to canonical source beneath `.github`. Do not add a fallback reader, duplicate membership list, copied plugin tree, or package recipe.

## Closure And Channels

Manifest synchronization discovers every convention-matching tracked artifact. Plugin validation checks deterministic ordering, locator parity and containment, declared component coverage, and hooks.

The plugin has one registration, `microsoft/hve-core`, which tracks `main`. Stable and PreRelease are VS Code extension channels with the same components. They differ only in source ownership, cadence, version, and VS Code Marketplace channel behavior.

The VSIX carries the manifest's agents, instructions, and skills, without canvases. VS Code forwards the extension's agents and skills to Copilot sessions, but its instructions may not reach them, so use the plugin when you need every component.

## Hooks

The plugin manifest declares no hooks. Hooks are not copied during repository adoption.

## Validation and Package Staging

Ordinary validation reads canonical `.github` sources and never creates a repository-root `plugins/` tree. Extension preparation reads the manifest's `agents`, `commands`, `rules`, and `skills` fields, writes them as the extension's `chatAgents`, `chatPromptFiles`, `chatInstructions`, and `chatSkills` contributions, and refreshes the single `extension/package.json` and `extension/README.md`. It ignores `extensions`. Packaging creates one VSIX.

Use these checks for package changes:

```bash
npm run plugin:sync
npm run plugin:validate
npm run docs:generate:check
npm run test:ps -- -TestPath scripts/tests/plugins/
npm run test:ps -- -TestPath scripts/tests/extension/
```

## Repository Adoption

The installer resolves all components from root `plugin.json` and copies the complete manifest, because agents load skills and instructions by name and a partial set can leave an agent without what it needs. It converts repository-relative `.github/...` declarations to its component form without changing canonical target paths.

Schema version 2 records `selection.profile` and `selection.components`. New installs record the `all` profile. Installs from earlier versions may record `custom` with the components picked then. An upgrade copies every component the current manifest declares, and offers that full set in place of a recorded `custom` list, because agents preload skills that an earlier partial list can't include. File records track installed components without package identity.

The installer copies agents, instructions, and complete distributable skill directories into the target repository's `.github` folders while preserving source-relative paths, and Copilot discovers the copies there without settings. [Copy HVE Core Into Your Repository](../getting-started/install#copy-hve-core-into-your-repository) walks through the installer.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
