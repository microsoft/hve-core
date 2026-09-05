#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Validates Design Intent Records and their generated verification artifacts.

.DESCRIPTION
    Reference implementation of the Design Intent contract. Authored records at
    design-intent/<surface-id>.intent.yaml are human-owned committed source.
    Verification artifacts at design-intent/.verification/<surface-id>.earl.json
    are transient CI output and are never committed.

    The validator applies both JSON Schemas and the semantic rules that JSON
    Schema cannot express: duplicate YAML mapping keys, real calendar dates and
    RFC 3339 timestamps, filename binding, runtime surface and state resolution,
    nested identifier uniqueness, probe vocabulary and adequacy, assertion
    reference and coverage, orphan artifacts, and digest freshness.

    Source-only mode never requires generated output. Pass -RequireVerification
    after a consumer generates results to additionally require a current and
    complete artifact for every accepted record.

.PARAMETER RootPath
    Repository root to validate. Defaults to the hve-core repository root.

.PARAMETER RequireVerification
    Additionally require a current, complete verification artifact for every
    accepted record. Proposed records may omit one and retired records need none.

.PARAMETER ProbeCriteriaMapPath
    Optional override for the runtime probe adequacy map. Defaults to the map
    shipped with the accessibility skill beside this script.

.PARAMETER OutputPath
    Structured result path, absolute or relative to RootPath.

.EXAMPLE
    ./Validate-DesignIntent.ps1

.EXAMPLE
    ./Validate-DesignIntent.ps1 -RootPath ./fixtures/valid-repo -RequireVerification
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RootPath,

    [Parameter(Mandatory = $false)]
    [switch]$RequireVerification,

    [Parameter(Mandatory = $false)]
    [string]$ProbeCriteriaMapPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'logs/design-intent-validation-results.json'
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

#region Contract

$script:AuthoredSchemaPath = Join-Path $PSScriptRoot 'schemas/design-intent.schema.json'
$script:VerificationSchemaPath = Join-Path $PSScriptRoot 'schemas/design-intent-verification.schema.json'
$script:DefaultProbeCriteriaMapPath = Join-Path $PSScriptRoot '../../.github/skills/accessibility/accessibility/scripts/runtime_a11y/probe-criteria-map.json'

# 'default' is every surface's implicit base state and is never declared in runtime config.
$script:ImplicitState = 'default'
$script:AxeProbeId = 'probe-axe'
$script:AxeMethod = 'axe-auto'
$script:RuntimeMethod = 'runtime-automation'
$script:CustomAssertion = 'custom'

#endregion Contract

#region Primitives

function Get-NormalizedDigest {
    <#
    .SYNOPSIS
        Computes the contract digest over LF-normalized UTF-8 content.

    .DESCRIPTION
        The repository normalizes line endings with text=auto, so a raw-byte
        digest would report false staleness on a CRLF checkout.

    .PARAMETER Content
        Raw file content.

    .OUTPUTS
        [string] Digest in 'sha256:<lowercase hex>' form.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content
    )

    $normalized = $Content -replace "`r`n", "`n"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($normalized)
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return 'sha256:' + [System.Convert]::ToHexString($hash).ToLowerInvariant()
}

function Test-CalendarDate {
    <#
    .SYNOPSIS
        Confirms a string is a real yyyy-MM-dd calendar date.

    .PARAMETER Value
        Candidate date string.

    .OUTPUTS
        [bool]
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Value
    )

    $parsed = [datetime]::MinValue
    return [datetime]::TryParseExact(
        $Value,
        'yyyy-MM-dd',
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None,
        [ref]$parsed)
}

function Test-Rfc3339Timestamp {
    <#
    .SYNOPSIS
        Confirms a string is an RFC 3339 date-time.

    .PARAMETER Value
        Candidate timestamp string.

    .OUTPUTS
        [bool]
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }

    # RFC 3339 requires a date, a 'T' separator, a time, and an explicit offset.
    if ($Value -notmatch '^\d{4}-\d{2}-\d{2}[Tt]\d{2}:\d{2}:\d{2}(\.\d+)?([Zz]|[+-]\d{2}:\d{2})$') {
        return $false
    }

    $parsed = [datetimeoffset]::MinValue
    return [datetimeoffset]::TryParse(
        $Value,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::RoundtripKind,
        [ref]$parsed)
}

