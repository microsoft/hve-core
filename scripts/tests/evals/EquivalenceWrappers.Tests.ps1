#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:DashboardScript = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../evals/New-EquivalenceDashboard.ps1')).Path
    $script:DriverScript    = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../evals/Invoke-BaselineEquivalence.ps1')).Path
    $script:FixturesRoot    = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'fixtures/equivalence')).Path

    function script:Initialize-DashboardFixture {
        param(
            [Parameter(Mandatory)][string]$RepoRoot,
            [Parameter(Mandatory)][string]$Model,
            [Parameter(Mandatory)][string]$RunId
        )

        $resultsRoot = Join-Path $RepoRoot 'evals/results/baseline-equivalence'
        $runRoot = Join-Path $resultsRoot "$Model/$RunId"
        $baselineDir = Join-Path $runRoot 'baseline'
        $customizedDir = Join-Path $runRoot 'customized'
        New-Item -ItemType Directory -Path $baselineDir -Force | Out-Null
        New-Item -ItemType Directory -Path $customizedDir -Force | Out-Null

        Copy-Item -LiteralPath (Join-Path $script:FixturesRoot 'baseline/20260101T000000000Z/results.jsonl') `
            -Destination (Join-Path $baselineDir 'results.jsonl') -Force
        Copy-Item -LiteralPath (Join-Path $script:FixturesRoot 'customized/20260101T000000000Z/results.jsonl') `
            -Destination (Join-Path $customizedDir 'results.jsonl') -Force

        return $resultsRoot
    }
}

Describe 'New-EquivalenceDashboard.ps1' -Tag 'Unit' {
    It 'Declares -Agent as a mandatory string parameter' {
        $cmd = Get-Command -Name $script:DashboardScript
        $param = $cmd.Parameters['Agent']
        $param | Should -Not -BeNullOrEmpty
        $param.ParameterType | Should -Be ([string])
        $param.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -Contain $true
    }

    Context 'Applied artifact wiring' {
        BeforeAll {
            $script:RepoRoot = Join-Path $TestDrive 'dashboard-repo'
            $script:Model = 'unit-model'
            $script:RunId = 'unit-run'
            $script:ResultsRoot = Initialize-DashboardFixture -RepoRoot $script:RepoRoot -Model $script:Model -RunId $script:RunId

            $script:Workspace = Join-Path $script:RepoRoot 'evals/baseline-equivalence/customized/workspace'
            New-Item -ItemType Directory -Path (Join-Path $script:Workspace '.github/agents') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $script:Workspace '.github/agents/foo.agent.md') -Value 'seed' -Encoding utf8NoBOM

            $script:OutPath = Join-Path $TestDrive 'dashboard.html'
            & $script:DashboardScript `
                -RunId $script:RunId `
                -Model $script:Model `
                -Agent 'task-researcher' `
                -RepoRoot $script:RepoRoot `
                -ResultsRoot $script:ResultsRoot `
                -OutPath $script:OutPath *> $null
            $script:Html = Get-Content -LiteralPath $script:OutPath -Raw
        }

        It 'Writes the HTML output to the requested path' {
            Test-Path -LiteralPath $script:OutPath | Should -BeTrue
        }

        It 'Renders the seeded workspace artifact in the applied list' {
            $script:Html | Should -Match '<li>\.github/agents/foo\.agent\.md</li>'
        }
    }

    Context 'Empty workspace falls back to no applied artifacts' {
        BeforeAll {
            $script:RepoRoot2 = Join-Path $TestDrive 'dashboard-repo-empty'
            $script:ResultsRoot2 = Initialize-DashboardFixture -RepoRoot $script:RepoRoot2 -Model 'unit-model' -RunId 'unit-run'

            # No workspace directory at all.
            $script:OutPath2 = Join-Path $TestDrive 'dashboard-empty.html'
            & $script:DashboardScript `
                -RunId 'unit-run' `
                -Model 'unit-model' `
                -Agent 'task-researcher' `
                -RepoRoot $script:RepoRoot2 `
                -ResultsRoot $script:ResultsRoot2 `
                -OutPath $script:OutPath2 *> $null
            $script:Html2 = Get-Content -LiteralPath $script:OutPath2 -Raw
        }

        It 'Renders the applied list with a (none) placeholder when no artifacts exist' {
            $script:Html2 | Should -Match '<li><em>\(none\)</em></li>'
        }
    }
}

