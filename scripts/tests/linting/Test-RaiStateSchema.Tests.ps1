#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Validates the canonical RAI Planner state schema against the fixture corpus.
#>

# Enumerated at discovery time so -ForEach receives the fixture corpus before BeforeAll runs.
$script:fixturesDir = (Resolve-Path (Join-Path $PSScriptRoot '../fixtures/rai-state')).Path
$script:fixtureCases = Get-ChildItem -Path $script:fixturesDir -Filter '*.json' -File | ForEach-Object {
    @{ Name = $_.Name; Path = $_.FullName }
}
$script:invalidCases = @(
    @{
        Name = 'populated templates with null assessmentContentFile'
        Mutate = { param($State) $State.preflight.assessmentContentFile = $null }
    }
    @{
        Name = 'populated templates without assessmentContentFile'
        Mutate = { param($State) $State.preflight.PSObject.Properties.Remove('assessmentContentFile') }
    }
    @{
        Name = 'populated templates with an empty assessmentContentFile'
        Mutate = { param($State) $State.preflight.assessmentContentFile = '' }
    }
    @{
        Name = 'populated templates with a malformed assessmentContentFile'
        Mutate = { param($State) $State.preflight.assessmentContentFile = '../assessment-content.md' }
    }
    @{
        Name = 'empty templates with a non-null assessmentContentFile'
        Mutate = {
            param($State)
            $State.preflight.templates = @()
        }
    }
    @{
        Name = 'document template without path'
        Mutate = { param($State) $State.preflight.templates = @([pscustomobject]@{ kind = 'document'; stableIdMap = [pscustomobject]@{ 'A1/source' = 'RAI-A1-001' } }) }
    }
    @{
        Name = 'document template with an empty path'
        Mutate = { param($State) $State.preflight.templates = @([pscustomobject]@{ kind = 'document'; path = ''; stableIdMap = [pscustomobject]@{ 'A1/source' = 'RAI-A1-001' } }) }
    }
    @{
        Name = 'document template with traversal'
        Mutate = { param($State) $State.preflight.templates = @([pscustomobject]@{ kind = 'document'; path = '../template.md'; stableIdMap = [pscustomobject]@{ 'A1/source' = 'RAI-A1-001' } }) }
    }
    @{
        Name = 'document template with an absolute path'
        Mutate = { param($State) $State.preflight.templates = @([pscustomobject]@{ kind = 'document'; path = '/tmp/template.md'; stableIdMap = [pscustomobject]@{ 'A1/source' = 'RAI-A1-001' } }) }
    }
    @{
        Name = 'document template with a UNC path'
        Mutate = { param($State) $State.preflight.templates = @([pscustomobject]@{ kind = 'document'; path = '\\server\share\template.md'; stableIdMap = [pscustomobject]@{ 'A1/source' = 'RAI-A1-001' } }) }
    }
    @{
        Name = 'document template with a URI'
        Mutate = { param($State) $State.preflight.templates = @([pscustomobject]@{ kind = 'document'; path = 'https://example.test/template.md'; stableIdMap = [pscustomobject]@{ 'A1/source' = 'RAI-A1-001' } }) }
    }
    @{
        Name = 'document template with credential-bearing query data'
        Mutate = { param($State) $State.preflight.templates = @([pscustomobject]@{ kind = 'document'; path = 'templates/template.md?token=secret'; stableIdMap = [pscustomobject]@{ 'A1/source' = 'RAI-A1-001' } }) }
    }
    @{
        Name = 'Mural template with a URL'
        Mutate = { param($State) $State.preflight.templates = @([pscustomobject]@{ kind = 'mural'; id = 'https://app.mural.co/template'; stableIdMap = [pscustomobject]@{ 'A1/source' = 'RAI-A1-001' } }) }
    }
    @{
        Name = 'Mural template with credential-bearing query data'
        Mutate = { param($State) $State.preflight.templates = @([pscustomobject]@{ kind = 'mural'; id = 'template?token=secret'; stableIdMap = [pscustomobject]@{ 'A1/source' = 'RAI-A1-001' } }) }
    }
    @{
        Name = 'template with an unknown kind'
        Mutate = { param($State) $State.preflight.templates = @([pscustomobject]@{ kind = 'board'; id = 'template-id'; stableIdMap = [pscustomobject]@{ 'A1/source' = 'RAI-A1-001' } }) }
    }
    @{
        Name = 'template with a mismatched kind-specific field'
        Mutate = { param($State) $State.preflight.templates = @([pscustomobject]@{ kind = 'document'; id = 'template-id'; stableIdMap = [pscustomobject]@{ 'A1/source' = 'RAI-A1-001' } }) }
    }
    @{
        Name = 'template with an extra property'
        Mutate = { param($State) $State.preflight.templates = @([pscustomobject]@{ kind = 'document'; path = 'templates/template.md'; stableIdMap = [pscustomobject]@{ 'A1/source' = 'RAI-A1-001' }; token = 'secret' }) }
    }
    @{
        Name = 'template without stableIdMap'
        Mutate = { param($State) $State.preflight.templates[0].PSObject.Properties.Remove('stableIdMap') }
    }
    @{
        Name = 'template with an empty stableIdMap'
        Mutate = { param($State) $State.preflight.templates[0].stableIdMap = [pscustomobject]@{} }
    }
    @{
        Name = 'stableIdMap with an invalid source key'
        Mutate = { param($State) $State.preflight.templates[0].stableIdMap = [pscustomobject]@{ 'A1/source key' = 'RAI-A1-001' } }
    }
    @{
        Name = 'stableIdMap with a legacy document prefix'
        Mutate = { param($State) $State.preflight.templates[0].stableIdMap = [pscustomobject]@{ 'document:A1/source' = 'RAI-A1-001' } }
    }
    @{
        Name = 'stableIdMap with a legacy Mural prefix'
        Mutate = { param($State) $State.preflight.templates[0].stableIdMap = [pscustomobject]@{ 'mural:A1/source' = 'RAI-A1-001' } }
    }
    @{
        Name = 'stableIdMap with an invalid stable ID'
        Mutate = { param($State) $State.preflight.templates[0].stableIdMap = [pscustomobject]@{ 'A1/source' = 'invalid stable id' } }
    }
    @{
        Name = 'from-security-plan without securityPlanRef'
        Mutate = {
            param($State)
            $State.entryMode = 'from-security-plan'
            $State.PSObject.Properties.Remove('securityPlanRef')
        }
    }
    @{
        Name = 'from-security-plan with null securityPlanRef'
        Mutate = {
            param($State)
            $State.entryMode = 'from-security-plan'
            $State.securityPlanRef = $null
        }
    }
    @{
        Name = 'from-security-plan with an empty securityPlanRef'
        Mutate = {
            param($State)
            $State.entryMode = 'from-security-plan'
            $State.securityPlanRef = ''
        }
    }
    @{
        Name = 'from-security-plan with traversal in securityPlanRef'
        Mutate = {
            param($State)
            $State.entryMode = 'from-security-plan'
            $State.securityPlanRef = '../security-plan.md'
        }
    }
    @{
        Name = 'capture with a non-null securityPlanRef'
        Mutate = { param($State) $State.securityPlanRef = '.copilot-tracking/security-plans/example-project/security-plan.md' }
    }
    @{
        Name = 'from-prd with a non-null securityPlanRef'
        Mutate = {
            param($State)
            $State.entryMode = 'from-prd'
            $State.securityPlanRef = '.copilot-tracking/security-plans/example-project/security-plan.md'
        }
    }
)

BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:schemaPath = Join-Path $script:repoRoot 'scripts/linting/schemas/rai-state.schema.json'
    $script:schemaJson = Get-Content -Path $script:schemaPath -Raw
    $script:minimalFixturePath = Join-Path $script:repoRoot 'scripts/tests/fixtures/rai-state/phase-1-minimal.json'

    function New-RaiTestState {
        Get-Content -Path $script:minimalFixturePath -Raw | ConvertFrom-Json
    }

    function Set-ValidTemplatePreflight {
        param(
            [Parameter(Mandatory)]
            [pscustomobject]$State
        )

        $State.preflight.templates = @(
            [pscustomobject]@{
                kind = 'document'
                path = 'templates/template.md'
                stableIdMap = [pscustomobject]@{ 'A1/source' = 'RAI-A1-001' }
            }
        )
        $State.preflight.assessmentContentFile = '.copilot-tracking/rai-plans/example-project/assessment-content.md'
    }
}

Describe 'Canonical rai-state schema validates fixture corpus' -Tag 'Unit' {
    It 'Schema file parses as JSON' {
        { Get-Content -Path $script:schemaPath -Raw | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'Fixture <Name> validates against rai-state schema' -ForEach $script:fixtureCases {
        $fixtureJson = Get-Content -Path $Path -Raw
        { $fixtureJson | ConvertFrom-Json } | Should -Not -Throw
        $result = Test-Json -Json $fixtureJson -Schema $script:schemaJson -ErrorAction SilentlyContinue -ErrorVariable testErrors
        if (-not $result) {
            $detail = ($testErrors | ForEach-Object { $_.ToString() }) -join "; "
            throw "Fixture $Name failed schema validation: $detail"
        }
        $result | Should -BeTrue
    }

    It 'Accepts from-prd with a null securityPlanRef' {
        $State = New-RaiTestState
        $State.entryMode = 'from-prd'
        $Json = $State | ConvertTo-Json -Depth 100

        Test-Json -Json $Json -Schema $script:schemaJson -ErrorAction SilentlyContinue | Should -BeTrue
    }

    It 'Accepts from-security-plan with a state.json securityPlanRef' {
        $State = New-RaiTestState
        $State.entryMode = 'from-security-plan'
        $State.securityPlanRef = '.copilot-tracking/security-plans/example-project/state.json'
        $Json = $State | ConvertTo-Json -Depth 100

        Test-Json -Json $Json -Schema $script:schemaJson -ErrorAction SilentlyContinue | Should -BeTrue
    }

    It 'Accepts repeated source keys in distinct template maps' {
        $State = New-RaiTestState
        $State.preflight.templates = @(
            [pscustomobject]@{
                kind = 'document'
                path = 'templates/a.md'
                stableIdMap = [pscustomobject]@{ 'A1/source' = 'RAI-A1-001' }
            }
            [pscustomobject]@{
                kind = 'document'
                path = 'templates/b.md'
                stableIdMap = [pscustomobject]@{ 'A1/source' = 'RAI-A1-002' }
            }
        )
        $State.preflight.assessmentContentFile = '.copilot-tracking/rai-plans/example-project/assessment-content.md'
        $Json = $State | ConvertTo-Json -Depth 100

        Test-Json -Json $Json -Schema $script:schemaJson -ErrorAction SilentlyContinue | Should -BeTrue
    }

    It 'Rejects <Name>' -ForEach $script:invalidCases {
        $State = New-RaiTestState
        Set-ValidTemplatePreflight -State $State
        & $Mutate $State
        $Json = $State | ConvertTo-Json -Depth 100

        Test-Json -Json $Json -Schema $script:schemaJson -ErrorAction SilentlyContinue | Should -BeFalse
    }
}
