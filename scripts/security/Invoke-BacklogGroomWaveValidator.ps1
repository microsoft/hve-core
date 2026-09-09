#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Validates one immutable backlog grooming wave.
.DESCRIPTION
    Validates a wave manifest and its exact shard result set, writes the
    deterministic aggregate, and emits GitHub Actions outputs.
.PARAMETER ManifestPath
    Path to the immutable wave manifest.
.PARAMETER ResultsDirectory
    Directory containing shard-result.json envelopes.
.PARAMETER AggregateDirectory
    Directory where aggregate.json is written.
.PARAMETER ExpectedRunId
    Producing orchestrator run ID.
.PARAMETER ExpectedAttempt
    Producing orchestrator attempt.
.EXAMPLE
    ./scripts/security/Invoke-BacklogGroomWaveValidator.ps1 -ManifestPath wave-manifest/manifest.json -ResultsDirectory wave-results -AggregateDirectory wave-aggregate -ExpectedRunId 123 -ExpectedAttempt 1
.NOTES
    Called by .github/workflows/backlog-groom-orchestrator.yml.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $false)]
    [string]$ResultsDirectory,

    [Parameter(Mandatory = $false)]
    [string]$AggregateDirectory,

    [Parameter(Mandatory = $false)]
    [string]$ExpectedRunId,

    [Parameter(Mandatory = $false)]
    [string]$ExpectedAttempt
)

$ErrorActionPreference = 'Stop'

#region Functions
<#
.SYNOPSIS
    Converts a value to a JavaScript-compatible JSON string.
.PARAMETER Value
    String value to encode.
.OUTPUTS
    System.String
#>
function ConvertTo-JavaScriptJsonString {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    $Builder = [System.Text.StringBuilder]::new()
    $null = $Builder.Append('"')
    for ($Index = 0; $Index -lt $Value.Length; $Index++) {
        $Character = $Value[$Index]
        $Code = [int]$Character
        $Escape = switch ($Code) {
            8 { '\b' }
            9 { '\t' }
            10 { '\n' }
            12 { '\f' }
            13 { '\r' }
            34 { '\"' }
            92 { '\\' }
            default { $null }
        }
        if ($null -ne $Escape) {
            $null = $Builder.Append($Escape)
            continue
        }
        if ($Code -lt 32 -or
            ([char]::IsSurrogate($Character) -and
                ($Index + 1 -ge $Value.Length -or -not [char]::IsSurrogatePair($Character, $Value[$Index + 1])) -and
                ($Index -eq 0 -or -not [char]::IsSurrogatePair($Value[$Index - 1], $Character)))) {
            $null = $Builder.AppendFormat('\u{0:x4}', $Code)
            continue
        }
        $null = $Builder.Append($Character)
    }
    $null = $Builder.Append('"')
    return $Builder.ToString()
}

<#
.SYNOPSIS
    Converts a JSON number to JavaScript-compatible canonical text.
.PARAMETER Element
    JSON number element to render.
.OUTPUTS
    System.String
#>
function ConvertTo-JavaScriptJsonNumber {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Text.Json.JsonElement]$Element
    )

    $Number = $Element.GetDouble()
    if ($Number -eq 0) {
        return '0'
    }

    $Absolute = [Math]::Abs($Number)
    $Rendered = $Number.ToString('R', [System.Globalization.CultureInfo]::InvariantCulture)
    if ($Rendered -match '^(?<mantissa>-?\d(?:\.\d+)?)[Ee](?<sign>[+-]?)(?<exponent>\d+)$') {
        $Mantissa = $Matches.mantissa
        $Exponent = [int]$Matches.exponent
        if ($Matches.sign -eq '-') {
            $Exponent = -$Exponent
        }
        if ($Absolute -ge 1e-6 -and $Absolute -lt 1e21) {
            $Digits = $Mantissa.Replace('-', '').Replace('.', '')
            $IsNegative = $Mantissa.StartsWith('-')
            $DecimalPosition = 1 + $Exponent
            if ($DecimalPosition -le 0) {
                $Rendered = '0.' + ('0' * -$DecimalPosition) + $Digits
            }
            elseif ($DecimalPosition -ge $Digits.Length) {
                $Rendered = $Digits + ('0' * ($DecimalPosition - $Digits.Length))
            }
            else {
                $Rendered = $Digits.Insert($DecimalPosition, '.')
            }
            if ($IsNegative) {
                $Rendered = '-' + $Rendered
            }
        }
        else {
            $ExponentText = if ($Exponent -ge 0) { "+$Exponent" } else { "$Exponent" }
            $Rendered = "$Mantissa" + 'e' + $ExponentText
        }
    }
    return $Rendered
}