function Get-JsonStringLiteral {
    <#
    .SYNOPSIS
        Reads a top-level string property without ConvertFrom-Json date coercion.

    .DESCRIPTION
        ConvertFrom-Json converts ISO-like strings to DateTime, which would hide
        the authored text from format validation. JsonDocument preserves it.

    .PARAMETER Json
        Document as JSON text.

    .PARAMETER Name
        Top-level property name.

    .OUTPUTS
        [string] The literal value.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Json,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    # Called only after schema validation, so the property exists and is a string.
    $document = [System.Text.Json.JsonDocument]::Parse($Json)
    try {
        return $document.RootElement.GetProperty($Name).GetString()
    }
    finally {
        $document.Dispose()
    }
}

function New-DesignIntentIssue {
    <#
    .SYNOPSIS
        Creates one structured validation issue.

    .PARAMETER File
        Repository-relative file the issue belongs to, or a contract-level label.

    .PARAMETER Code
        Stable diagnostic code.

    .PARAMETER Message
        Human-readable description.

    .OUTPUTS
        [hashtable]
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$File,

        [Parameter(Mandatory = $true)]
        [string]$Code,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    return @{ File = $File; Code = $Code; Message = $Message }
}

function Test-SchemaConformance {
    <#
    .SYNOPSIS
        Validates a JSON document against a schema and returns error strings.

    .PARAMETER Json
        Document as JSON text.

    .PARAMETER Schema
        Schema as JSON text.

    .OUTPUTS
        [string[]] Empty when the document conforms.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Json,

        [Parameter(Mandatory = $true)]
        [string]$Schema
    )

    $schemaErrors = $null
    $isValid = Test-Json -Json $Json -Schema $Schema -ErrorAction SilentlyContinue -ErrorVariable schemaErrors
    if ($isValid) { return @() }

    if ($schemaErrors) {
        return @($schemaErrors | ForEach-Object { $_.ToString() })
    }
    return @('document does not conform to the schema')
}

#endregion Primitives

#region Adequacy map

function Get-ProbeAdequacy {
    <#
    .SYNOPSIS
        Loads the runtime probe adequacy map and projects its decides/informs tuples.

    .DESCRIPTION
        Fails closed. A missing, unreadable, or structurally invalid map is a
        validation failure, because skipping the rule would let unsupported
        deciding claims pass unchecked.

    .PARAMETER Path
        Adequacy map path.

    .OUTPUTS
        [hashtable] Keyed by probeId, each value holding Decides and Informs lookup sets.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "probe adequacy map not found at '$Path'"
    }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        $map = $raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    }
    catch {
        throw "probe adequacy map at '$Path' is unreadable: $($_.Exception.Message)"
    }

    if ($map -isnot [System.Collections.IDictionary] -or -not $map.ContainsKey('probes')) {
        throw "probe adequacy map at '$Path' is missing the 'probes' array"
    }

    $probes = @($map['probes'])
    if ($probes.Count -eq 0) {
        throw "probe adequacy map at '$Path' declares no probes"
    }

    $adequacy = @{}
    foreach ($probe in $probes) {
        if ($probe -isnot [System.Collections.IDictionary] -or
            [string]::IsNullOrWhiteSpace([string]$probe['probeId'])) {
            throw "probe adequacy map at '$Path' contains a probe entry without a probeId"
        }

        $entry = @{ Decides = [System.Collections.Generic.HashSet[string]]::new();
            Informs        = [System.Collections.Generic.HashSet[string]]::new()
        }

        foreach ($relation in @('decides', 'informs')) {
            foreach ($tuple in @($probe[$relation])) {
                if ($null -eq $tuple) { continue }
                $framework = [string]$tuple['framework']
                $criterion = [string]$tuple['criterionId']
                foreach ($state in @($tuple['states'])) {
                    $key = "${framework}|${criterion}|${state}"
                    if ($relation -eq 'decides') {
                        [void]$entry.Decides.Add($key)
                    }
                    else {
                        [void]$entry.Informs.Add($key)
                    }
                }
            }
        }

        $adequacy[[string]$probe['probeId']] = $entry
    }

    return $adequacy
}

#endregion Adequacy map

#region Authored record semantics

