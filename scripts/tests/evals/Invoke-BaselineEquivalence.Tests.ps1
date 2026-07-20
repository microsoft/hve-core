#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../evals/Invoke-BaselineEquivalence.ps1'
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..') | Select-Object -ExpandProperty Path
}

Describe 'Invoke-BaselineEquivalence.ps1 (dry-run)' -Tag 'Unit' {
    BeforeEach {
        $script:OutputPath = Join-Path $TestDrive "summary-$([Guid]::NewGuid()).json"
    }

    Context 'PR tier defaults' {
        BeforeEach {
            & $script:ScriptPath `
                -Agent 'task-researcher' `
                -Tier 'pr' `
                -RepoRoot $script:RepoRoot `
                -OutputPath $script:OutputPath `
                -WhatIf *> $null
            $script:Summary = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
        }

        It 'Exits with code 0' {
            $LASTEXITCODE | Should -Be 0
        }

        It 'Writes a summary JSON to the requested path' {
            Test-Path -LiteralPath $script:OutputPath | Should -BeTrue
        }

        It 'Records the agent slug' {
            $script:Summary.agent | Should -Be 'task-researcher'
        }

        It 'Records tier=pr' {
            $script:Summary.tier | Should -Be 'pr'
        }

        It 'Selects exactly one PR-tier model' {
            $script:Summary.model | Should -Not -BeNullOrEmpty
            $script:Summary.plannedCommands.Count | Should -Be 3
        }

        It 'Includes workspace and skill-dir flags for baseline and customized runs' {
            $baselineCommand = $script:Summary.plannedCommands[0]
            $customizedCommand = $script:Summary.plannedCommands[1]

            $baselineCommand | Should -Match '--workspace'
            $baselineCommand | Should -Match '--skill-dir'
            $customizedCommand | Should -Match '--workspace'
            $customizedCommand | Should -Match '--skill-dir'
        }

        It 'Isolates the baseline run with empty workspace and skill-dir arguments' {
            $baselineCommand = $script:Summary.plannedCommands[0]

            $baselineCommand | Should -Match '--workspace ""'
            $baselineCommand | Should -Match '--skill-dir ""'
        }

        It 'Points the customized run at populated workspace and skill-dir paths' {
            $customizedCommand = $script:Summary.plannedCommands[1]

            $customizedCommand | Should -Match '--workspace "[^"]+"'
            $customizedCommand | Should -Match '--skill-dir "[^"]+\.github[/\\]skills"'
        }

        It 'Reports zeroed run/aggregate counters' {
            $script:Summary.runs | Should -Be 0
            $script:Summary.ties | Should -Be 0
            $script:Summary.aWins | Should -Be 0
            $script:Summary.bWins | Should -Be 0
            $script:Summary.invariantFailures | Should -Be 0
            $script:Summary.divergenceFailures | Should -Be 0
        }

        It 'Sets verdict to dry-run' {
            $script:Summary.verdict | Should -Be 'dry-run'
        }

        It 'Records variant metadata for baseline (A) and customized (B)' {
            $script:Summary.variants | Should -Not -BeNullOrEmpty
            $script:Summary.variants.a | Should -Not -BeNullOrEmpty
            $script:Summary.variants.b | Should -Not -BeNullOrEmpty
            $script:Summary.variants.a.kind | Should -Be 'baseline'
            $script:Summary.variants.b.name | Should -Be 'task-researcher'
            $script:Summary.variants.subject | Should -Be 'task-researcher'
        }
    }

    Context 'Nightly tier expansion' {
        BeforeEach {
            & $script:ScriptPath `
                -Agent 'task-researcher' `
                -Tier 'nightly' `
                -RepoRoot $script:RepoRoot `
                -OutputPath $script:OutputPath `
                -WhatIf *> $null
            $script:Summary = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
        }

        It 'Records tier=nightly' {
            $script:Summary.tier | Should -Be 'nightly'
        }

        It 'Plans commands for three nightly models' {
            $script:Summary.plannedCommands.Count | Should -Be 9
        }

        It 'Selects gpt-5.5 as the primary nightly model' {
            $script:Summary.model | Should -Be 'gpt-5.5'
        }
    }

    Context 'Stimulus filter passthrough' {
        It 'Embeds the filter in the planned commands' {
            & $script:ScriptPath `
                -Agent 'task-researcher' `
                -Tier 'pr' `
                -StimulusFilter '^code-' `
                -RepoRoot $script:RepoRoot `
                -OutputPath $script:OutputPath `
                -WhatIf *> $null

            $summary = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
            $summary.stimulusFilter | Should -Be '^code-'
            ($summary.plannedCommands -join "`n") | Should -Match '\^code-'
        }
    }

    Context 'Model override' {
        It 'Pins the PR-tier model to the supplied override' {
            & $script:ScriptPath `
                -Agent 'task-researcher' `
                -Tier 'pr' `
                -Model 'gpt-5-mini' `
                -RepoRoot $script:RepoRoot `
                -OutputPath $script:OutputPath `
                -WhatIf *> $null

            $summary = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
            $summary.model | Should -Be 'gpt-5-mini'
            ($summary.plannedCommands -join "`n") | Should -Match 'gpt-5-mini'
        }

        It 'Ignores the override for the nightly tier' {
            & $script:ScriptPath `
                -Agent 'task-researcher' `
                -Tier 'nightly' `
                -Model 'gpt-5-mini' `
                -RepoRoot $script:RepoRoot `
                -OutputPath $script:OutputPath `
                -WhatIf *> $null

            $summary = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
            $summary.model | Should -Be 'gpt-5.5'
        }
    }

    Context 'Parameter validation' {
        It 'Rejects an unknown tier' {
            { & $script:ScriptPath -Tier 'weekly' -RepoRoot $script:RepoRoot -OutputPath $script:OutputPath -WhatIf } |
                Should -Throw
        }
    }
}

