#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../linting/Test-AgentColdStartBudget.ps1')
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path

    function New-TestFile {
        param([string]$Root, [string]$RelativePath, [string]$Content)
        $path = Join-Path $Root $RelativePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
        [System.IO.File]::WriteAllText($path, $Content)
    }

    function New-TestConfig {
        param([string]$Root, [hashtable]$Agents)
        $path = Join-Path $Root 'budgets.json'
        @{ agents = $Agents } | ConvertTo-Json -Depth 5 | Set-Content -Path $path
        return $path
    }
}

Describe 'Get-AgentColdStartSet' -Tag 'Unit' {
    It 'Sums the agent and its recursive #file: imports once each' {
        $root = Join-Path $TestDrive 'recursive'
        New-TestFile $root '.github/agents/a/x.agent.md' 'see #file:../../instructions/one.instructions.md and #file:../../instructions/one.instructions.md.'
        New-TestFile $root '.github/instructions/one.instructions.md' 'chain #file:./two.instructions.md:'
        New-TestFile $root '.github/instructions/two.instructions.md' 'leaf'

        $set = Get-AgentColdStartSet -RepoRoot $root -AgentPath '.github/agents/a/x.agent.md'

        @($set.Files.Path) | Should -Be @('.github/agents/a/x.agent.md', '.github/instructions/one.instructions.md', '.github/instructions/two.instructions.md')
        $set.Issues | Should -HaveCount 0
        $set.Bytes | Should -Be ([long](($set.Files | ForEach-Object { $_.Bytes }) | Measure-Object -Sum).Sum)
    }

    It 'Normalizes CRLF to LF when counting bytes' {
        $root = Join-Path $TestDrive 'crlf'
        New-TestFile $root '.github/agents/x.agent.md' "a`r`nb`r`n"

        (Get-AgentColdStartSet -RepoRoot $root -AgentPath '.github/agents/x.agent.md').Bytes | Should -Be 4
    }

    It 'Ignores prose that mentions #file: without a path' {
        $root = Join-Path $TestDrive 'prose'
        New-TestFile $root '.github/agents/x.agent.md' 'When a `#file:` import did not resolve, read the owner.'

        $set = Get-AgentColdStartSet -RepoRoot $root -AgentPath '.github/agents/x.agent.md'
        $set.Files | Should -HaveCount 1
        $set.Issues | Should -HaveCount 0
    }

    It 'Reports an unresolved #file: target' {
        $root = Join-Path $TestDrive 'missing'
        New-TestFile $root '.github/agents/x.agent.md' 'see #file:../instructions/gone.instructions.md'

        $set = Get-AgentColdStartSet -RepoRoot $root -AgentPath '.github/agents/x.agent.md'
        $set.Issues | Should -HaveCount 1
        $set.Issues[0] | Should -Match 'gone\.instructions\.md'
    }

    It 'Reports a missing agent' {
        $set = Get-AgentColdStartSet -RepoRoot (Join-Path $TestDrive 'empty') -AgentPath '.github/agents/none.agent.md'
        $set.Issues[0] | Should -Match 'Agent not found'
    }
}

Describe 'Get-AlwaysOnInstructionPath' -Tag 'Unit' {
    It 'Returns only instructions whose applyTo attaches to every file' {
        $root = Join-Path $TestDrive 'always-on'
        New-TestFile $root '.github/instructions/all.instructions.md' "---`napplyTo: '**'`n---`nbody"
        New-TestFile $root '.github/instructions/mixed.instructions.md' "---`napplyTo: '**/*.md, **/*'`n---`nbody"
        New-TestFile $root '.github/instructions/scoped.instructions.md' "---`napplyTo: '**/*.ps1'`n---`nbody"

        $paths = Get-AlwaysOnInstructionPath -RepoRoot $root | ForEach-Object { Split-Path -Leaf $_ }
        $paths | Should -Be @('all.instructions.md', 'mixed.instructions.md')
    }
}

