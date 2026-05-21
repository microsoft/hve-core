---
title: Collection Scripts
description: PowerShell tooling for validating collection manifests and shared collection helpers
---

PowerShell tooling for validating collection manifests and shared collection
helper functions used by both collection validation and plugin generation.

## Scripts

| Script                         | npm Command                         | Description                                       |
|--------------------------------|-------------------------------------|---------------------------------------------------|
| Validate-Collections.ps1       | `npm run lint:collections-metadata` | Validate collection manifests                     |
| Modules/CollectionHelpers.psm1 | (library)                           | YAML parsing, frontmatter, and collection helpers |

## Prerequisites

* PowerShell 7.0+
* PowerShell-Yaml module (`Install-Module -Name PowerShell-Yaml -RequiredVersion 0.4.7`)

## Validate-Collections.ps1

Validates collection manifests and writes a structured JSON report after each
run.

### Parameters

* `-OutputPath` (string) - Path where the JSON result file is written (default:
  `logs/collection-validation-results.json`)

### JSON output

The report contains:

* `Timestamp` - UTC timestamp for the validation run
* `TotalCollections` - Number of collection manifests validated
* `ErrorCount` - Number of validation errors
* `Results` - Per-collection validation messages with `Collection`, `Severity`,
  `ErrorType`, and `Message` fields

### Examples

```powershell
./scripts/collections/Validate-Collections.ps1
./scripts/collections/Validate-Collections.ps1 -OutputPath custom/results.json
```

## Adding a New Collection

1. Create `collections/<id>.collection.yml` (see existing collections for
   format)
2. Run `npm run lint:collections-metadata` to check the manifest
3. Run `npm run plugin:generate` to generate the plugin
4. Commit both the collection and generated plugin

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