Describe 'Measure-InvariantFailures' -Tag 'Unit' {
    BeforeAll {
        . $script:ScriptPath
        $script:Pass = [char]::ConvertFromUtf32(0x2705)
        $script:Fail = [char]::ConvertFromUtf32(0x274C)
        $script:Warn = [char]::ConvertFromUtf32(0x1F7E1)
        $script:Header = '| Stimulus | Graders | Pass Rate | pass@k | pass^k | Duration | Tokens | Verdict |'
        $script:Sep = '|---|---|---|---|---|---|---|---|'
    }

    It 'Returns zero failures when all rows pass' {
        $lines = @(
            $script:Header,
            $script:Sep,
            "| s1 | $script:Pass g 5/5 | 100% | 1.00 | 1.00 | 1s | 10 | $script:Pass |",
            "| s2 | $script:Pass g 5/5 | 100% | 1.00 | 1.00 | 1s | 10 | $script:Pass |"
        )
        $result = Measure-InvariantFailures -Lines $lines
        $result.Total | Should -Be 2
        $result.Failed | Should -Be 0
    }

    It 'Counts failed and warned rows as failures' {
        $lines = @(
            $script:Header,
            $script:Sep,
            "| s1 | g | 100% | 1.00 | 1.00 | 1s | 10 | $script:Pass |",
            "| s2 | g | 0%   | 0.00 | 0.00 | 1s | 10 | $script:Fail |",
            "| s3 | g | 60%  | 0.60 | 0.30 | 1s | 10 | $script:Warn |",
            "| s4 | g | 0%   | 0.00 | 0.00 | 1s | 10 | $script:Fail |"
        )
        $result = Measure-InvariantFailures -Lines $lines
        $result.Total | Should -Be 4
        $result.Failed | Should -Be 3
    }

    It 'Ignores header and separator rows' {
        $lines = @(
            $script:Header,
            $script:Sep,
            "| s1 | g | 100% | 1.00 | 1.00 | 1s | 10 | $script:Pass |"
        )
        $result = Measure-InvariantFailures -Lines $lines
        $result.Total | Should -Be 1
        $result.Failed | Should -Be 0
    }

    It 'Strips ANSI escape sequences before matching' {
        $ansiLine = "`e[32m| s1 | g | 100% | 1.00 | 1.00 | 1s | 10 | $script:Fail |`e[0m"
        $result = Measure-InvariantFailures -Lines @($ansiLine)
        $result.Total | Should -Be 1
        $result.Failed | Should -Be 1
    }

    It 'Handles empty input' {
        $result = Measure-InvariantFailures -Lines @()
        $result.Total | Should -Be 0
        $result.Failed | Should -Be 0
    }

    It 'Ignores non-table lines' {
        $lines = @(
            '# Eval Results',
            '',
            'Some prose here.',
            $script:Header,
            $script:Sep,
            "| s1 | g | 0% | 0.00 | 0.00 | 1s | 10 | $script:Fail |"
        )
        $result = Measure-InvariantFailures -Lines $lines
        $result.Total | Should -Be 1
        $result.Failed | Should -Be 1
    }
}

