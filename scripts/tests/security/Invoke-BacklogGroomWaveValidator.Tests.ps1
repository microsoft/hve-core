#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ValidatorPath = Join-Path $PSScriptRoot '../../security/Invoke-BacklogGroomWaveValidator.ps1'
    . $script:ValidatorPath

    function ConvertTo-TestJsonNode {
        param([Parameter(Mandatory)] [System.Collections.IDictionary]$Value)

        return , ([System.Text.Json.Nodes.JsonNode]::Parse(($Value | ConvertTo-Json -Depth 20 -Compress)))
    }

    function Set-TestDigest {
        param(
            [Parameter(Mandatory)] [System.Collections.IDictionary]$Value,
            [Parameter(Mandatory)] [string]$DigestProperty
        )

        $null = $Value.Remove($DigestProperty)
        $Node = ConvertTo-TestJsonNode -Value $Value
        $Value[$DigestProperty] = Get-CanonicalJsonDigest -Element (Read-JsonElementFromNode -Node $Node)
    }

    function Write-TestJson {
        param(
            [Parameter(Mandatory)] [System.Collections.IDictionary]$Value,
            [Parameter(Mandatory)] [string]$Path
        )

        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
        [System.IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 20) + "`n")
    }

    function New-ValidWaveFixture {
        param([Parameter(Mandatory)] [string]$Root)

        $ManifestPath = Join-Path $Root 'manifest/manifest.json'
        $ResultsDirectory = Join-Path $Root 'results'
        $AggregateDirectory = Join-Path $Root 'aggregate'
        $Manifest = [ordered]@{
            schema_version = 'backlog-grooming-wave-manifest/v1'
            sweep_id = 'a' * 64
            snapshot_digest = 'b' * 64
            wave_number = 1
            required_waves = 1
            prior_checkpoint_run_id = $null
            prior_checkpoint_artifact_id = $null
            prior_checkpoint_digest = $null
            ordered_issue_ids = @(101, 102)
            planned_aic = 2
            run_id = '12345'
            attempt = 1
            shards = @(
                [ordered]@{
                    shard_id = 'shard-01'
                    ordered_candidate_ids = @(101, 102)
                    priority_candidate_ids = @(101)
                    round_robin_candidate_ids = @(102)
                    total_open_inventory = 2
                    prior_cursor = 0
                    worker_timeout_minutes = 15
                }
            )
        }
        Set-TestDigest -Value $Manifest -DigestProperty 'manifest_digest'
        Write-TestJson -Value $Manifest -Path $ManifestPath

        $Rows = @(
            [ordered]@{
                issue = 101
                title = 'First issue'
                selection_reason = 'priority'
                activity_and_ownership_context = 'active'
                acceptance_signals = 'signal'
                repository_evidence = @('evidence')
                lineage_evidence = [ordered]@{ original_delivery = @(); replacement_or_removal = @() }
                similarity_outcome = 'Distinct'
                disposition = 'Still needed'
                grooming_finding = 'Keep'
                recommended_next_step = 'Refine'
                assessment_status = 'Assessed'
                deferral_reason = ''
            },
            [ordered]@{
                issue = 102
                title = 'Second issue'
                selection_reason = 'round-robin'
                activity_and_ownership_context = 'unknown'
                acceptance_signals = 'signal unavailable before the assessment budget expired'
                repository_evidence = @('issue state captured from the immutable inventory')
                lineage_evidence = [ordered]@{ original_delivery = @(); replacement_or_removal = @() }
                similarity_outcome = 'Uncertain'
                disposition = 'Uncertain'
                grooming_finding = 'Deferred'
                recommended_next_step = 'Revisit'
                assessment_status = 'Deferred'
                deferral_reason = 'Assessment budget was exhausted'
            }
        )
        $Result = [ordered]@{
            schema_version = 'backlog-grooming-shard-result/v1'
            run_id = '12345'
            attempt = 1
            shard_id = 'shard-01'
            manifest_digest = $Manifest.manifest_digest
            ordered_candidate_ids = @(101, 102)
            producer = 'backlog-groom/result-job'
            started_at = '2026-08-24T10:00:00Z'
            completed_at = '2026-08-24T10:01:00Z'
            report_data = [ordered]@{
                run = [ordered]@{
                    timestamp = '2026-08-24T10:01:00Z'
                    total_open_inventory = 2
                    assessed = 1
                    priority_cohort = 1
                    round_robin_cohort = 1
                    deferred = 1
                    stop_reason = 'complete'
                    next_cursor = 101
                }
                issues = $Rows
            }
        }
        Set-TestDigest -Value $Result -DigestProperty 'result_digest'
        $ResultPath = Join-Path $ResultsDirectory 'shard-01/shard-result.json'
        Write-TestJson -Value $Result -Path $ResultPath

        return [pscustomobject]@{
            Manifest = $Manifest
            ManifestPath = $ManifestPath
            Result = $Result
            ResultPath = $ResultPath
            ResultsDirectory = $ResultsDirectory
            AggregateDirectory = $AggregateDirectory
        }
    }
}

