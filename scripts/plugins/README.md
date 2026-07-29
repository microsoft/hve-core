---
title: Plugin Generation Scripts
description: PowerShell tooling for generating Copilot CLI plugins from collection manifests
---

PowerShell tooling for generating Copilot CLI plugins from collection
manifests.

## Scripts

| Script                     | npm Command                | Description                                  |
|----------------------------|----------------------------|----------------------------------------------|
| Generate-Plugins.ps1       | `npm run plugin:generate`  | Generate plugin directories from collections |
| Validate-Marketplace.ps1   | `npm run lint:marketplace` | Validate marketplace.json plugin manifest    |
| Modules/PluginHelpers.psm1 | (library)                  | Plugin symlink, manifest, and packaging      |

## Prerequisites

* PowerShell 7.0+
* PowerShell-Yaml module (`Install-Module -Name PowerShell-Yaml -RequiredVersion 0.4.7`)

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

## Marketplace Validation

`Validate-Marketplace.ps1` validates `.github/plugin/marketplace.json` against
its JSON schema and checks plugin source directory existence, name-source
consistency, version alignment with the root `package.json`, and absence of
path separators in source values.

```bash
npm run lint:marketplace
```

Parameters:

* `-OutputPath` (default: `logs/marketplace-validation-results.json`): path
  for the structured JSON report, absolute or relative to the repository root

The script writes structured JSON results to `logs/`, consistent with the rest
of the linting pipeline. Pass `-OutputPath ''` to suppress the report file.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