Describe 'Resolve-ModelList' -Tag 'Unit' {
    BeforeAll {
        . $script:ScriptPath
    }

    It 'Uses GPT-5.6 Luna as the low-cost PR default' {
        $models = Resolve-ModelList -Tier 'pr' -Hint '' -ModelOverride ''

        $models | Should -Be @('gpt-5.6-luna')
    }
}

Describe 'Get-InvariantFailureCount' -Tag 'Unit' {
    BeforeAll {
        . $script:ScriptPath
        $script:Pass = [char]::ConvertFromUtf32(0x2705)
        $script:Fail = [char]::ConvertFromUtf32(0x274C)
        $script:Warn = [char]::ConvertFromUtf32(0x1F7E1)
        $script:Header = '| Stimulus | Graders | Pass Rate | pass@k | pass^k | Duration | Tokens | Verdict |'
        $script:Sep = '|---|---|---|---|---|---|---|---|'
    }

    It 'Returns $null when RunDir is empty' {
        Get-InvariantFailureCount -RunDir '' | Should -BeNullOrEmpty
    }

    It 'Returns $null when RunDir does not exist' {
        Get-InvariantFailureCount -RunDir (Join-Path $TestDrive 'nope') | Should -BeNullOrEmpty
    }

    It 'Returns $null when eval-results.md is missing' {
        $dir = Join-Path $TestDrive 'no-md'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Get-InvariantFailureCount -RunDir $dir | Should -BeNullOrEmpty
    }

    It 'Returns $null when the markdown table has no data rows' {
        $dir = Join-Path $TestDrive 'empty-table'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $md = Join-Path $dir 'eval-results.md'
        Set-Content -LiteralPath $md -Value @($script:Header, $script:Sep) -Encoding utf8NoBOM
        Get-InvariantFailureCount -RunDir $dir | Should -BeNullOrEmpty
    }

    It 'Returns the failed-stimulus count parsed from eval-results.md' {
        $dir = Join-Path $TestDrive 'with-failures'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $md = Join-Path $dir 'eval-results.md'
        $lines = @(
            $script:Header,
            $script:Sep,
            "| s1 | g | 100% | 1.00 | 1.00 | 1s | 10 | $script:Pass |",
            "| s2 | g | 0%   | 0.00 | 0.00 | 1s | 10 | $script:Fail |",
            "| s3 | g | 60%  | 0.60 | 0.30 | 1s | 10 | $script:Warn |"
        )
        Set-Content -LiteralPath $md -Value $lines -Encoding utf8NoBOM
        Get-InvariantFailureCount -RunDir $dir | Should -Be 2
    }

    It 'Returns 0 when all stimuli pass' {
        $dir = Join-Path $TestDrive 'all-pass'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $md = Join-Path $dir 'eval-results.md'
        $lines = @(
            $script:Header,
            $script:Sep,
            "| s1 | g | 100% | 1.00 | 1.00 | 1s | 10 | $script:Pass |",
            "| s2 | g | 100% | 1.00 | 1.00 | 1s | 10 | $script:Pass |"
        )
        Set-Content -LiteralPath $md -Value $lines -Encoding utf8NoBOM
        Get-InvariantFailureCount -RunDir $dir | Should -Be 0
    }
}