function Test-AuthoredRecordSemantics {
    <#
    .SYNOPSIS
        Applies the authored-record rules JSON Schema cannot express.

    .PARAMETER Record
        Parsed authored record.

    .PARAMETER RelativePath
        Repository-relative path used in diagnostics.

    .PARAMETER FileStem
        Authored filename stem.

    .PARAMETER Surfaces
        Runtime surface lookup keyed by surface id, each value a state name set.

    .PARAMETER Adequacy
        Probe adequacy projection from Get-ProbeAdequacy.

    .OUTPUTS
        [hashtable[]] Structured issues. Empty when the record is valid.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true)]
        $Record,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath,

        [Parameter(Mandatory = $true)]
        [string]$FileStem,

        [Parameter(Mandatory = $true)]
        [hashtable]$Surfaces,

        [Parameter(Mandatory = $true)]
        [hashtable]$Adequacy
    )

    $issues = [System.Collections.Generic.List[hashtable]]::new()
    $surfaceId = [string]$Record['surfaceId']

    if ($surfaceId -ne $FileStem) {
        $issues.Add((New-DesignIntentIssue -File $RelativePath -Code 'filename-binding' `
                    -Message "surfaceId '$surfaceId' must equal the filename stem '$FileStem'"))
    }

    if (-not (Test-CalendarDate -Value ([string]$Record['decidedOn']))) {
        $issues.Add((New-DesignIntentIssue -File $RelativePath -Code 'invalid-date' `
                    -Message "decidedOn '$($Record['decidedOn'])' is not a real calendar date"))
    }

    $surfaceStates = $null
    if (-not $Surfaces.ContainsKey($surfaceId)) {
        $issues.Add((New-DesignIntentIssue -File $RelativePath -Code 'unknown-surface' `
                    -Message "surfaceId '$surfaceId' is not declared in a11y-runtime.config.json"))
    }
    else {
        $surfaceStates = $Surfaces[$surfaceId]
    }

    $intentIds = [System.Collections.Generic.HashSet[string]]::new()
    $expectationIds = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($intent in @($Record['intents'])) {
        $intentId = [string]$intent['id']
        if (-not $intentIds.Add($intentId)) {
            $issues.Add((New-DesignIntentIssue -File $RelativePath -Code 'duplicate-intent-id' `
                        -Message "intent id '$intentId' is declared more than once"))
        }

        $state = [string]$intent['binding']['state']
        if ($state -ne $script:ImplicitState -and $null -ne $surfaceStates -and -not $surfaceStates.Contains($state)) {
            $issues.Add((New-DesignIntentIssue -File $RelativePath -Code 'undeclared-state' `
                        -Message "intent '$intentId' binds state '$state', which surface '$surfaceId' does not declare"))
        }

        foreach ($expectation in @($intent['expectations'])) {
            $expectationId = [string]$expectation['id']
            if (-not $expectationIds.Add($expectationId)) {
                $issues.Add((New-DesignIntentIssue -File $RelativePath -Code 'duplicate-expectation-id' `
                            -Message "expectation id '$expectationId' is declared more than once"))
            }

            $expectationIssues = @(Test-ExpectationSemantics `
                    -Expectation $expectation -IntentId $intentId -State $state `
                    -RelativePath $RelativePath -Adequacy $Adequacy)
            if ($expectationIssues.Count -gt 0) {
                $issues.AddRange([hashtable[]]$expectationIssues)
            }
        }
    }

    return $issues.ToArray()
}

