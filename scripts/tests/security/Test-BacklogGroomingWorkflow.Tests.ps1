#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path

    function Read-RepoFile {
        param([Parameter(Mandatory)] [string]$Path)

        return Get-Content -LiteralPath (Join-Path $script:RepoRoot $Path) -Raw
    }

    function Test-GroomingMutationFields {
        param(
            [Parameter(Mandatory)] [ValidateSet('Update', 'Comment')] [string]$Action,
            [Parameter(Mandatory)] [string[]]$MutationFields
        )

        $allowedFields = if ($Action -eq 'Update') { @('title', 'body') } else { @('body') }
        return $MutationFields.Count -gt 0 -and
            @($MutationFields | Where-Object { $_ -notin $allowedFields }).Count -eq 0
    }

    function Select-GroomingCohort {
        param(
            [Parameter(Mandatory)] [object[]]$Issues,
            [Parameter(Mandatory)] [int]$PreviousCursor,
            [Parameter(Mandatory)] [datetime]$PreviousRun,
            [Parameter(Mandatory)] [int]$Capacity
        )

        $ordered = @($Issues | Where-Object { $_.State -eq 'open' -and -not $_.PullRequest } | Sort-Object Number)
        $priority = @($ordered | Where-Object { $_.UpdatedAt -gt $PreviousRun })
        $roundRobin = @($ordered | Where-Object Number -GT $PreviousCursor) +
            @($ordered | Where-Object Number -LE $PreviousCursor)
        $selected = [System.Collections.Generic.List[object]]::new()
        $selectedNumbers = [System.Collections.Generic.HashSet[int]]::new()
        $roundRobinNumbers = [System.Collections.Generic.List[int]]::new()

        foreach ($issue in @($priority) + @($roundRobin)) {
            if ($selected.Count -ge $Capacity) { break }
            if (-not $selectedNumbers.Add($issue.Number)) { continue }

            $selected.Add($issue)
            if ($priority.Number -notcontains $issue.Number) {
                $roundRobinNumbers.Add($issue.Number)
            }
        }

        $nextCursor = if ($selected.Count -gt 0) {
            $selected[-1].Number
        }
        else {
            $PreviousCursor
        }

        return @{
            Selected = @($selected)
            Priority = @($priority.Number | Where-Object { $selectedNumbers.Contains($_) })
            RoundRobin = @($roundRobinNumbers)
            NextCursor = $nextCursor
        }
    }

    function New-GroomingReport {
        param(
            [Parameter(Mandatory)] [hashtable]$Run,
            [Parameter(Mandatory)] [object[]]$Rows
        )

        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add('# Backlog Grooming Report')
        $lines.Add('')
        $lines.Add('| Run timestamp | Total open inventory | Assessed | Priority cohort | Round-robin cohort | Deferred | Stop reason | Next cursor |')
        $lines.Add('|---|---|---|---|---|---|---|---|')
        $lines.Add("| $($Run.Timestamp) | $($Run.Total) | $($Run.Assessed) | $($Run.Priority) | $($Run.RoundRobin) | $($Run.Deferred) | $($Run.StopReason) | $($Run.NextCursor) |")
        $lines.Add('')
        $lines.Add('| Issue | Title | Selection reason | Activity and ownership context | Repository evidence | Similarity outcome | Disposition | Grooming finding | Recommended next step | Assessment status |')
        $lines.Add('|---|---|---|---|---|---|---|---|---|---|')
        foreach ($row in $Rows) {
            $lines.Add("| #$($row.Number) | $($row.Title) | $($row.SelectionReason) | $($row.Context) | $($row.Evidence) | $($row.Similarity) | $($row.Disposition) | $($row.Finding) | $($row.NextStep) | $($row.Status) |")
        }

        return $lines -join "`n"
    }

    function Publish-GroomingReport {
        param(
            [Parameter(Mandatory)] [string]$Report,
            [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]]$Issues,
            [Parameter(Mandatory)] [scriptblock]$CreateSink,
            [Parameter(Mandatory)] [scriptblock]$UpdateSink,
            [Parameter(Mandatory)] [scriptblock]$SummarySink,
            [Parameter(Mandatory)] [scriptblock]$FailureSink
        )

        $marker = '<!-- gh-aw:backlog-grooming-tracker -->'
        $sanitizedReport = $Report -replace '[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]', ''
        $sanitizedReport = $sanitizedReport -replace '@(?=[a-z\d](?:[a-z\d-]{0,38})(?![\w-]))', "@`u{200b}"
        if ($sanitizedReport.Length -lt 20 -or $sanitizedReport.Length -gt 65000) {
            throw "Report length $($sanitizedReport.Length) is outside the allowed range"
        }

        $trackers = @($Issues | Where-Object {
                -not $_.PullRequest -and
                $_.Body.Contains($marker) -and
                $_.User.Login -ceq 'github-actions[bot]' -and
                $_.User.Type -ceq 'Bot'
            })
        if ($trackers.Count -gt 1) {
            & $FailureSink "Expected at most one trusted marker-bearing tracker, found $($trackers.Count)"
            return
        }

        $body = "$marker`n`n$sanitizedReport"
        if ($trackers.Count -eq 0) {
            & $CreateSink 'Backlog grooming tracker' $body
        }
        else {
            & $UpdateSink $trackers[0].Number $body 'open'
        }
        & $SummarySink $sanitizedReport
    }

    function Merge-GroomingShardResults {
        param(
            [Parameter(Mandatory)] [int[]]$CandidateIds,
            [Parameter(Mandatory)] [int]$PriorCursor,
            [Parameter(Mandatory)] [object[]]$Results
        )

        $rowsByIssue = @{}
        $inventoryCounts = [System.Collections.Generic.HashSet[int]]::new()
        foreach ($shardId in @('shard-01', 'shard-02')) {
            $shardResults = @($Results | Where-Object ShardId -EQ $shardId)
            if ($shardResults.Count -ne 1) {
                throw "$shardId expected exactly one result, found $($shardResults.Count)"
            }
            $null = $inventoryCounts.Add($shardResults[0].Inventory)
            foreach ($row in $shardResults[0].Rows) {
                if ($rowsByIssue.ContainsKey($row.Issue)) {
                    throw "duplicate aggregate issue $($row.Issue)"
                }
                $rowsByIssue[$row.Issue] = $row
            }
        }
        if ($inventoryCounts.Count -ne 1) {
            throw 'shard inventory counts disagree'
        }

        $orderedRows = @($CandidateIds | ForEach-Object { $rowsByIssue[$_] })
        if ($orderedRows.Count -ne $CandidateIds.Count -or @($orderedRows | Where-Object { $null -eq $_ }).Count -gt 0) {
            throw 'aggregate issue coverage is incomplete'
        }
        $assessedRows = @($orderedRows | Where-Object Status -EQ 'Assessed')
        $deferredRows = @($orderedRows | Where-Object Status -EQ 'Deferred')

        return [ordered]@{
            Inventory = @($inventoryCounts)[0]
            Assessed = $assessedRows.Count
            Deferred = $deferredRows.Count
            NextCursor = if ($assessedRows.Count -gt 0) { $assessedRows[-1].Issue } else { $PriorCursor }
            Issues = @($orderedRows.Issue)
        }
    }

    function Get-SweepSlices {
        param(
            [AllowNull()] [int[]]$IssueIds,
            [Parameter(Mandatory)] [int]$WaveCapacity
        )

        $slices = [System.Collections.Generic.List[object]]::new()
        $requiredWaves = [Math]::Max(1, [Math]::Ceiling($IssueIds.Count / $WaveCapacity))
        foreach ($waveNumber in 1..$requiredWaves) {
            $start = ($waveNumber - 1) * $WaveCapacity
            $end = [Math]::Min($start + $WaveCapacity - 1, $IssueIds.Count - 1)
            $slice = if ($start -ge $IssueIds.Count) { @() } else { @($IssueIds[$start..$end]) }
            $slices.Add($slice)
        }
        return @($slices)
    }

    function Get-SweepCursor {
        param(
            [Parameter(Mandatory)] [int[]]$CursorCandidateIds,
            [Parameter(Mandatory)] [object[]]$Rows,
            [Parameter(Mandatory)] [int]$PriorCursor
        )

        $rowsByIssue = @{}
        foreach ($row in $Rows) { $rowsByIssue[$row.Issue] = $row }
        $assessed = @($CursorCandidateIds | Where-Object { $rowsByIssue[$_].Status -eq 'Assessed' })
        if ($assessed.Count -gt 0) { return $assessed[-1] }
        return $PriorCursor
    }

    function Get-WorkflowJobSection {
        param(
            [Parameter(Mandatory)] [string]$WorkflowSource,
            [Parameter(Mandatory)] [string]$JobName
        )

        $jobMatch = [regex]::Match(
            $WorkflowSource,
            "(?ms)^  $([regex]::Escape($JobName)):\s+.*?(?=^  [a-z0-9-]+:|\z)"
        )
        if (-not $jobMatch.Success) { throw "Workflow job '$JobName' was not found" }
        return $jobMatch.Value
    }

    function Test-OptionalPublicationEnabled {
        param([AllowEmptyString()] [string]$Value)

        return $Value -ceq 'true'
    }

    $script:Source = Read-RepoFile '.github/workflows/backlog-groom.md'
    $script:Lock = Read-RepoFile '.github/workflows/backlog-groom.lock.yml'
    $script:Orchestrator = Read-RepoFile '.github/workflows/backlog-groom-orchestrator.yml'
    $script:Publisher = Read-RepoFile '.github/workflows/backlog-groom-publisher.yml'
    $script:WaveValidator = Read-RepoFile 'scripts/security/Invoke-BacklogGroomWaveValidator.ps1'
    $script:DeployDocs = Read-RepoFile '.github/workflows/deploy-docs.yml'
    $script:WorkflowReadme = Read-RepoFile '.github/workflows/README.md'
    $script:CorePublisher = Get-WorkflowJobSection -WorkflowSource $script:Publisher -JobName 'publish'
    $script:HistoryPublisher = Get-WorkflowJobSection -WorkflowSource $script:Publisher -JobName 'publish-history'
    $script:Policy = Read-RepoFile '.github/instructions/project-planning/github-backlog-grooming.instructions.md'
    $script:Agent = Read-RepoFile '.github/agents/backlog-grooming.agent.md'
    $script:Manager = Read-RepoFile '.github/agents/project-planning/backlog-manager.agent.md'
    $script:Executor = Read-RepoFile '.github/agents/project-planning/subagents/github-backlog-executor.agent.md'
}

