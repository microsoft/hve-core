#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Validates the canonical Security Planner state schema against the fixture corpus
    and asserts cross-schema parity for `disclaimerShownAt` against the sister RAI schema.
#>

# Enumerated at discovery time so -ForEach receives the fixture corpus before BeforeAll runs.
$script:fixturesDir = (Resolve-Path (Join-Path $PSScriptRoot '../fixtures/security-state')).Path
$script:fixtureCases = Get-ChildItem -Path $script:fixturesDir -Filter '*.json' -File | ForEach-Object {
    @{ Name = $_.Name; Path = $_.FullName }
}

BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:schemaPath = Join-Path $script:repoRoot 'scripts/linting/schemas/security-state.schema.json'
    $script:raiSchemaPath = Join-Path $script:repoRoot 'scripts/linting/schemas/rai-state.schema.json'

    $script:schemaJson = Get-Content -Path $script:schemaPath -Raw
}

Describe 'Canonical security-state schema validates fixture corpus' {
    It 'Schema file parses as JSON' {
        { Get-Content -Path $script:schemaPath -Raw | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'Fixture <Name> validates against security-state schema' -ForEach $script:fixtureCases {
        $fixtureJson = Get-Content -Path $Path -Raw
        { $fixtureJson | ConvertFrom-Json } | Should -Not -Throw
        $result = Test-Json -Json $fixtureJson -Schema $script:schemaJson -ErrorAction SilentlyContinue -ErrorVariable testErrors
        if (-not $result) {
            $detail = ($testErrors | ForEach-Object { $_.ToString() }) -join "; "
            throw "Fixture $Name failed schema validation: $detail"
        }
        $result | Should -BeTrue
    }
}

Describe 'Cross-schema parity for disclaimerShownAt' {
    It 'security-state and rai-state declare structurally identical disclaimerShownAt definitions' {
        $sec = Get-Content -Path $script:schemaPath -Raw | ConvertFrom-Json
        $rai = Get-Content -Path $script:raiSchemaPath -Raw | ConvertFrom-Json
        $secProp = $sec.properties.disclaimerShownAt | ConvertTo-Json -Depth 10 -Compress
        $raiProp = $rai.properties.disclaimerShownAt | ConvertTo-Json -Depth 10 -Compress
        $secProp | Should -Be $raiProp -Because 'disclaimerShownAt definitions must remain in lockstep across schemas'
    }
}

Describe 'RAI-disabled invariant' {
    It 'rejects a disabled state with inconsistent RAI fields' {
        $fixturePath = Join-Path $script:repoRoot 'scripts/tests/fixtures/security-state/phase-1-minimal.json'
        $base = Get-Content -Path $fixturePath -Raw | ConvertFrom-Json
        $base.raiScope = 'embedded'
        $base.raiTier = 'standard'
        $base.aiComponents = @('stray-component')
        $invalidJson = $base | ConvertTo-Json -Depth 10
        $result = Test-Json -Json $invalidJson -Schema $script:schemaJson -ErrorAction SilentlyContinue
        $result | Should -BeFalse -Because 'raiEnabled=false must force raiScope/raiTier to none, no dispatch, and no AI components'
    }
}