Describe 'Backlog grooming canonical JSON compatibility' -Tag 'Unit' {
    It 'matches the JavaScript reference vector <Name>' -ForEach @(
        @{
            Name = 'reordered nested data'
            Json = '{"zebra":[3,{"beta":true,"alpha":null}],"alpha":"value"}'
            Canonical = '{"alpha":"value","zebra":[3,{"alpha":null,"beta":true}]}'
            Digest = '7262f9edd2f348b3f245d79b077135b7448d3e9ac048fd1a1d4a9ce89e4fe50a'
        }
        @{
            Name = 'escaped and Unicode strings'
            Json = "{`"text`":`"quote\`" slash\\ control\b\f\n\r\t unicode-$([char]0x00e9)-$([char]0x2028)-$([char]0x2029)`"}"
            Canonical = "{`"text`":`"quote\`" slash\\ control\b\f\n\r\t unicode-$([char]0x00e9)-$([char]0x2028)-$([char]0x2029)`"}"
            Digest = '3a0b70b8653e122c06614fddd0d4a6c4c8f98bbe91699adaeb9a3015f1fe6dc3'
        }
        @{
            Name = 'JavaScript number thresholds'
            Json = '{"fraction":1.25,"exponentSmall":1e-7,"fixedSmall":1e-6,"exponentLarge":1e21,"fixedLarge":1e20,"negativeZero":-0,"safeMax":9007199254740991}'
            Canonical = '{"exponentLarge":1e+21,"exponentSmall":1e-7,"fixedLarge":100000000000000000000,"fixedSmall":0.000001,"fraction":1.25,"negativeZero":0,"safeMax":9007199254740991}'
            Digest = '6119890ebd76ace15d72b25d525462147d9e0d1fda9073d003214c6d53bd805f'
        }
    ) {
        $Document = [System.Text.Json.JsonDocument]::Parse($Json)
        try {
            ConvertTo-CanonicalJson -Element $Document.RootElement | Should -BeExactly $Canonical
            Get-CanonicalJsonDigest -Element $Document.RootElement | Should -BeExactly $Digest
        }
        finally {
            $Document.Dispose()
        }
    }
}