<#
.SYNOPSIS
    Serializes a JSON element using the workflow canonicalization rules.
.PARAMETER Element
    JSON element to canonicalize.
.OUTPUTS
    System.String
#>
function ConvertTo-CanonicalJson {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Text.Json.JsonElement]$Element
    )

    switch ($Element.ValueKind) {
        ([System.Text.Json.JsonValueKind]::Object) {
            $Properties = [System.Collections.Generic.Dictionary[string, System.Text.Json.JsonElement]]::new(
                [System.StringComparer]::Ordinal
            )
            foreach ($Property in $Element.EnumerateObject()) {
                $Properties[$Property.Name] = $Property.Value.Clone()
            }
            $Names = [string[]]$Properties.Keys
            [Array]::Sort($Names, [System.StringComparer]::Ordinal)
            $Members = foreach ($Name in $Names) {
                "$(ConvertTo-JavaScriptJsonString -Value $Name):$(ConvertTo-CanonicalJson -Element $Properties[$Name])"
            }
            return '{' + ($Members -join ',') + '}'
        }
        ([System.Text.Json.JsonValueKind]::Array) {
            $Items = foreach ($Item in $Element.EnumerateArray()) {
                ConvertTo-CanonicalJson -Element $Item
            }
            return '[' + ($Items -join ',') + ']'
        }
        ([System.Text.Json.JsonValueKind]::String) {
            return ConvertTo-JavaScriptJsonString -Value $Element.GetString()
        }
        ([System.Text.Json.JsonValueKind]::Number) {
            return ConvertTo-JavaScriptJsonNumber -Element $Element
        }
        ([System.Text.Json.JsonValueKind]::True) { return 'true' }
        ([System.Text.Json.JsonValueKind]::False) { return 'false' }
        ([System.Text.Json.JsonValueKind]::Null) { return 'null' }
        default { throw "Unsupported JSON value kind $($Element.ValueKind)" }
    }
}

<#
.SYNOPSIS
    Computes the canonical SHA-256 digest for a JSON element.
.PARAMETER Element
    JSON element to digest.
.OUTPUTS
    System.String
#>
function Get-CanonicalJsonDigest {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Text.Json.JsonElement]$Element
    )

    $Canonical = ConvertTo-CanonicalJson -Element $Element
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Canonical)
    return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
}

<#
.SYNOPSIS
    Tests whether a JSON object has exactly the expected keys.
.PARAMETER Element
    JSON object to inspect.
.PARAMETER Keys
    Complete expected key set.
.OUTPUTS
    System.Boolean
#>
function Test-ExactJsonKeys {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Text.Json.JsonElement]$Element,

        [Parameter(Mandatory = $true)]
        [string[]]$Keys
    )

    if ($Element.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
        return $false
    }
    $ActualKeys = @($Element.EnumerateObject() | ForEach-Object Name)
    [Array]::Sort($ActualKeys, [System.StringComparer]::Ordinal)
    $ExpectedKeys = [string[]]$Keys.Clone()
    [Array]::Sort($ExpectedKeys, [System.StringComparer]::Ordinal)
    return ($ActualKeys -join '|') -ceq ($ExpectedKeys -join '|')
}

<#
.SYNOPSIS
    Tests whether a JSON number is an integer within safe bounds.
.PARAMETER Element
    JSON number to inspect.
.PARAMETER Minimum
    Inclusive minimum value.
.PARAMETER Maximum
    Inclusive maximum value.
.OUTPUTS
    System.Boolean
#>
function Test-SafeJsonInteger {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Text.Json.JsonElement]$Element,

        [Parameter(Mandatory = $false)]
        [long]$Minimum = -9007199254740991,

        [Parameter(Mandatory = $false)]
        [long]$Maximum = 9007199254740991
    )

    $Value = 0L
    return $Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Number -and
        $Element.TryGetInt64([ref]$Value) -and $Value -ge $Minimum -and $Value -le $Maximum
}

<#
.SYNOPSIS
    Reads unique positive safe integers from a JSON array.
.PARAMETER Name
    Field name used in validation errors.
.PARAMETER Element
    JSON array to validate.
.OUTPUTS
    System.Int64[]