Describe 'Backlog grooming workflow source' -Tag 'Unit' {
    It 'declares only a reusable worker trigger with the dedicated agent import' {
        $script:Source | Should -Match '(?m)^  workflow_call:$'
        $script:Source | Should -Not -Match '(?m)^  schedule:$'
        $script:Source | Should -Not -Match '(?m)^  workflow_dispatch:$'
        $script:Orchestrator | Should -Match '(?m)^  workflow_dispatch:$'
        $script:Source | Should -Match '(?m)^  - \.\./agents/backlog-grooming\.agent\.md$'
        $script:Source | Should -Match '(?m)^  - \.\./instructions/project-planning/github-backlog-grooming\.instructions\.md$'
    }

    It 'keeps model permissions read-only and safe outputs bounded' {
        $script:Source | Should -Match '(?ms)^permissions:\s+contents: read\s+issues: read$'
        $script:Source | Should -Match '(?ms)^  noop:\s+max: 1\s+report-as-issue: false'
        $script:Source | Should -Match '(?m)^    publish-backlog-grooming-result:$'
        $script:Source | Should -Match '(?ms)^    publish-backlog-grooming-result:.*?permissions: \{\}'
        $script:Source | Should -Not -Match '(?m)^\s+issues: write$'
        $script:Source | Should -Not -Match '(?m)^\s+target: "\*"$'
        $script:Source | Should -Match '(?m)^  report-failure-as-issue: false$'
        $script:Source | Should -Match '(?m)^  report-incomplete: false$'
        $script:Source | Should -Match '(?m)^  missing-tool: false$'
        $script:Source | Should -Match '(?m)^  missing-data: false$'
    }

    It 'contains no prohibited mutation or code-scanning output' {
        $script:Source | Should -Not -Match '(?m)^  (create-issue|update-issue|close-issue|add-labels|remove-labels|create-code-scanning-alert):'
        $script:Source | Should -Not -Match '(?m)^\s*security-events: write$'
        $script:Source | Should -Not -Match '(?i)upload.*sarif'
    }

    It 'binds assessment to the planned open non-pull-request candidate set' {
        $script:Source | Should -Match 'retrieve every listed issue by number'
        $script:Source | Should -Match '(?s)missing,\s+closed, or has become a pull request'
        $script:Source | Should -Match 'emit one canonical `Deferred` row for that number'
        $script:Source | Should -Match '(?s)Do not omit the\s+row or call `noop` for an individual post-capture state change'
        $script:Source | Should -Match '(?s)Call `noop` only when shard input validation fails or a repository-wide access'
        $script:Source | Should -Match 'Report issue IDs do not match the planned shard candidates'
        $script:Source | Should -Match 'Worker candidate IDs must be unique positive integers'
        $script:Source | Should -Not -Match 'Worker candidate IDs must be unique positive integers in ascending order'
        $script:Source | Should -Match 'The orchestrator, not the worker,\s+owns inventory selection'
        $script:Source | Should -Not -Match '<!-- gh-aw:backlog-grooming-tracker -->'
    }

    It 'emits one independently validated immutable shard result' {
        $script:Source | Should -Match 'call `publish-backlog-grooming-result` exactly once'
        $script:Source | Should -Match 'const requests = agentOutput\.items\.filter'
        $script:Source | Should -Match 'item\.type === "publish_backlog_grooming_result"'
        $script:Source | Should -Match 'Expected one report publication request, found \$\{requests\.length\}'
        $script:Source | Should -Match 'fs\.writeFileSync\('
        $script:Source | Should -Match '(?m)^        - name: Upload immutable shard result$'
        $script:Source | Should -Match 'backlog-grooming-proof-\$\{\{ inputs\.orchestrator_run_id \}\}-\$\{\{ inputs\.orchestrator_attempt \}\}-\$\{\{ inputs\.shard_id \}\}'
        $script:Source | Should -Not -Match 'github\.rest\.issues\.(create|update|createComment)'
    }

    It 'validates structured report data and computes deterministic result provenance' {
        $script:Source | Should -Match 'JSON\.parse\(String\(requests\[0\]\["report-data"\]'
        $script:Source | Should -Match 'exactKeys\(payload, \["run", "issues"\]\)'
        $script:Source | Should -Match 'const similarities = new Set\(\["Match", "Similar", "Distinct", "Uncertain"\]\)'
        $script:Source | Should -Match 'const dispositions = new Set\(\["Still needed", "Likely completed", "Superseded", "Possible duplicate", "Needs correction", "Uncertain"\]\)'
        $script:Source | Should -Match 'row\.acceptance_signals'
        $script:Source | Should -Match 'const lineageKeys = \["original_delivery", "replacement_or_removal"\]'
        $script:Source | Should -Match 'Superseded requires distinct original-delivery and replacement-or-removal evidence'
        $script:Source | Should -Match 'assessedRows !== run\.assessed \|\| deferredRows !== run\.deferred'
        $script:Source | Should -Match 'Report row statuses do not match the run counts'
        $script:Source | Should -Match 'Deferred rows require a reason, Uncertain outcomes, and empty lineage evidence'
        $script:Source | Should -Match 'Assessed rows cannot include a deferral reason'
        $script:Source | Should -Match 'const canonicalize = \(value\) =>'
        $script:Source | Should -Match '\.createHash\("sha256"\)'
        $script:Source | Should -Match '\.update\(canonicalize\(result\)\)'
        $script:Source | Should -Match 'result_digest: resultDigest'
        $script:Source | Should -Match 'Shard timestamps must be valid and completion cannot precede start'
    }

    It 'reads the hyphenated report-data field from the safe-output envelope' {
        $agentOutput = @{
            items = @(
                @{
                    type = 'publish_backlog_grooming_report'
                    'report-data' = '{"run":{"timestamp":"2026-08-11T00:33:20Z"},"issues":[]}'
                }
            )
        } | ConvertTo-Json -Depth 5 | ConvertFrom-Json

        $request = $agentOutput.items | Where-Object type -EQ 'publish_backlog_grooming_report'
        $payload = $request.'report-data' | ConvertFrom-Json

        $payload.run.timestamp.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') |
            Should -Be '2026-08-11T00:33:20Z'
        $payload.issues.Count | Should -Be 0
        $script:Source | Should -Not -Match 'requests\[0\]\.report_data'
    }
}

Describe 'Compiled backlog grooming workflow' -Tag 'Unit' {
    It 'is compiler-owned and preserves the reusable trigger and read-only model access' {
        $script:Lock | Should -Match '^# gh-aw-metadata:'
        $script:Lock | Should -Match '(?m)^  workflow_call:$'
        $script:Lock | Should -Not -Match '(?m)^  schedule:$'
        $script:Lock | Should -Not -Match '(?m)^  workflow_dispatch:$'
        $script:Lock | Should -Match '(?m)^      issues: read$'
        $script:Lock | Should -Match 'runtime-import \.github/instructions/project-planning/github-backlog-grooming\.instructions\.md'
    }

    It 'allows only the artifact-bound result job and noop from agent output' {
        $script:Lock | Should -Match 'publish_backlog_grooming_result'
        $script:Lock | Should -Match '"noop":\{"max":1,"report-as-issue":"false"\}'
        $script:Lock | Should -Match 'Upload immutable shard result'
        $script:Lock | Should -Match 'producer: "backlog-groom/result-job"'
        $script:Lock | Should -Not -Match '"add_comment"'
        $script:Lock | Should -Not -Match '"(create_issue|update_issue|close_issue|add_labels|remove_labels)"'
        $script:Lock | Should -Not -Match 'GH_AW_\w*CREATE_ISSUE'
        $script:Lock | Should -Not -Match 'issues\.createComment'
    }

    It 'uploads the validated result without issue-write or SARIF permissions' {
        $script:Lock | Should -Match 'JSON\.parse\(String\(requests\[0\]\["report-data"\]'
        $script:Lock | Should -Match 'Possible duplicate requires a Match or Similar outcome'
        $script:Lock | Should -Match 'Superseded requires distinct original-delivery and replacement-or-removal evidence'
        $script:Lock | Should -Match 'result-output/shard-result\.json'
        $script:Lock | Should -Match 'actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a'
        $script:Lock | Should -Not -Match '(?m)^\s*issues: write$'
        $script:Lock | Should -Not -Match '(?m)^\s*security-events: write$'
        $script:Lock | Should -Not -Match 'create_code_scanning_alert'
    }

    It 'requires role authorization and authenticated orchestrator provenance for initial and continuation bots' {
        $script:Source | Should -Match '(?m)^  bots: \["github-actions\[bot\]"\]$'
        $script:Source | Should -Match '(?ms)^  permissions:\s+actions: read$'
        $script:Source | Should -Match '(?ms)^      continuation_authenticated:\s+.*?required: true\s+type: boolean'
        $script:Source | Should -Match "(?m)^if: needs\.pre_activation\.outputs\.trusted_caller == 'true'$"
        $script:Source | Should -Match '(?m)^      trusted_caller: \$\{\{ steps\.trusted-caller\.outputs\.trusted_caller \}\}$'
        $script:Source | Should -Match 'run\.path === "\.github/workflows/backlog-groom-orchestrator\.yml"'
        $script:Source | Should -Match 'run\.actor\?\.login === bot'
        $script:Source | Should -Match 'run\.triggering_actor\?\.login === bot'
        $script:Source | Should -Match 'context\.eventName === "schedule"'
        $script:Source | Should -Match 'run\.event === "schedule"'
        $script:Source | Should -Match 'process\.env\.CONTINUATION_AUTHENTICATED === "false"'
        $script:Source | Should -Match 'context\.eventName === "workflow_dispatch"'
        $script:Source | Should -Match 'run\.event === "workflow_dispatch"'
        $script:Source | Should -Match 'process\.env\.CONTINUATION_AUTHENTICATED === "true"'
        $script:Source | Should -Match '\(initialRun \|\| continuationRun\)'
        $script:Source | Should -Match 'String\(process\.env\.ORCHESTRATOR_RUN_ID\) === String\(context\.runId\)'
        $script:Source | Should -Match 'Number\(process\.env\.ORCHESTRATOR_ATTEMPT\) === Number\(process\.env\.GITHUB_RUN_ATTEMPT\)'

        $script:Orchestrator | Should -Match 'continuation-authenticated: \$\{\{ steps\.plan\.outputs\.continuation-authenticated \}\}'
        $script:Orchestrator | Should -Match 'core\.setOutput\("continuation-authenticated", String\(isContinuation\)\)'
        $script:Orchestrator | Should -Match 'continuation_authenticated: \$\{\{ needs\.plan\.outputs\.continuation-authenticated == ''true'' \}\}'

        $script:Lock | Should -Match 'GH_AW_REQUIRED_ROLES: "admin,maintainer,write"'
        $script:Lock | Should -Match 'GH_AW_ALLOWED_BOTS: "github-actions\[bot\]"'
        $script:Lock | Should -Match "needs\.pre_activation\.outputs\.activated == 'true' && \(needs\.pre_activation\.outputs\.trusted_caller == 'true'\)"
    }
}

