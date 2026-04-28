#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:SchemaPath = Resolve-Path (Join-Path $PSScriptRoot '../../linting/schemas/sustainability-state.schema.json')
    $script:FixtureDir = Resolve-Path (Join-Path $PSScriptRoot 'fixtures/sustainability-state')
    $script:DisclaimerPath = Resolve-Path (Join-Path $PSScriptRoot '../../../.github/instructions/shared/disclaimer-language.instructions.md')

    function Test-Fixture {
        param([Parameter(Mandatory)][string]$Name)
        $path = Join-Path $script:FixtureDir $Name
        $json = Get-Content -Path $path -Raw
        return Test-Json -Json $json -SchemaFile $script:SchemaPath -ErrorAction SilentlyContinue
    }

    function Get-SustainabilityDisclaimerHash {
        $content = Get-Content -Path $script:DisclaimerPath -Raw
        $content = $content -replace "`r`n", "`n"
        if ($content -notmatch '(?ms)^## Sustainability Planning\s*\n(.*?)(?=\n## )') {
            throw 'Sustainability Planning section not found in disclaimer file.'
        }
        $body = $matches[1].Trim()
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
        return ([System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
    }
}

Describe 'sustainability-state schema' -Tag 'Unit' {
    Context 'valid fixtures' {
        It 'accepts a minimal valid state' {
            Test-Fixture 'minimal-valid.json' | Should -BeTrue
        }
    }

    Context 'disclaimerShownAt' {
        It 'rejects a state missing disclaimerShownAt' {
            Test-Fixture 'invalid-missing-disclaimer.json' | Should -BeFalse
        }
    }

    Context 'phase enum' {
        It 'rejects an unknown phase value' {
            Test-Fixture 'invalid-unknown-phase.json' | Should -BeFalse
        }

        It 'accepts canonical phase value <_>' -ForEach @(
            '1.scoping',
            '2.workload-assessment',
            '3.standards-mapping',
            '4.gap-analysis',
            '5.backlog',
            '6.handoff'
        ) {
            $base = Get-Content -Path (Join-Path $script:FixtureDir 'minimal-valid.json') -Raw | ConvertFrom-Json
            $base.phase = $_
            $json = $base | ConvertTo-Json -Depth 20
            Test-Json -Json $json -SchemaFile $script:SchemaPath -ErrorAction SilentlyContinue | Should -BeTrue
        }
    }

    Context 'entryMode enum' {
        It 'rejects an unknown entryMode value' {
            Test-Fixture 'invalid-unknown-entrymode.json' | Should -BeFalse
        }
    }

    Context 'licenseRegister whitelist' {
        It 'rejects a license outside the whitelist' {
            Test-Fixture 'invalid-bad-license.json' | Should -BeFalse
        }
    }

    Context 'disclaimer drift guard' {
        It 'minimal-valid fixture disclaimerVersion matches Sustainability Planning section hash' {
            $expected = Get-SustainabilityDisclaimerHash
            $fixture = Get-Content -Path (Join-Path $script:FixtureDir 'minimal-valid.json') -Raw | ConvertFrom-Json
            $fixture.meta.disclaimerVersion | Should -Be $expected
        }
    }
}
