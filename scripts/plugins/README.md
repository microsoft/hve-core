---
title: Plugin Generation Scripts
description: PowerShell tooling for generating Copilot CLI plugins from collection manifests
---

PowerShell tooling for generating Copilot CLI plugins from collection
manifests.

## Scripts

| Script                     | npm Command               | Description                                  |
|----------------------------|---------------------------|----------------------------------------------|
| Generate-Plugins.ps1       | `npm run plugin:generate` | Generate plugin directories from collections |
| Modules/PluginHelpers.psm1 | (library)                 | Plugin symlink, manifest, and packaging      |

## Prerequisites

* PowerShell 7.0+
* PowerShell-Yaml module (`Install-Module PowerShell-Yaml`)

## Collection to Plugin Pipeline

1. Author artifacts in `.github/` (agents, prompts, skills)
2. Define collections in `collections/*.collection.yml`
3. Run `npm run plugin:generate` to produce `plugins/`
4. Commit generated `plugins/` to the repository

## Refreshing Plugins After Artifact Changes

```bash
npm run plugin:generate
```

This regenerates all plugins from their collection manifests.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