#>
function Assert-PositiveUniqueJsonIds {
    [CmdletBinding()]
    [OutputType([long[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [System.Text.Json.JsonElement]$Element
    )

    if ($Element.ValueKind -ne [System.Text.Json.JsonValueKind]::Array) {
        throw "$Name must contain unique positive safe integers"
    }
    $Ids = [System.Collections.Generic.List[long]]::new()
    $UniqueIds = [System.Collections.Generic.HashSet[long]]::new()
    foreach ($Item in $Element.EnumerateArray()) {
        if (-not (Test-SafeJsonInteger -Element $Item -Minimum 1) -or -not $UniqueIds.Add($Item.GetInt64())) {
            throw "$Name must contain unique positive safe integers"
        }
        $Ids.Add($Item.GetInt64())
    }
    return $Ids.ToArray()
}

<#
.SYNOPSIS
    Tests two integer arrays for identical ordered values.
.PARAMETER Left
    First integer array.
.PARAMETER Right
    Second integer array.
.OUTPUTS
    System.Boolean
#>
function Test-LongArrayEqual {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [long[]]$Left = @(),

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [long[]]$Right = @()
    )

    return $Left.Count -eq $Right.Count -and ($Left -join ',') -ceq ($Right -join ',')
}

<#
.SYNOPSIS
    Reads one JSON file as a detached element.
.PARAMETER Path
    JSON file path.
.OUTPUTS
    System.Text.Json.JsonElement
#>
function Read-JsonElement {
    [CmdletBinding()]
    [OutputType([System.Text.Json.JsonElement])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $Document = [System.Text.Json.JsonDocument]::Parse([System.IO.File]::ReadAllText($Path))
    try {
        return $Document.RootElement.Clone()
    }
    finally {
        $Document.Dispose()
    }
}

<#
.SYNOPSIS
    Creates a JSON array from ordinary values or JSON elements.
.PARAMETER Values
    Values to append in order.
.OUTPUTS
    System.Text.Json.Nodes.JsonArray
#>
function New-JsonArray {
    [CmdletBinding()]
    [OutputType([System.Text.Json.Nodes.JsonArray])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [object[]]$Values = @()
    )

    $Array = [System.Text.Json.Nodes.JsonArray]::new()
    foreach ($Value in $Values) {
        if ($Value -is [System.Text.Json.JsonElement]) {
            $Array.Add([System.Text.Json.Nodes.JsonNode]::Parse($Value.GetRawText()))
        }
        else {
            $Array.Add([System.Text.Json.Nodes.JsonValue]::Create($Value))
        }
    }
    return , $Array
}

<#
.SYNOPSIS
    Validates a complete backlog grooming wave and writes its aggregate.
.PARAMETER ManifestPath
    Immutable wave manifest path.
.PARAMETER ResultsDirectory
    Directory containing shard result envelopes.
.PARAMETER AggregateDirectory
    Directory that receives aggregate.json.
.PARAMETER ExpectedRunId
    Authorized orchestrator run ID.
.PARAMETER ExpectedAttempt
    Authorized orchestrator attempt.
.OUTPUTS
    System.Management.Automation.PSCustomObject
#>
function Invoke-BacklogGroomWaveValidation {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ManifestPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ResultsDirectory,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AggregateDirectory,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ExpectedRunId,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 9007199254740991)]
        [long]$ExpectedAttempt
    )

    $Manifest = Read-JsonElement -Path $ManifestPath
    $ManifestKeys = @(
        'schema_version', 'sweep_id', 'snapshot_digest', 'wave_number', 'required_waves',
        'prior_checkpoint_run_id', 'prior_checkpoint_artifact_id', 'prior_checkpoint_digest',
        'ordered_issue_ids', 'planned_aic', 'run_id', 'attempt', 'shards', 'manifest_digest'
    )
    $ShardKeys = @(
        'shard_id', 'ordered_candidate_ids', 'priority_candidate_ids', 'round_robin_candidate_ids',
        'total_open_inventory', 'prior_cursor', 'worker_timeout_minutes'
    )
    $RecordedManifestDigest = $Manifest.GetProperty('manifest_digest').GetString()
    $ManifestMaterial = [System.Text.Json.Nodes.JsonObject]::new()
    foreach ($Property in $Manifest.EnumerateObject()) {
        if ($Property.Name -cne 'manifest_digest') {
            $ManifestMaterial.Add($Property.Name, [System.Text.Json.Nodes.JsonNode]::Parse($Property.Value.GetRawText()))
        }
    }
    $ManifestMaterialElement = Read-JsonElementFromNode -Node $ManifestMaterial
    $WaveNumber = $Manifest.GetProperty('wave_number')
    $RequiredWaves = $Manifest.GetProperty('required_waves')
    $PlannedAic = $Manifest.GetProperty('planned_aic')
    $Attempt = $Manifest.GetProperty('attempt')
    if (-not (Test-ExactJsonKeys -Element $Manifest -Keys $ManifestKeys) -or
        $Manifest.GetProperty('schema_version').GetString() -cne 'backlog-grooming-wave-manifest/v1' -or
        $Manifest.GetProperty('sweep_id').GetString() -notmatch '^[a-f0-9]{64}$' -or
        $Manifest.GetProperty('snapshot_digest').GetString() -notmatch '^[a-f0-9]{64}$' -or
        $Manifest.GetProperty('run_id').GetString() -cne $ExpectedRunId -or
        -not (Test-SafeJsonInteger -Element $Attempt -Minimum 1) -or $Attempt.GetInt64() -ne $ExpectedAttempt -or
        -not (Test-SafeJsonInteger -Element $WaveNumber -Minimum 1) -or
        -not (Test-SafeJsonInteger -Element $RequiredWaves -Minimum 1) -or
        $WaveNumber.GetInt64() -gt $RequiredWaves.GetInt64() -or
        -not (Test-SafeJsonInteger -Element $PlannedAic -Minimum 0) -or
        $Manifest.GetProperty('shards').ValueKind -ne [System.Text.Json.JsonValueKind]::Array -or
        (Get-CanonicalJsonDigest -Element $ManifestMaterialElement) -cne $RecordedManifestDigest) {
        throw 'Wave manifest digest mismatch or invalid schema/identity'
    }

    $OrderedIssueIds = [long[]]@(Assert-PositiveUniqueJsonIds -Name 'manifest ordered_issue_ids' -Element $Manifest.GetProperty('ordered_issue_ids'))
    $ManifestShards = @($Manifest.GetProperty('shards').EnumerateArray())
    $ShardIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $PlannedIssueIds = [System.Collections.Generic.List[long]]::new()
    $ExpectedShards = @{}
    foreach ($Shard in $ManifestShards) {
        $ShardId = $Shard.GetProperty('shard_id').GetString()
        $TotalOpenInventory = $Shard.GetProperty('total_open_inventory')
        $PriorCursor = $Shard.GetProperty('prior_cursor')
        $WorkerTimeout = $Shard.GetProperty('worker_timeout_minutes')
        if (-not (Test-ExactJsonKeys -Element $Shard -Keys $ShardKeys) -or
            $ShardId -notmatch '^[a-z0-9][a-z0-9-]{0,62}$' -or -not $ShardIds.Add($ShardId) -or
            -not (Test-SafeJsonInteger -Element $TotalOpenInventory -Minimum $OrderedIssueIds.Count) -or
            -not (Test-SafeJsonInteger -Element $PriorCursor -Minimum 0) -or
            -not (Test-SafeJsonInteger -Element $WorkerTimeout -Minimum 1)) {
            throw 'Wave manifest shard schema is invalid'
        }
        $OrderedCandidateIds = [long[]]@(Assert-PositiveUniqueJsonIds -Name "$ShardId ordered_candidate_ids" -Element $Shard.GetProperty('ordered_candidate_ids'))
        $PriorityCandidateIds = [long[]]@(Assert-PositiveUniqueJsonIds -Name "$ShardId priority_candidate_ids" -Element $Shard.GetProperty('priority_candidate_ids'))
        $RoundRobinCandidateIds = [long[]]@(Assert-PositiveUniqueJsonIds -Name "$ShardId round_robin_candidate_ids" -Element $Shard.GetProperty('round_robin_candidate_ids'))
        $CohortIds = [long[]]@(@($PriorityCandidateIds) + @($RoundRobinCandidateIds))
        $UniqueCohortIds = [System.Collections.Generic.HashSet[long]]::new()
        $CohortsAreUnique = @($CohortIds | Where-Object { -not $UniqueCohortIds.Add($_) }).Count -eq 0
        if (-not $CohortsAreUnique -or
            @($CohortIds | Where-Object { $OrderedCandidateIds -notcontains $_ }).Count -gt 0 -or
            @($OrderedCandidateIds | Where-Object { $UniqueCohortIds -notcontains $_ }).Count -gt 0) {
            throw 'Wave manifest shard cohorts do not match its candidate IDs'
        }
        $PlannedIssueIds.AddRange($OrderedCandidateIds)
        $ExpectedShards[$ShardId] = [pscustomobject]@{
            Element = $Shard
            OrderedCandidateIds = $OrderedCandidateIds
            PriorityCandidateIds = $PriorityCandidateIds
            RoundRobinCandidateIds = $RoundRobinCandidateIds
        }
    }
    $SortedPlannedIssueIds = $PlannedIssueIds.ToArray()
    [Array]::Sort($SortedPlannedIssueIds)
    $SortedOrderedIssueIds = [long[]]$OrderedIssueIds.Clone()
    [Array]::Sort($SortedOrderedIssueIds)
    if (-not (Test-LongArrayEqual -Left $SortedPlannedIssueIds -Right $SortedOrderedIssueIds)) {
        throw 'Wave manifest shards do not exactly partition the wave issue IDs'
    }

    $ResultPaths = if (Test-Path -LiteralPath $ResultsDirectory -PathType Container) {
        @(Get-ChildItem -LiteralPath $ResultsDirectory -File -Recurse |
            Where-Object Name -CEQ 'shard-result.json' |
            ForEach-Object FullName)
    }
    else { @() }
    $ByShard = @{}
    $RowsByIssue = @{}
    $ResultDigests = [System.Collections.Generic.List[string]]::new()
    $ReportKeys = @('run', 'issues')
    $RunKeys = @(
        'timestamp', 'total_open_inventory', 'assessed', 'priority_cohort', 'round_robin_cohort',
        'deferred', 'stop_reason', 'next_cursor'
    )
    $RowKeys = @(
        'issue', 'title', 'selection_reason', 'activity_and_ownership_context', 'acceptance_signals',
        'repository_evidence', 'lineage_evidence', 'similarity_outcome', 'disposition', 'grooming_finding',
        'recommended_next_step', 'assessment_status', 'deferral_reason'
    )
    $ResultKeys = @(
        'schema_version', 'run_id', 'attempt', 'shard_id', 'manifest_digest',
        'ordered_candidate_ids', 'producer', 'started_at', 'completed_at', 'report_data', 'result_digest'
    )
    foreach ($ResultPath in $ResultPaths) {
        $Result = Read-JsonElement -Path $ResultPath
        if (-not (Test-ExactJsonKeys -Element $Result -Keys $ResultKeys) -or
            $Result.GetProperty('schema_version').GetString() -cne 'backlog-grooming-shard-result/v1') {
            throw 'Malformed shard result envelope'
        }
        $ResultShardId = $Result.GetProperty('shard_id').GetString()
        $ResultAttempt = $Result.GetProperty('attempt')
        $StartedAt = [datetimeoffset]::MinValue
        $CompletedAt = [datetimeoffset]::MinValue
        $DatesValid = [datetimeoffset]::TryParse($Result.GetProperty('started_at').GetString(), [ref]$StartedAt) -and
            [datetimeoffset]::TryParse($Result.GetProperty('completed_at').GetString(), [ref]$CompletedAt)
        $Expected = $ExpectedShards[$ResultShardId]
        $ReportData = $Result.GetProperty('report_data')
        $Run = [System.Text.Json.JsonElement]::new()
        $Issues = [System.Text.Json.JsonElement]::new()
        $HasRun = $ReportData.ValueKind -eq [System.Text.Json.JsonValueKind]::Object -and
            $ReportData.TryGetProperty('run', [ref]$Run)
        $HasIssues = $ReportData.ValueKind -eq [System.Text.Json.JsonValueKind]::Object -and
            $ReportData.TryGetProperty('issues', [ref]$Issues)
        if ($null -eq $Expected -or $ByShard.ContainsKey($ResultShardId) -or
            $Result.GetProperty('run_id').GetString() -cne $ExpectedRunId -or
            -not (Test-SafeJsonInteger -Element $ResultAttempt -Minimum 1) -or $ResultAttempt.GetInt64() -ne $ExpectedAttempt -or
            $Result.GetProperty('manifest_digest').GetString() -cne $RecordedManifestDigest -or
            $Result.GetProperty('producer').GetString() -cne 'backlog-groom/result-job' -or
            -not $DatesValid -or $CompletedAt -lt $StartedAt -or
            -not (Test-LongArrayEqual -Left (Assert-PositiveUniqueJsonIds -Name "$ResultShardId ordered_candidate_ids" -Element $Result.GetProperty('ordered_candidate_ids')) -Right $Expected.OrderedCandidateIds) -or
            -not $HasRun -or -not $HasIssues -or
            -not (Test-ExactJsonKeys -Element $ReportData -Keys $ReportKeys) -or
            -not (Test-ExactJsonKeys -Element $Run -Keys $RunKeys) -or
            $Issues.ValueKind -ne [System.Text.Json.JsonValueKind]::Array -or
            $Run.GetProperty('total_open_inventory').GetInt64() -ne $Expected.Element.GetProperty('total_open_inventory').GetInt64() -or
            $Run.GetProperty('priority_cohort').GetInt64() -ne $Expected.PriorityCandidateIds.Count -or
            $Run.GetProperty('round_robin_cohort').GetInt64() -ne $Expected.RoundRobinCandidateIds.Count -or
            $Run.GetProperty('assessed').GetInt64() + $Run.GetProperty('deferred').GetInt64() -ne $Issues.GetArrayLength()) {
            throw 'Missing, duplicate, stale, unexpected, or manifest-mismatched shard result'
        }
        $RecordedResultDigest = $Result.GetProperty('result_digest').GetString()
        $ResultMaterial = [System.Text.Json.Nodes.JsonObject]::new()
        foreach ($Property in $Result.EnumerateObject()) {
            if ($Property.Name -cne 'result_digest') {
                $ResultMaterial.Add($Property.Name, [System.Text.Json.Nodes.JsonNode]::Parse($Property.Value.GetRawText()))
            }
        }
        if ((Get-CanonicalJsonDigest -Element (Read-JsonElementFromNode -Node $ResultMaterial)) -cne $RecordedResultDigest) {
            throw 'Shard result digest mismatch'
        }
        $ByShard[$ResultShardId] = $true
        $ResultDigests.Add($RecordedResultDigest)
        foreach ($Row in $Issues.EnumerateArray()) {
            $Issue = $Row.GetProperty('issue')
            $IssueId = if (Test-SafeJsonInteger -Element $Issue -Minimum 1) { $Issue.GetInt64() } else { -1 }
            $Title = $Row.GetProperty('title')
            $SelectionReason = $Row.GetProperty('selection_reason')
            $ActivityContext = $Row.GetProperty('activity_and_ownership_context')
            $AcceptanceSignals = $Row.GetProperty('acceptance_signals')
            $RepositoryEvidence = $Row.GetProperty('repository_evidence')
            $LineageEvidence = $Row.GetProperty('lineage_evidence')
            $SimilarityOutcome = $Row.GetProperty('similarity_outcome')
            $Disposition = $Row.GetProperty('disposition')
            $GroomingFinding = $Row.GetProperty('grooming_finding')
            $RecommendedNextStep = $Row.GetProperty('recommended_next_step')
            $AssessmentStatusElement = $Row.GetProperty('assessment_status')
            $DeferralReasonElement = $Row.GetProperty('deferral_reason')
            $LineageKeys = @('original_delivery', 'replacement_or_removal')
            $TextFields = @(
                @{ Element = $Title; Maximum = 500 },
                @{ Element = $SelectionReason; Maximum = 200 },
                @{ Element = $ActivityContext; Maximum = 2000 },
                @{ Element = $AcceptanceSignals; Maximum = 2000 },
                @{ Element = $GroomingFinding; Maximum = 2000 },
                @{ Element = $RecommendedNextStep; Maximum = 2000 }
            )
            $TextFieldsValid = @($TextFields | Where-Object {
                    $_.Element.ValueKind -ne [System.Text.Json.JsonValueKind]::String -or
                    [string]::IsNullOrWhiteSpace($_.Element.GetString()) -or
                    $_.Element.GetString().Length -gt $_.Maximum
                }).Count -eq 0
            $RepositoryEvidenceValid = $RepositoryEvidence.ValueKind -eq [System.Text.Json.JsonValueKind]::Array -and
                $RepositoryEvidence.GetArrayLength() -gt 0 -and
                @($RepositoryEvidence.EnumerateArray() | Where-Object {
                        $_.ValueKind -ne [System.Text.Json.JsonValueKind]::String -or
                        [string]::IsNullOrWhiteSpace($_.GetString()) -or $_.GetString().Length -gt 500
                    }).Count -eq 0
            $LineageValid = Test-ExactJsonKeys -Element $LineageEvidence -Keys $LineageKeys
            $OriginalDelivery = if ($LineageValid) { $LineageEvidence.GetProperty('original_delivery') } else { [System.Text.Json.JsonElement]::new() }
            $ReplacementOrRemoval = if ($LineageValid) { $LineageEvidence.GetProperty('replacement_or_removal') } else { [System.Text.Json.JsonElement]::new() }
            $LineageValid = $LineageValid -and
                $OriginalDelivery.ValueKind -eq [System.Text.Json.JsonValueKind]::Array -and
                $ReplacementOrRemoval.ValueKind -eq [System.Text.Json.JsonValueKind]::Array -and
                @(@($OriginalDelivery.EnumerateArray()) + @($ReplacementOrRemoval.EnumerateArray()) | Where-Object {
                        $_.ValueKind -ne [System.Text.Json.JsonValueKind]::String -or
                        [string]::IsNullOrWhiteSpace($_.GetString()) -or $_.GetString().Length -gt 500
                    }).Count -eq 0
            $AssessmentStatus = if ($AssessmentStatusElement.ValueKind -eq [System.Text.Json.JsonValueKind]::String) {
                $AssessmentStatusElement.GetString()
            } else { '' }
            if (-not (Test-ExactJsonKeys -Element $Row -Keys $RowKeys) -or
                $Expected.OrderedCandidateIds -notcontains $IssueId -or
                -not $TextFieldsValid -or -not $RepositoryEvidenceValid -or -not $LineageValid -or
                $SimilarityOutcome.ValueKind -ne [System.Text.Json.JsonValueKind]::String -or
                $SimilarityOutcome.GetString() -notin @('Match', 'Similar', 'Distinct', 'Uncertain') -or
                $Disposition.ValueKind -ne [System.Text.Json.JsonValueKind]::String -or
                $Disposition.GetString() -notin @('Still needed', 'Likely completed', 'Superseded', 'Possible duplicate', 'Needs correction', 'Uncertain') -or
                $AssessmentStatus -notin @('Assessed', 'Deferred') -or
                $DeferralReasonElement.ValueKind -ne [System.Text.Json.JsonValueKind]::String -or
                $DeferralReasonElement.GetString().Length -gt 500 -or
                $RowsByIssue.ContainsKey($IssueId)) {
                throw "Malformed, duplicate, or out-of-shard wave issue $IssueId"
            }
            $DeferralReason = $DeferralReasonElement.GetString()
            if ($AssessmentStatus -ceq 'Deferred' -and
                ([string]::IsNullOrWhiteSpace($DeferralReason) -or
                $SimilarityOutcome.GetString() -cne 'Uncertain' -or
                $Disposition.GetString() -cne 'Uncertain' -or
                $OriginalDelivery.GetArrayLength() -ne 0 -or $ReplacementOrRemoval.GetArrayLength() -ne 0)) {
                throw "Deferred wave issue $IssueId requires a reason, Uncertain outcomes, and empty lineage evidence"
            }
            if ($AssessmentStatus -ceq 'Assessed' -and $DeferralReason -cne '') {
                throw "Assessed wave issue $IssueId cannot include a deferral reason"
            }
            if ($Disposition.GetString() -ceq 'Possible duplicate' -and
                $SimilarityOutcome.GetString() -notin @('Match', 'Similar')) {
                throw "Possible duplicate wave issue $IssueId requires a Match or Similar outcome"
            }
            if ($Disposition.GetString() -ceq 'Superseded') {
                $OriginalValues = @($OriginalDelivery.EnumerateArray() | ForEach-Object { $_.GetString() })
                $ReplacementValues = @($ReplacementOrRemoval.EnumerateArray() | ForEach-Object { $_.GetString() })
                if ($OriginalValues.Count -eq 0 -or $ReplacementValues.Count -eq 0 -or
                    @($ReplacementValues | Where-Object { $OriginalValues -notcontains $_ }).Count -eq 0) {
                    throw "Superseded wave issue $IssueId requires distinct original and replacement evidence"
                }
            }
            $RowsByIssue[$IssueId] = $Row.Clone()
        }
    }
    if ($ByShard.Count -ne $ManifestShards.Count) {
        throw 'Wave result set is incomplete'
    }
    $Rows = @($OrderedIssueIds | ForEach-Object { $RowsByIssue[$_] })
    if (@($Rows | Where-Object { $null -eq $_ }).Count -gt 0 -or $RowsByIssue.Count -ne $OrderedIssueIds.Count) {
        throw 'Wave issue coverage is incomplete or out of snapshot'
    }
    $AssessedIds = [long[]]@($Rows | Where-Object { $_.GetProperty('assessment_status').GetString() -ceq 'Assessed' } |
            ForEach-Object { $_.GetProperty('issue').GetInt64() })
    $DeferredIds = [long[]]@($Rows | Where-Object { $_.GetProperty('assessment_status').GetString() -ceq 'Deferred' } |
            ForEach-Object { $_.GetProperty('issue').GetInt64() })
    if ($AssessedIds.Count + $DeferredIds.Count -ne $Rows.Count) {
        throw 'Wave row status is invalid'
    }

    $ResultDigestValues = $ResultDigests.ToArray()
    [Array]::Sort($ResultDigestValues, [System.StringComparer]::Ordinal)
    $AggregateMaterial = [System.Text.Json.Nodes.JsonObject]::new()
    $AggregateMaterial.Add('schema_version', 'backlog-grooming-wave-aggregate/v1')
    $AggregateMaterial.Add('sweep_id', $Manifest.GetProperty('sweep_id').GetString())
    $AggregateMaterial.Add('snapshot_digest', $Manifest.GetProperty('snapshot_digest').GetString())
    $AggregateMaterial.Add('wave_number', $WaveNumber.GetInt64())
    $AggregateMaterial.Add('required_waves', $RequiredWaves.GetInt64())
    $AggregateMaterial.Add('manifest_digest', $RecordedManifestDigest)
    $AggregateMaterial.Add('source_run_id', $ExpectedRunId)
    $AggregateMaterial.Add('source_attempt', $ExpectedAttempt)
    $AggregateMaterial.Add('result_digests', (New-JsonArray -Values $ResultDigestValues))
    $AggregateMaterial.Add('assessed_issue_ids', (New-JsonArray -Values $AssessedIds))
    $AggregateMaterial.Add('deferred_issue_ids', (New-JsonArray -Values $DeferredIds))
    $AggregateMaterial.Add('rows', (New-JsonArray -Values $Rows))
    $AggregateDigest = Get-CanonicalJsonDigest -Element (Read-JsonElementFromNode -Node $AggregateMaterial)
    $AggregateMaterial.Add('aggregate_digest', $AggregateDigest)
    $SerializerOptions = [System.Text.Json.JsonSerializerOptions]::new()
    $SerializerOptions.WriteIndented = $true
    $SerializerOptions.Encoder = [System.Text.Encodings.Web.JavaScriptEncoder]::UnsafeRelaxedJsonEscaping
    $null = [System.IO.Directory]::CreateDirectory($AggregateDirectory)
    $AggregatePath = Join-Path $AggregateDirectory 'aggregate.json'
    [System.IO.File]::WriteAllText($AggregatePath, $AggregateMaterial.ToJsonString($SerializerOptions) + "`n", [System.Text.UTF8Encoding]::new($false))

    return [pscustomobject]@{
        AggregateDigest = $AggregateDigest
        AssessedIds = $AssessedIds
        DeferredIds = $DeferredIds
        AggregatePath = $AggregatePath
    }
}

<#
.SYNOPSIS
    Converts a mutable JSON node to a detached JSON element.
.PARAMETER Node
    JSON node to convert.
.OUTPUTS
    System.Text.Json.JsonElement
#>
function Read-JsonElementFromNode {
    [CmdletBinding()]
    [OutputType([System.Text.Json.JsonElement])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Text.Json.Nodes.JsonNode]$Node
    )

    $Document = [System.Text.Json.JsonDocument]::Parse($Node.ToJsonString())
    try {
        return $Document.RootElement.Clone()
    }
    finally {
        $Document.Dispose()
    }
}
#endregion Functions

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force
        $Validation = Invoke-BacklogGroomWaveValidation @PSBoundParameters
        Set-CIOutput -Name 'aggregate-digest' -Value $Validation.AggregateDigest
        Set-CIOutput -Name 'assessed-ids' -Value (New-JsonArray -Values @($Validation.AssessedIds)).ToJsonString()
        Set-CIOutput -Name 'deferred-ids' -Value (New-JsonArray -Values @($Validation.DeferredIds)).ToJsonString()
        Write-Host 'Backlog grooming wave validation passed' -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Backlog grooming wave validation failed: $($_.Exception.Message)"
        exit 1
    }
}
#endregion Main Execution