function Test-ExpectationSemantics {
    <#
    .SYNOPSIS
        Applies assertion vocabulary, method pairing, override, and adequacy rules.

    .PARAMETER Expectation
        Parsed expectation.

    .PARAMETER IntentId
        Owning intent id.

    .PARAMETER State
        Bound interaction state.

    .PARAMETER RelativePath
        Repository-relative path used in diagnostics.

    .PARAMETER Adequacy
        Probe adequacy projection from Get-ProbeAdequacy.

    .OUTPUTS
        [hashtable[]] Structured issues. Empty when the expectation is valid.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true)]
        $Expectation,

        [Parameter(Mandatory = $true)]
        [string]$IntentId,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$State,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath,

        [Parameter(Mandatory = $true)]
        [hashtable]$Adequacy
    )

    $issues = [System.Collections.Generic.List[hashtable]]::new()
    $expectationId = [string]$Expectation['id']
    $label = "expectation '$expectationId' in intent '$IntentId'"
    $assert = [string]$Expectation['assert']
    $method = [string]$Expectation['method']
    $role = [string]$Expectation['role']
    $blocking = [bool]$Expectation['blocking']

    # The schema enforces the informing/blocking and custom-assertion conditionals,
    # so this function owns only the rules JSON Schema cannot express.
    if ($Expectation.Contains('override') -and $null -ne $Expectation['override']) {
        $reviewedOn = [string]$Expectation['override']['reviewedOn']
        if (-not (Test-CalendarDate -Value $reviewedOn)) {
            $issues.Add((New-DesignIntentIssue -File $RelativePath -Code 'invalid-date' `
                        -Message "$label has override.reviewedOn '$reviewedOn', which is not a real calendar date"))
        }
    }

    if ($assert -eq $script:CustomAssertion) {
        # A custom assertion has no registered probe, so adequacy does not apply.
        return $issues.ToArray()
    }

    if (-not $Adequacy.ContainsKey($assert)) {
        $issues.Add((New-DesignIntentIssue -File $RelativePath -Code 'unknown-probe' `
                    -Message "$label asserts '$assert', which is not a current runtime probe"))
        return $issues.ToArray()
    }

    $expectedMethod = if ($assert -eq $script:AxeProbeId) { $script:AxeMethod } else { $script:RuntimeMethod }
    if ($method -ne $expectedMethod) {
        $issues.Add((New-DesignIntentIssue -File $RelativePath -Code 'probe-method-mismatch' `
                    -Message "$label asserts '$assert', which requires method '$expectedMethod' but declares '$method'"))
    }

    $requiresDeciding = ($role -eq 'decides') -or $blocking
    $probe = $Adequacy[$assert]

    foreach ($criterion in @($Expectation['criteria'])) {
        # The schema pattern guarantees a 'framework:criterionId' shape.
        $reference = [string]$criterion
        $separator = $reference.IndexOf(':')
        $key = $reference.Substring(0, $separator) + '|' + $reference.Substring($separator + 1) + "|$State"

        if ($requiresDeciding) {
            if (-not $probe.Decides.Contains($key)) {
                $issues.Add((New-DesignIntentIssue -File $RelativePath -Code 'inadequate-deciding-claim' `
                            -Message "$label claims a deciding or blocking result, but probe '$assert' does not decide '$reference' in state '$State'"))
            }
        }
        elseif (-not $probe.Decides.Contains($key) -and -not $probe.Informs.Contains($key)) {
            $issues.Add((New-DesignIntentIssue -File $RelativePath -Code 'unsupported-criterion' `
                        -Message "$label references '$reference', which probe '$assert' neither decides nor informs in state '$State'"))
        }
    }

    return $issues.ToArray()
}

#endregion Authored record semantics

#region Verification artifact semantics

function Test-VerificationSemantics {
    <#
    .SYNOPSIS
        Applies digest freshness, assertion resolution, and coverage rules.

    .PARAMETER Artifact
        Parsed verification artifact.

    .PARAMETER Record
        Parsed authored record the artifact describes.

    .PARAMETER RelativePath
        Repository-relative artifact path used in diagnostics.

    .PARAMETER FileStem
        Artifact filename stem.

    .PARAMETER ExpectedDigest
        Digest computed from the authored record.

    .PARAMETER Timestamp
        Timestamp literal read from the artifact before date coercion.

    .OUTPUTS
        [hashtable[]] Structured issues. Empty when the artifact is valid.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true)]
        $Artifact,

        [Parameter(Mandatory = $true)]
        $Record,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath,

        [Parameter(Mandatory = $true)]
        [string]$FileStem,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedDigest,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Timestamp
    )

    $issues = [System.Collections.Generic.List[hashtable]]::new()
    $surfaceId = [string]$Artifact['surfaceId']

    if ($surfaceId -ne $FileStem -or $surfaceId -ne [string]$Record['surfaceId']) {
        $issues.Add((New-DesignIntentIssue -File $RelativePath -Code 'filename-binding' `
                    -Message "artifact surfaceId '$surfaceId' must equal the filename stem '$FileStem' and the authored surfaceId"))
    }

    if (-not (Test-Rfc3339Timestamp -Value $Timestamp)) {
        $issues.Add((New-DesignIntentIssue -File $RelativePath -Code 'invalid-timestamp' `
                    -Message "timestamp '$Timestamp' is not an RFC 3339 date-time"))
    }

    if ([string]$Artifact['intentDigest'] -ne $ExpectedDigest) {
        $issues.Add((New-DesignIntentIssue -File $RelativePath -Code 'stale-digest' `
                    -Message "intentDigest does not match the authored record; expected '$ExpectedDigest'"))
    }

    $expectationPairs = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($intent in @($Record['intents'])) {
        foreach ($expectation in @($intent['expectations'])) {
            [void]$expectationPairs.Add("$([string]$intent['id'])|$([string]$expectation['id'])")
        }
    }

    $asserted = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($assertion in @($Artifact['assertions'])) {
        $pair = "$([string]$assertion['intentId'])|$([string]$assertion['expectationId'])"

        if (-not $expectationPairs.Contains($pair)) {
            $issues.Add((New-DesignIntentIssue -File $RelativePath -Code 'unresolved-assertion' `
                        -Message "assertion pair '$pair' does not resolve to a current intent and expectation"))
            continue
        }

        if (-not $asserted.Add($pair)) {
            $issues.Add((New-DesignIntentIssue -File $RelativePath -Code 'duplicate-assertion' `
                        -Message "assertion pair '$pair' appears more than once"))
        }
    }

    foreach ($pair in $expectationPairs) {
        if (-not $asserted.Contains($pair)) {
            $issues.Add((New-DesignIntentIssue -File $RelativePath -Code 'incomplete-coverage' `
                        -Message "no assertion covers expectation pair '$pair'"))
        }
    }

    return $issues.ToArray()
}

#endregion Verification artifact semantics

#region Orchestration

function Get-RuntimeSurfaceInventory {
    <#
    .SYNOPSIS
        Projects a11y-runtime.config.json into a surface-to-declared-state lookup.

    .PARAMETER Path
        Runtime config path.

    .OUTPUTS
        [hashtable] Keyed by surface id, each value a set of declared state names.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $config = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    $surfaces = @{}

    foreach ($surface in @($config['surfaces'])) {
        if ($null -eq $surface) { continue }
        $states = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($stateEntry in @($surface['states'])) {
            if ($null -eq $stateEntry) { continue }
            [void]$states.Add([string]$stateEntry['state'])
        }
        $surfaces[[string]$surface['id']] = $states
    }

    return $surfaces
}

function Write-DesignIntentReport {
    <#
    .SYNOPSIS
        Writes the structured validation result.

    .PARAMETER RootPath
        Validated repository root.

    .PARAMETER OutputPath
        Report path, absolute or relative to RootPath.

    .PARAMETER Status
        Overall status.

    .PARAMETER Mode
        Validation mode applied.

    .PARAMETER FilesChecked
        Repository-relative paths that were validated.

    .PARAMETER Issues
        Structured issues.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$OutputPath,

        [Parameter(Mandatory = $true)]
        [string]$Status,

        [Parameter(Mandatory = $true)]
        [string]$Mode,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$FilesChecked,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [hashtable[]]$Issues
    )

    if ([string]::IsNullOrWhiteSpace($OutputPath)) { return }

    $resolved = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
        $OutputPath
    }
    else {
        Join-Path -Path $RootPath -ChildPath $OutputPath
    }

    $directory = Split-Path -Path $resolved -Parent
    if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }

    $report = [ordered]@{
        Timestamp    = (Get-Date).ToUniversalTime().ToString('o')
        RootPath     = $RootPath
        Mode         = $Mode
        Status       = $Status
        FilesChecked = @($FilesChecked)
        IssueCount   = $Issues.Count
        Issues       = @($Issues)
    }

    $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolved -Encoding UTF8
}

function Invoke-DesignIntentValidation {
    <#
    .SYNOPSIS
        Validates every Design Intent Record and artifact beneath a root.

    .PARAMETER RootPath
        Repository root to validate.

    .PARAMETER RequireVerification
        Require a current, complete artifact for every accepted record.

    .PARAMETER ProbeCriteriaMapPath
        Adequacy map path.

    .OUTPUTS
        [hashtable] with Issues, FilesChecked, and Status.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,

        [Parameter(Mandatory = $false)]
        [bool]$RequireVerification = $false,

        [Parameter(Mandatory = $true)]
        [string]$ProbeCriteriaMapPath
    )

    $issues = [System.Collections.Generic.List[hashtable]]::new()
    $filesChecked = [System.Collections.Generic.List[string]]::new()
    $designIntentDir = Join-Path $RootPath 'design-intent'

    if (-not (Test-Path -LiteralPath $designIntentDir -PathType Container)) {
        Write-Host 'No design-intent directory found; nothing to validate.'
        return @{ Issues = @(); FilesChecked = @(); Status = 'passed' }
    }

    try {
        $adequacy = Get-ProbeAdequacy -Path $ProbeCriteriaMapPath
    }
    catch {
        $issues.Add((New-DesignIntentIssue -File 'probe-criteria-map.json' -Code 'adequacy-map-unavailable' `
                    -Message "adequacy enforcement cannot run: $($_.Exception.Message)"))
        return @{ Issues = $issues.ToArray(); FilesChecked = @(); Status = 'failed' }
    }

    $authoredFiles = @(Get-ChildItem -LiteralPath $designIntentDir -Filter '*.intent.yaml' -File | Sort-Object Name)
    $verificationDir = Join-Path $designIntentDir '.verification'
    $artifactFiles = @()
    if (Test-Path -LiteralPath $verificationDir -PathType Container) {
        $artifactFiles = @(Get-ChildItem -LiteralPath $verificationDir -Filter '*.earl.json' -File | Sort-Object Name)
    }

    $runtimeConfigPath = Join-Path $RootPath 'a11y-runtime.config.json'
    $surfaces = @{}
    if ($authoredFiles.Count -gt 0) {
        if (-not (Test-Path -LiteralPath $runtimeConfigPath -PathType Leaf)) {
            $issues.Add((New-DesignIntentIssue -File 'a11y-runtime.config.json' -Code 'missing-runtime-config' `
                        -Message 'authored records exist but a11y-runtime.config.json was not found beneath the validated root'))
            return @{ Issues = $issues.ToArray(); FilesChecked = @(); Status = 'failed' }
        }

        try {
            $surfaces = Get-RuntimeSurfaceInventory -Path $runtimeConfigPath
        }
        catch {
            $issues.Add((New-DesignIntentIssue -File 'a11y-runtime.config.json' -Code 'unreadable-runtime-config' `
                        -Message "a11y-runtime.config.json is unreadable: $($_.Exception.Message)"))
            return @{ Issues = $issues.ToArray(); FilesChecked = @(); Status = 'failed' }
        }
    }

    $authoredSchema = Get-Content -LiteralPath $script:AuthoredSchemaPath -Raw
    $verificationSchema = Get-Content -LiteralPath $script:VerificationSchemaPath -Raw

    $records = @{}
    $digests = @{}

    foreach ($file in $authoredFiles) {
        $relativePath = "design-intent/$($file.Name)"
        $filesChecked.Add($relativePath)
        $stem = $file.Name -replace '\.intent\.yaml$', ''
        $raw = Get-Content -LiteralPath $file.FullName -Raw

        try {
            $record = ConvertFrom-Yaml -Yaml $raw -Ordered
        }
        catch {
            $message = $_.Exception.Message
            $code = if ($message -match 'Duplicate key') { 'duplicate-yaml-key' } else { 'yaml-parse-error' }
            $issues.Add((New-DesignIntentIssue -File $relativePath -Code $code -Message $message))
            continue
        }

        if ($record -isnot [System.Collections.IDictionary]) {
            $issues.Add((New-DesignIntentIssue -File $relativePath -Code 'yaml-parse-error' `
                        -Message 'authored record must parse to a YAML mapping'))
            continue
        }

        $schemaErrors = Test-SchemaConformance -Json ($record | ConvertTo-Json -Depth 20) -Schema $authoredSchema
        if ($schemaErrors.Count -gt 0) {
            foreach ($schemaError in $schemaErrors) {
                $issues.Add((New-DesignIntentIssue -File $relativePath -Code 'schema-violation' -Message $schemaError))
            }
            continue
        }

        $records[$stem] = $record
        $digests[$stem] = Get-NormalizedDigest -Content $raw

        $recordIssues = @(Test-AuthoredRecordSemantics -Record $record -RelativePath $relativePath `
                -FileStem $stem -Surfaces $surfaces -Adequacy $adequacy)
        if ($recordIssues.Count -gt 0) {
            $issues.AddRange([hashtable[]]$recordIssues)
        }
    }

    foreach ($file in $artifactFiles) {
        $relativePath = "design-intent/.verification/$($file.Name)"
        $filesChecked.Add($relativePath)
        $stem = $file.Name -replace '\.earl\.json$', ''

        if (-not $records.ContainsKey($stem)) {
            $issues.Add((New-DesignIntentIssue -File $relativePath -Code 'orphan-artifact' `
                        -Message "no valid authored record 'design-intent/$stem.intent.yaml' corresponds to this artifact"))
            continue
        }

        $rawArtifact = Get-Content -LiteralPath $file.FullName -Raw
        try {
            $artifact = $rawArtifact | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        }
        catch {
            $issues.Add((New-DesignIntentIssue -File $relativePath -Code 'json-parse-error' -Message $_.Exception.Message))
            continue
        }

        $schemaErrors = Test-SchemaConformance -Json $rawArtifact -Schema $verificationSchema
        if ($schemaErrors.Count -gt 0) {
            foreach ($schemaError in $schemaErrors) {
                $issues.Add((New-DesignIntentIssue -File $relativePath -Code 'schema-violation' -Message $schemaError))
            }
            continue
        }

        $artifactIssues = @(Test-VerificationSemantics -Artifact $artifact -Record $records[$stem] `
                -RelativePath $relativePath -FileStem $stem -ExpectedDigest $digests[$stem] `
                -Timestamp (Get-JsonStringLiteral -Json $rawArtifact -Name 'timestamp'))
        if ($artifactIssues.Count -gt 0) {
            $issues.AddRange([hashtable[]]$artifactIssues)
        }
    }

    if ($RequireVerification) {
        $artifactStems = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($file in $artifactFiles) {
            [void]$artifactStems.Add(($file.Name -replace '\.earl\.json$', ''))
        }

        foreach ($stem in $records.Keys) {
            # Proposed records may predate generation; retired records are inactive.
            if ([string]$records[$stem]['status'] -eq 'accepted' -and -not $artifactStems.Contains($stem)) {
                $issues.Add((New-DesignIntentIssue -File "design-intent/$stem.intent.yaml" -Code 'missing-verification' `
                            -Message "accepted record '$stem' has no verification artifact at design-intent/.verification/$stem.earl.json"))
            }
        }
    }

    $status = if ($issues.Count -eq 0) { 'passed' } else { 'failed' }
    return @{ Issues = $issues.ToArray(); FilesChecked = $filesChecked.ToArray(); Status = $status }
}

#endregion Orchestration

#region Main

if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
    Write-Error "Required module 'powershell-yaml' is not installed. Run 'Install-Module powershell-yaml -Scope CurrentUser' before invoking this script." -ErrorAction Continue
    exit 2
}
Import-Module powershell-yaml -ErrorAction Stop | Out-Null

