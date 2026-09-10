#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../../..')).Path
    $script:CollectorPath = Join-Path $script:RepoRoot 'scripts/agentic-workflows/backlog-grooming/Invoke-BacklogGroomResultCollector.ps1'

    function New-CollectorAgentOutput {
        param([Parameter(Mandatory)] [long]$IssueNumber)

        return [ordered]@{
            items = @(
                [ordered]@{
                    type = 'publish_backlog_grooming_result'
                    'issue-number' = $IssueNumber
                    title = "Issue $IssueNumber"
                    'selection-reason' = 'priority'
                    'activity-and-ownership-context' = 'active'
                    'acceptance-signals' = 'requested behavior is present'
                    'evidence-1-category' = 'Repository'
                    'evidence-1-text' = 'src/example.ps1'
                    'similarity-outcome' = 'Distinct'
                    disposition = 'Still needed'
                    'grooming-finding' = 'evidence supports assessment'
                    'recommended-next-step' = 'maintain the issue'
                    'assessment-status' = 'Assessed'
                    'deferral-reason' = ''
                }
            )
        }
    }

    function Invoke-CollectorProcess {
        param(
            [Parameter(Mandatory)] [string]$AgentOutputPath,
            [Parameter(Mandatory)] [string]$OutputPath,
            [string]$OrderedCandidateIdsJson = '[42]'
        )

        $Output = & pwsh -NoProfile -File $script:CollectorPath `
            -AgentOutputPath $AgentOutputPath `
            -ShardId 'shard-01' `
            -ManifestDigest ('a' * 64) `
            -OrderedCandidateIdsJson $OrderedCandidateIdsJson `
            -PriorityCandidateIdsJson $OrderedCandidateIdsJson `
            -RoundRobinCandidateIdsJson '[]' `
            -TotalOpenInventoryText '1' `
            -PriorCursorText '0' `
            -OrchestratorRunId '12345' `
            -OrchestratorAttemptText '1' `
            -OutputPath $OutputPath 2>&1
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output = @($Output)
        }
    }
}

Describe 'Invoke-BacklogGroomResultCollector process boundary' -Tag 'Unit' {
    It 'uses the workflow environment contract when no CLI arguments are supplied' {
        $AgentOutputPath = Join-Path $TestDrive 'environment/agent-output.json'
        $OutputPath = Join-Path $TestDrive 'result-output/shard-result.json'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $AgentOutputPath) -Force
        New-CollectorAgentOutput -IssueNumber 42 | ConvertTo-Json -Depth 20 |
            Set-Content -LiteralPath $AgentOutputPath -Encoding utf8NoBOM

        $Environment = @{
            GH_AW_AGENT_OUTPUT = $AgentOutputPath
            SHARD_ID = 'shard-01'
            MANIFEST_DIGEST = 'a' * 64
            ORDERED_CANDIDATE_IDS = '[42]'
            PRIORITY_CANDIDATE_IDS = '[42]'
            ROUND_ROBIN_CANDIDATE_IDS = '[]'
            TOTAL_OPEN_INVENTORY = '1'
            PRIOR_CURSOR = '0'
            ORCHESTRATOR_RUN_ID = '12345'
            ORCHESTRATOR_ATTEMPT = '1'
        }
        $OriginalEnvironment = @{}
        foreach ($Name in $Environment.Keys) {
            $OriginalEnvironment[$Name] = [Environment]::GetEnvironmentVariable($Name)
            [Environment]::SetEnvironmentVariable($Name, $Environment[$Name])
        }
        try {
            Push-Location $TestDrive
            try {
                $ProcessOutput = & pwsh -NoProfile -File $script:CollectorPath 2>&1
                $ExitCode = $LASTEXITCODE
            }
            finally {
                Pop-Location
            }
        }
        finally {
            foreach ($Name in $OriginalEnvironment.Keys) {
                [Environment]::SetEnvironmentVariable($Name, $OriginalEnvironment[$Name])
            }
        }

        $ExitCode | Should -Be 0 -Because ($ProcessOutput -join "`n")
        $OutputPath | Should -Exist
        $Result = Get-Content -LiteralPath $OutputPath -Raw | ConvertFrom-Json
        $Result.report_data.issues.issue | Should -Be @(42)
        $Result.report_data.contract_errors | Should -HaveCount 0
    }

    It 'reads normalized agent output and writes v2 to the requested output path' {
        $AgentOutputPath = Join-Path $TestDrive 'normalized/agent-output.json'
        $OutputPath = Join-Path $TestDrive 'custom/result/shard-result.json'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $AgentOutputPath) -Force
        New-CollectorAgentOutput -IssueNumber 42 | ConvertTo-Json -Depth 20 |
            Set-Content -LiteralPath $AgentOutputPath -Encoding utf8NoBOM

        $Process = Invoke-CollectorProcess -AgentOutputPath $AgentOutputPath -OutputPath $OutputPath

        $Process.ExitCode | Should -Be 0
        $OutputPath | Should -Exist
        $Result = Get-Content -LiteralPath $OutputPath -Raw | ConvertFrom-Json
        $Result.schema_version | Should -BeExactly 'backlog-grooming-shard-result/v2'
        $Result.ordered_candidate_ids | Should -Be @(42)
        $Result.report_data.issues.issue | Should -Be @(42)
        $Result.report_data.contract_errors | Should -HaveCount 0
        $Result.result_digest | Should -Match '^[a-f0-9]{64}$'
    }

    It 'returns nonzero and writes no shard result when trusted shard context is invalid' {
        $AgentOutputPath = Join-Path $TestDrive 'invalid-context/agent-output.json'
        $OutputPath = Join-Path $TestDrive 'invalid-context/result/shard-result.json'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $AgentOutputPath) -Force
        New-CollectorAgentOutput -IssueNumber 42 | ConvertTo-Json -Depth 20 |
            Set-Content -LiteralPath $AgentOutputPath -Encoding utf8NoBOM

        $Process = Invoke-CollectorProcess -AgentOutputPath $AgentOutputPath -OutputPath $OutputPath `
            -OrderedCandidateIdsJson '[]'

        $Process.ExitCode | Should -Not -Be 0
        $OutputPath | Should -Not -Exist
        $Process.Output -join "`n" | Should -Match 'Worker candidate IDs must contain 1 to 5 unique positive integers'
    }
}
