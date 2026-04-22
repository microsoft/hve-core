#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:SchemaDir = Resolve-Path (Join-Path $PSScriptRoot '../../linting/schemas')
    $script:OriginalSchemaPath = Join-Path $script:SchemaDir 'sssc-state.schema.json'
    $script:RaiSchemaPath = Join-Path $script:SchemaDir 'rai-state.schema.json'

    # PowerShell's Test-Json cannot resolve $ref to a sibling schema file.
    # Inline the riskClassification $def from rai-state.schema.json so we can
    # exercise the rest of the SSSC state schema with Test-Json.
    $script:SchemaObject = Get-Content -Path $script:OriginalSchemaPath -Raw |
        ConvertFrom-Json -AsHashtable
    $script:RaiObject = Get-Content -Path $script:RaiSchemaPath -Raw |
        ConvertFrom-Json -AsHashtable

    $script:SchemaObject.properties.riskClassification = $script:RaiObject['$defs'].riskClassification
    # The riskClassification $def itself contains $ref entries to sibling defs
    # (framework, riskIndicator). After merge those refs resolve against the
    # SSSC schema, so copy each transitively required def into $defs.
    foreach ($defName in @('framework', 'riskIndicator')) {
        if (-not $script:SchemaObject['$defs'].Contains($defName)) {
            $script:SchemaObject['$defs'][$defName] = $script:RaiObject['$defs'][$defName]
        }
    }

    $script:MergedSchemaPath = Join-Path $TestDrive 'sssc-state.merged.schema.json'
    $script:SchemaObject | ConvertTo-Json -Depth 32 |
        Set-Content -Path $script:MergedSchemaPath -Encoding utf8NoBOM

    function New-Indicator {
        return @{
            method      = 'binary'
            nistSource  = @('GOVERN-1.1')
            activated   = $false
            observation = $null
            result      = $null
        }
    }

    function New-ValidState {
        return @{
            projectSlug         = 'demo-project'
            ssscPlanFile        = 'sssc-plan.instructions.md'
            phase               = 'scoping'
            frameworks          = @()
            capabilityInventory = @()
            gates               = @()
            riskClassification  = @{
                framework          = @{
                    id                       = 'nist-ai-rmf'
                    name                     = 'NIST AI RMF'
                    version                  = '1.0'
                    source                   = 'https://example.com'
                    replaceDefaultIndicators = $false
                    replaceDefaultFramework  = $false
                }
                indicators         = @{
                    safety_reliability      = (New-Indicator)
                    rights_fairness_privacy = (New-Indicator)
                    security_explainability = (New-Indicator)
                }
                activatedCount     = 0
                riskScore          = $null
                suggestedDepthTier = 'basic'
            }
            skillsLoaded        = @()
        }
    }

    function Test-State {
        param([Parameter(Mandatory)][hashtable]$State)
        $json = $State | ConvertTo-Json -Depth 20
        return Test-Json -Json $json -SchemaFile $script:MergedSchemaPath -ErrorAction SilentlyContinue
    }
}

Describe 'sssc-state schema' -Tag 'Unit' {
    Context 'required properties' {
        It 'accepts a minimally valid state' {
            Test-State (New-ValidState) | Should -BeTrue
        }

        It 'rejects state missing the phase property' {
            $state = New-ValidState
            $state.Remove('phase')
            Test-State $state | Should -BeFalse
        }

        It 'rejects state missing the skillsLoaded property' {
            $state = New-ValidState
            $state.Remove('skillsLoaded')
            Test-State $state | Should -BeFalse
        }

        It 'rejects state missing the riskClassification property' {
            $state = New-ValidState
            $state.Remove('riskClassification')
            Test-State $state | Should -BeFalse
        }
    }

    Context 'phase enum' {
        It 'accepts each defined phase value' {
            foreach ($phase in @('scoping', 'assessment', 'standards-mapping', 'gap-analysis', 'backlog-generation', 'handoff')) {
                $state = New-ValidState
                $state.phase = $phase
                Test-State $state | Should -BeTrue -Because "phase '$phase' is in the enum"
            }
        }

        It 'rejects an unknown phase value' {
            $state = New-ValidState
            $state.phase = 'invalid-phase'
            Test-State $state | Should -BeFalse
        }
    }

    Context 'riskClassification $ref' {
        It 'declares the cross-file $ref to rai-state.schema.json' {
            $raw = Get-Content -Path $script:OriginalSchemaPath -Raw | ConvertFrom-Json -AsHashtable
            $raw.properties.riskClassification['$ref'] |
                Should -Be 'rai-state.schema.json#/$defs/riskClassification'
        }

        It 'resolves to a riskClassification definition in rai-state.schema.json' {
            $script:RaiObject['$defs'].ContainsKey('riskClassification') | Should -BeTrue
        }

        It 'rejects state with a riskClassification missing required indicators' {
            $state = New-ValidState
            $state.riskClassification.indicators.Remove('safety_reliability')
            Test-State $state | Should -BeFalse
        }

        It 'rejects state with an unknown suggestedDepthTier' {
            $state = New-ValidState
            $state.riskClassification.suggestedDepthTier = 'extreme'
            Test-State $state | Should -BeFalse
        }
    }

    Context 'gate default' {
        It 'declares "pending" as the default gate status' {
            $script:SchemaObject['$defs'].gateResult.properties.status.default | Should -Be 'pending'
        }

        It 'accepts a gate with status "pending"' {
            $state = New-ValidState
            $state.gates = @(@{ id = 'gate-a'; status = 'pending' })
            Test-State $state | Should -BeTrue
        }

        It 'rejects a gate with an unknown status' {
            $state = New-ValidState
            $state.gates = @(@{ id = 'gate-a'; status = 'in-progress' })
            Test-State $state | Should -BeFalse
        }
    }
}