$resolvedRoot = if ([string]::IsNullOrWhiteSpace($RootPath)) {
    (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
}
else {
    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        Write-Error "RootPath '$RootPath' is not a directory." -ErrorAction Continue
        exit 2
    }
    (Resolve-Path -LiteralPath $RootPath).Path
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $resolvedMapPath = if ([string]::IsNullOrWhiteSpace($ProbeCriteriaMapPath)) {
            $script:DefaultProbeCriteriaMapPath
        }
        else {
            $ProbeCriteriaMapPath
        }

        $mode = if ($RequireVerification) { 'require-verification' } else { 'source-only' }
        Write-Host "Validating Design Intent contract under '$resolvedRoot' (mode: $mode)..."

        $result = Invoke-DesignIntentValidation -RootPath $resolvedRoot `
            -RequireVerification:$RequireVerification.IsPresent -ProbeCriteriaMapPath $resolvedMapPath

        Write-DesignIntentReport -RootPath $resolvedRoot -OutputPath $OutputPath -Status $result.Status `
            -Mode $mode -FilesChecked $result.FilesChecked -Issues $result.Issues

        foreach ($file in $result.FilesChecked) {
            Write-Host "  checked $file"
        }

        if ($result.Issues.Count -gt 0) {
            foreach ($issue in $result.Issues) {
                Write-CIAnnotation -Level Error -File $issue.File -Message "[$($issue.Code)] $($issue.Message)"
            }
            Write-Host "Design Intent validation failed with $($result.Issues.Count) issue(s)." -ForegroundColor Red
            exit 1
        }

        Write-Host "Design Intent validation passed ($($result.FilesChecked.Count) file(s) checked)."
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Validate-DesignIntent.ps1 failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main