Describe 'Backlog grooming sharded orchestration contracts' -Tag 'Unit' {
    It 'defines typed worker identity, manifest envelopes, and shard-specific generated concurrency' {
        foreach ($inputName in @('shard_id', 'manifest_digest', 'ordered_candidate_ids', 'orchestrator_run_id')) {
            $script:Source | Should -Match "(?ms)^      ${inputName}:\s+.*?required: true\s+type: string"
            $script:Lock | Should -Match "(?ms)^      ${inputName}:\s+.*?required: true\s+type: string"
        }
        foreach ($inputName in @('orchestrator_attempt', 'worker_timeout_minutes')) {
            $script:Source | Should -Match "(?ms)^      ${inputName}:\s+.*?type: number"
            $script:Lock | Should -Match "(?ms)^      ${inputName}:\s+.*?type: number"
        }

        $script:Source | Should -Match '(?m)^max-ai-credits: 1000$'
        $script:Source | Should -Match '(?m)^  group: gh-aw-backlog-groom-\$\{\{ inputs\.shard_id \|\| github\.run_id \}\}$'
        $script:Source | Should -Match '(?m)^  job-discriminator: \$\{\{ inputs\.shard_id \|\| github\.run_id \}\}$'
        $script:Source | Should -Match '`ordered_candidate_ids`:\s+`\$\{\{ inputs\.ordered_candidate_ids \}\}`'
        $script:Lock | Should -Match 'gh-aw-copilot-backlog-groom-\$\{\{ inputs\.shard_id \|\| github\.run_id \}\}'
        $script:Lock | Should -Match 'gh-aw-conclusion-backlog-groom-\$\{\{ inputs\.shard_id \|\| github\.run_id \}\}'
        $script:Lock | Should -Match '(?ms)^concurrency:\s+group: gh-aw-backlog-groom-\$\{\{ inputs\.shard_id \|\| github\.run_id \}\}'

        foreach ($field in @(
                'schema_version', 'run_id', 'attempt', 'shard_id', 'manifest_digest',
                'ordered_candidate_ids', 'producer', 'started_at', 'completed_at'
            )) {
            $script:Source | Should -Match "(?m)^\s+${field}(?::|,)"
        }
        $script:Source | Should -Match 'const envelope = \{ \.\.\.result, result_digest: resultDigest \}'
        $script:Source | Should -Not -Match '`result_digest`'
        $script:Orchestrator | Should -Match 'schema_version: "backlog-grooming-sweep-snapshot/v1"'
        $script:Orchestrator | Should -Match 'schema_version: "backlog-grooming-wave-manifest/v1"'
        $script:Orchestrator | Should -Match 'cursor_candidate_ids: cursorIds'
        $script:Orchestrator | Should -Match 'if \(!seen\.has\(issue\.number\)\)'
        $script:Orchestrator | Should -Not -Match 'if \(seen\.add\(issue\.number\)\)'
        $script:Orchestrator | Should -Match 'requiredWaves = Math\.max\(1, Math\.ceil\(openIssues\.length / waveCapacity\)\)'
        $script:Orchestrator | Should -Match 'createHash\("sha256"\)'
        $script:Orchestrator | Should -Match 'backlog-grooming-sweep-v1-\$\{\{ github\.repository_id \}\}-snapshot-'
        $script:Orchestrator | Should -Match 'plannedSweepAic = requiredWaves \* plannedAicPerWave'
        $script:Orchestrator | Should -Match 'Sweep capacity or AIC exceeds safe integer arithmetic'
        $script:Orchestrator | Should -Match 'prior_cursor: priorCursor'
        $script:Orchestrator | Should -Match 'core\.setOutput\("shard-matrix", JSON\.stringify\(matrix\)\)'
        $script:Orchestrator | Should -Match '(?ms)^  assess:.*?max-parallel: 2'
        $script:Orchestrator | Should -Match '(?ms)^  assess:.*?shard: \$\{\{ fromJSON\(needs\.plan\.outputs\.shard-matrix\) \}\}'
        $script:Orchestrator | Should -Match 'shard_id: \$\{\{ matrix\.shard\.shard_id \}\}'
        $script:Orchestrator | Should -Match 'ordered_candidate_ids: \$\{\{ toJSON\(matrix\.shard\.ordered_candidate_ids\) \}\}'
        $script:Orchestrator | Should -Not -Match '(?ms)^  assess:.*?shard_id: shard-01'
        $script:Orchestrator | Should -Match '(?ms)^  assess:.*?permissions:\s+actions: write\s+contents: read\s+issues: read'
        $script:Orchestrator | Should -Match '(?ms)^  assess:.*?secrets:\s+COPILOT_GITHUB_TOKEN: \$\{\{ secrets\.COPILOT_GITHUB_TOKEN \}\}\s+GH_AW_GITHUB_MCP_SERVER_TOKEN: \$\{\{ secrets\.GH_AW_GITHUB_MCP_SERVER_TOKEN \}\}\s+GH_AW_GITHUB_TOKEN: \$\{\{ secrets\.GH_AW_GITHUB_TOKEN \}\}'
        $script:Orchestrator | Should -Not -Match '(?ms)^  assess:.*?secrets: inherit'
        [regex]::Matches($script:Orchestrator, '(?m)^\s+issues: write$').Count | Should -Be 0
        [regex]::Matches($script:Publisher, '(?m)^\s+issues: write$').Count | Should -Be 1
        $script:WaveValidator | Should -Match '\$ByShard\.Count -ne \$ManifestShards\.Count'
        $script:WaveValidator | Should -Match 'Wave result set is incomplete'
        foreach ($rejection in @('missing', 'stale', 'unexpected', 'duplicate', 'manifest-mismatched')) {
            $script:WaveValidator | Should -Match ([regex]::Escape($rejection))
        }
        $script:WaveValidator | Should -Match 'Test-ExactJsonKeys -Element \$Result -Keys \$ResultKeys'
    }

    It 'fails closed on invalid shard artifact sets without issue-write access' {
        $script:Orchestrator | Should -Not -Match '(?m)^  inject:$'
        $script:Orchestrator | Should -Not -Match '(?m)^      failure-injection:$'
        $script:Orchestrator | Should -Match '(?m)^  validate-wave:$'
        $script:Orchestrator | Should -Match '(?ms)^      - name: Validate wave artifacts\s+id: validate\s+shell: pwsh\s+env:'
        $script:Orchestrator | Should -Match 'MANIFEST_PATH: wave-manifest/manifest\.json'
        $script:Orchestrator | Should -Match 'RESULTS_DIRECTORY: wave-results'
        $script:Orchestrator | Should -Match 'AGGREGATE_DIRECTORY: wave-aggregate'
        $script:Orchestrator | Should -Match 'EXPECTED_RUN_ID: \$\{\{ github\.run_id \}\}'
        $script:Orchestrator | Should -Match 'EXPECTED_ATTEMPT: \$\{\{ github\.run_attempt \}\}'
        $script:Orchestrator | Should -Match '\./scripts/security/Invoke-BacklogGroomWaveValidator\.ps1'
        $script:Orchestrator | Should -Not -Match 'uses: \./\.github/actions/backlog-groom-wave-validator'
        $script:WaveValidator | Should -Match 'Wave manifest digest mismatch'
        $script:WaveValidator | Should -Match 'Missing, duplicate, stale, unexpected, or manifest-mismatched shard result'
        $script:WaveValidator | Should -Match 'Shard result digest mismatch'
        $script:WaveValidator | Should -Match 'Wave result set is incomplete'
        $script:WaveValidator | Should -Match 'Wave issue coverage is incomplete or out of snapshot'
        [regex]::Matches($script:Orchestrator, '(?m)^\s+issues: write$').Count | Should -Be 0
        $script:Publisher | Should -Match '(?m)^  workflow_dispatch:$'
    }
}

