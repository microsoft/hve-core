# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
# BacklogGrooming.psm1
# Purpose: Construct canonical backlog grooming shard results from candidate-addressed scalar calls.
#Requires -Version 7.4

$ErrorActionPreference = 'Stop'

#region Canonical JSON
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
    Parses JSON text into a detached JSON element.
.PARAMETER Json
    JSON text to parse.
.OUTPUTS
    System.Text.Json.JsonElement
#>
function ConvertFrom-JsonElementText {
    [CmdletBinding()]
    [OutputType([System.Text.Json.JsonElement])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Json
    )

    $Document = [System.Text.Json.JsonDocument]::Parse($Json)
    try {
        return $Document.RootElement.Clone()
    }
    finally {
        $Document.Dispose()
    }
}
#endregion Canonical JSON

#region Trusted Input
<#
.SYNOPSIS
    Reads and validates a JSON array of unique positive issue IDs.
.PARAMETER Name
    Input name used in validation errors.
.PARAMETER Json
    JSON array text.
.PARAMETER MinimumCount
    Minimum accepted array length.
.PARAMETER MaximumCount
    Maximum accepted array length.
.OUTPUTS
    System.Int64[]
#>
function ConvertFrom-TrustedIssueIdList {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Json,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 5)]
        [int]$MinimumCount = 0,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 5)]
        [int]$MaximumCount = 5
    )

    try {
        $Element = ConvertFrom-JsonElementText -Json $Json
    }
    catch {
        throw "$Name is not valid JSON"
    }
    if ($Element.ValueKind -ne [System.Text.Json.JsonValueKind]::Array -or
        $Element.GetArrayLength() -lt $MinimumCount -or $Element.GetArrayLength() -gt $MaximumCount) {
        throw "$Name must contain $MinimumCount to $MaximumCount unique positive integers"
    }

    $IssueIds = [System.Collections.Generic.List[long]]::new()
    $UniqueIssueIds = [System.Collections.Generic.HashSet[long]]::new()
    foreach ($Item in $Element.EnumerateArray()) {
        $IssueId = 0L
        if ($Item.ValueKind -ne [System.Text.Json.JsonValueKind]::Number -or
            -not $Item.TryGetInt64([ref]$IssueId) -or $IssueId -le 0 -or
            $IssueId -gt 9007199254740991 -or -not $UniqueIssueIds.Add($IssueId)) {
            throw "$Name must contain $MinimumCount to $MaximumCount unique positive integers"
        }
        $IssueIds.Add($IssueId)
    }
    return , $IssueIds.ToArray()
}

<#
.SYNOPSIS
    Parses a trusted decimal integer string within supplied bounds.
.PARAMETER Name
    Input name used in validation errors.
.PARAMETER Value
    Decimal text to parse.
.PARAMETER Minimum
    Inclusive minimum value.
.OUTPUTS
    System.Int64
#>
function ConvertFrom-TrustedInteger {
    [CmdletBinding()]
    [OutputType([long])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Value,

        [Parameter(Mandatory = $false)]
        [long]$Minimum = 0
    )

    $Parsed = 0L
    if ($Value -notmatch '^\d+$' -or
        -not [long]::TryParse($Value, [System.Globalization.NumberStyles]::None,
            [System.Globalization.CultureInfo]::InvariantCulture, [ref]$Parsed) -or
        $Parsed -lt $Minimum -or $Parsed -gt 9007199254740991) {
        throw "$Name must be an integer from $Minimum through 9007199254740991"
    }
    return $Parsed
}

<#
.SYNOPSIS
    Validates trusted shard identity and cohort inputs.
.PARAMETER ShardId
    Stable shard identifier.
.PARAMETER ManifestDigest
    Canonical manifest SHA-256 digest.
.PARAMETER OrderedCandidateIdsJson
    Ordered candidate issue IDs as JSON.
.PARAMETER PriorityCandidateIdsJson
    Priority cohort issue IDs as JSON.
.PARAMETER RoundRobinCandidateIdsJson
    Round-robin cohort issue IDs as JSON.
