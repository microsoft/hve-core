# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

#Requires -Modules Pester

BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:collectionSchemaPath = Join-Path $script:repoRoot 'scripts/linting/schemas/collection-manifest.schema.json'
    $script:skillSchemaPath = Join-Path $script:repoRoot 'scripts/linting/schemas/skill-frontmatter.schema.json'
    $script:collectionSchema = Get-Content -Path $script:collectionSchemaPath -Raw | ConvertFrom-Json
    $script:skillSchema = Get-Content -Path $script:skillSchemaPath -Raw | ConvertFrom-Json
}

Describe 'collection-manifest schema accepts removed maturity' {
    It 'Includes removed in collection-level maturity enum' {
        $script:collectionSchema.properties.maturity.enum | Should -Contain 'removed'
    }

    It 'Includes removed in item-level maturity enum' {
        $script:collectionSchema.properties.items.items.properties.maturity.enum | Should -Contain 'removed'
    }
}

Describe 'skill-frontmatter schema accepts removed maturity' {
    It 'Includes removed in maturity enum' {
        $script:skillSchema.properties.maturity.enum | Should -Contain 'removed'
    }
}