Describe 'Backlog grooming deterministic fan-in behavior' -Tag 'Unit' {
    BeforeAll {
        $script:ShardOne = [pscustomobject]@{
            ShardId = 'shard-01'
            Inventory = 50
            Rows = @(
                [pscustomobject]@{ Issue = 1; Status = 'Assessed' },
                [pscustomobject]@{ Issue = 3; Status = 'Deferred' }
            )
        }
        $script:ShardTwo = [pscustomobject]@{
            ShardId = 'shard-02'
            Inventory = 50
            Rows = @(
                [pscustomobject]@{ Issue = 2; Status = 'Assessed' },
                [pscustomobject]@{ Issue = 4; Status = 'Assessed' }
            )
        }
    }

    It 'produces byte-equivalent normalized data for permuted result arrival' {
        $forward = Merge-GroomingShardResults -CandidateIds @(1, 2, 3, 4) -PriorCursor 0 -Results @($script:ShardOne, $script:ShardTwo)
        $reverse = Merge-GroomingShardResults -CandidateIds @(1, 2, 3, 4) -PriorCursor 0 -Results @($script:ShardTwo, $script:ShardOne)

        ($forward | ConvertTo-Json -Compress) | Should -Be ($reverse | ConvertTo-Json -Compress)
        $forward.Issues | Should -Be @(1, 2, 3, 4)
    }

    It 'reconciles global counts and advances to the final assessed issue' {
        $aggregate = Merge-GroomingShardResults -CandidateIds @(1, 2, 3, 4) -PriorCursor 0 -Results @($script:ShardOne, $script:ShardTwo)

        $aggregate.Assessed | Should -Be 3
        $aggregate.Deferred | Should -Be 1
        $aggregate.NextCursor | Should -Be 4
    }

    It 'retains the prior cursor when every planned issue is deferred' {
        $deferredOne = [pscustomobject]@{ ShardId = 'shard-01'; Inventory = 50; Rows = @([pscustomobject]@{ Issue = 1; Status = 'Deferred' }) }
        $deferredTwo = [pscustomobject]@{ ShardId = 'shard-02'; Inventory = 50; Rows = @([pscustomobject]@{ Issue = 2; Status = 'Deferred' }) }

        $aggregate = Merge-GroomingShardResults -CandidateIds @(1, 2) -PriorCursor 19 -Results @($deferredOne, $deferredTwo)

        $aggregate.NextCursor | Should -Be 19
    }

    It 'rejects a missing planned shard result' {
        { Merge-GroomingShardResults -CandidateIds @(1, 3) -PriorCursor 0 -Results @($script:ShardOne) } |
            Should -Throw '*shard-02 expected exactly one result, found 0*'
    }

    It 'rejects a second result for one planned shard' {
        { Merge-GroomingShardResults -CandidateIds @(1, 2, 3, 4) -PriorCursor 0 -Results @($script:ShardOne, $script:ShardOne, $script:ShardTwo) } |
            Should -Throw '*shard-01 expected exactly one result, found 2*'
    }

    It 'rejects inconsistent inventory snapshots' {
        $mismatched = [pscustomobject]@{ ShardId = 'shard-02'; Inventory = 51; Rows = $script:ShardTwo.Rows }

        { Merge-GroomingShardResults -CandidateIds @(1, 2, 3, 4) -PriorCursor 0 -Results @($script:ShardOne, $mismatched) } |
            Should -Throw '*shard inventory counts disagree*'
    }

    It 'enforces selected planner ceilings and aggregate construction after validation' {
        $script:Orchestrator | Should -Match '(?m)^  SWEEP_SHARD_COUNT: 2$'
        $script:Orchestrator | Should -Match '(?m)^  SWEEP_SHARD_WIDTH: 5$'
        $script:Orchestrator | Should -Match '(?m)^  SWEEP_MAX_PARALLEL: 2$'
        $script:Orchestrator | Should -Match '(?m)^  SWEEP_PER_WORKER_AIC: 1000$'
        $script:Orchestrator | Should -Match 'schema_version: "backlog-grooming-sweep-aggregate/v1"'
        $script:Orchestrator | Should -Match 'next_cursor: cursorRows\.length > 0 \? cursorRows\.at\(-1\)\.issue : snapshot\.prior_cursor'
        $script:Orchestrator | Should -Match 'Upload final detailed sweep evidence'
    }
}

Describe 'Backlog grooming production publisher' -Tag 'Unit' {
    It 'isolates the sole issue-write permission behind complete fan-in' {
        [regex]::Matches($script:Orchestrator, '(?m)^\s+issues: write$').Count | Should -Be 0
        [regex]::Matches($script:Publisher, '(?m)^\s+issues: write$').Count | Should -Be 1
        $script:Publisher | Should -Match '(?m)^  workflow_dispatch:$'
        $script:Publisher | Should -Match '(?ms)^  workflow_run:\s+workflows:\s+- Backlog Grooming Sweep\s+branches:\s+- main\s+types:\s+- completed'
        $script:Publisher | Should -Match 'context\.payload\.workflow_run\?\.id'
        $script:Publisher | Should -Match 'const manualReplay = !automaticRunId'
        $script:Publisher | Should -Match 'manualReplay\s+\? parsePositiveInteger\("final-run-id", process\.env\.FINAL_RUN_ID\)'
        $script:Publisher | Should -Match 'run\.head_branch !== repository\.default_branch'
        $script:Publisher | Should -Match 'run\.head_sha !== defaultRef\.object\.sha'
        $script:Publisher | Should -Match 'Publication requires the current default-branch orchestrator revision'
        $script:Publisher | Should -Match 'Completed orchestrator run is nonterminal; publication is not required'
        $script:Publisher | Should -Match "if: \$\{\{ needs\.discover\.outputs\.terminal == 'true' \}\}"
        $script:Publisher | Should -Match '(?m)^          artifact-ids: \$\{\{ steps\.authenticate\.outputs\.final-artifact-id \}\}$'
        $script:Publisher | Should -Match 'run\.path !== "\.github/workflows/backlog-groom-orchestrator\.yml"'
        $script:Orchestrator | Should -Match '(?ms)^  assess:.*?permissions:\s+actions: write\s+contents: read\s+issues: read'
        $script:Source | Should -Not -Match '(?m)^\s+issues: write$'
        $script:Lock | Should -Not -Match '(?m)^\s+issues: write$'
    }

    It 'automates terminal publication while scheduling only the first Monday sweep' {
        $script:Orchestrator | Should -Not -Match '(?m)^      publish-report:$'
        $script:Orchestrator | Should -Not -Match '(?m)^      failure-injection:$'
        $script:Publisher | Should -Not -Match '(?m)^  schedule:$'
        $script:Orchestrator | Should -Match "(?ms)^  schedule:\s+- cron: '0 9 \* \* 1'"
        $script:Orchestrator | Should -Match 'context\.eventName === "schedule" && new Date\(\)\.getUTCDate\(\) > 7'
        $script:Orchestrator | Should -Match 'core\.setOutput\("mode", "calendar-noop"\)'
        $script:Orchestrator | Should -Match "INPUT_PROTOCOL_VERSION: \$\{\{ inputs\.protocol-version \|\| 'backlog-grooming-sweep/v1' \}\}"
        $script:Orchestrator | Should -Match 'INPUT_WAVE_NUMBER: \$\{\{ inputs\.wave-number \|\| 1 \}\}'
        $script:Orchestrator | Should -Match "steps\.plan\.outputs\.mode != 'calendar-noop'"
        $script:Orchestrator | Should -Match "needs\.plan\.outputs\.mode != 'calendar-noop'"
        $script:Orchestrator | Should -Match "needs\.plan\.outputs\.mode != 'complete-noop'"
        $script:Publisher | Should -Match "github\.event\.workflow_run\.conclusion == 'success'"
        $script:Source | Should -Match '(?m)^  workflow_call:$'
        $script:Source | Should -Not -Match '(?m)^  (schedule|workflow_dispatch):$'
    }

    It 'revalidates aggregate identity, digest, counts, and cursor before writing' {
        $script:Publisher | Should -Match 'Final sweep aggregate failed trusted publication validation'
        $script:Publisher | Should -Match 'digest\(material\) !== recordedDigest'
        $script:Publisher | Should -Match 'aggregate\.assessed \+ aggregate\.deferred !== aggregate\.total_snapshot_count'
        $script:Publisher | Should -Match 'aggregate\.checkpoint_digests\.length !== aggregate\.completed_waves'
        $script:Publisher | Should -Match 'artifact\.workflow_run\?\.id !== finalRunId'
        $script:Orchestrator | Should -Match 'Final result set does not exactly equal the snapshot'
        $script:Orchestrator | Should -Match 'snapshot\.cursor_candidate_ids\.map'
        $script:Orchestrator | Should -Match 'predecessor_aggregate_digest: snapshot\.prior_published_aggregate_digest'
        $script:Publisher | Should -Not -Match 'observed_aic|Observed AIC'
    }

    It 're-resolves only the trusted bot-owned marker tracker before one create or update' {
        $script:CorePublisher | Should -Match 'const marker = "<!-- gh-aw:backlog-grooming-tracker -->"'
        $script:CorePublisher | Should -Match 'const resolveTrustedTrackerState = async \(\) =>'
        $script:CorePublisher | Should -Match 'github\.rest\.issues\.listForRepo'
        $script:CorePublisher | Should -Match 'issue\.user\?\.login === "github-actions\[bot\]"'
        $script:CorePublisher | Should -Match 'issue\.user\?\.type === "Bot"'
        $script:CorePublisher | Should -Match 'Multiple trusted backlog grooming trackers are ambiguous'
        $script:CorePublisher | Should -Match 'mutationTrackerState\.aggregateDigest === aggregate\.aggregate_digest'
        $script:CorePublisher | Should -Match 'publication is idempotent'
        $script:CorePublisher | Should -Match 'Trusted marker-only tracker accepted for initial publication'
        $script:CorePublisher | Should -Match 'aggregate\.predecessor_aggregate_digest !== null'
        $script:CorePublisher | Should -Match 'initialTrackerState\.aggregateDigest !== aggregate\.predecessor_aggregate_digest'
        $script:CorePublisher | Should -Match 'tracker changed after this sweep snapshot was captured'
        [regex]::Matches($script:CorePublisher, 'await resolveTrustedTrackerState\(\)').Count | Should -Be 2
        $refreshIndex = $script:CorePublisher.LastIndexOf('await resolveTrustedTrackerState()')
        $mutationIndex = $script:CorePublisher.IndexOf('await github.rest.issues.create({')
        $mutationIndex | Should -BeGreaterThan $refreshIndex
        $script:CorePublisher | Should -Match 'mutationTrackerState\.fingerprint !== initialTrackerState\.fingerprint'
        $script:CorePublisher | Should -Match 'tracker identity or state changed before mutation'
        $script:CorePublisher | Should -Match 'issue_number: mutationTrackerState\.tracker\.number'
        $script:CorePublisher | Should -Not -Match 'issue_number: trackers\[0\]\.number'
        [regex]::Matches($script:CorePublisher, 'github\.rest\.issues\.create\(').Count | Should -Be 1
        [regex]::Matches($script:CorePublisher, 'github\.rest\.issues\.update\(').Count | Should -Be 1
        $script:CorePublisher | Should -Match 'title: "Backlog grooming tracker"'
        $script:HistoryPublisher | Should -Not -Match 'github\.rest\.issues\.'
    }

    It 'has no candidate mutation or comment path and writes summary after persistence' {
        $script:Publisher | Should -Not -Match 'github\.rest\.issues\.(createComment|addLabels|removeLabel|lock|unlock)'
        $script:Publisher | Should -Not -Match 'issue_number: row\.issue'
        $updateIndex = $script:Publisher.IndexOf('await github.rest.issues.update({')
        $summaryIndex = $script:Publisher.LastIndexOf('await core.summary.addRaw(report).write();')
        $updateIndex | Should -BeGreaterThan -1
        $summaryIndex | Should -BeGreaterThan $updateIndex
    }

    It 'gates the complete non-blocking optional publication unit with an exact repository variable' {
        [regex]::Matches(
            $script:Publisher,
            "(?m)^    if: \$\{\{ vars\.BACKLOG_GROOM_PUBLISH_GH_PAGES == 'true' \}\}$"
        ).Count | Should -Be 1
        [regex]::Matches($script:Publisher, '(?m)^    continue-on-error: true$').Count | Should -Be 1
        $script:HistoryPublisher | Should -Match '(?ms)^  publish-history:.*?needs:\s+- discover\s+- publish'
        $script:CorePublisher | Should -Match '(?ms)^  publish:.*?permissions:\s+actions: read\s+issues: write'
        $script:CorePublisher | Should -Not -Match 'contents: write|GitHub Pages|pagesRoot|reportUrl|backlog-grooming-reports'
        $script:CorePublisher | Should -Match 'Inspect the \[source workflow run\]'
        $script:HistoryPublisher | Should -Match '(?ms)permissions:\s+actions: read\s+contents: write'
        $script:HistoryPublisher | Should -Not -Match 'issues: write'
        $script:HistoryPublisher | Should -Match 'actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a'
    }

    It 'enables optional publication only for the exact lowercase value <Value>' -ForEach @(
        @{ Value = 'true'; Expected = $true }
        @{ Value = ''; Expected = $false }
        @{ Value = 'TRUE'; Expected = $false }
        @{ Value = 'True'; Expected = $false }
        @{ Value = 'false'; Expected = $false }
        @{ Value = '1'; Expected = $false }
    ) {
        Test-OptionalPublicationEnabled -Value $Value | Should -Be $Expected
    }

    It 'persists accessible historical reports before recording immutable provenance' {
        $script:HistoryPublisher | Should -Match 'const reportsBranch = "backlog-grooming-reports"'
        $script:HistoryPublisher | Should -Match 'backlog-grooming/sweeps/\$\{reportSlug\}/index\.html'
        $script:HistoryPublisher | Should -Match 'backlog-grooming/history\.json'
        $script:HistoryPublisher | Should -Match 'const escapeHtml = \(value\) =>'
        $script:HistoryPublisher | Should -Match 'github\.rest\.git\.createBlob'
        $script:HistoryPublisher | Should -Match 'github\.rest\.git\.createTree'
        $script:HistoryPublisher | Should -Match 'github\.rest\.git\.createCommit'
        $script:HistoryPublisher | Should -Match 'authenticatedReportRef\.object\.sha !== reportCommitSha'
        $script:HistoryPublisher | Should -Match 'Report history commit is not the current authenticated branch head'
        $script:HistoryPublisher.IndexOf('authenticatedReportRef.object.sha !== reportCommitSha') |
            Should -BeLessThan $script:HistoryPublisher.IndexOf('core.setOutput("report-commit-sha", reportCommitSha)')
        $script:HistoryPublisher | Should -Match '<caption>Issue assessments for \$\{escapeHtml\(reportSlug\)\}</caption>'
        $script:HistoryPublisher | Should -Match '<caption>Published backlog grooming sweeps</caption>'
        [regex]::Matches($script:HistoryPublisher, '<th scope=(?:"|\\")col(?:"|\\")>').Count |
            Should -BeGreaterOrEqual 12
        [regex]::Matches($script:HistoryPublisher, '<th scope="row">').Count | Should -Be 2
        $script:HistoryPublisher | Should -Match '<summary>Evidence for issue #\$\{escapeHtml\(row\.issue\)\}</summary>'
        $script:HistoryPublisher | Should -Match 'backlog-grooming-pages-provenance-\$\{\{ github\.run_id \}\}'
        $script:HistoryPublisher | Should -Match 'publisher_run_id: String\(context\.runId\)'
        $script:HistoryPublisher | Should -Match 'publisher_source_sha: context\.sha'
        $script:HistoryPublisher | Should -Match 'provenance_digest: crypto\.createHash\("sha256"\)'
    }

    It 'stages reports only from immutable provenance bound to a successful publisher run' {
        $script:DeployDocs | Should -Match '(?ms)^  workflow_run:\s+workflows:\s+- Backlog Grooming Publisher\s+branches:\s+- main\s+types:\s+- completed'
        $script:DeployDocs | Should -Match "github\.event_name == 'workflow_run' && github\.event\.workflow_run\.conclusion == 'success'"
        $script:DeployDocs | Should -Match 'run\.path !== "\.github/workflows/backlog-groom-publisher\.yml"'
        $script:DeployDocs | Should -Match 'github\.rest\.actions\.listWorkflowRunArtifacts'
        $script:DeployDocs | Should -Match 'Publisher run must contain exactly one immutable Pages provenance artifact'
        $script:DeployDocs | Should -Match 'artifact-ids: \$\{\{ steps\.reports\.outputs\.artifact-id \}\}'
        $script:DeployDocs | Should -Match 'provenance\.publisher_run_id !== String\(run\.id\)'
        $script:DeployDocs | Should -Match 'provenance\.publisher_run_attempt !== run\.run_attempt'
        $script:DeployDocs | Should -Match 'provenance\.publisher_source_sha !== run\.head_sha'
        $script:DeployDocs | Should -Match 'recordedDigest !== computedDigest'
        $script:DeployDocs | Should -Match 'Pages provenance is not bound to the triggering publisher run'
        $script:DeployDocs | Should -Not -Match 'const reportsBranch = "backlog-grooming-reports"|requestedRef|report-ref'
        $script:DeployDocs | Should -Match 'ref: \$\{\{ steps\.provenance\.outputs\.ref \}\}'
        $script:DeployDocs | Should -Match 'docs/docusaurus/build/backlog-grooming'
    }
}