.PARAMETER TotalOpenInventoryText
    Complete open inventory count as decimal text.
.PARAMETER PriorCursorText
    Prior cursor as decimal text.
.PARAMETER OrchestratorRunId
    Producing orchestrator run ID.
.PARAMETER OrchestratorAttemptText
    Producing orchestrator attempt as decimal text.
.OUTPUTS
    System.Management.Automation.PSCustomObject
#>
function Assert-BacklogGroomingTrustedContext {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)] [string]$ShardId,
        [Parameter(Mandatory = $true)] [string]$ManifestDigest,
        [Parameter(Mandatory = $true)] [string]$OrderedCandidateIdsJson,
        [Parameter(Mandatory = $true)] [string]$PriorityCandidateIdsJson,
        [Parameter(Mandatory = $true)] [string]$RoundRobinCandidateIdsJson,
        [Parameter(Mandatory = $true)] [string]$TotalOpenInventoryText,
        [Parameter(Mandatory = $true)] [string]$PriorCursorText,
        [Parameter(Mandatory = $true)] [string]$OrchestratorRunId,
        [Parameter(Mandatory = $true)] [string]$OrchestratorAttemptText
    )

    if ($ShardId -notmatch '^[a-z0-9][a-z0-9-]{0,62}$' -or $ManifestDigest -notmatch '^[a-f0-9]{64}$' -or
        $OrchestratorRunId -notmatch '^\d+$') {
        throw 'Shard identity or manifest provenance is invalid'
    }
    $OrderedCandidateIds = ConvertFrom-TrustedIssueIdList -Name 'Worker candidate IDs' `
        -Json $OrderedCandidateIdsJson -MinimumCount 1 -MaximumCount 5
    $PriorityCandidateIds = ConvertFrom-TrustedIssueIdList -Name 'Worker priority cohort IDs' `
        -Json $PriorityCandidateIdsJson
    $RoundRobinCandidateIds = ConvertFrom-TrustedIssueIdList -Name 'Worker round-robin cohort IDs' `
        -Json $RoundRobinCandidateIdsJson
    $TotalOpenInventory = ConvertFrom-TrustedInteger -Name 'Worker total open inventory' `
        -Value $TotalOpenInventoryText -Minimum $OrderedCandidateIds.Count
    $PriorCursor = ConvertFrom-TrustedInteger -Name 'Worker prior cursor' -Value $PriorCursorText
    $OrchestratorAttempt = ConvertFrom-TrustedInteger -Name 'Orchestrator attempt' `
        -Value $OrchestratorAttemptText -Minimum 1

    $CandidateSet = [System.Collections.Generic.HashSet[long]]::new()
    foreach ($IssueId in $OrderedCandidateIds) {
        $null = $CandidateSet.Add($IssueId)
    }
    $CohortSet = [System.Collections.Generic.HashSet[long]]::new()
    $CohortIds = [long[]]@($PriorityCandidateIds + $RoundRobinCandidateIds)
    $CohortsAreUnique = $true
    foreach ($IssueId in $CohortIds) {
        if (-not $CohortSet.Add($IssueId)) {
            $CohortsAreUnique = $false
        }
    }
    if (-not $CohortsAreUnique -or $CohortSet.Count -ne $CandidateSet.Count -or
        @($CohortSet | Where-Object { -not $CandidateSet.Contains($_) }).Count -gt 0) {
        throw 'Worker cohort IDs must exactly partition the planned candidate IDs'
    }

    return [pscustomobject]@{
        OrderedCandidateIds = $OrderedCandidateIds
        PriorityCandidateIds = $PriorityCandidateIds
        RoundRobinCandidateIds = $RoundRobinCandidateIds
        TotalOpenInventory = $TotalOpenInventory
        PriorCursor = $PriorCursor
        OrchestratorAttempt = $OrchestratorAttempt
    }
}
#endregion Trusted Input

#region Candidate Calls
<#
.SYNOPSIS
    Reads one named JSON property without coercion.
.PARAMETER Element
    JSON object to inspect.
.PARAMETER Name
    Property name to read.
.OUTPUTS
    System.Management.Automation.PSCustomObject
#>
function Get-JsonPropertyState {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Text.Json.JsonElement]$Element,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $Property = [System.Text.Json.JsonElement]::new()
    $Present = $Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object -and
        $Element.TryGetProperty($Name, [ref]$Property)
    return [pscustomobject]@{
        Present = $Present
        Element = if ($Present) { $Property.Clone() } else { [System.Text.Json.JsonElement]::new() }
    }
}

<#
.SYNOPSIS
    Reads one named scalar string property without coercion.
.PARAMETER Element
    JSON object to inspect.
.PARAMETER Name
    Property name to read.
.OUTPUTS
    System.Management.Automation.PSCustomObject
#>
function Get-JsonStringState {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)] [System.Text.Json.JsonElement]$Element,
        [Parameter(Mandatory = $true)] [string]$Name
    )

    $State = Get-JsonPropertyState -Element $Element -Name $Name
    $IsString = $State.Present -and $State.Element.ValueKind -eq [System.Text.Json.JsonValueKind]::String
    return [pscustomobject]@{
        Present = $State.Present
        IsString = $IsString
        Value = if ($IsString) { $State.Element.GetString() } else { $null }
    }
}

<#
.SYNOPSIS
    Tests a required semantic text value.
.PARAMETER Value
    Text to validate.
.PARAMETER MaximumLength
    Maximum accepted character count.
.OUTPUTS
    System.Boolean
#>
function Test-RequiredSemanticText {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)] [AllowNull()] [AllowEmptyString()] [string]$Value,
        [Parameter(Mandatory = $true)] [int]$MaximumLength
    )

    return -not [string]::IsNullOrWhiteSpace($Value) -and $Value.Length -le $MaximumLength
}

<#
.SYNOPSIS
    Truncates one evidence item to the established 500-character bound.
.PARAMETER Value
    Evidence text to normalize.
.OUTPUTS
    System.String
#>
function ConvertTo-BoundedEvidenceText {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)] [AllowEmptyString()] [string]$Value
    )

    if ($Value.Length -le 500) {
        return $Value
    }
    return $Value.Substring(0, 497).TrimEnd() + '...'
}

<#
.SYNOPSIS
    Reconstructs evidence lists from numbered scalar fields.
.PARAMETER Call
    Candidate call object.
.PARAMETER Prefix
    Scalar property prefix.
.OUTPUTS
    System.Management.Automation.PSCustomObject
#>
function ConvertFrom-CategorizedEvidence {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)] [System.Text.Json.JsonElement]$Call
    )

    $Valid = $true
    $Repository = [System.Collections.Generic.List[string]]::new()
    $OriginalDelivery = [System.Collections.Generic.List[string]]::new()
    $ReplacementOrRemoval = [System.Collections.Generic.List[string]]::new()
    $ActualCount = 0
    $ReachedEmptyPosition = $false
    foreach ($Position in 1..5) {
        $CategoryState = Get-JsonStringState -Element $Call -Name "evidence-$Position-category"
        $TextState = Get-JsonStringState -Element $Call -Name "evidence-$Position-text"
        if (-not $CategoryState.Present -and -not $TextState.Present) {
            $ReachedEmptyPosition = $true
            continue
        }
        if ($ReachedEmptyPosition -or -not $CategoryState.IsString -or
            -not $TextState.IsString -or [string]::IsNullOrWhiteSpace($TextState.Value)) {
            $Valid = $false
            continue
        }
        $ActualCount++
        $BoundedText = ConvertTo-BoundedEvidenceText -Value $TextState.Value
        $Repository.Add($BoundedText)
        switch -CaseSensitive ($CategoryState.Value) {
            'Repository' { }
            'Original delivery' { $OriginalDelivery.Add($BoundedText) }
            'Replacement or removal' { $ReplacementOrRemoval.Add($BoundedText) }
            default { $Valid = $false }
        }
    }
    if ($ActualCount -eq 0) {
        $Valid = $false
    }
    return [pscustomobject]@{
        Valid = $Valid
        Repository = [string[]]$Repository.ToArray()
        OriginalDelivery = [string[]]$OriginalDelivery.ToArray()
        ReplacementOrRemoval = [string[]]$ReplacementOrRemoval.ToArray()
    }
}

<#
.SYNOPSIS
    Tests whether a reconstructed row has distinct supersession lineage.
.PARAMETER Row
    Reconstructed candidate row.
.OUTPUTS
    System.Boolean
#>
function Test-ValidSupersessionLineage {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary]$Row
    )

    $OriginalDelivery = [string[]]$Row.lineage_evidence.original_delivery
    $ReplacementOrRemoval = [string[]]$Row.lineage_evidence.replacement_or_removal
    return $OriginalDelivery.Count -gt 0 -and $ReplacementOrRemoval.Count -gt 0 -and
        @($ReplacementOrRemoval | Where-Object { $OriginalDelivery -cnotcontains $_ }).Count -gt 0
}

<#
.SYNOPSIS
    Converts one candidate scalar call into a canonical row or contract error.
.PARAMETER Call
    Candidate call object.
.PARAMETER IssueId
    Trusted planned issue identity.
.OUTPUTS
    System.Management.Automation.PSCustomObject
#>
function ConvertFrom-BacklogGroomingCandidateCall {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)] [System.Text.Json.JsonElement]$Call,
        [Parameter(Mandatory = $true)] [long]$IssueId
    )

    $Valid = $true
    $ScalarValues = [ordered]@{}
    $FieldDefinitions = [ordered]@{
        title = @{ Input = 'title'; Maximum = 500 }
        selection_reason = @{ Input = 'selection-reason'; Maximum = 200 }
        activity_and_ownership_context = @{ Input = 'activity-and-ownership-context'; Maximum = 2000 }
        acceptance_signals = @{ Input = 'acceptance-signals'; Maximum = 2000 }
        grooming_finding = @{ Input = 'grooming-finding'; Maximum = 2000 }
        recommended_next_step = @{ Input = 'recommended-next-step'; Maximum = 2000 }
        similarity_outcome = @{ Input = 'similarity-outcome'; Maximum = 100 }
        disposition = @{ Input = 'disposition'; Maximum = 100 }
        assessment_status = @{ Input = 'assessment-status'; Maximum = 100 }
    }
    foreach ($FieldName in $FieldDefinitions.Keys) {
        $Definition = $FieldDefinitions[$FieldName]
        $State = Get-JsonStringState -Element $Call -Name $Definition.Input
        if (-not $State.Present -or -not $State.IsString -or
            -not (Test-RequiredSemanticText -Value $State.Value -MaximumLength $Definition.Maximum)) {
            $Valid = $false
        }
        $ScalarValues[$FieldName] = $State.Value
    }

    $DeferralReasonState = Get-JsonStringState -Element $Call -Name 'deferral-reason'
    $NormalizationCodes = [System.Collections.Generic.List[string]]::new()
    if (-not $DeferralReasonState.Present) {
        if ($ScalarValues.assessment_status -ceq 'Assessed') {
            $DeferralReason = ''
        }
        else {
            $Valid = $false
            $DeferralReason = $null
        }
    }
    else {
        $DeferralReason = $DeferralReasonState.Value
        if (-not $DeferralReasonState.IsString -or $DeferralReason.Length -gt 500) {
            $Valid = $false
        }
    }

    $Evidence = ConvertFrom-CategorizedEvidence -Call $Call
    if (-not $Evidence.Valid -or $Evidence.Repository.Count -eq 0) {
        $Valid = $false
    }
    if (-not $Valid) {
        return [pscustomobject]@{ Valid = $false; Row = $null; Normalizations = @() }
    }

    $Row = [ordered]@{
        issue = $IssueId
        title = $ScalarValues.title
        selection_reason = $ScalarValues.selection_reason
        activity_and_ownership_context = $ScalarValues.activity_and_ownership_context
        acceptance_signals = $ScalarValues.acceptance_signals
        repository_evidence = $Evidence.Repository
        lineage_evidence = [ordered]@{
            original_delivery = $Evidence.OriginalDelivery
            replacement_or_removal = $Evidence.ReplacementOrRemoval
        }
        similarity_outcome = $ScalarValues.similarity_outcome
        disposition = $ScalarValues.disposition
        grooming_finding = $ScalarValues.grooming_finding
        recommended_next_step = $ScalarValues.recommended_next_step
        assessment_status = $ScalarValues.assessment_status
        deferral_reason = $DeferralReason
    }
    if ($Row.similarity_outcome -ceq 'Superseded' -and $Row.disposition -ceq 'Superseded' -and
        (Test-ValidSupersessionLineage -Row $Row)) {
        $Row.similarity_outcome = 'Uncertain'
        $NormalizationCodes.Add('superseded_similarity_normalized')
    }

    if ($Row.similarity_outcome -cnotin @('Match', 'Similar', 'Distinct', 'Uncertain') -or
        $Row.disposition -cnotin @('Still needed', 'Likely completed', 'Superseded', 'Possible duplicate', 'Needs correction', 'Uncertain') -or
        $Row.assessment_status -cnotin @('Assessed', 'Deferred')) {
        return [pscustomobject]@{ Valid = $false; Row = $null; Normalizations = @() }
    }
    if ($Row.disposition -ceq 'Superseded' -and -not (Test-ValidSupersessionLineage -Row $Row)) {
        $Row.disposition = 'Uncertain'
        $Row.similarity_outcome = 'Uncertain'
    }
    if ($Row.assessment_status -ceq 'Deferred' -and
        ([string]::IsNullOrWhiteSpace($Row.deferral_reason) -or
        $Row.similarity_outcome -cne 'Uncertain' -or $Row.disposition -cne 'Uncertain' -or
        $Row.lineage_evidence.original_delivery.Count -ne 0 -or
        $Row.lineage_evidence.replacement_or_removal.Count -ne 0)) {
        return [pscustomobject]@{ Valid = $false; Row = $null; Normalizations = @() }
    }
    if ($Row.assessment_status -ceq 'Assessed' -and $Row.deferral_reason -cne '') {
        return [pscustomobject]@{ Valid = $false; Row = $null; Normalizations = @() }
    }
    if ($Row.disposition -ceq 'Possible duplicate' -and
        $Row.similarity_outcome -cnotin @('Match', 'Similar')) {
        return [pscustomobject]@{ Valid = $false; Row = $null; Normalizations = @() }
    }

    $Normalizations = @($NormalizationCodes | ForEach-Object {
            [ordered]@{ issue = $IssueId; code = $_ }
        })
    return [pscustomobject]@{ Valid = $true; Row = $Row; Normalizations = $Normalizations }
}
#endregion Candidate Calls

#region Result Construction
<#
.SYNOPSIS
    Constructs one canonical backlog grooming shard result envelope.
.DESCRIPTION
    Validates trusted shard context, indexes candidate calls by explicit issue
    identity, preserves candidate-local failures, and returns the unchanged v2
    result envelope with its canonical SHA-256 digest.
.PARAMETER AgentOutput
    Normalized GH_AW_AGENT_OUTPUT JSON root.
.PARAMETER ShardId
    Stable shard identifier.
.PARAMETER ManifestDigest
    Canonical manifest SHA-256 digest.
.PARAMETER OrderedCandidateIdsJson
    Ordered candidate issue IDs as JSON.
.PARAMETER PriorityCandidateIdsJson
    Priority cohort issue IDs as JSON.
.PARAMETER RoundRobinCandidateIdsJson
    Round-robin cohort issue IDs as JSON.
.PARAMETER TotalOpenInventoryText
    Complete open inventory count as decimal text.
.PARAMETER PriorCursorText
    Prior cursor as decimal text.
.PARAMETER OrchestratorRunId
    Producing orchestrator run ID.
.PARAMETER OrchestratorAttemptText
    Producing orchestrator attempt as decimal text.
.PARAMETER StartedAt
    Trusted collector start time.
.OUTPUTS
    System.Collections.Specialized.OrderedDictionary
#>
function ConvertTo-BacklogGroomingShardResult {
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $true)] [System.Text.Json.JsonElement]$AgentOutput,
        [Parameter(Mandatory = $true)] [string]$ShardId,
        [Parameter(Mandatory = $true)] [string]$ManifestDigest,
        [Parameter(Mandatory = $true)] [string]$OrderedCandidateIdsJson,
        [Parameter(Mandatory = $true)] [string]$PriorityCandidateIdsJson,
        [Parameter(Mandatory = $true)] [string]$RoundRobinCandidateIdsJson,
        [Parameter(Mandatory = $true)] [string]$TotalOpenInventoryText,
        [Parameter(Mandatory = $true)] [string]$PriorCursorText,
        [Parameter(Mandatory = $true)] [string]$OrchestratorRunId,
        [Parameter(Mandatory = $true)] [string]$OrchestratorAttemptText,
        [Parameter(Mandatory = $true)] [datetimeoffset]$StartedAt
    )

    $TrustedContext = Assert-BacklogGroomingTrustedContext -ShardId $ShardId `
        -ManifestDigest $ManifestDigest -OrderedCandidateIdsJson $OrderedCandidateIdsJson `
        -PriorityCandidateIdsJson $PriorityCandidateIdsJson `
        -RoundRobinCandidateIdsJson $RoundRobinCandidateIdsJson `
        -TotalOpenInventoryText $TotalOpenInventoryText -PriorCursorText $PriorCursorText `
        -OrchestratorRunId $OrchestratorRunId -OrchestratorAttemptText $OrchestratorAttemptText

    $ItemsState = Get-JsonPropertyState -Element $AgentOutput -Name 'items'
    if (-not $ItemsState.Present -or $ItemsState.Element.ValueKind -ne [System.Text.Json.JsonValueKind]::Array) {
        throw 'Normalized agent output must contain an items array'
    }

    $CandidateSet = [System.Collections.Generic.HashSet[long]]::new()
    foreach ($IssueId in $TrustedContext.OrderedCandidateIds) {
        $null = $CandidateSet.Add($IssueId)
    }
    $CallsByIssue = @{}
    foreach ($Item in $ItemsState.Element.EnumerateArray()) {
        $TypeState = Get-JsonStringState -Element $Item -Name 'type'
        if (-not $TypeState.IsString -or $TypeState.Value -cne 'publish_backlog_grooming_result') {
            continue
        }
        $IssueState = Get-JsonPropertyState -Element $Item -Name 'issue-number'
        $IssueId = 0L
        if (-not $IssueState.Present -or $IssueState.Element.ValueKind -ne [System.Text.Json.JsonValueKind]::Number -or
            -not $IssueState.Element.TryGetInt64([ref]$IssueId) -or $IssueId -le 0 -or
            $IssueId -gt 9007199254740991) {
            Write-Information 'Rejected backlog grooming result call with invalid issue identity' -InformationAction Continue
            continue
        }
        if (-not $CandidateSet.Contains($IssueId)) {
            Write-Information "Rejected foreign backlog grooming result call for issue #$IssueId" -InformationAction Continue
            continue
        }
        if (-not $CallsByIssue.ContainsKey($IssueId)) {
            $CallsByIssue[$IssueId] = [System.Collections.Generic.List[System.Text.Json.JsonElement]]::new()
        }
        $CallsByIssue[$IssueId].Add($Item.Clone())
    }

    $AcceptedRows = [System.Collections.Generic.List[object]]::new()
    $ContractErrors = [System.Collections.Generic.List[object]]::new()
    $Normalizations = [System.Collections.Generic.List[object]]::new()
    foreach ($IssueId in $TrustedContext.OrderedCandidateIds) {
        if (-not $CallsByIssue.ContainsKey($IssueId) -or $CallsByIssue[$IssueId].Count -ne 1) {
            $ContractErrors.Add([ordered]@{ issue = $IssueId; code = 'invalid_row_contract' })
            continue
        }
        $CandidateResult = ConvertFrom-BacklogGroomingCandidateCall -Call $CallsByIssue[$IssueId][0] -IssueId $IssueId
        if (-not $CandidateResult.Valid) {
            $ContractErrors.Add([ordered]@{ issue = $IssueId; code = 'invalid_row_contract' })
            continue
        }
        $AcceptedRows.Add($CandidateResult.Row)
        foreach ($Normalization in $CandidateResult.Normalizations) {
            $Normalizations.Add($Normalization)
        }
    }

    $AssessedRows = @($AcceptedRows | Where-Object { $_.assessment_status -ceq 'Assessed' })
    $DeferredRows = @($AcceptedRows | Where-Object { $_.assessment_status -ceq 'Deferred' })
    $NextCursor = $TrustedContext.PriorCursor
    foreach ($IssueId in $TrustedContext.OrderedCandidateIds) {
        if (@($AssessedRows | Where-Object { $_.issue -eq $IssueId }).Count -eq 1) {
            $NextCursor = $IssueId
        }
    }
    $DistinctDeferralReasons = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($Row in $DeferredRows) {
        $null = $DistinctDeferralReasons.Add($Row.deferral_reason.Trim())
    }

    $CompletedAt = [datetimeoffset]::UtcNow
    if ($CompletedAt -lt $StartedAt) {
        $CompletedAt = $StartedAt
    }
    $StartedAtText = $StartedAt.ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'", [System.Globalization.CultureInfo]::InvariantCulture)
    $CompletedAtText = $CompletedAt.ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'", [System.Globalization.CultureInfo]::InvariantCulture)
    $StopReason = if ($ContractErrors.Count -gt 0) {
        "Contract errors: $($ContractErrors.Count)"
    }
    elseif ($DeferredRows.Count -eq 0) {
        'Complete shard assessed'
    }
    else {
        "Deferred rows: $($DeferredRows.Count); distinct non-empty reasons: $($DistinctDeferralReasons.Count)"
    }
    $Run = [ordered]@{
        timestamp = $CompletedAtText
        total_open_inventory = $TrustedContext.TotalOpenInventory
        assessed = $AssessedRows.Count
        priority_cohort = $TrustedContext.PriorityCandidateIds.Count
        round_robin_cohort = $TrustedContext.RoundRobinCandidateIds.Count
        deferred = $DeferredRows.Count
        contract_errors = $ContractErrors.Count
        stop_reason = $StopReason
        next_cursor = $NextCursor
    }
    $ReportData = [ordered]@{
        run = $Run
        issues = $AcceptedRows.ToArray()
        contract_errors = $ContractErrors.ToArray()
        normalizations = $Normalizations.ToArray()
    }
    $Result = [ordered]@{
        schema_version = 'backlog-grooming-shard-result/v2'
        run_id = $OrchestratorRunId
        attempt = $TrustedContext.OrchestratorAttempt
        shard_id = $ShardId
        manifest_digest = $ManifestDigest
        ordered_candidate_ids = $TrustedContext.OrderedCandidateIds
        producer = 'backlog-groom/result-job'
        started_at = $StartedAtText
        completed_at = $CompletedAtText
        report_data = $ReportData
    }
    $ResultElement = ConvertFrom-JsonElementText -Json ($Result | ConvertTo-Json -Depth 20 -Compress)
    $Envelope = [ordered]@{}
    foreach ($Key in $Result.Keys) {
        $Envelope[$Key] = $Result[$Key]
    }
    $Envelope.result_digest = Get-CanonicalJsonDigest -Element $ResultElement
    return $Envelope
}
#endregion Result Construction

Export-ModuleMember -Function @(
    'ConvertTo-BacklogGroomingShardResult'
)