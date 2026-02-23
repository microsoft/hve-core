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
* PowerShell-Yaml module (`Install-Module PowerShell-Yaml`)

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