Describe 'Backlog grooming policy and agent' -Tag 'Unit' {
    It 'keeps the reusable policy workflow-neutral' {
        $script:Policy | Should -Match 'Assess an ordinary GitHub issue inventory'
        $script:Policy | Should -Match 'When the caller supplies a bounded inventory,\s+assess only that inventory'
        $script:Policy | Should -Match 'paginate until\s+the complete relevant inventory'
        $script:Policy | Should -Match 'Do not impose an age threshold as an eligibility rule'
        foreach ($automationTerm in @('shard', 'manifest', 'digest', 'safe-output', 'safe output', 'artifact', 'checkpoint', 'publisher', 'ordered candidate')) {
            $script:Policy | Should -Not -Match ([regex]::Escape($automationTerm))
        }
    }

    It 'defines the compact report and qualitative outcomes' {
        $script:Policy | Should -Match '\| Issue \| Similarity \| Disposition \| Status \| Recommended next step \|'
        $script:Policy | Should -Match '### Issue #123: Example title'
        $script:Policy | Should -Match '\* Repository evidence:'
        $script:Policy | Should -Match '\* Grooming finding:'
        $script:Policy | Should -Not -Match '\| Issue \| Title \| Selection reason \| Activity and ownership context \|'
        foreach ($outcome in @('Match', 'Similar', 'Distinct', 'Uncertain')) {
            $script:Policy | Should -Match "\* ``$outcome``"
        }
    }

    It 'gives the model the exact structured publisher contract' {
        foreach ($key in @('timestamp', 'total_open_inventory', 'assessed', 'priority_cohort', 'round_robin_cohort', 'deferred', 'stop_reason', 'next_cursor')) {
            $script:Agent | Should -Match ([regex]::Escape("`"$key`""))
        }
        foreach ($key in @('issue', 'title', 'selection_reason', 'activity_and_ownership_context', 'acceptance_signals', 'repository_evidence', 'lineage_evidence', 'original_delivery', 'replacement_or_removal', 'similarity_outcome', 'disposition', 'grooming_finding', 'recommended_next_step', 'assessment_status', 'deferral_reason')) {
            $script:Agent | Should -Match ([regex]::Escape("`"$key`""))
        }
        $script:Agent | Should -Match 'Use integers without `#` or prose for `issue`, `next_cursor`, and every count'
        $script:Agent | Should -Match 'Use exactly `Assessed` or `Deferred` for `assessment_status`'
        $script:Agent | Should -Match 'For `Deferred`, use a\s+non-empty `deferral_reason`, `Uncertain` similarity and disposition, and empty\s+lineage arrays'
        $script:Agent | Should -Match 'put compared issue numbers in the finding rather than the\s+enum value'
        [regex]::Matches($script:Source, 'result_digest').Count | Should -Be 1
        $script:Source | Should -Match 'return only the canonical Backlog Grooming Report required by the\s+imported agent'
    }

    It 'requires repository-grounded dispositions and evidence-backed maintainer actions' {
        $script:Agent | Should -Match 'extract.*requested outcomes.*acceptance signals'
        $script:Agent | Should -Match 'default branch.*code.*configuration.*documentation'
        $script:Agent | Should -Match 'open, merged, and closed pull requests'
        $script:Agent | Should -Match 'open and closed issues'
        $script:Agent | Should -Match 'commits or releases'
        $script:Agent | Should -Match 'Use `Uncertain` when'
        $script:Agent | Should -Match 'unlinked pull requests and commits as valid lineage evidence'
        $script:Policy | Should -Match 'Direct issue linkage is not required'
        $script:Source | Should -Match 'Do not require a direct issue link'
        $script:Policy | Should -Match '\| Issue \| Similarity \| Disposition \| Status \| Recommended next step \|'
        foreach ($disposition in @('Still needed', 'Likely completed', 'Superseded', 'Possible duplicate', 'Needs correction', 'Uncertain')) {
            $script:Policy | Should -Match "\* ``$disposition``"
        }
        $script:Policy | Should -Match 'recommend that a maintainer close the\s+issue'
        $script:Policy | Should -Match 'recommend specific title or body corrections'
        $script:Agent | Should -Not -Match 'Do not add closure language, mutation proposals'
    }

    It 'requires complete legacy and replacement lineage for superseded work' {
        $script:Agent | Should -Match 'For `Superseded`, record both the original surface''s delivery lineage and its\s+removal or replacement lineage when both are available'
        $script:Policy | Should -Match 'cite the original\s+surface''s delivery issue or pull request and the later removal or replacement\s+issue or pull request'
        $script:Agent | Should -Match '`lineage_evidence` with exactly\s+`original_delivery` and `replacement_or_removal` arrays'
        $script:Agent | Should -Match 'For `Superseded`, both\s+arrays contain non-empty, distinct'
    }

    It 'defines discriminating evidence rules for representative dispositions' -ForEach @(
        @{
            Scenario = 'implemented capability on the default branch with merged delivery history'
            Disposition = 'Likely completed'
            EvidencePattern = 'default-branch evidence satisfies.*acceptance signals.*merged pull-request, commit, or release evidence'
        },
        @{
            Scenario = 'legacy surface removed and replaced by a current capability'
            Disposition = 'Superseded'
            EvidencePattern = 'named surface was removed,\s+replaced, or intentionally abandoned.*replacement or\s+decision history'
        },
        @{
            Scenario = 'requested outcome remains absent with no completing work'
            Disposition = 'Still needed'
            EvidencePattern = 'requested outcome is\s+absent or incomplete.*no merged or closed work establishes completion'
        },
        @{
            Scenario = 'matching issue has no distinct repository need'
            Disposition = 'Possible duplicate'
            EvidencePattern = 'similarity outcome is `Match` or `Similar`.*same outcome.*does\s+not establish a distinct remaining need'
        },
        @{
            Scenario = 'issue text conflicts with current repository facts'
            Disposition = 'Needs correction'
            EvidencePattern = 'title or body conflicts with verified current\s+paths, names, behavior, or scope.*corrected issue would still describe\s+useful work'
        },
        @{
            Scenario = 'acceptance or repository history is ambiguous'
            Disposition = 'Uncertain'
            EvidencePattern = 'acceptance signals are ambiguous.*searches cannot be\s+completed.*evidence conflicts'
        }
    ) {
        $script:Policy | Should -Match "``$Disposition``:"
        $script:Policy | Should -Match "(?s)$EvidencePattern"
    }

    It 'keeps candidate content inert and sensitive output minimized' {
        $script:Agent | Should -Match 'untrusted\s+inert data'
        $script:Policy | Should -Match 'escape backslashes\s+and pipe characters'
        $script:Policy | Should -Match 'replace line breaks with `<br>`'
        $script:Policy | Should -Match 'zero-width space\s+after `@`'
        $script:Policy | Should -Match 'sensitive context omitted'
        $script:Agent | Should -Match 'Do not close, create, edit, assign, milestone, label, or comment on candidate'
    }
}

Describe 'Interactive grooming route and fresh-state execution' -Tag 'Unit' {
    It 'classifies grooming without stealing triage or ordinary single-issue requests' {
        foreach ($signal in @('groom', 'grooming', 'staleness', 'backlog health')) {
            $script:Manager | Should -Match ([regex]::Escape($signal))
        }
        $script:Manager | Should -Match '`needs-triage` indicates Triage'
        $script:Manager | Should -Match 'explicit item key or single-entity phrasing scopes the request to Single Item unless the request explicitly reviews a grooming digest'
    }

    It 'applies reusable grooming policy directly without a child-agent dispatch' {
        $script:Manager | Should -Not -Match '(?m)^  - Backlog Grooming$'
        $script:Manager | Should -Match '#file:\.\./\.\./instructions/project-planning/github-backlog-grooming\.instructions\.md'
        $script:Manager | Should -Match '\| Grooming\s+\| Apply `github-backlog-grooming\.instructions\.md` directly with ordinary GitHub issue inventory and repository evidence'
        $script:Manager | Should -Match 'Do not dispatch the repository-only AW worker'
    }

    It 'limits grooming handoffs to one approved non-closing operation per issue' {
        $script:Policy | Should -Match 'only\s+`Update` or `Comment` operations'
        $script:Policy | Should -Match 'at most one mutating operation per issue'
        $script:Policy | Should -Match 'It never contains `Close`'
        $script:Policy | Should -Match 'Require explicit per-field approval'
    }

    It 'enforces operation-specific Grooming mutation field allowlists' {
        foreach ($fields in @(@('title'), @('body'), @('title', 'body'))) {
            Test-GroomingMutationFields -Action Update -MutationFields $fields | Should -BeTrue
        }
        Test-GroomingMutationFields -Action Comment -MutationFields @('body') | Should -BeTrue

        foreach ($field in @('labels', 'assignees', 'milestone', 'state', 'state_reason', 'type', 'duplicate_of', 'unsupported')) {
            Test-GroomingMutationFields -Action Update -MutationFields @($field) | Should -BeFalse
        }
        Test-GroomingMutationFields -Action Comment -MutationFields @('title') | Should -BeFalse

        $script:Executor | Should -Match 'For a Grooming Update, accept `title` and `body` as the only mutation fields'
        $script:Executor | Should -Match 'For a Grooming Comment, accept `body` as the only mutation field'
        $script:Executor | Should -Match 'Reject `labels`, `assignees`, `milestone`, `state`, `state_reason`, `type`, `duplicate_of`'
        $script:Executor | Should -Match 'Immediately before each Grooming Update or Comment API call, revalidate'
    }

    It 'suppresses stale mutations and requires renewed approval' {
        $script:Executor | Should -Match 'Immediately before an Update or Comment carrying `Expected Updated At`'
        $script:Executor | Should -Match 'Compare the returned `updated_at` string exactly'
        $script:Executor | Should -Match 'do not call a mutation tool'
        $script:Executor | Should -Match 'Skipped: stale approval'
        $script:Executor | Should -Match 'Expected Updated At` and `Observed Updated At`'
        $script:Executor | Should -Match 'rehydrate the issue and obtain renewed approval'
    }
}

Describe 'Backlog grooming continuation behavior' -Tag 'Unit' {
    BeforeAll {
        $script:Baseline = [datetime]'2026-07-01T00:00:00Z'
        $script:Inventory = @(1..105 | ForEach-Object {
                [pscustomobject]@{
                    Number = $_
                    State = 'open'
                    PullRequest = $false
                    UpdatedAt = if ($_ -eq 105) { $script:Baseline.AddDays(1) } else { $script:Baseline.AddDays(-1) }
                }
            })
    }

    It 'advances across successive runs while preserving priority and wraparound cohorts' {
        $firstRun = Select-GroomingCohort -Issues $script:Inventory -PreviousCursor 100 -PreviousRun $script:Baseline -Capacity 4
        $firstRun.Selected.Number | Should -Be @(105, 101, 102, 103)
        $firstRun.Priority | Should -Be @(105)
        $firstRun.RoundRobin | Should -Be @(101, 102, 103)
        $firstRun.NextCursor | Should -Be 103

        $secondRun = Select-GroomingCohort -Issues $script:Inventory -PreviousCursor $firstRun.NextCursor -PreviousRun $script:Baseline.AddDays(2) -Capacity 4
        $secondRun.Selected.Number | Should -Be @(104, 105, 1, 2)
        $secondRun.RoundRobin | Should -Be @(104, 105, 1, 2)
        $secondRun.NextCursor | Should -Be 2
    }

    It 'uses the last assessed priority issue as the cursor when capacity is exhausted' {
        $run = Select-GroomingCohort -Issues $script:Inventory -PreviousCursor 100 -PreviousRun $script:Baseline -Capacity 1

        $run.Selected.Number | Should -Be @(105)
        $run.Priority | Should -Be @(105)
        $run.RoundRobin | Should -Be @()
        $run.NextCursor | Should -Be 105
    }

    It 'creates the fixed-title tracker when no non-pull-request match exists' {
        $marker = '<!-- gh-aw:backlog-grooming-tracker -->'
        $creates = [System.Collections.Generic.List[object]]::new()
        $updates = [System.Collections.Generic.List[object]]::new()
        $summaries = [System.Collections.Generic.List[string]]::new()
        $failures = [System.Collections.Generic.List[string]]::new()

        Publish-GroomingReport -Report 'Canonical report with enough content' -Issues @() `
            -CreateSink { param($title, $body) $creates.Add([pscustomobject]@{ Title = $title; Body = $body }) } `
            -UpdateSink { param($number, $body, $state) $updates.Add([pscustomobject]@{ Number = $number; Body = $body; State = $state }) } `
            -SummarySink { param($value) $summaries.Add($value) } `
            -FailureSink { param($value) $failures.Add($value) }

        $creates | Should -HaveCount 1
        $creates[0].Title | Should -BeExactly 'Backlog grooming tracker'
        $creates[0].Body | Should -BeExactly "$marker`n`n$($summaries[0])"
        $updates | Should -HaveCount 0
        $failures | Should -HaveCount 0
    }

    It 'updates and reopens the sole tracker with full body replacement' {
        $marker = '<!-- gh-aw:backlog-grooming-tracker -->'
        foreach ($state in @('open', 'closed')) {
            $creates = [System.Collections.Generic.List[object]]::new()
            $updates = [System.Collections.Generic.List[object]]::new()
            $summaries = [System.Collections.Generic.List[string]]::new()
            $failures = [System.Collections.Generic.List[string]]::new()
            $tracker = [pscustomobject]@{
                Number = 10
                State = $state
                PullRequest = $false
                Body = "$marker`n`nOld report"
                User = [pscustomobject]@{ Login = 'github-actions[bot]'; Type = 'Bot' }
            }

            Publish-GroomingReport -Report "Replacement report for $state tracker" -Issues @($tracker) `
                -CreateSink { param($title, $body) $creates.Add([pscustomobject]@{ Title = $title; Body = $body }) } `
                -UpdateSink { param($number, $body, $newState) $updates.Add([pscustomobject]@{ Number = $number; Body = $body; State = $newState }) } `
                -SummarySink { param($value) $summaries.Add($value) } `
                -FailureSink { param($value) $failures.Add($value) }

            $creates | Should -HaveCount 0
            $updates | Should -HaveCount 1
            $updates[0].Number | Should -Be 10
            $updates[0].State | Should -BeExactly 'open'
            $updates[0].Body | Should -BeExactly "$marker`n`n$($summaries[0])"
            $updates[0].Body | Should -Not -Match 'Old report'
            $failures | Should -HaveCount 0
        }
    }

    It 'fails without mutation for every multiple-tracker state combination' {
        $marker = '<!-- gh-aw:backlog-grooming-tracker -->'
        foreach ($states in @(@('open', 'open'), @('closed', 'closed'), @('open', 'closed'))) {
            $issues = @(0..1 | ForEach-Object {
                    [pscustomobject]@{
                        Number = 10 + $_
                        State = $states[$_]
                        PullRequest = $false
                        Body = $marker
                        User = [pscustomobject]@{ Login = 'github-actions[bot]'; Type = 'Bot' }
                    }
                })
            $creates = [System.Collections.Generic.List[object]]::new()
            $updates = [System.Collections.Generic.List[object]]::new()
            $summaries = [System.Collections.Generic.List[string]]::new()
            $failures = [System.Collections.Generic.List[string]]::new()

            Publish-GroomingReport -Report 'Canonical report with enough content' -Issues $issues `
                -CreateSink { param($title, $body) $creates.Add(@($title, $body)) } `
                -UpdateSink { param($number, $body, $state) $updates.Add(@($number, $body, $state)) } `
                -SummarySink { param($value) $summaries.Add($value) } `
                -FailureSink { param($value) $failures.Add($value) }

            $creates | Should -HaveCount 0
            $updates | Should -HaveCount 0
            $summaries | Should -HaveCount 0
            $failures | Should -HaveCount 1
        }
    }

    It 'excludes marker-bearing pull requests and creates the tracker' {
        $marker = '<!-- gh-aw:backlog-grooming-tracker -->'
        $pullRequest = [pscustomobject]@{
            Number = 20
            State = 'open'
            PullRequest = $true
            Body = $marker
            User = [pscustomobject]@{ Login = 'github-actions[bot]'; Type = 'Bot' }
        }
        $creates = [System.Collections.Generic.List[object]]::new()
        $updates = [System.Collections.Generic.List[object]]::new()

        Publish-GroomingReport -Report 'Canonical report with enough content' -Issues @($pullRequest) `
            -CreateSink { param($title, $body) $creates.Add([pscustomobject]@{ Title = $title; Body = $body }) } `
            -UpdateSink { param($number, $body, $state) $updates.Add(@($number, $body, $state)) } `
            -SummarySink { param($value) } `
            -FailureSink { param($value) }

        $creates | Should -HaveCount 1
        $updates | Should -HaveCount 0
    }

    It 'ignores an untrusted marker-bearing issue and creates the tracker' {
        $marker = '<!-- gh-aw:backlog-grooming-tracker -->'
        $untrusted = [pscustomobject]@{
            Number = 20
            State = 'open'
            PullRequest = $false
            Body = $marker
            User = [pscustomobject]@{ Login = 'contributor'; Type = 'User' }
        }
        $creates = [System.Collections.Generic.List[object]]::new()
        $updates = [System.Collections.Generic.List[object]]::new()

        Publish-GroomingReport -Report 'Canonical report with enough content' -Issues @($untrusted) `
            -CreateSink { param($title, $body) $creates.Add([pscustomobject]@{ Title = $title; Body = $body }) } `
            -UpdateSink { param($number, $body, $state) $updates.Add(@($number, $body, $state)) } `
            -SummarySink { param($value) } `
            -FailureSink { param($value) }

        $creates | Should -HaveCount 1
        $updates | Should -HaveCount 0
    }

    It 'updates only the trusted tracker in a mixed marker set' {
        $marker = '<!-- gh-aw:backlog-grooming-tracker -->'
        $trusted = [pscustomobject]@{
            Number = 10
            State = 'open'
            PullRequest = $false
            Body = $marker
            User = [pscustomobject]@{ Login = 'github-actions[bot]'; Type = 'Bot' }
        }
        $untrusted = [pscustomobject]@{
            Number = 20
            State = 'open'
            PullRequest = $false
            Body = $marker
            User = [pscustomobject]@{ Login = 'contributor'; Type = 'User' }
        }
        $creates = [System.Collections.Generic.List[object]]::new()
        $updates = [System.Collections.Generic.List[object]]::new()

        Publish-GroomingReport -Report 'Canonical report with enough content' -Issues @($trusted, $untrusted) `
            -CreateSink { param($title, $body) $creates.Add([pscustomobject]@{ Title = $title; Body = $body }) } `
            -UpdateSink { param($number, $body, $state) $updates.Add([pscustomobject]@{ Number = $number; Body = $body; State = $state }) } `
            -SummarySink { param($value) } `
            -FailureSink { param($value) }

        $creates | Should -HaveCount 0
        $updates | Should -HaveCount 1
        $updates[0].Number | Should -Be 10
    }

    It 'does not write the summary when tracker persistence fails' {
        $marker = '<!-- gh-aw:backlog-grooming-tracker -->'
        $tracker = [pscustomobject]@{
            Number = 10
            State = 'open'
            PullRequest = $false
            Body = $marker
            User = [pscustomobject]@{ Login = 'github-actions[bot]'; Type = 'Bot' }
        }
        foreach ($issues in @(@(), @($tracker))) {
            $summaryReports = [System.Collections.Generic.List[string]]::new()

            {
                Publish-GroomingReport -Report 'Canonical report with enough content' -Issues $issues `
                    -CreateSink { param($title, $body) throw 'Persistence failed' } `
                    -UpdateSink { param($number, $body, $state) throw 'Persistence failed' } `
                    -SummarySink { param($value) $summaryReports.Add($value) } `
                    -FailureSink { param($value) }
            } | Should -Throw '*Persistence failed*'

            $summaryReports | Should -HaveCount 0
        }
    }

    It 'publishes one sanitized deferred report identically to persistence and summary' {
        $report = New-GroomingReport -Run @{
            Timestamp = '2026-07-29T09:23:00Z'
            Total = 105
            Assessed = 1
            Priority = 1
            RoundRobin = 1
            Deferred = 1
            StopReason = 'Budget reserved for report publication'
            NextCursor = 2
        } -Rows @(
            [pscustomobject]@{
                Number = 105
                Title = 'Assigned issue'
                SelectionReason = 'Priority'
                Context = 'Assigned today'
                Evidence = 'src/current.md; PR #17 merged'
                Similarity = 'Distinct'
                Disposition = 'Still needed'
                Finding = 'Current'
                NextStep = 'No change'
                Status = 'Assessed'
            },
            [pscustomobject]@{
                Number = 2
                Title = 'Deferred issue'
                SelectionReason = 'Round-robin'
                Context = 'Not hydrated'
                Evidence = 'Not collected'
                Similarity = 'Uncertain'
                Disposition = 'Uncertain'
                Finding = 'Deferred: report budget reached'
                NextStep = 'Assess next run'
                Status = 'Deferred'
            }
        )

        $marker = '<!-- gh-aw:backlog-grooming-tracker -->'
        $summaryReports = [System.Collections.Generic.List[string]]::new()
        $trackerBodies = [System.Collections.Generic.List[string]]::new()
        Publish-GroomingReport -Report "$report`nOwner: @maintainer`u{0007}" `
            -Issues @() `
            -CreateSink { param($title, $body) $trackerBodies.Add($body) } `
            -UpdateSink { param($number, $body, $state) } `
            -SummarySink { param($value) $summaryReports.Add($value) } `
            -FailureSink { param($value) }

        $summaryReports.Count | Should -Be 1
        $trackerBodies.Count | Should -Be 1
        $trackerBodies[0] | Should -BeExactly "$marker`n`n$($summaryReports[0])"
        $summaryReports[0] | Should -Match '@\u200bmaintainer'
        $summaryReports[0] | Should -Not -Match '\x07'
        $summaryReports[0] | Should -Match '\| #2 \| Deferred issue .*\| Deferred \|'
        $summaryReports[0] | Should -Match '\| 2026-07-29T09:23:00Z \| 105 \| 1 \| 1 \| 1 \| 1 .*\| 2 \|'
    }

    It 'persists a successful no-action report before writing the summary' {
        $report = New-GroomingReport -Run @{
            Timestamp = '2026-07-30T09:23:00Z'
            Total = 0
            Assessed = 0
            Priority = 0
            RoundRobin = 0
            Deferred = 0
            StopReason = 'No open issues'
            NextCursor = 0
        } -Rows @(
            [pscustomobject]@{
                Number = '-'
                Title = 'No issues assessed'
                SelectionReason = '-'
                Context = '-'
                Evidence = '-'
                Similarity = '-'
                Disposition = '-'
                Finding = 'No maintainer action'
                NextStep = 'None'
                Status = 'Assessed'
            }
        )
        $summaryReports = [System.Collections.Generic.List[string]]::new()
        $trackerBodies = [System.Collections.Generic.List[string]]::new()

        Publish-GroomingReport -Report $report `
            -Issues @() `
            -CreateSink { param($title, $body) $trackerBodies.Add($body) } `
            -UpdateSink { param($number, $body, $state) } `
            -SummarySink { param($value) $summaryReports.Add($value) } `
            -FailureSink { param($value) }

        $summaryReports | Should -HaveCount 1
        $trackerBodies | Should -HaveCount 1
        $trackerBodies[0] | Should -Match ([regex]::Escape($summaryReports[0]))
        $trackerBodies[0] | Should -Match 'No issues assessed'
        $trackerBodies[0] | Should -Match 'No maintainer action'
    }
}

Describe 'Backlog grooming sweep snapshot and checkpoint contracts' -Tag 'Unit' {
    It 'S01 emits a deterministic versioned snapshot schema and canonical digest' {
        $script:Orchestrator | Should -Match 'schema_version: "backlog-grooming-sweep-snapshot/v1"'
        $script:Orchestrator | Should -Match 'snapshot_digest: digest\(material\)'
        $script:Orchestrator | Should -Match 'validateSnapshot\(snapshot\)'
        $script:Orchestrator | Should -Match 'Sweep snapshot digest mismatch'
    }

    It 'S02 derives finite wave counts across matrix boundaries without a cardinality rejection' {
        $expectedWaves = @{ 0 = 1; 1 = 1; 10 = 1; 11 = 2; 2560 = 256; 2561 = 257 }
        foreach ($count in $expectedWaves.Keys) {
            [Math]::Max(1, [Math]::Ceiling($count / 10)) | Should -Be $expectedWaves[$count]
        }
        $script:Orchestrator | Should -Match 'requiredWaves = Math\.max\(1, Math\.ceil\(openIssues\.length / waveCapacity\)\)'
        $script:Orchestrator | Should -Not -Match 'max-waves|max-issues|candidate-ids exceed'
    }

    It 'S03 partitions snapshot IDs into exhaustive ordered disjoint wave slices' {
        $ids = @(9, 2, 7, 12, 3, 8, 1, 11, 4, 10, 6, 5)
        $slices = Get-SweepSlices -IssueIds $ids -WaveCapacity 10
        @($slices | ForEach-Object { $_ }) | Should -Be $ids
        @($slices | ForEach-Object { $_ } | Select-Object -Unique) | Should -HaveCount 12
        $slices[0] | Should -Be $ids[0..9]
        $slices[1] | Should -Be $ids[10..11]
        $script:Orchestrator | Should -Match 'waveIssueIds = snapshot\.cursor_candidate_ids\.slice'
        $script:Orchestrator | Should -Not -Match 'waveIssueIds = snapshot\.ordered_issue_ids\.slice'
    }

    It 'S04 computes planned sweep AIC with safe finite arithmetic' {
        $script:Orchestrator | Should -Match 'plannedSweepAic = requiredWaves \* plannedAicPerWave'
        $script:Orchestrator | Should -Match '\[waveCapacity, requiredWaves, plannedAicPerWave, plannedSweepAic\]\.every\(Number\.isSafeInteger\)'
        $script:Orchestrator | Should -Match 'planned_sweep_aic: plannedSweepAic'
    }

    It 'S05 binds checkpoint provenance and applies 30-day retention to every sweep artifact' {
        foreach ($field in @(
                'snapshot_digest', 'source_manifest_artifact_id', 'source_manifest_digest',
                'source_aggregate_artifact_id', 'source_aggregate_digest', 'prior_checkpoint_digest',
                'cumulative_digest', 'checkpoint_digest'
            )) {
            $script:Orchestrator | Should -Match ([regex]::Escape($field))
        }
        $script:Orchestrator | Should -Not -Match 'retention-days: 7'
        $script:Source | Should -Match '(?ms)Upload immutable shard result.*?retention-days: 30'
        $script:Lock | Should -Match '(?ms)Upload immutable shard result.*?retention-days: 30'
    }

    It 'S06 accepts only a contiguous digest-bound checkpoint chain' {
        $script:Orchestrator | Should -Match 'prior\.checkpoint_digest !== process\.env\.PRIOR_CHECKPOINT_DIGEST'
        $script:Orchestrator | Should -Match 'prior\.wave_number \+ 1 !== waveNumber'
        $script:Orchestrator | Should -Match 'checkpoint\.prior_checkpoint_digest !== priorCheckpoint\.checkpoint_digest'
        $script:Orchestrator | Should -Match 'chain\.some\(\(item, index\) => item\.wave_number !== index \+ 1\)'
        $script:Orchestrator | Should -Match 'Active sweep checkpoint chain is missing, reordered, duplicated, or broken'
        $script:Orchestrator | Should -Match 'getArtifactMetadata'
    }
}

Describe 'Backlog grooming sweep dispatch and recovery contracts' -Tag 'Unit' {
    It 'S07 rejects broken reordered stale and expired state' {
        foreach ($guard in @(
                'Sweep checkpoint digest mismatch', 'Checkpoint predecessor link failed',
                'Complete checkpoint chain is missing or reordered', 'artifact.expired',
                'Continuation tuple does not match the accepted predecessor'
            )) {
            $script:Orchestrator | Should -Match ([regex]::Escape($guard))
        }
    }

    It 'S08 makes an accepted duplicate dispatch a worker-free no-op' {
        $script:Orchestrator | Should -Match 'already has an accepted checkpoint; duplicate dispatch is a no-op'
        $script:Orchestrator | Should -Match 'core\.setOutput\("mode", "complete-noop"\)'
        $script:Orchestrator | Should -Match 'core\.setOutput\("shard-matrix", "\[\]"\)'
        $script:Orchestrator | Should -Match 'Multiple accepted checkpoints for one sweep wave are ambiguous'
        $script:Orchestrator | Should -Match 'const matrix = shards\.filter\(\(shard\) => shard\.ordered_candidate_ids\.length > 0\)'
        $script:Orchestrator | Should -Match "needs\.assess\.result == 'skipped'.*needs\.plan\.outputs\.shard-matrix == '\[\]'"
    }

    It 'S09 dispatches no successor when wave validation or checkpoint upload fails' {
        $script:Orchestrator | Should -Match '(?ms)^  checkpoint:.*?if:.*?needs\.validate-wave\.result == ''success'''
        $script:Orchestrator | Should -Match '(?ms)^  continue:.*?if:.*?needs\.checkpoint\.result == ''success''.*?sweep-complete == ''false'''
        $script:Orchestrator | Should -Match '(?ms)^  validate-wave:.*?permissions:\s+actions: read\s+outputs:'
    }

    It 'S10 narrows paginated discovery and resumes the first missing wave within a download limit' {
        $script:Orchestrator | Should -Match 'github\.paginate\(\s+github\.rest\.actions\.listArtifactsForRepo'
        $script:Orchestrator | Should -Match 'artifact\.name\.startsWith\(snapshotPrefix\)'
        [regex]::Matches($script:Orchestrator, 'github\.rest\.actions\.downloadArtifact\(').Count | Should -Be 2
        $script:Orchestrator | Should -Not -Match 'outStream: fs\.createWriteStream'
        [regex]::Matches($script:Orchestrator, 'fs\.writeFileSync\([^;]+Buffer\.from\(').Count | Should -Be 2
        $script:Orchestrator | Should -Match 'SWEEP_DISCOVERY_DOWNLOAD_LIMIT: 50'
        $script:Orchestrator | Should -Match 'SWEEP_DISCOVERY_METADATA_LIMIT: 500'
        $script:Orchestrator | Should -Match 'Active sweep discovery candidate download limit exceeded'
        $script:Orchestrator | Should -Match 'Active sweep discovery metadata candidate limit exceeded'
        $metadataIndex = $script:Orchestrator.IndexOf('snapshotMetadata = await getArtifactMetadata(artifact.id)')
        $downloadIndex = $script:Orchestrator.IndexOf('await downloadArtifact(artifact.id, destination, snapshotMetadata)')
        $metadataIndex | Should -BeGreaterThan -1
        $downloadIndex | Should -BeGreaterThan $metadataIndex
        $script:Orchestrator | Should -Match 'consumeDiscoveryDownload\(\)'
        $script:Orchestrator | Should -Match 'candidateSnapshot\.source_ref !== process\.env\.GITHUB_REF'
        $script:Orchestrator | Should -Match 'candidateSnapshot\.source_sha !== process\.env\.GITHUB_SHA'
        $script:Orchestrator | Should -Match 'current\.prior_checkpoint_artifact_id !=='
        $script:Orchestrator | Should -Match 'waveNumber = priorCheckpoint \? priorCheckpoint\.wave_number \+ 1 : 1'
    }

    It 'S11 sends only the bounded protocol-versioned continuation allowlist' {
        foreach ($inputName in @(
                'protocol-version', 'sweep-id', 'wave-number', 'snapshot-run-id',
                'snapshot-artifact-id', 'snapshot-digest', 'checkpoint-run-id',
                'checkpoint-artifact-id', 'checkpoint-digest'
            )) {
            $script:Orchestrator | Should -Match ([regex]::Escape("`"$inputName`""))
        }
        $script:Orchestrator | Should -Not -Match 'candidate-ids|publish-report|failure-injection'
    }

    It 'S12 isolates lifecycle dispatch and publisher write scopes' {
        [regex]::Matches($script:Orchestrator, '(?m)^\s+issues: write$').Count | Should -Be 0
        [regex]::Matches($script:Publisher, '(?m)^\s+issues: write$').Count | Should -Be 1
        [regex]::Matches($script:Orchestrator, '(?m)^\s+actions: write$').Count | Should -Be 2
        $script:Orchestrator | Should -Match '(?ms)^  continue:.*?permissions:\s+actions: write\s+contents: read'
        $script:CorePublisher | Should -Match '(?ms)permissions:\s+actions: read\s+issues: write'
        $script:HistoryPublisher | Should -Match '(?ms)permissions:\s+actions: read\s+contents: write'
        $script:Publisher | Should -Not -Match '(?m)^\s+actions: write$'
        $script:DeployDocs | Should -Match '(?ms)^  build:.*?permissions:\s+actions: read\s+contents: read\s+pages: write'
    }
}

Describe 'Backlog grooming sweep reduction publication and documentation contracts' -Tag 'Unit' {
    It 'S13 rejects missing duplicate and out-of-snapshot final rows' {
        $script:Orchestrator | Should -Match 'Duplicate or out-of-snapshot result \$\{row\.issue\}'
        $script:Orchestrator | Should -Match 'Final result set does not exactly equal the snapshot'
        $script:Orchestrator | Should -Match 'rowsByIssue\.size !== snapshot\.total_snapshot_count'
    }

    It 'S14 preserves report order and derives the cursor from full-snapshot cursor order' {
        $rows = @(
            [pscustomobject]@{ Issue = 1; Status = 'Assessed' },
            [pscustomobject]@{ Issue = 2; Status = 'Deferred' },
            [pscustomobject]@{ Issue = 3; Status = 'Assessed' }
        )
        Get-SweepCursor -CursorCandidateIds @(3, 1, 2) -Rows $rows -PriorCursor 9 | Should -Be 1
        $script:Orchestrator | Should -Match 'const rows = snapshot\.cursor_candidate_ids\.map'
        [regex]::Matches($script:Orchestrator, '(?:candidateSnapshot|snapshot)\.cursor_candidate_ids\.slice').Count | Should -BeGreaterOrEqual 4
        $script:Orchestrator | Should -Not -Match 'snapshot\.ordered_issue_ids\.slice'
    }

    It 'S15 counts deferred and closed-after-capture rows exactly once with a reason' {
        $script:Orchestrator | Should -Match 'deferredRows = rows\.filter\(\(row\) => row\.assessment_status === "Deferred"\)'
        $script:WaveValidator | Should -Match '\$AssessedIds\.Count \+ \$DeferredIds\.Count -ne \$Rows\.Count'
        $script:Agent | Should -Match 'representing post-snapshot unavailable entries as `Deferred`'
        $script:Source | Should -Match '(?s)Individual\s+candidate retrieval or evidence gaps produce canonical `Deferred` rows'
    }

    It 'S16 keeps the trusted tracker compact and inventory-independent' {
        $script:CorePublisher | Should -Match 'Compact trusted tracker exceeds 65,000 characters'
        $script:CorePublisher | Should -Not -Match 'for \(const row of aggregate\.rows\)'
        $script:CorePublisher | Should -Not -Match 'GitHub Pages|detailed report|report history'
        $script:CorePublisher | Should -Match 'Inspect the \[source workflow run\]'
        $script:HistoryPublisher | Should -Match 'View the optional detailed report'
    }

    It 'S17 keeps failure injection out of production' {
        $script:Orchestrator | Should -Not -Match 'failure-injection|(?m)^  inject:$|complete-three-wave|duplicate-dispatch|failed-wave-resume'
    }

    It 'S18 documents source-accurate sweep operations limits recovery and rollout state' {
        foreach ($content in @(
                'Backlog Grooming Sweep', 'wave_capacity', 'required_waves',
                'N_max \u2248 retention_days \* 24 \* 60 / T_wave_minutes \* wave_capacity',
                '30 days', '2,000', '65,000', 'Recovery',
                'first Monday of each month at 09:00 UTC'
            )) {
            $script:WorkflowReadme | Should -Match $content
        }
    }
}
