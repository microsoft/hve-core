#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:SchemaPath = Resolve-Path (Join-Path $PSScriptRoot '../../linting/schemas/planner-framework-control.schema.json')
    $script:SchemaJson = Get-Content -Path $script:SchemaPath -Raw
    $script:SchemaObject = $script:SchemaJson | ConvertFrom-Json -AsHashtable

    function Test-Bundle {
        param([Parameter(Mandatory)][hashtable]$Bundle)
        $json = $Bundle | ConvertTo-Json -Depth 20
        return Test-Json -Json $json -SchemaFile $script:SchemaPath -ErrorAction SilentlyContinue
    }

    function New-ValidBundle {
        return @{
            id       = 'test-fw'
            version  = '1.0.0'
            name     = 'Test Framework'
            controls = @(
                @{
                    id               = 'ctl-1'
                    title            = 'Control One'
                    assessmentMethod = 'binary'
                    risk             = 'low'
                }
            )
        }
    }
}

Describe 'planner-framework-control schema' -Tag 'Unit' {
    Context 'baseline' {
        It 'accepts a minimally valid bundle' {
            Test-Bundle (New-ValidBundle) | Should -BeTrue
        }
    }

    Context 'RI-1: assessmentMethod is a closed enum' {
        It 'rejects assessmentMethod "scored"' {
            $bundle = New-ValidBundle
            $bundle.controls[0].assessmentMethod = 'scored'
            Test-Bundle $bundle | Should -BeFalse
        }

        It 'accepts assessmentMethod "categorical" when categories supplied' {
            $bundle = New-ValidBundle
            $bundle.controls[0].assessmentMethod = 'categorical'
            $bundle.controls[0].categories = @('alpha', 'beta')
            Test-Bundle $bundle | Should -BeTrue
        }

        It 'accepts assessmentMethod "continuous" when scoreRange supplied' {
            $bundle = New-ValidBundle
            $bundle.controls[0].assessmentMethod = 'continuous'
            $bundle.controls[0].scoreRange = @{ min = 0; max = 10 }
            Test-Bundle $bundle | Should -BeTrue
        }

        It 'rejects categorical without categories' {
            $bundle = New-ValidBundle
            $bundle.controls[0].assessmentMethod = 'categorical'
            Test-Bundle $bundle | Should -BeFalse
        }

        It 'rejects continuous without scoreRange' {
            $bundle = New-ValidBundle
            $bundle.controls[0].assessmentMethod = 'continuous'
            Test-Bundle $bundle | Should -BeFalse
        }
    }

    Context 'RI-2: gates default to "pending"' {
        It 'accepts gate with default "pending"' {
            $bundle = New-ValidBundle
            $bundle.controls[0].gates = @(@{ id = 'gate-a'; default = 'pending' })
            Test-Bundle $bundle | Should -BeTrue
        }

        It 'rejects gate with default "passed"' {
            $bundle = New-ValidBundle
            $bundle.controls[0].gates = @(@{ id = 'gate-a'; default = 'passed' })
            Test-Bundle $bundle | Should -BeFalse
        }

        It 'rejects gate with default "failed"' {
            $bundle = New-ValidBundle
            $bundle.controls[0].gates = @(@{ id = 'gate-a'; default = 'failed' })
            Test-Bundle $bundle | Should -BeFalse
        }
    }

    Context 'RI-3: schema $id is a URL' {
        It 'declares $id at the top level' {
            $script:SchemaObject['$id'] | Should -Not -BeNullOrEmpty
        }

        It 'declares $id as an http(s) URL' {
            $script:SchemaObject['$id'] | Should -Match '^https?://'
        }
    }

    Context 'RI-4: evidenceHints are paths or globs (no prose)' {
        It 'accepts a path-like evidence hint' {
            $bundle = New-ValidBundle
            $bundle.controls[0].evidenceHints = @('src/**/*.ps1', '.github/workflows/ci.yml')
            Test-Bundle $bundle | Should -BeTrue
        }

        It 'rejects a prose evidence hint with spaces' {
            $bundle = New-ValidBundle
            $bundle.controls[0].evidenceHints = @('See policy document for details.')
            Test-Bundle $bundle | Should -BeFalse
        }
    }

    Context 'RI-5: identifiers are lower-kebab' {
        It 'rejects bundle id with mixed case' {
            $bundle = New-ValidBundle
            $bundle.id = 'Test-FW'
            Test-Bundle $bundle | Should -BeFalse
        }

        It 'rejects categorical category with mixed case' {
            $bundle = New-ValidBundle
            $bundle.controls[0].assessmentMethod = 'categorical'
            $bundle.controls[0].categories = @('Mixed-Case', 'beta')
            Test-Bundle $bundle | Should -BeFalse
        }

        It 'requires at least two categorical categories' {
            $bundle = New-ValidBundle
            $bundle.controls[0].assessmentMethod = 'categorical'
            $bundle.controls[0].categories = @('alpha')
            Test-Bundle $bundle | Should -BeFalse
        }
    }
}