Describe 'Test-AgentColdStartBudget' -Tag 'Unit' {
    BeforeAll {
        $script:BandRoot = Join-Path $TestDrive 'bands'
        New-TestFile $script:BandRoot '.github/agents/x.agent.md' ('x' * 100)
        New-TestFile $script:BandRoot '.github/instructions/always.instructions.md' "---`napplyTo: '**'`n---`n"
    }

    It 'Includes always-on instructions in the cold-start set' {
        $config = New-TestConfig $script:BandRoot @{ '.github/agents/x.agent.md' = @{ target = 1000; ceiling = 1000; rationale = 'r' } }
        $result = Test-AgentColdStartBudget -RepoRoot $script:BandRoot -ConfigPath $config
        @($result.Agents[0].files.Path) | Should -Contain '.github/instructions/always.instructions.md'
    }

    It 'Classifies <Name>' -ForEach @(
        @{ Name = 'within target'; Target = 1000; Ceiling = 2000; Status = 'within-target'; Passed = $true; Warnings = 0 }
        @{ Name = 'within tolerance'; Target = 50; Ceiling = 2000; Status = 'within-tolerance'; Passed = $true; Warnings = 1 }
        @{ Name = 'over ceiling'; Target = 50; Ceiling = 60; Status = 'over-ceiling'; Passed = $false; Warnings = 0 }
    ) {
        $config = New-TestConfig $script:BandRoot @{ '.github/agents/x.agent.md' = @{ target = $Target; ceiling = $Ceiling; rationale = 'r' } }
        $result = Test-AgentColdStartBudget -RepoRoot $script:BandRoot -ConfigPath $config
        $result.Agents[0].status | Should -Be $Status
        $result.Passed | Should -Be $Passed
        $result.Warnings | Should -HaveCount $Warnings
    }

    It 'Fails a budget whose ceiling is below its target or that has no rationale' {
        $config = New-TestConfig $script:BandRoot @{ '.github/agents/x.agent.md' = @{ target = 2000; ceiling = 1000; rationale = '' } }
        $result = Test-AgentColdStartBudget -RepoRoot $script:BandRoot -ConfigPath $config
        $result.Passed | Should -BeFalse
        $result.Issues | Should -HaveCount 2
    }
}

Describe 'Invoke-AgentColdStartBudgetCheck' -Tag 'Unit' {
    BeforeAll {
        $script:RunRoot = Join-Path $TestDrive 'run'
        New-TestFile $script:RunRoot '.github/agents/x.agent.md' ('x' * 100)
        Mock Write-Host {}
        Mock Write-Warning {}
        Mock Write-Error {}
    }

    It 'Returns <Code> and writes JSON results when the budget is <Name>' -ForEach @(
        @{ Name = 'within target'; Target = 1000; Ceiling = 2000; Code = 0; Warnings = 0; Errors = 0 }
        @{ Name = 'within tolerance'; Target = 50; Ceiling = 2000; Code = 0; Warnings = 1; Errors = 0 }
        @{ Name = 'over ceiling'; Target = 50; Ceiling = 60; Code = 1; Warnings = 0; Errors = 1 }
    ) {
        $config = New-TestConfig $script:RunRoot @{ '.github/agents/x.agent.md' = @{ target = $Target; ceiling = $Ceiling; rationale = 'r' } }
        $output = Join-Path $TestDrive "out-$Code-$Warnings/results.json"

        Invoke-AgentColdStartBudgetCheck -RepoRoot $script:RunRoot -ConfigPath $config -OutputPath $output | Should -Be $Code

        (Get-Content -Path $output -Raw | ConvertFrom-Json).Agents[0].agent | Should -Be '.github/agents/x.agent.md'
        Should -Invoke Write-Warning -Exactly -Times $Warnings -Scope It
        Should -Invoke Write-Error -Exactly -Times $Errors -Scope It
    }

    It 'Resolves the default config and output paths under the repository root' {
        $root = Join-Path $TestDrive 'defaults'
        New-TestFile $root '.github/agents/x.agent.md' 'x'
        $configPath = Join-Path $root 'scripts/linting/agent-cold-start-budgets.json'
        New-Item -ItemType Directory -Path (Split-Path -Parent $configPath) -Force | Out-Null
        @{ agents = @{ '.github/agents/x.agent.md' = @{ target = 10; ceiling = 10; rationale = 'r' } } } | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath

        Invoke-AgentColdStartBudgetCheck -RepoRoot $root | Should -Be 0
        Join-Path $root 'logs/agent-cold-start-results.json' | Should -Exist
    }

    It 'Returns 1 and reports the failure when the check throws' {
        Invoke-AgentColdStartBudgetCheck -RepoRoot $script:RunRoot -ConfigPath (Join-Path $TestDrive 'missing.json') -OutputPath (Join-Path $TestDrive 'never.json') | Should -Be 1
        Should -Invoke Write-Error -Exactly -Times 1 -Scope It -ParameterFilter { "$Message" -match 'Test-AgentColdStartBudget failed' }
    }
}

Describe 'Repository cold-start budgets' -Tag 'Unit' {
    It 'Keeps every configured planning-chain agent at or below its ceiling' {
        $result = Test-AgentColdStartBudget -RepoRoot $script:RepoRoot -ConfigPath (Join-Path $script:RepoRoot 'scripts/linting/agent-cold-start-budgets.json')
        $result.Issues | Should -BeNullOrEmpty
        $result.Passed | Should -BeTrue
    }
}
