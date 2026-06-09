#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Validates `disclaimerShownAt` schema field shape across both inline planner state schemas.
.DESCRIPTION
    For each identity file (security/identity, security/sssc-identity), the inline JSON-literal
    schema block must declare `disclaimerShownAt` with default `null` and the canonical state
    schemas must declare type `["string","null"]`, format `date-time`, and keep the key in
    `required` for cross-planner uniformity (see plan DD-06/ID-02).
.NOTES
    Effective case count: 4 (2 inline-default + 2 canonical-schema), not parametrized; each
    identity / schema pair is asserted in its own `It` block by design.
#>

BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path

    function Get-InlineStateJson {
        param([string]$Path)
        $content = Get-Content -Path $Path -Raw
        if ($content -notmatch '(?s)```json\s*\r?\n(\{.*?\})\s*\r?\n```') {
            throw "No ```json block found in $Path"
        }
        return $Matches[1] | ConvertFrom-Json
    }

    $script:secIdentity = Join-Path $script:repoRoot '.github/instructions/security/identity.instructions.md'
    $script:ssscIdentity = Join-Path $script:repoRoot '.github/instructions/security/sssc-identity.instructions.md'
    $script:secSchema = Join-Path $script:repoRoot 'scripts/linting/schemas/security-state.schema.json'
    $script:raiSchema = Join-Path $script:repoRoot 'scripts/linting/schemas/rai-state.schema.json'
}

Describe 'Planner state inline JSON-literal defaults' {
    It 'Security identity inline state includes disclaimerShownAt default null' {
        $state = Get-InlineStateJson -Path $script:secIdentity
        $state.PSObject.Properties.Name | Should -Contain 'disclaimerShownAt'
        $state.disclaimerShownAt | Should -BeNullOrEmpty
    }

    It 'SSSC identity inline state includes disclaimerShownAt default null' {
        $state = Get-InlineStateJson -Path $script:ssscIdentity
        $state.PSObject.Properties.Name | Should -Contain 'disclaimerShownAt'
        $state.disclaimerShownAt | Should -BeNullOrEmpty
    }
}

Describe 'Canonical state schemas declare disclaimerShownAt with nullable string + date-time format' {
    It 'security-state.schema.json declares disclaimerShownAt correctly' {
        $schema = Get-Content -Path $script:secSchema -Raw | ConvertFrom-Json
        $prop = $schema.properties.disclaimerShownAt
        $prop | Should -Not -BeNullOrEmpty
        $prop.type | Should -Be @('string','null')
        $prop.format | Should -Be 'date-time'
        $schema.required | Should -Contain 'disclaimerShownAt'
    }

    It 'rai-state.schema.json declares disclaimerShownAt correctly' {
        $schema = Get-Content -Path $script:raiSchema -Raw | ConvertFrom-Json
        $prop = $schema.properties.disclaimerShownAt
        $prop | Should -Not -BeNullOrEmpty
        $prop.type | Should -Be @('string','null')
        $prop.format | Should -Be 'date-time'
        $schema.required | Should -Contain 'disclaimerShownAt'
    }
}