Describe 'Invoke-BaselineEquivalence.ps1' -Tag 'Unit' {
    Context 'Applied artifact wiring (workspace present)' {
        BeforeAll {
            $script:DriverRepo = Join-Path $TestDrive 'driver-repo'
            $script:Workspace = Join-Path $script:DriverRepo 'evals/baseline-equivalence/customized/workspace'
            New-Item -ItemType Directory -Path (Join-Path $script:Workspace '.github/agents') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $script:Workspace '.github/agents/bar.agent.md') -Value 'seed' -Encoding utf8NoBOM

            $signatureDir = Join-Path $script:DriverRepo 'evals/baseline-equivalence/surface-signatures'
            New-Item -ItemType Directory -Path $signatureDir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $signatureDir 'task-researcher.yml') -Value "description: stub`n" -Encoding utf8NoBOM
            $compareSpecPath = Join-Path $script:DriverRepo 'evals/baseline-equivalence/compare.eval.yml'
            Set-Content -LiteralPath $compareSpecPath -Value "surface_signatures: {}`n" -Encoding utf8NoBOM

            $script:SummaryPath = Join-Path $TestDrive 'driver-summary.json'
            & $script:DriverScript `
                -Agent 'task-researcher' `
                -Tier 'pr' `
                -RepoRoot $script:DriverRepo `
                -OutputPath $script:SummaryPath `
                -WhatIf *> $null
            $script:Summary = Get-Content -LiteralPath $script:SummaryPath -Raw | ConvertFrom-Json
        }

        It 'Writes the summary JSON' {
            Test-Path -LiteralPath $script:SummaryPath | Should -BeTrue
        }

        It 'Populates variants.b.applied with the seeded artifact' {
            $script:Summary.variants.b.applied | Should -Contain '.github/agents/bar.agent.md'
        }
    }

    Context 'Applied artifact wiring (workspace absent)' {
        BeforeAll {
            $script:DriverRepoEmpty = Join-Path $TestDrive 'driver-repo-empty'
            New-Item -ItemType Directory -Path $script:DriverRepoEmpty -Force | Out-Null

            $signatureDirEmpty = Join-Path $script:DriverRepoEmpty 'evals/baseline-equivalence/surface-signatures'
            New-Item -ItemType Directory -Path $signatureDirEmpty -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $signatureDirEmpty 'task-researcher.yml') -Value "description: stub`n" -Encoding utf8NoBOM
            $compareSpecPathEmpty = Join-Path $script:DriverRepoEmpty 'evals/baseline-equivalence/compare.eval.yml'
            New-Item -ItemType Directory -Path (Split-Path -Parent $compareSpecPathEmpty) -Force | Out-Null
            Set-Content -LiteralPath $compareSpecPathEmpty -Value "surface_signatures: {}`n" -Encoding utf8NoBOM

            $script:SummaryPathEmpty = Join-Path $TestDrive 'driver-summary-empty.json'
            & $script:DriverScript `
                -Agent 'task-researcher' `
                -Tier 'pr' `
                -RepoRoot $script:DriverRepoEmpty `
                -OutputPath $script:SummaryPathEmpty `
                -WhatIf *> $null
            $script:SummaryEmpty = Get-Content -LiteralPath $script:SummaryPathEmpty -Raw | ConvertFrom-Json
        }

        It 'Emits an empty variants.b.applied array' {
            @($script:SummaryEmpty.variants.b.applied).Count | Should -Be 0
        }
    }
}
