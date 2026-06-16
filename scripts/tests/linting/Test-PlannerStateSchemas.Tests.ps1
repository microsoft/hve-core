#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Validates planner notice state schema fields across inline and canonical planner state schemas.
.DESCRIPTION
    For each identity file with inline defaults, the JSON-literal schema block must declare
    `disclaimerShownAt` with default `null` and `noticeLog` as an empty array. Canonical state
    schemas must declare `noticeLog` as an array of typed notice entries and keep it in required
    where the planner has a required disclaimer timestamp.
.NOTES
    Each identity / schema pair is asserted in its own `It` block by design.
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
    $script:ssscIdentity = Join-Path $script:repoRoot '.github/instructions/security/sssc-planner.instructions.md'
    $script:secSchema = Join-Path $script:repoRoot 'scripts/linting/schemas/security-state.schema.json'
    $script:raiSchema = Join-Path $script:repoRoot 'scripts/linting/schemas/rai-state.schema.json'
    $script:ssscSchema = Join-Path $script:repoRoot 'scripts/linting/schemas/sssc-state.schema.json'
    $script:accessibilitySchema = Join-Path $script:repoRoot 'scripts/linting/schemas/accessibility-state.schema.json'

    function Assert-NoticeLogSchema {
        param([object]$Schema)

        $prop = $Schema.properties.noticeLog
        $prop | Should -Not -BeNullOrEmpty
        $prop.type | Should -Be 'array'
        $prop.items.'$ref' | Should -Be '#/$defs/noticeLogEntry'

        $entry = $Schema.'$defs'.noticeLogEntry
        $entry | Should -Not -BeNullOrEmpty
        $entry.required | Should -Contain 'noticeType'
        $entry.required | Should -Contain 'shownAt'
        $entry.required | Should -Contain 'source'
        $entry.properties.noticeType.enum | Should -Contain 'session-start-disclaimer'
        $entry.properties.noticeType.enum | Should -Contain 'framework-attribution'
        $entry.properties.noticeType.enum | Should -Contain 'handoff-disclaimer'
        $entry.properties.noticeType.enum | Should -Contain 'professional-review-reminder'
        $entry.properties.shownAt.format | Should -Be 'date-time'
        $entry.properties.source.minLength | Should -Be 1
    }
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

    It 'Security identity inline state includes noticeLog default empty array' {
        $state = Get-InlineStateJson -Path $script:secIdentity
        $state.PSObject.Properties.Name | Should -Contain 'noticeLog'
        @($state.noticeLog).Count | Should -Be 0
    }

    It 'SSSC identity inline state includes noticeLog default empty array' {
        $state = Get-InlineStateJson -Path $script:ssscIdentity
        $state.PSObject.Properties.Name | Should -Contain 'noticeLog'
        @($state.noticeLog).Count | Should -Be 0
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

Describe 'Canonical state schemas declare noticeLog audit entries' {
    It 'security-state.schema.json declares noticeLog correctly' {
        $schema = Get-Content -Path $script:secSchema -Raw | ConvertFrom-Json
        Assert-NoticeLogSchema -Schema $schema
        $schema.required | Should -Contain 'noticeLog'
    }

    It 'rai-state.schema.json declares noticeLog correctly' {
        $schema = Get-Content -Path $script:raiSchema -Raw | ConvertFrom-Json
        Assert-NoticeLogSchema -Schema $schema
        $schema.required | Should -Contain 'noticeLog'
    }

    It 'sssc-state.schema.json declares noticeLog correctly' {
        $schema = Get-Content -Path $script:ssscSchema -Raw | ConvertFrom-Json
        Assert-NoticeLogSchema -Schema $schema
        $schema.required | Should -Contain 'noticeLog'
    }

    It 'accessibility-state.schema.json declares noticeLog correctly' {
        $schema = Get-Content -Path $script:accessibilitySchema -Raw | ConvertFrom-Json
        Assert-NoticeLogSchema -Schema $schema
        $schema.required | Should -Contain 'noticeLog'
    }
}

Describe 'Cross-schema parity for noticeLog audit entries' -Tag 'Unit' {
    It 'sssc-state and rai-state declare byte-identical noticeLog definitions' {
        $sssc = Get-Content -Path $script:ssscSchema -Raw | ConvertFrom-Json
        $rai = Get-Content -Path $script:raiSchema -Raw | ConvertFrom-Json
        $ssscProp = $sssc.properties.noticeLog | ConvertTo-Json -Depth 10 -Compress
        $raiProp = $rai.properties.noticeLog | ConvertTo-Json -Depth 10 -Compress
        $ssscProp | Should -Be $raiProp -Because 'sssc-state noticeLog definitions must remain in lockstep with rai-state'
    }

    It 'accessibility-state and rai-state declare byte-identical noticeLog definitions' {
        $accessibility = Get-Content -Path $script:accessibilitySchema -Raw | ConvertFrom-Json
        $rai = Get-Content -Path $script:raiSchema -Raw | ConvertFrom-Json
        $accessibilityProp = $accessibility.properties.noticeLog | ConvertTo-Json -Depth 10 -Compress
        $raiProp = $rai.properties.noticeLog | ConvertTo-Json -Depth 10 -Compress
        $accessibilityProp | Should -Be $raiProp -Because 'accessibility-state noticeLog definitions must remain in lockstep with rai-state'
    }

    It 'sssc-state and rai-state declare byte-identical noticeLogEntry definitions' {
        $sssc = Get-Content -Path $script:ssscSchema -Raw | ConvertFrom-Json
        $rai = Get-Content -Path $script:raiSchema -Raw | ConvertFrom-Json
        $ssscDef = $sssc.'$defs'.noticeLogEntry | ConvertTo-Json -Depth 10 -Compress
        $raiDef = $rai.'$defs'.noticeLogEntry | ConvertTo-Json -Depth 10 -Compress
        $ssscDef | Should -Be $raiDef -Because 'sssc-state noticeLogEntry definitions must remain in lockstep with rai-state'
    }

    It 'accessibility-state and rai-state declare byte-identical noticeLogEntry definitions' {
        $accessibility = Get-Content -Path $script:accessibilitySchema -Raw | ConvertFrom-Json
        $rai = Get-Content -Path $script:raiSchema -Raw | ConvertFrom-Json
        $accessibilityDef = $accessibility.'$defs'.noticeLogEntry | ConvertTo-Json -Depth 10 -Compress
        $raiDef = $rai.'$defs'.noticeLogEntry | ConvertTo-Json -Depth 10 -Compress
        $accessibilityDef | Should -Be $raiDef -Because 'accessibility-state noticeLogEntry definitions must remain in lockstep with rai-state'
    }
}