Describe 'Backlog grooming wave validation' -Tag 'Unit' {
    It 'writes a deterministic ordered aggregate for a valid complete wave' {
        $Fixture = New-ValidWaveFixture -Root (Join-Path $TestDrive 'valid')

        $Validation = Invoke-BacklogGroomWaveValidation -ManifestPath $Fixture.ManifestPath `
            -ResultsDirectory $Fixture.ResultsDirectory -AggregateDirectory $Fixture.AggregateDirectory `
            -ExpectedRunId '12345' -ExpectedAttempt 1

        $Validation.AssessedIds | Should -Be @(101)
        $Validation.DeferredIds | Should -Be @(102)
        $Aggregate = Get-Content -LiteralPath $Validation.AggregatePath -Raw | ConvertFrom-Json
        $Aggregate.rows.issue | Should -Be @(101, 102)
        $Aggregate.aggregate_digest | Should -BeExactly $Validation.AggregateDigest
        $Aggregate.result_digests | Should -Be @($Fixture.Result.result_digest)
    }

    It 'preserves priority-first cursor wraparound order while comparing cohort membership as a set' {
        $Fixture = New-ValidWaveFixture -Root (Join-Path $TestDrive 'wraparound-order')
        $ThirdRow = $Fixture.Result.report_data.issues[0] | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
        $ThirdRow.issue = 2
        $ThirdRow.title = 'Third issue'
        $Fixture.Manifest.ordered_issue_ids = @(105, 1, 2)
        $Fixture.Manifest.planned_aic = 3
        $Fixture.Manifest.shards[0].ordered_candidate_ids = @(105, 1, 2)
        $Fixture.Manifest.shards[0].priority_candidate_ids = @(105)
        $Fixture.Manifest.shards[0].round_robin_candidate_ids = @(1, 2)
        $Fixture.Manifest.shards[0].total_open_inventory = 3
        $Fixture.Result.ordered_candidate_ids = @(105, 1, 2)
        $Fixture.Result.report_data.issues[0].issue = 105
        $Fixture.Result.report_data.issues[1].issue = 1
        $Fixture.Result.report_data.issues = @($Fixture.Result.report_data.issues) + @($ThirdRow)
        $Fixture.Result.report_data.run.total_open_inventory = 3
        $Fixture.Result.report_data.run.assessed = 2
        $Fixture.Result.report_data.run.round_robin_cohort = 2
        $Fixture.Result.report_data.run.next_cursor = 105
        Set-TestDigest -Value $Fixture.Manifest -DigestProperty 'manifest_digest'
        $Fixture.Result.manifest_digest = $Fixture.Manifest.manifest_digest
        Set-TestDigest -Value $Fixture.Result -DigestProperty 'result_digest'
        Write-TestJson -Value $Fixture.Manifest -Path $Fixture.ManifestPath
        Write-TestJson -Value $Fixture.Result -Path $Fixture.ResultPath

        $Validation = Invoke-BacklogGroomWaveValidation -ManifestPath $Fixture.ManifestPath `
            -ResultsDirectory $Fixture.ResultsDirectory -AggregateDirectory $Fixture.AggregateDirectory `
            -ExpectedRunId '12345' -ExpectedAttempt 1

        (Get-Content -LiteralPath $Validation.AggregatePath -Raw | ConvertFrom-Json).rows.issue |
            Should -Be @(105, 1, 2)
    }

    It 'rejects a manifest digest mismatch' {
        $Fixture = New-ValidWaveFixture -Root (Join-Path $TestDrive 'manifest-digest')
        $Fixture.Manifest.planned_aic = 3
        Write-TestJson -Value $Fixture.Manifest -Path $Fixture.ManifestPath

        { Invoke-BacklogGroomWaveValidation -ManifestPath $Fixture.ManifestPath `
                -ResultsDirectory $Fixture.ResultsDirectory -AggregateDirectory $Fixture.AggregateDirectory `
                -ExpectedRunId '12345' -ExpectedAttempt 1 } |
            Should -Throw '*Wave manifest digest mismatch or invalid schema/identity*'
    }

    It 'rejects a stale result identity' {
        $Fixture = New-ValidWaveFixture -Root (Join-Path $TestDrive 'stale')

        { Invoke-BacklogGroomWaveValidation -ManifestPath $Fixture.ManifestPath `
                -ResultsDirectory $Fixture.ResultsDirectory -AggregateDirectory $Fixture.AggregateDirectory `
                -ExpectedRunId '99999' -ExpectedAttempt 1 } |
            Should -Throw '*Wave manifest digest mismatch or invalid schema/identity*'
    }

    It 'rejects a shard result digest mismatch' {
        $Fixture = New-ValidWaveFixture -Root (Join-Path $TestDrive 'result-digest')
        $Fixture.Result.report_data.issues[0].title = 'Tampered title'
        Write-TestJson -Value $Fixture.Result -Path $Fixture.ResultPath

        { Invoke-BacklogGroomWaveValidation -ManifestPath $Fixture.ManifestPath `
                -ResultsDirectory $Fixture.ResultsDirectory -AggregateDirectory $Fixture.AggregateDirectory `
                -ExpectedRunId '12345' -ExpectedAttempt 1 } | Should -Throw '*Shard result digest mismatch*'
    }

    It 'rejects an incomplete result set' {
        $Fixture = New-ValidWaveFixture -Root (Join-Path $TestDrive 'incomplete')
        Remove-Item -LiteralPath $Fixture.ResultPath

        { Invoke-BacklogGroomWaveValidation -ManifestPath $Fixture.ManifestPath `
                -ResultsDirectory $Fixture.ResultsDirectory -AggregateDirectory $Fixture.AggregateDirectory `
                -ExpectedRunId '12345' -ExpectedAttempt 1 } | Should -Throw '*Wave result set is incomplete*'
    }

    It 'rejects a duplicate shard result' {
        $Fixture = New-ValidWaveFixture -Root (Join-Path $TestDrive 'duplicate')
        $DuplicatePath = Join-Path $Fixture.ResultsDirectory 'duplicate/shard-result.json'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $DuplicatePath) -Force
        Copy-Item -LiteralPath $Fixture.ResultPath -Destination $DuplicatePath

        { Invoke-BacklogGroomWaveValidation -ManifestPath $Fixture.ManifestPath `
                -ResultsDirectory $Fixture.ResultsDirectory -AggregateDirectory $Fixture.AggregateDirectory `
                -ExpectedRunId '12345' -ExpectedAttempt 1 } |
            Should -Throw '*Missing, duplicate, stale, unexpected, or manifest-mismatched shard result*'
    }

            It 'rejects an unexpected shard result' {
            $Fixture = New-ValidWaveFixture -Root (Join-Path $TestDrive 'unexpected')
            $Fixture.Result.shard_id = 'shard-99'
            Set-TestDigest -Value $Fixture.Result -DigestProperty 'result_digest'
            Write-TestJson -Value $Fixture.Result -Path $Fixture.ResultPath

            { Invoke-BacklogGroomWaveValidation -ManifestPath $Fixture.ManifestPath `
                -ResultsDirectory $Fixture.ResultsDirectory -AggregateDirectory $Fixture.AggregateDirectory `
                -ExpectedRunId '12345' -ExpectedAttempt 1 } |
                Should -Throw '*Missing, duplicate, stale, unexpected, or manifest-mismatched shard result*'
            }

    It 'rejects an out-of-shard issue row' {
        $Fixture = New-ValidWaveFixture -Root (Join-Path $TestDrive 'out-of-shard')
        $Fixture.Result.report_data.issues[0].issue = 999
        Set-TestDigest -Value $Fixture.Result -DigestProperty 'result_digest'
        Write-TestJson -Value $Fixture.Result -Path $Fixture.ResultPath

        { Invoke-BacklogGroomWaveValidation -ManifestPath $Fixture.ManifestPath `
                -ResultsDirectory $Fixture.ResultsDirectory -AggregateDirectory $Fixture.AggregateDirectory `
                -ExpectedRunId '12345' -ExpectedAttempt 1 } |
            Should -Throw '*Malformed, duplicate, or out-of-shard wave issue 999*'
    }

    It 'rejects a Deferred row with <InvalidState>' -ForEach @(
        @{
            InvalidState = 'no deferral reason'
            Mutate = { param($Row) $Row.deferral_reason = '' }
        }
        @{
            InvalidState = 'a definitive similarity outcome'
            Mutate = { param($Row) $Row.similarity_outcome = 'Distinct' }
        }
        @{
            InvalidState = 'a definitive disposition'
            Mutate = { param($Row) $Row.disposition = 'Still needed' }
        }
        @{
            InvalidState = 'lineage evidence'
            Mutate = { param($Row) $Row.lineage_evidence.original_delivery = @('PR #1') }
        }
    ) {
        $Fixture = New-ValidWaveFixture -Root (Join-Path $TestDrive "deferred-$InvalidState")
        & $Mutate $Fixture.Result.report_data.issues[1]
        Set-TestDigest -Value $Fixture.Result -DigestProperty 'result_digest'
        Write-TestJson -Value $Fixture.Result -Path $Fixture.ResultPath

        { Invoke-BacklogGroomWaveValidation -ManifestPath $Fixture.ManifestPath `
                -ResultsDirectory $Fixture.ResultsDirectory -AggregateDirectory $Fixture.AggregateDirectory `
                -ExpectedRunId '12345' -ExpectedAttempt 1 } |
            Should -Throw '*Deferred wave issue 102 requires a reason, Uncertain outcomes, and empty lineage evidence*'
    }

    It 'rejects an Assessed row with a deferral reason' {
        $Fixture = New-ValidWaveFixture -Root (Join-Path $TestDrive 'assessed-deferral-reason')
        $Fixture.Result.report_data.issues[0].deferral_reason = 'Not deferred'
        Set-TestDigest -Value $Fixture.Result -DigestProperty 'result_digest'
        Write-TestJson -Value $Fixture.Result -Path $Fixture.ResultPath

        { Invoke-BacklogGroomWaveValidation -ManifestPath $Fixture.ManifestPath `
                -ResultsDirectory $Fixture.ResultsDirectory -AggregateDirectory $Fixture.AggregateDirectory `
                -ExpectedRunId '12345' -ExpectedAttempt 1 } |
            Should -Throw '*Assessed wave issue 101 cannot include a deferral reason*'
    }

    It 'rejects a row with invalid producer field <InvalidField>' -ForEach @(
        @{ InvalidField = 'array acceptance signals'; Mutate = { param($Row) $Row.acceptance_signals = @('signal') } }
        @{ InvalidField = 'empty repository evidence'; Mutate = { param($Row) $Row.repository_evidence = @() } }
        @{ InvalidField = 'blank title'; Mutate = { param($Row) $Row.title = ' ' } }
        @{ InvalidField = 'overlong selection reason'; Mutate = { param($Row) $Row.selection_reason = 'x' * 201 } }
        @{ InvalidField = 'unknown similarity'; Mutate = { param($Row) $Row.similarity_outcome = 'Exact' } }
        @{ InvalidField = 'non-string lineage item'; Mutate = { param($Row) $Row.lineage_evidence.original_delivery = @(1) } }
    ) {
        $Fixture = New-ValidWaveFixture -Root (Join-Path $TestDrive "invalid-$InvalidField")
        & $Mutate $Fixture.Result.report_data.issues[0]
        Set-TestDigest -Value $Fixture.Result -DigestProperty 'result_digest'
        Write-TestJson -Value $Fixture.Result -Path $Fixture.ResultPath

        { Invoke-BacklogGroomWaveValidation -ManifestPath $Fixture.ManifestPath `
                -ResultsDirectory $Fixture.ResultsDirectory -AggregateDirectory $Fixture.AggregateDirectory `
                -ExpectedRunId '12345' -ExpectedAttempt 1 } |
            Should -Throw '*Malformed, duplicate, or out-of-shard wave issue 101*'
    }

    It 'rejects a Possible duplicate row without Match or Similar evidence' {
        $Fixture = New-ValidWaveFixture -Root (Join-Path $TestDrive 'duplicate-coupling')
        $Fixture.Result.report_data.issues[0].disposition = 'Possible duplicate'
        Set-TestDigest -Value $Fixture.Result -DigestProperty 'result_digest'
        Write-TestJson -Value $Fixture.Result -Path $Fixture.ResultPath

        { Invoke-BacklogGroomWaveValidation -ManifestPath $Fixture.ManifestPath `
                -ResultsDirectory $Fixture.ResultsDirectory -AggregateDirectory $Fixture.AggregateDirectory `
                -ExpectedRunId '12345' -ExpectedAttempt 1 } |
            Should -Throw '*Possible duplicate wave issue 101 requires a Match or Similar outcome*'
    }

    It 'rejects a Superseded row without distinct original and replacement evidence' {
        $Fixture = New-ValidWaveFixture -Root (Join-Path $TestDrive 'superseded-lineage')
        $Fixture.Result.report_data.issues[0].disposition = 'Superseded'
        $Fixture.Result.report_data.issues[0].similarity_outcome = 'Match'
        Set-TestDigest -Value $Fixture.Result -DigestProperty 'result_digest'
        Write-TestJson -Value $Fixture.Result -Path $Fixture.ResultPath

        { Invoke-BacklogGroomWaveValidation -ManifestPath $Fixture.ManifestPath `
                -ResultsDirectory $Fixture.ResultsDirectory -AggregateDirectory $Fixture.AggregateDirectory `
                -ExpectedRunId '12345' -ExpectedAttempt 1 } |
            Should -Throw '*Superseded wave issue 101 requires distinct original and replacement evidence*'
    }

    It 'rejects <Mode> properties at the <Layer> layer' -ForEach @(
        @{ Layer = 'manifest'; Mode = 'missing'; Property = 'planned_aic' }
        @{ Layer = 'manifest'; Mode = 'additional'; Property = 'unexpected' }
        @{ Layer = 'shard'; Mode = 'missing'; Property = 'worker_timeout_minutes' }
        @{ Layer = 'shard'; Mode = 'additional'; Property = 'unexpected' }
        @{ Layer = 'result'; Mode = 'missing'; Property = 'completed_at' }
        @{ Layer = 'result'; Mode = 'additional'; Property = 'unexpected' }
        @{ Layer = 'report data'; Mode = 'missing'; Property = 'run' }
        @{ Layer = 'report data'; Mode = 'additional'; Property = 'unexpected' }
        @{ Layer = 'report run'; Mode = 'missing'; Property = 'next_cursor' }
        @{ Layer = 'report run'; Mode = 'additional'; Property = 'unexpected' }
        @{ Layer = 'report row'; Mode = 'missing'; Property = 'title' }
        @{ Layer = 'report row'; Mode = 'additional'; Property = 'unexpected' }
    ) {
        $Fixture = New-ValidWaveFixture -Root (Join-Path $TestDrive "$Layer-$Mode")
        $Target = switch ($Layer) {
            'manifest' { $Fixture.Manifest }
            'shard' { $Fixture.Manifest.shards[0] }
            'result' { $Fixture.Result }
            'report data' { $Fixture.Result.report_data }
            'report run' { $Fixture.Result.report_data.run }
            'report row' { $Fixture.Result.report_data.issues[0] }
        }
        if ($Mode -eq 'missing') {
            $null = $Target.Remove($Property)
        }
        else {
            $Target[$Property] = 'not allowed'
        }
        if ($Layer -eq 'shard') {
            Set-TestDigest -Value $Fixture.Manifest -DigestProperty 'manifest_digest'
            $Fixture.Result.manifest_digest = $Fixture.Manifest.manifest_digest
            Set-TestDigest -Value $Fixture.Result -DigestProperty 'result_digest'
        }
        elseif ($Layer -eq 'report row') {
            Set-TestDigest -Value $Fixture.Result -DigestProperty 'result_digest'
        }
        Write-TestJson -Value $Fixture.Manifest -Path $Fixture.ManifestPath
        Write-TestJson -Value $Fixture.Result -Path $Fixture.ResultPath

        { Invoke-BacklogGroomWaveValidation -ManifestPath $Fixture.ManifestPath `
                -ResultsDirectory $Fixture.ResultsDirectory -AggregateDirectory $Fixture.AggregateDirectory `
                -ExpectedRunId '12345' -ExpectedAttempt 1 } | Should -Throw
    }

    It 'rejects the numeric boundary case <Name>' -ForEach @(
        @{
            Name = 'string attempt'
            Mutate = { param($Fixture) $Fixture.Manifest.attempt = '1' }
        }
        @{
            Name = 'fractional wave number'
            Mutate = { param($Fixture) $Fixture.Manifest.wave_number = 1.5 }
        }
        @{
            Name = 'unsafe issue ID'
            Mutate = { param($Fixture) $Fixture.Manifest.ordered_issue_ids = @(101, 9007199254740992L) }
        }
        @{
            Name = 'fractional result issue ID'
            Mutate = {
                param($Fixture)
                $Fixture.Result.report_data.issues[0].issue = 101.5
                Set-TestDigest -Value $Fixture.Result -DigestProperty 'result_digest'
            }
        }
    ) {
        $Fixture = New-ValidWaveFixture -Root (Join-Path $TestDrive $Name)
        & $Mutate $Fixture
        Write-TestJson -Value $Fixture.Manifest -Path $Fixture.ManifestPath
        Write-TestJson -Value $Fixture.Result -Path $Fixture.ResultPath

        { Invoke-BacklogGroomWaveValidation -ManifestPath $Fixture.ManifestPath `
                -ResultsDirectory $Fixture.ResultsDirectory -AggregateDirectory $Fixture.AggregateDirectory `
                -ExpectedRunId '12345' -ExpectedAttempt 1 } | Should -Throw
    }

    It 'accepts an empty wave with no results directory' {
        $Fixture = New-ValidWaveFixture -Root (Join-Path $TestDrive 'empty')
        $Fixture.Manifest.ordered_issue_ids = @()
        $Fixture.Manifest.planned_aic = 0
        $Fixture.Manifest.shards = @()
        Set-TestDigest -Value $Fixture.Manifest -DigestProperty 'manifest_digest'
        Write-TestJson -Value $Fixture.Manifest -Path $Fixture.ManifestPath
        Remove-Item -LiteralPath $Fixture.ResultsDirectory -Recurse

        $Validation = Invoke-BacklogGroomWaveValidation -ManifestPath $Fixture.ManifestPath `
            -ResultsDirectory $Fixture.ResultsDirectory -AggregateDirectory $Fixture.AggregateDirectory `
            -ExpectedRunId '12345' -ExpectedAttempt 1

        @($Validation.AssessedIds).Count | Should -Be 0
        @($Validation.DeferredIds).Count | Should -Be 0
        (Get-Content -LiteralPath $Validation.AggregatePath -Raw | ConvertFrom-Json).rows.Count | Should -Be 0
    }

    It 'discovers only the exact case-sensitive shard result basename' {
        $Fixture = New-ValidWaveFixture -Root (Join-Path $TestDrive 'case-sensitive')
        Rename-Item -LiteralPath $Fixture.ResultPath -NewName 'Shard-Result.json'

        { Invoke-BacklogGroomWaveValidation -ManifestPath $Fixture.ManifestPath `
                -ResultsDirectory $Fixture.ResultsDirectory -AggregateDirectory $Fixture.AggregateDirectory `
                -ExpectedRunId '12345' -ExpectedAttempt 1 } | Should -Throw '*Wave result set is incomplete*'
    }

    It 'aggregates two shards in manifest order regardless of discovery order' {
        $Fixture = New-ValidWaveFixture -Root (Join-Path $TestDrive 'permuted')
        $Fixture.Manifest.shards[0].ordered_candidate_ids = @(101)
        $Fixture.Manifest.shards[0].round_robin_candidate_ids = @()
        $SecondShard = [ordered]@{
            shard_id = 'shard-02'
            ordered_candidate_ids = @(102)
            priority_candidate_ids = @()
            round_robin_candidate_ids = @(102)
            total_open_inventory = 2
            prior_cursor = 0
            worker_timeout_minutes = 15
        }
        $Fixture.Manifest.shards = @($Fixture.Manifest.shards[0], $SecondShard)
        Set-TestDigest -Value $Fixture.Manifest -DigestProperty 'manifest_digest'

        $SecondResult = $Fixture.Result | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
        $Fixture.Result.manifest_digest = $Fixture.Manifest.manifest_digest
        $Fixture.Result.ordered_candidate_ids = @(101)
        $Fixture.Result.report_data.run.assessed = 1
        $Fixture.Result.report_data.run.deferred = 0
        $Fixture.Result.report_data.run.round_robin_cohort = 0
        $Fixture.Result.report_data.issues = @($Fixture.Result.report_data.issues[0])
        Set-TestDigest -Value $Fixture.Result -DigestProperty 'result_digest'
        $SecondResult.manifest_digest = $Fixture.Manifest.manifest_digest
        $SecondResult.shard_id = 'shard-02'
        $SecondResult.ordered_candidate_ids = @(102)
        $SecondResult.report_data.run.assessed = 0
        $SecondResult.report_data.run.deferred = 1
        $SecondResult.report_data.run.priority_cohort = 0
        $SecondResult.report_data.issues = @($SecondResult.report_data.issues[1])
        Set-TestDigest -Value $SecondResult -DigestProperty 'result_digest'

        Remove-Item -LiteralPath $Fixture.ResultsDirectory -Recurse
        Write-TestJson -Value $Fixture.Manifest -Path $Fixture.ManifestPath
        Write-TestJson -Value $Fixture.Result -Path (Join-Path $Fixture.ResultsDirectory 'z-first/shard-result.json')
        Write-TestJson -Value $SecondResult -Path (Join-Path $Fixture.ResultsDirectory 'a-second/shard-result.json')

        $Validation = Invoke-BacklogGroomWaveValidation -ManifestPath $Fixture.ManifestPath `
            -ResultsDirectory $Fixture.ResultsDirectory -AggregateDirectory $Fixture.AggregateDirectory `
            -ExpectedRunId '12345' -ExpectedAttempt 1
        $Aggregate = Get-Content -LiteralPath $Validation.AggregatePath -Raw | ConvertFrom-Json
        $Aggregate.rows.issue | Should -Be @(101, 102)
        $Aggregate.result_digests | Should -Be @($Fixture.Result.result_digest, $SecondResult.result_digest | Sort-Object)
    }

    It 'emits the three GitHub outputs at the command boundary' {
        $Fixture = New-ValidWaveFixture -Root (Join-Path $TestDrive 'command')
        $OutputPath = Join-Path $TestDrive 'github-output.txt'
        $PreviousOutput = $env:GITHUB_OUTPUT
        $PreviousActions = $env:GITHUB_ACTIONS
        try {
            $env:GITHUB_OUTPUT = $OutputPath
            $env:GITHUB_ACTIONS = 'true'
            $CommandOutput = & pwsh -NoProfile -File $script:ValidatorPath `
                -ManifestPath $Fixture.ManifestPath `
                -ResultsDirectory $Fixture.ResultsDirectory `
                -AggregateDirectory $Fixture.AggregateDirectory `
                -ExpectedRunId '12345' `
                -ExpectedAttempt 1 2>&1
            $LASTEXITCODE | Should -Be 0 -Because ($CommandOutput -join "`n")
            $Outputs = Get-Content -LiteralPath $OutputPath
            $Outputs.Count | Should -Be 3
            $Outputs | Should -Contain 'assessed-ids=[101]'
            $Outputs | Should -Contain 'deferred-ids=[102]'
            @($Outputs | Where-Object { $_ -match '^aggregate-digest=[a-f0-9]{64}$' }).Count | Should -Be 1
            $AggregateBytes = [System.IO.File]::ReadAllBytes((Join-Path $Fixture.AggregateDirectory 'aggregate.json'))
            $AggregateBytes[0..2] | Should -Not -Be @(0xEF, 0xBB, 0xBF)
            $AggregateBytes[-1] | Should -Be 10
        }
        finally {
            $env:GITHUB_OUTPUT = $PreviousOutput
            $env:GITHUB_ACTIONS = $PreviousActions
        }
    }
}
