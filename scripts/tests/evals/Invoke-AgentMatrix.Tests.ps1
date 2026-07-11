#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../evals/Invoke-AgentMatrix.ps1'
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..') | Select-Object -ExpandProperty Path
    $script:InventoryPath = Join-Path $script:RepoRoot 'evals/agent-behavior/AGENTS.yml'

    # Dot-source the script (guarded main is skipped) so the inventory readers are
    # available, then derive the expected slug set from the live inventory. Tests
    # assert conformance against this set rather than a hard-coded agent count.
    . $script:ScriptPath
    $script:Inventory = Read-AgentInventory -RepoRoot $script:RepoRoot
    $script:InventorySlugs = @($script:Inventory | ForEach-Object { $_['slug'] } | Sort-Object -Unique)
}

Describe 'Invoke-AgentMatrix.ps1 (dry-run)' -Tag 'Unit' {

    BeforeEach {
        $script:OutputDir = Join-Path $TestDrive ("am-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:OutputDir -Force | Out-Null
        $script:SummaryPath = Join-Path $script:OutputDir 'agent-matrix-summary.json'
    }

    Context 'All mode' {
        BeforeEach {
            & $script:ScriptPath `
                -All `
                -Tier pr `
                -RepoRoot $script:RepoRoot `
                -OutputDir $script:OutputDir `
                -WhatIf *> $null
            $script:Summary = Get-Content -LiteralPath $script:SummaryPath -Raw | ConvertFrom-Json
        }

        It 'Exits with code 0' {
            $LASTEXITCODE | Should -Be 0
        }

        It 'Writes the aggregate summary JSON' {
            Test-Path -LiteralPath $script:SummaryPath | Should -BeTrue
        }

        It 'Records tier=pr and mode=all' {
            $script:Summary.tier | Should -Be 'pr'
            $script:Summary.mode | Should -Be 'all'
        }

        It 'Reports verdict=dry-run' {
            $script:Summary.overall | Should -Be 'dry-run'
        }

        It 'Enumerates every inventory agent exactly once (DD-09)' {
            $resultSlugs = @($script:Summary.results | ForEach-Object { $_.slug } | Sort-Object -Unique)
            $script:Summary.agentCount | Should -Be $script:InventorySlugs.Count
            $script:Summary.results.Count | Should -Be $script:InventorySlugs.Count
            $script:Summary.plannedCommands.Count | Should -Be $script:InventorySlugs.Count
            $resultSlugs | Should -Be $script:InventorySlugs
        }

        It 'Records a class and cost_tier for every result row' {
            foreach ($row in $script:Summary.results) {
                $row.slug      | Should -Not -BeNullOrEmpty
                $row.class     | Should -Not -BeNullOrEmpty
                $row.cost_tier | Should -Not -BeNullOrEmpty
                $row.overall   | Should -Be 'dry-run'
            }
        }

        It 'Plans a vally command per slug using --eval-spec eval.yaml with an agent tag' {
            $first = $script:Summary.plannedCommands[0]
            $first | Should -Match '^npx vally eval --eval-spec evals/agent-behavior/eval\.yaml --tag agent=[^ ]+ --model \S+$'
            $first | Should -Match '--model gpt-5\.6-luna$'
        }
    }

    Context 'Changed mode with explicit slugs' {
        BeforeEach {
            & $script:ScriptPath `
                -Changed @('task-researcher', 'task-planner') `
                -Tier pr `
                -RepoRoot $script:RepoRoot `
                -OutputDir $script:OutputDir `
                -WhatIf *> $null
            $script:Summary = Get-Content -LiteralPath $script:SummaryPath -Raw | ConvertFrom-Json
        }

        It 'Exits with code 0' {
            $LASTEXITCODE | Should -Be 0
        }

        It 'Records mode=changed' {
            $script:Summary.mode | Should -Be 'changed'
        }

        It 'Enumerates only the requested known slugs' {
            $script:Summary.agentCount | Should -Be 2
            $slugs = @($script:Summary.results | ForEach-Object { $_.slug })
            $slugs | Should -Contain 'task-researcher'
            $slugs | Should -Contain 'task-planner'
        }
    }

    Context 'Changed mode with a subagent path' {
        BeforeEach {
            & $script:ScriptPath `
                -Changed @('.github/agents/coding-standards/subagents/code-review-standards.agent.md') `
                -Tier pr `
                -RepoRoot $script:RepoRoot `
                -OutputDir $script:OutputDir `
                -WhatIf *> $null
            $script:Summary = Get-Content -LiteralPath $script:SummaryPath -Raw | ConvertFrom-Json
        }

        It 'Plans both the parent and own slugs for a changed subagent' {
            $script:Summary.agentCount | Should -Be 2
            $planText = $script:Summary.plannedCommands -join [Environment]::NewLine
            $planText | Should -Match '--tag agent=code-review(?:\s|$)'
            $planText | Should -Match '--tag agent=code-review-standards(?:\s|$)'
        }
    }

    Context 'Changed mode with no slugs' {
        BeforeEach {
            & $script:ScriptPath `
                -Changed @() `
                -Tier pr `
                -RepoRoot $script:RepoRoot `
                -OutputDir $script:OutputDir `
                -WhatIf *> $null
            $script:Summary = Get-Content -LiteralPath $script:SummaryPath -Raw | ConvertFrom-Json
        }

        It 'Exits with code 0' {
            $LASTEXITCODE | Should -Be 0
        }

        It 'Writes an empty summary' {
            $script:Summary.agentCount | Should -Be 0
            $script:Summary.results.Count | Should -Be 0
        }
    }

    Context 'Nightly tier metadata' {
        BeforeEach {
            & $script:ScriptPath `
                -All `
                -Tier nightly `
                -RepoRoot $script:RepoRoot `
                -OutputDir $script:OutputDir `
                -WhatIf *> $null
            $script:Summary = Get-Content -LiteralPath $script:SummaryPath -Raw | ConvertFrom-Json
        }

        It 'Records tier=nightly' {
            $script:Summary.tier | Should -Be 'nightly'
        }

        It 'Exits 0 in dry-run even at nightly tier' {
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context 'Parameter validation' {
        It 'Rejects an unknown tier' {
            { & $script:ScriptPath -All -Tier 'weekly' -RepoRoot $script:RepoRoot -OutputDir $script:OutputDir -WhatIf } |
                Should -Throw
        }

        It 'Rejects combining -All and -Changed' {
            { & $script:ScriptPath -All -Changed @('task-researcher') -RepoRoot $script:RepoRoot -OutputDir $script:OutputDir -WhatIf } |
                Should -Throw
        }
    }
}

Describe 'Invoke-AgentMatrix helper functions' -Tag 'Unit' {

    BeforeAll {
        . $script:ScriptPath
    }

    Context 'Get-GraderStatusesFromLog' {
        It 'Parses pass/fail grader lines' {
            $lines = @(
                'grader "header-present": pass',
                'grader "scope-adherence": fail',
                'grader "no-source-edit": pass'
            )
            $result = @(Get-GraderStatusesFromLog -Lines $lines)
            $result.Count | Should -Be 3
            ($result | Where-Object { $_['name'] -eq 'header-present' }).status | Should -Be 'pass'
            ($result | Where-Object { $_['name'] -eq 'scope-adherence' }).status | Should -Be 'fail'
        }

        It 'Deduplicates repeated grader names' {
            $lines = @(
                'grader "header-present": pass',
                'grader "header-present": fail'
            )
            $result = @(Get-GraderStatusesFromLog -Lines $lines)
            $result.Count | Should -Be 1
            $result[0]['status'] | Should -Be 'pass'
        }

        It 'Returns an empty collection on empty input' {
            $result = @(Get-GraderStatusesFromLog -Lines @())
            $result.Count | Should -Be 0
        }

        It 'Ignores lines that do not match the grader pattern' {
            $result = @(Get-GraderStatusesFromLog -Lines @('random log line', 'no grader here'))
            $result.Count | Should -Be 0
        }
    }

    Context 'New-AgentSummary' {
        BeforeEach {
            $script:Entry = @{ slug = 'task-researcher'; class = 'research-writer'; cost_tier = 'light' }
            $script:Graders = [System.Collections.Generic.List[hashtable]]::new()
            $script:Graders.Add(@{ name = 'header-present'; status = 'pass' })
        }

        It 'Reports overall=pass when ExitCode=0 and no failing graders' {
            $summary = New-AgentSummary -AgentEntry $script:Entry -ExitCode 0 -Graders $script:Graders -LogPath 'x.log'
            $summary.overall | Should -Be 'pass'
            $summary.slug | Should -Be 'task-researcher'
            $summary.class | Should -Be 'research-writer'
            $summary.cost_tier | Should -Be 'light'
            $summary.logPath | Should -Be 'x.log'
            $summary.exitCode | Should -Be 0
        }

        It 'Reports overall=fail when ExitCode is non-zero' {
            $summary = New-AgentSummary -AgentEntry $script:Entry -ExitCode 2 -Graders $script:Graders -LogPath 'x.log'
            $summary.overall | Should -Be 'fail'
            $summary.exitCode | Should -Be 2
        }

        It 'Reports overall=fail when a grader status is fail even with exit 0' {
            $script:Graders.Add(@{ name = 'scope'; status = 'fail' })
            $summary = New-AgentSummary -AgentEntry $script:Entry -ExitCode 0 -Graders $script:Graders -LogPath 'x.log'
            $summary.overall | Should -Be 'fail'
        }
    }

    Context 'New-MatrixSummary' {
        It 'Collects failure slugs and sets overall=fail' {
            $results = [System.Collections.Generic.List[hashtable]]::new()
            $results.Add(@{ slug = 'a'; overall = 'pass' })
            $results.Add(@{ slug = 'b'; overall = 'fail' })
            $summary = New-MatrixSummary -Tier 'nightly' -Mode 'all' -Results $results -PlannedCommands @('cmd-a','cmd-b')
            $summary.overall | Should -Be 'fail'
            $summary.failures | Should -Contain 'b'
            $summary.agentCount | Should -Be 2
            $summary.tier | Should -Be 'nightly'
            $summary.mode | Should -Be 'all'
            $summary.plannedCommands.Count | Should -Be 2
        }

        It 'Sets overall=pass when all results pass' {
            $results = [System.Collections.Generic.List[hashtable]]::new()
            $results.Add(@{ slug = 'a'; overall = 'pass' })
            $results.Add(@{ slug = 'b'; overall = 'pass' })
            $summary = New-MatrixSummary -Tier 'pr' -Mode 'changed' -Results $results -PlannedCommands @()
            $summary.overall | Should -Be 'pass'
            $summary.failures.Count | Should -Be 0
        }

        It 'Honors an explicit verdict override' {
            $results = [System.Collections.Generic.List[hashtable]]::new()
            $summary = New-MatrixSummary -Tier 'pr' -Mode 'all' -Results $results -PlannedCommands @() -Verdict 'dry-run'
            $summary.overall | Should -Be 'dry-run'
        }
    }

    Context 'Resolve-SlugSet' {
        BeforeAll {
            $script:Inventory = Read-AgentInventory -RepoRoot $script:RepoRoot
        }

        It 'Returns every inventory slug in All mode' {
            $slugs = Resolve-SlugSet -RepoRoot $script:RepoRoot -Inventory $script:Inventory -ParameterSet 'All'
            $expected = @($script:Inventory | ForEach-Object { $_['slug'] } | Sort-Object -Unique)
            $slugs.Count | Should -Be $script:Inventory.Count
            $slugs | Should -Be $expected
        }

        It 'Filters Changed inputs to known slugs' {
            $slugs = Resolve-SlugSet -RepoRoot $script:RepoRoot -Inventory $script:Inventory -ParameterSet 'Changed' -Changed @('task-researcher', 'definitely-not-an-agent')
            $slugs | Should -Contain 'task-researcher'
            $slugs | Should -Not -Contain 'definitely-not-an-agent'
        }

        It 'Returns an empty array when Changed is empty' {
            $slugs = Resolve-SlugSet -RepoRoot $script:RepoRoot -Inventory $script:Inventory -ParameterSet 'Changed' -Changed @()
            $slugs.Count | Should -Be 0
        }
    }

    Context 'Get-GraderStatusesFromLog pattern extraction' {
        It 'Extracts pattern from positive-match glyph line ("matches pattern ...")' {
            $checkGlyph = [string][char]0x2714
            $lines = @(
                'Graders (1/1)',
                "  $checkGlyph field-vocab-present  Output matches pattern /(?i)(title|description)/",
                ''
            )
            $result = @(Get-GraderStatusesFromLog -Lines $lines)
            $result.Count | Should -Be 1
            $result[0]['name']    | Should -Be 'field-vocab-present'
            $result[0]['status']  | Should -Be 'pass'
            $result[0]['pattern'] | Should -Be '/(?i)(title|description)/'
        }

        It 'Extracts pattern from negative-match glyph line ("does not match pattern ...")' {
            $crossGlyph = [string][char]0x2718
            $lines = @(
                'Graders (0/1)',
                "  $crossGlyph tracking-file-write  Output does not match pattern /(?i)\.copilot-tracking/workitems/",
                ''
            )
            $result = @(Get-GraderStatusesFromLog -Lines $lines)
            $result.Count | Should -Be 1
            $result[0]['name']    | Should -Be 'tracking-file-write'
            $result[0]['status']  | Should -Be 'fail'
            $result[0]['pattern'] | Should -Be '/(?i)\.copilot-tracking/workitems/'
        }
    }

    Context 'Merge-GraderDetails' {
        It 'Preserves log message when rich grader provides only evidence' {
            $logGrader = @{
                name    = 'field-vocab-present'
                status  = 'pass'
                message = 'Output matches pattern /(?i)(title)/'
                pattern = '/(?i)(title)/'
            }
            $logList = [System.Collections.Generic.List[hashtable]]::new()
            $logList.Add($logGrader)
            $richGrader = @{
                name     = 'field-vocab-present'
                status   = 'pass'
                evidence = 'Output matches pattern /(?i)(title)/'
                pattern  = '/(?i)(title)/'
                label    = 'vocab'
                kind     = 'regex'
            }
            $merged = @(Merge-GraderDetails -LogGraders $logList -RichGraders @($richGrader))
            $merged.Count | Should -Be 1
            $merged[0]['message']  | Should -Be 'Output matches pattern /(?i)(title)/'
            $merged[0]['pattern']  | Should -Be '/(?i)(title)/'
            $merged[0]['evidence'] | Should -Be 'Output matches pattern /(?i)(title)/'
            $merged[0]['label']    | Should -Be 'vocab'
            $merged[0]['kind']     | Should -Be 'regex'
        }

        It 'Backfills pattern from rich grader when log pattern is empty' {
            $logGrader = @{
                name    = 'no-source-edit'
                status  = 'pass'
                message = 'Output does not match pattern /\.cs/'
                pattern = ''
            }
            $logList = [System.Collections.Generic.List[hashtable]]::new()
            $logList.Add($logGrader)
            $richGrader = @{
                name     = 'no-source-edit'
                status   = 'pass'
                evidence = 'Output does not match pattern /\.cs/'
                pattern  = '/\.cs/'
                label    = ''
                kind     = ''
            }
            $merged = @(Merge-GraderDetails -LogGraders $logList -RichGraders @($richGrader))
            $merged[0]['pattern'] | Should -Be '/\.cs/'
            $merged[0]['message'] | Should -Be 'Output does not match pattern /\.cs/'
        }
    }
}
