#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Validates the canonical SSSC Planner state schema against the fixture corpus.
#>

# Enumerated at discovery time so -ForEach receives the fixture corpus before BeforeAll runs.
$script:fixturesDir = (Resolve-Path (Join-Path $PSScriptRoot '../fixtures/sssc-state')).Path
$script:fixtureCases = Get-ChildItem -Path $script:fixturesDir -Filter '*.json' -File | ForEach-Object {
    @{ Name = $_.Name; Path = $_.FullName }
}

BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:schemaPath = Join-Path $script:repoRoot 'scripts/linting/schemas/sssc-state.schema.json'
    $script:schemaJson = Get-Content -Path $script:schemaPath -Raw
}

Describe 'Canonical sssc-state schema validates fixture corpus' -Tag 'Unit' {
    It 'Schema file parses as JSON' {
        { Get-Content -Path $script:schemaPath -Raw | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'Fixture <Name> validates against sssc-state schema' -ForEach $script:fixtureCases {
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
