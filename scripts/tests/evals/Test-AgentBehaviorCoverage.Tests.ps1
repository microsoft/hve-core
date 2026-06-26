#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = (Resolve-Path (Join-Path $PSScriptRoot '../../evals/Test-EvalSpec.ps1')).Path
    $script:ModulePath = (Resolve-Path (Join-Path $PSScriptRoot '../../evals/Modules/EvalSpecSchema.psm1')).Path

    Import-Module $script:ModulePath -Force

    if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
        throw "Pester suite requires 'powershell-yaml'. Install via Install-Module powershell-yaml -Scope CurrentUser."
    }
    Import-Module powershell-yaml -ErrorAction Stop

    . $script:ScriptPath -SkipAgentCoverage *> $null

    function New-CoverageFixture {
        param(
            [Parameter(Mandatory = $true)][string]$Root,
            [Parameter(Mandatory = $true)][hashtable[]]$Agents,
            [Parameter(Mandatory = $false)][string[]]$Stimuli = @()
        )

        $agentsRoot = Join-Path $Root '.github/agents/sample'
        $stimuliRoot = Join-Path $Root 'evals/agent-behavior/stimuli'
        New-Item -ItemType Directory -Path $agentsRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $stimuliRoot -Force | Out-Null

        foreach ($agent in $Agents) {
            $slug = [string]$agent.slug
            $frontmatter = @('---', "name: $slug")
            if ($agent.ContainsKey('userInvocable')) {
                $frontmatter += "user-invocable: $($agent.userInvocable.ToString().ToLowerInvariant())"
            }
            $frontmatter += '---'
            $frontmatter += ''
            $frontmatter += "# $slug"
            $path = Join-Path $agentsRoot "$slug.agent.md"
            Set-Content -LiteralPath $path -Value ($frontmatter -join "`n") -Encoding UTF8
        }

        foreach ($slug in $Stimuli) {
            $path = Join-Path $stimuliRoot "$slug.yml"
            Set-Content -LiteralPath $path -Value "name: $slug`nprompt: test`n" -Encoding UTF8
        }
    }
}

Describe 'Test-AgentBehaviorCoverage (function)' -Tag 'Unit' {
    BeforeEach {
        $script:Fixture = Join-Path $TestDrive ("coverage-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:Fixture -Force | Out-Null
    }

    It 'Returns covered and missing slugs against a fixture repo' {
        New-CoverageFixture -Root $script:Fixture -Agents @(
            @{ slug = 'alpha' },
            @{ slug = 'beta' }
        ) -Stimuli @('alpha')

        $report = Test-AgentBehaviorCoverage -RepoRoot $script:Fixture

        $report.parentCount | Should -Be 2
        $report.checkedCount | Should -Be 2
        $report.covered.Count | Should -Be 1
        $report.missing.Count | Should -Be 1
        $report.covered[0].slug | Should -Be 'alpha'
        $report.missing[0].slug | Should -Be 'beta'
    }

    It 'Ignores subagents that declare user-invocable: false' {
        New-CoverageFixture -Root $script:Fixture -Agents @(
            @{ slug = 'parent-agent' },
            @{ slug = 'helper-subagent'; userInvocable = $false }
        )

        $report = Test-AgentBehaviorCoverage -RepoRoot $script:Fixture

        $report.parentCount | Should -Be 1
        $report.missing.Count | Should -Be 1
        $report.missing[0].slug | Should -Be 'parent-agent'
        $allSlugs = @($report.covered | ForEach-Object { $_.slug }) + @($report.missing | ForEach-Object { $_.slug })
        $allSlugs | Should -Not -Contain 'helper-subagent'
    }

    It 'Honors -RestrictToSlugs for incremental enforcement' {
        New-CoverageFixture -Root $script:Fixture -Agents @(
            @{ slug = 'legacy' },
            @{ slug = 'newly-added' }
        )

        $report = Test-AgentBehaviorCoverage -RepoRoot $script:Fixture -RestrictToSlugs @('newly-added')

        $report.parentCount | Should -Be 2
        $report.checkedCount | Should -Be 1
        $report.missing.Count | Should -Be 1
        $report.missing[0].slug | Should -Be 'newly-added'
    }

    It 'Returns zero missing when every parent agent has a partial' {
        New-CoverageFixture -Root $script:Fixture -Agents @(
            @{ slug = 'one' },
            @{ slug = 'two' }
        ) -Stimuli @('one', 'two')

        $report = Test-AgentBehaviorCoverage -RepoRoot $script:Fixture

        $report.missing.Count | Should -Be 0
        $report.covered.Count | Should -Be 2
    }
}

Describe 'Test-EvalSpec.ps1 -NewAgentsOnly (entry script)' -Tag 'Unit' {
    BeforeEach {
        $script:OutputPath = Join-Path $TestDrive ("eval-spec-coverage-" + [Guid]::NewGuid().ToString('N') + ".json")
    }

    It 'Skips coverage check gracefully when no new parent agents are detected' {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $output = & $script:ScriptPath `
            -Root 'scripts/tests/evals/fixtures/specs/valid' `
            -RepoRoot $repoRoot `
            -OutputPath $script:OutputPath `
            -NewAgentsOnly `
            -BaseRef 'HEAD' *>&1
        $exit = $LASTEXITCODE
        $exit | Should -Be 0
        ($output -join "`n") | Should -Match 'Skipping coverage check|coverage'
    }
}
