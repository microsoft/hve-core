---
title: Plugin Engineering Scripts
description: PowerShell tooling for generating Copilot CLI plugins from collection manifests
---

PowerShell tooling for generating Copilot CLI plugins from collection
manifests.

## Scripts

| Script                     | npm Command               | Description                                   |
|----------------------------|---------------------------|-----------------------------------------------|
| Generate-Plugins.ps1       | `npm run plugin:generate` | Generate plugin directories from collections  |
| Validate-Collections.ps1   | `npm run plugin:validate` | Validate collection manifests                 |
| Modules/PluginHelpers.psm1 | (library)                 | Shared YAML parsing, symlink, and frontmatter |

## Prerequisites

- PowerShell 7.0+
- PowerShell-Yaml module (`Install-Module PowerShell-Yaml`)

## Collection to Plugin Pipeline

1. Author artifacts in `.github/` (agents, prompts, skills)
2. Define collections in `collections/*.collection.yml`
3. Run `npm run plugin:generate` to produce `plugins/`
4. Commit generated `plugins/` to the repository

## Adding a New Collection

1. Create `collections/<id>.collection.yml` (see existing collections for
   format)
2. Run `npm run plugin:validate` to check the manifest
3. Run `npm run plugin:generate` to generate the plugin
4. Commit both the collection and generated plugin

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
