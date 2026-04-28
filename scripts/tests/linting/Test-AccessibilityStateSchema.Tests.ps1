#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:SchemaPath = Resolve-Path (Join-Path $PSScriptRoot '../../linting/schemas/accessibility-state.schema.json')
    $script:FixtureDir = Resolve-Path (Join-Path $PSScriptRoot 'fixtures/accessibility-state')

    function Test-Fixture {
        param([Parameter(Mandatory)][string]$Name)
        $path = Join-Path $script:FixtureDir $Name
        $json = Get-Content -Path $path -Raw
        return Test-Json -Json $json -SchemaFile $script:SchemaPath -ErrorAction SilentlyContinue
    }
}

Describe 'accessibility-state schema' -Tag 'Unit' {
    Context 'valid fixtures' {
        It 'accepts a minimal valid state' {
            Test-Fixture 'minimal-valid.json' | Should -BeTrue
        }

        It 'accepts a full valid state with all six phase blocks populated' {
            Test-Fixture 'full-valid.json' | Should -BeTrue
        }
    }

    Context 'atomic disabled-framework rule' {
        It 'rejects a disabled framework that omits disabledReason' {
            Test-Fixture 'invalid-disabled-missing-reason.json' | Should -BeFalse
        }

        It 'rejects a disabled framework that omits disabledAtPhase' {
            Test-Fixture 'invalid-disabled-missing-phase.json' | Should -BeFalse
        }
    }

    Context 'currentPhase enum' {
        It 'rejects an unknown currentPhase value' {
            Test-Fixture 'invalid-unknown-phase.json' | Should -BeFalse
        }
    }

    Context 'disclaimerShownAt' {
        It 'rejects a state missing disclaimerShownAt' {
            Test-Fixture 'invalid-missing-disclaimer.json' | Should -BeFalse
        }

        It 'rejects a state whose disclaimerShownAt is not ISO-8601 date-time' {
            Test-Fixture 'invalid-disclaimer-format.json' | Should -BeFalse
        }
    }
}
