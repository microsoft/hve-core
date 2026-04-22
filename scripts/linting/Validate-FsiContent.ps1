# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# Validate-FsiContent.ps1
#
# Purpose: Validates Framework Skill content, governance, pipeline, and
#          attestation rules. Phases 1-6 of the Framework Skill content-generation plan add
#          individual lint checks to this scaffold.

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SkillsPath = '.github/skills',

    [Parameter(Mandatory = $false)]
    [switch]$WarningsAsErrors,

    [Parameter(Mandatory = $false)]
    [switch]$ChangedFilesOnly,

    [Parameter(Mandatory = $false)]
    [string]$BaseBranch = 'origin/main',

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'logs/fsi-content-validation-results.json',

    [Parameter(Mandatory = $false)]
    [int]$MaxItemBodyChars = 200
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'Modules/LintingHelpers.psm1') -Force
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '../lib/Modules/CIHelpers.psm1') -Force
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '../lib/Modules/FrameworkSkillDiscovery.psm1') -Force

function Get-ItemKindSchemaPath {
    <#
    .SYNOPSIS
        Maps an Framework Skill itemKind to its per-item JSON Schema file path.

    .PARAMETER RepoRoot
        Repository root directory.

    .PARAMETER ItemKind
        The itemKind value from the Framework Skill manifest.

    .OUTPUTS
        [string] Absolute path to the schema file, or $null when unrecognized.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$ItemKind
    )

    $schemaMap = @{
        'control'          = 'planner-framework-control.schema.json'
        'capability'       = 'planner-framework-control.schema.json'
        'document-section' = 'document-section.schema.json'
        'criterion'        = 'accessibility-criterion.schema.json'
        'pattern'          = 'aria-pattern.schema.json'
    }

    $schemaFile = $schemaMap[$ItemKind]
    if (-not $schemaFile) { return $null }

    $schemaPath = Join-Path -Path $RepoRoot -ChildPath "scripts/linting/schemas/$schemaFile"
    if (Test-Path -LiteralPath $schemaPath -PathType Leaf) {
        return $schemaPath
    }
    return $null
}

function Test-FsiVariableResolution {
    <#
    .SYNOPSIS
        Validates {{var}} token references in document-section templates.

    .DESCRIPTION
        Extracts {{name}} tokens from the template string, then checks each
        against the item's declared inputs[].name and the manifest globals
        keys. Emits errors for unresolved tokens and warnings when an input
        name shadows a globals key.

    .PARAMETER ItemPath
        Absolute path to the item YAML file.

    .PARAMETER Globals
        Hashtable of globals keys from the manifest.

    .OUTPUTS
        [pscustomobject] with Errors (string[]) and Warnings (string[]).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$ItemPath,

        [Parameter(Mandatory = $false)]
        [hashtable]$Globals = @{}
    )

    $errors = @()
    $warnings = @()

    try {
        $raw = Get-Content -LiteralPath $ItemPath -Raw -Encoding utf8
        $data = $raw | ConvertFrom-Yaml
    }
    catch {
        return [pscustomobject]@{ Errors = @("yaml-parse-error: $($_.Exception.Message)"); Warnings = @() }
    }

    if ($null -eq $data) {
        return [pscustomobject]@{ Errors = @(); Warnings = @() }
    }

    $template = $null
    if ($data -is [System.Collections.IDictionary] -and $data.ContainsKey('template')) {
        $template = [string]$data['template']
    }
    if (-not $template) {
        return [pscustomobject]@{ Errors = @(); Warnings = @() }
    }

    # Collect declared input names
    $inputNames = @{}
    if ($data.ContainsKey('inputs') -and $data['inputs'] -is [System.Collections.IList]) {
        foreach ($input in $data['inputs']) {
            if ($input -is [System.Collections.IDictionary] -and $input.ContainsKey('name')) {
                $inputNames[[string]$input['name']] = $true
            }
        }
    }

    # Extract {{var}} tokens, skipping escaped \{{...}}
    $tokenPattern = '(?<!\\)\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}'
    $matches = [regex]::Matches($template, $tokenPattern)

    foreach ($m in $matches) {
        $varName = $m.Groups[1].Value
        $resolvedInInputs = $inputNames.ContainsKey($varName)
        $resolvedInGlobals = $Globals.ContainsKey($varName)

        if ($resolvedInInputs -and $resolvedInGlobals) {
            $warnings += "shadow: input '$varName' shadows globals key with the same name"
        }
        elseif (-not $resolvedInInputs -and -not $resolvedInGlobals) {
            $itemId = if ($data.ContainsKey('id')) { [string]$data['id'] } else { Split-Path -Leaf $ItemPath }
            $errors += "unresolved-var: '{{$varName}}' in item '$itemId' not found in inputs or globals"
        }
    }

    return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
}

function Test-FsiPipelineCompatibility {
    <#
    .SYNOPSIS
        Validates pipeline.stages[].consumes references against prior stages' produces[].

    .DESCRIPTION
        Walks pipeline.stages in array order. Tracks every produces[].id seen so
        far. For each stage's consumes[] entry: a value prefixed with 'host:'
        emits a warning (host-sourced input); any other value must match an
        already-produced id from a prior stage, otherwise an error is emitted.
        Also enforces produces[].id uniqueness across the whole pipeline and
        stage id uniqueness.

    .PARAMETER Pipeline
        The pipeline object (IDictionary) extracted from the manifest.

    .PARAMETER Framework
        Framework identifier used in diagnostic messages.

    .OUTPUTS
        [pscustomobject] with Errors (string[]) and Warnings (string[]).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $false)]
        $Pipeline,

        [Parameter(Mandatory = $false)]
        [string]$Framework = '<unknown>'
    )

    $errors = @()
    $warnings = @()

    if ($null -eq $Pipeline -or $Pipeline -isnot [System.Collections.IDictionary]) {
        return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
    }
    if (-not $Pipeline.ContainsKey('stages') -or $Pipeline['stages'] -isnot [System.Collections.IList]) {
        return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
    }

    $producedIds = @{}
    $stageIds = @{}
    $index = -1
    foreach ($stage in $Pipeline['stages']) {
        $index++
        if ($stage -isnot [System.Collections.IDictionary]) { continue }

        $stageId = if ($stage.ContainsKey('id')) { [string]$stage['id'] } else { "stage[$index]" }
        if ($stageIds.ContainsKey($stageId)) {
            $errors += "$Framework : pipeline stage id '$stageId' is duplicated"
        }
        else {
            $stageIds[$stageId] = $true
        }

        $consumes = @()
        if ($stage.ContainsKey('consumes') -and $stage['consumes'] -is [System.Collections.IList]) {
            $consumes = @($stage['consumes'])
        }
        foreach ($c in $consumes) {
            $cs = [string]$c
            if ($cs.StartsWith('host:')) {
                $warnings += "$Framework : stage '$stageId' consumes host-sourced input '$cs' (not produced by a prior stage)"
                continue
            }
            if (-not $producedIds.ContainsKey($cs)) {
                $errors += "$Framework : stage '$stageId' consumes '$cs' which is not produced by any prior stage"
            }
        }

        # Register this stage's produces AFTER processing consumes so a stage cannot self-consume.
        if ($stage.ContainsKey('produces') -and $stage['produces'] -is [System.Collections.IList]) {
            foreach ($p in $stage['produces']) {
                if ($p -isnot [System.Collections.IDictionary]) { continue }
                if (-not $p.ContainsKey('id')) { continue }
                $produceId = [string]$p['id']
                if ($producedIds.ContainsKey($produceId)) {
                    $errors += "$Framework : pipeline produces id '$produceId' is duplicated (first seen in earlier stage)"
                }
                else {
                    $producedIds[$produceId] = $true
                }
            }
        }
    }

    return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
}

function Test-FsiItemSchema {
    <#
    .SYNOPSIS
        Validates a single Framework Skill item YAML file against the schema for its itemKind.

    .PARAMETER ItemPath
        Absolute path to the item YAML file.

    .PARAMETER SchemaPath
        Absolute path to the JSON Schema file.

    .OUTPUTS
        [pscustomobject] with Valid (bool) and Errors (string[]).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$ItemPath,

        [Parameter(Mandatory)]
        [string]$SchemaPath
    )

    try {
        $raw = Get-Content -LiteralPath $ItemPath -Raw -Encoding utf8
        $data = $raw | ConvertFrom-Yaml
        if ($null -eq $data) {
            return [pscustomobject]@{ Valid = $false; Errors = @('empty-or-invalid-yaml') }
        }

        $json = $data | ConvertTo-Json -Depth 20
        $errors = @()
        $valid = Test-Json -Json $json -SchemaFile $SchemaPath -ErrorVariable validationErrors -ErrorAction SilentlyContinue
        if ($validationErrors) {
            $errors = $validationErrors | ForEach-Object { $_.ToString() }
        }

        return [pscustomobject]@{ Valid = [bool]$valid; Errors = $errors }
    }
    catch {
        return [pscustomobject]@{ Valid = $false; Errors = @($_.Exception.Message) }
    }
}

function Test-FsiBinaryArtifactContract {
    <#
    .SYNOPSIS
        Warns when a pipeline stage produces a binary/* artifact without a cleanup hint.
    .DESCRIPTION
        Iterates pipeline.stages[].produces[]; for any artifact whose kind starts
        with 'binary/' (binary/docx, binary/pdf, binary/png, binary/zip, etc.),
        emits a warning when the optional 'cleanup' field is absent. The lint is
        advisory: hosts MAY choose any cleanup posture, but explicit declaration
        eliminates ambiguity for downstream consumers and audit tooling.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Pipeline,

        [Parameter(Mandatory)]
        [string]$Framework
    )

    $warnings = @()
    if (-not $Pipeline.ContainsKey('stages')) {
        return [pscustomobject]@{ Warnings = $warnings }
    }
    foreach ($stage in $Pipeline['stages']) {
        if ($stage -isnot [System.Collections.IDictionary]) { continue }
        if (-not $stage.ContainsKey('produces')) { continue }
        $stageId = if ($stage.ContainsKey('id')) { [string]$stage['id'] } else { '<unknown>' }
        foreach ($produce in $stage['produces']) {
            if ($produce -isnot [System.Collections.IDictionary]) { continue }
            $kind = if ($produce.ContainsKey('kind')) { [string]$produce['kind'] } else { '' }
            if (-not $kind.StartsWith('binary/')) { continue }
            if ($produce.ContainsKey('cleanup')) { continue }
            $produceId = if ($produce.ContainsKey('id')) { [string]$produce['id'] } else { '<unknown>' }
            $warnings += "$Framework : pipeline.stages[$stageId].produces[$produceId] declares binary kind '$kind' without 'cleanup' (recommended: ephemeral or retained)"
        }
    }
    return [pscustomobject]@{ Warnings = $warnings }
}

function Test-FsiSkillReferenceResolution {
    <#
    .SYNOPSIS
        Validates that every requiredSkills[].ref resolves to a real skill and
        that every usedByStages[] entry matches a known stage id.
    .DESCRIPTION
        For each entry in manifest.requiredSkills:
        - Errors when '<repoRoot>/.github/skills/<ref>/SKILL.md' does not exist.
        - When the manifest declares a pipeline, errors on any usedByStages entry
          that does not match a stage id.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Manifest,

        [Parameter(Mandatory)]
        [string]$Framework,

        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    $errors = @()
    $warnings = @()
    $source = $Manifest
    if ($Manifest -isnot [System.Collections.IDictionary] -and $Manifest.PSObject.Properties['Raw']) {
        $source = $Manifest.Raw
    }
    if ($null -eq $source -or $source -isnot [System.Collections.IDictionary]) {
        return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
    }
    if (-not $source.ContainsKey('requiredSkills')) {
        return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
    }
    $refs = $source['requiredSkills']
    if ($null -eq $refs) {
        return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
    }

    $stageIds = @{}
    if ($source.ContainsKey('pipeline') -and $source['pipeline'] -is [System.Collections.IDictionary]) {
        $pipeline = $source['pipeline']
        if ($pipeline.ContainsKey('stages')) {
            foreach ($stage in $pipeline['stages']) {
                if ($stage -is [System.Collections.IDictionary] -and $stage.ContainsKey('id')) {
                    $stageIds[[string]$stage['id']] = $true
                }
            }
        }
    }

    foreach ($entry in $refs) {
        if ($entry -isnot [System.Collections.IDictionary]) { continue }
        if (-not $entry.ContainsKey('ref')) { continue }
        $ref = [string]$entry['ref']
        $skillPath = Join-Path $RepoRoot ".github/skills/$ref/SKILL.md"
        if (-not (Test-Path -LiteralPath $skillPath)) {
            $errors += "$Framework : requiredSkills[$ref] does not resolve to '.github/skills/$ref/SKILL.md'"
        }
        if ($entry.ContainsKey('usedByStages')) {
            foreach ($sid in $entry['usedByStages']) {
                $sidStr = [string]$sid
                if (-not $stageIds.ContainsKey($sidStr)) {
                    $errors += "$Framework : requiredSkills[$ref].usedByStages references unknown stage id '$sidStr'"
                }
            }
        }
    }

    return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
}

function Test-FsiLicensePresence {
    <#
    .SYNOPSIS
        Validates required licensing fields on a Framework Skill manifest.

    .DESCRIPTION
        Confirms metadata.authority, metadata.license, and metadata.attributionRequired
        are present and non-empty. Confirms metadata.licenseUrl is present whenever
        metadata.license is not one of the public-domain sentinels.

    .PARAMETER Manifest
        Hashtable / IDictionary of the parsed index.yml manifest.

    .PARAMETER Framework
        Framework identifier used in error messages.

    .OUTPUTS
        [pscustomobject] with Errors (string[]) and Warnings (string[]).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory)]
        [string]$Framework
    )

    $errors = @()
    $warnings = @()

    if (-not $Manifest.Contains('metadata') -or $Manifest['metadata'] -isnot [System.Collections.IDictionary]) {
        $errors += "$Framework : metadata block is required and must be a mapping"
        return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
    }

    $metadata = $Manifest['metadata']

    foreach ($field in @('authority', 'license', 'attributionRequired')) {
        if (-not $metadata.Contains($field)) {
            $errors += "$Framework : metadata.$field is required"
            continue
        }
        $value = $metadata[$field]
        if ($field -eq 'attributionRequired') {
            if ($value -isnot [bool]) {
                $errors += "$Framework : metadata.attributionRequired must be a boolean"
            }
        }
        else {
            if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
                $errors += "$Framework : metadata.$field must be a non-empty string"
            }
        }
    }

    if ($metadata.Contains('license')) {
        $license = [string]$metadata['license']
        $isPublicDomain = $license -match '^(US-Gov-Public-Domain|public-domain)$'
        if (-not $isPublicDomain) {
            if (-not $metadata.Contains('licenseUrl') -or [string]::IsNullOrWhiteSpace([string]$metadata['licenseUrl'])) {
                $errors += "$Framework : metadata.licenseUrl is required when metadata.license is '$license' (only the 'public-domain' and 'US-Gov-Public-Domain' sentinels are exempt)"
            }
        }
    }

    return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
}

function Test-FsiAttributionCoherence {
    <#
    .SYNOPSIS
        Validates that attributionText is non-empty when attributionRequired is true.

    .PARAMETER Manifest
        Hashtable / IDictionary of the parsed index.yml manifest.

    .PARAMETER Framework
        Framework identifier used in error messages.

    .OUTPUTS
        [pscustomobject] with Errors (string[]) and Warnings (string[]).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory)]
        [string]$Framework
    )

    $errors = @()
    $warnings = @()

    if (-not $Manifest.Contains('metadata') -or $Manifest['metadata'] -isnot [System.Collections.IDictionary]) {
        return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
    }

    $metadata = $Manifest['metadata']
    if (-not $metadata.Contains('attributionRequired')) {
        return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
    }

    if ($metadata['attributionRequired'] -eq $true) {
        $hasText = $metadata.Contains('attributionText') -and -not [string]::IsNullOrWhiteSpace([string]$metadata['attributionText'])
        if (-not $hasText) {
            $errors += "$Framework : metadata.attributionText must be a non-empty string when metadata.attributionRequired is true"
        }
    }

    return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
}

function Test-FsiRedistributionCoherence {
    <#
    .SYNOPSIS
        Validates redistribution flags against per-item content size.

    .DESCRIPTION
        When metadata.redistribution.textVerbatim is false or
        metadata.redistribution.idsAndUrlsOnly is true, no per-item file may carry a
        body, text, or description field longer than -MaxItemBodyChars characters.

    .PARAMETER Manifest
        Hashtable / IDictionary of the parsed index.yml manifest.

    .PARAMETER Framework
        Framework identifier used in error messages.

    .PARAMETER ItemFiles
        Array of FileInfo objects for items/*.yml files in the bundle.

    .PARAMETER MaxItemBodyChars
        Maximum permitted character length of a per-item body/text/description field
        when the redistribution flags forbid verbatim content. Defaults to 200.

    .OUTPUTS
        [pscustomobject] with Errors (string[]) and Warnings (string[]).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory)]
        [string]$Framework,

        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$ItemFiles,

        [Parameter(Mandatory = $false)]
        [int]$MaxItemBodyChars = 200,

        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    $errors = @()
    $warnings = @()

    if (-not $Manifest.Contains('metadata') -or $Manifest['metadata'] -isnot [System.Collections.IDictionary]) {
        return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
    }

    $metadata = $Manifest['metadata']
    if (-not $metadata.Contains('redistribution') -or $metadata['redistribution'] -isnot [System.Collections.IDictionary]) {
        return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
    }

    $redistribution = $metadata['redistribution']
    $textVerbatim = $true
    if ($redistribution.Contains('textVerbatim')) { $textVerbatim = [bool]$redistribution['textVerbatim'] }
    $idsAndUrlsOnly = $false
    if ($redistribution.Contains('idsAndUrlsOnly')) { $idsAndUrlsOnly = [bool]$redistribution['idsAndUrlsOnly'] }

    $restricted = (-not $textVerbatim) -or $idsAndUrlsOnly
    if (-not $restricted) {
        return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
    }

    foreach ($itemFile in $ItemFiles) {
        try {
            $raw = Get-Content -LiteralPath $itemFile.FullName -Raw
            $item = $raw | ConvertFrom-Yaml -ErrorAction Stop
        }
        catch {
            continue
        }

        if ($item -isnot [System.Collections.IDictionary]) { continue }

        $relPath = [System.IO.Path]::GetRelativePath($RepoRoot, $itemFile.FullName)

        foreach ($field in @('body', 'text', 'description')) {
            if ($item.Contains($field) -and $null -ne $item[$field]) {
                $value = [string]$item[$field]
                if ($value.Length -gt $MaxItemBodyChars) {
                    $errors += "$relPath : item.$field length $($value.Length) exceeds redistribution limit of $MaxItemBodyChars characters (manifest declares textVerbatim=$textVerbatim idsAndUrlsOnly=$idsAndUrlsOnly)"
                }
            }
        }
    }

    return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
}

function ConvertFrom-Iso8601Duration {
    <#
    .SYNOPSIS
        Parses an ISO 8601 duration string into a TimeSpan (approximate).
    .DESCRIPTION
        Recognises Y, M (months), W, D, H, M (minutes), S components. Years
        approximate to 365 days, months to 30 days. Returns $null when the
        input cannot be parsed.
    #>
    [CmdletBinding()]
    [OutputType([System.Nullable[TimeSpan]])]
    param([string]$Duration)

    if ([string]::IsNullOrWhiteSpace($Duration)) { return $null }

    $pattern = '^P(?:(?<Y>\d+)Y)?(?:(?<Mo>\d+)M)?(?:(?<W>\d+)W)?(?:(?<D>\d+)D)?(?:T(?:(?<H>\d+)H)?(?:(?<Mi>\d+)M)?(?:(?<S>\d+)S)?)?$'
    $m = [regex]::Match($Duration, $pattern)
    if (-not $m.Success) { return $null }

    $totalDays = 0.0
    if ($m.Groups['Y'].Success)  { $totalDays += [int]$m.Groups['Y'].Value  * 365 }
    if ($m.Groups['Mo'].Success) { $totalDays += [int]$m.Groups['Mo'].Value * 30  }
    if ($m.Groups['W'].Success)  { $totalDays += [int]$m.Groups['W'].Value  * 7   }
    if ($m.Groups['D'].Success)  { $totalDays += [int]$m.Groups['D'].Value }

    $totalHours = 0.0
    if ($m.Groups['H'].Success)  { $totalHours += [int]$m.Groups['H'].Value }
    $totalMinutes = 0.0
    if ($m.Groups['Mi'].Success) { $totalMinutes += [int]$m.Groups['Mi'].Value }
    $totalSeconds = 0.0
    if ($m.Groups['S'].Success)  { $totalSeconds += [int]$m.Groups['S'].Value }

    return [TimeSpan]::FromDays($totalDays) + [TimeSpan]::FromHours($totalHours) + [TimeSpan]::FromMinutes($totalMinutes) + [TimeSpan]::FromSeconds($totalSeconds)
}

function Test-FsiGovernanceReviewCurrency {
    <#
    .SYNOPSIS
        Warns when a Framework Skill's last governance review is older than
        last_reviewed + review_cadence.
    .DESCRIPTION
        Reads governance.review_cadence (ISO 8601 duration) and
        governance.last_reviewed (date) and compares last_reviewed +
        cadence to $Now. Emits a warning when the next-review date is
        in the past. Emits a warning when review_cadence is set without
        last_reviewed. Skips silently when the governance block is absent.
    .PARAMETER Manifest
        The raw manifest hashtable.
    .PARAMETER Framework
        Framework identifier used in diagnostic messages.
    .PARAMETER Now
        Reference date for the currency comparison; defaults to UTC today.
    .OUTPUTS
        [pscustomobject] with Errors (string[]) and Warnings (string[]).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        $Manifest,

        [Parameter(Mandatory = $false)]
        [string]$Framework = '<unknown>',

        [Parameter(Mandatory = $false)]
        [DateTime]$Now = [DateTime]::UtcNow.Date
    )

    $errors = @()
    $warnings = @()

    if ($null -eq $Manifest -or $Manifest -isnot [System.Collections.IDictionary]) {
        return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
    }
    if (-not $Manifest.ContainsKey('governance')) {
        return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
    }
    $gov = $Manifest['governance']
    if ($gov -isnot [System.Collections.IDictionary]) {
        return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
    }

    $cadence = if ($gov.ContainsKey('review_cadence')) { [string]$gov['review_cadence'] } else { $null }
    $lastReviewedRaw = if ($gov.ContainsKey('last_reviewed')) { [string]$gov['last_reviewed'] } else { $null }

    if (-not [string]::IsNullOrWhiteSpace($cadence) -and [string]::IsNullOrWhiteSpace($lastReviewedRaw)) {
        $warnings += "$Framework : governance.last_reviewed required when review_cadence is set"
        return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
    }

    if ([string]::IsNullOrWhiteSpace($cadence) -or [string]::IsNullOrWhiteSpace($lastReviewedRaw)) {
        return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
    }

    $lastReviewed = [DateTime]::MinValue
    if (-not [DateTime]::TryParse($lastReviewedRaw, [ref]$lastReviewed)) {
        $warnings += "$Framework : governance.last_reviewed '$lastReviewedRaw' is not a parseable date"
        return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
    }

    $span = ConvertFrom-Iso8601Duration -Duration $cadence
    if ($null -eq $span) {
        $warnings += "$Framework : governance.review_cadence '$cadence' is not a parseable ISO 8601 duration"
        return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
    }

    $nextDue = $lastReviewed.Date + $span
    if ($nextDue -lt $Now) {
        $warnings += "$Framework : governance review overdue (last_reviewed=$($lastReviewed.ToString('yyyy-MM-dd')) + cadence=$cadence due $($nextDue.ToString('yyyy-MM-dd')), now=$($Now.ToString('yyyy-MM-dd')))"
    }

    return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
}

function Test-FsiSurfaceTagging {
    <#
    .SYNOPSIS
        Validates the FSI v1.0 sustainability surface-tagging extension.
    .DESCRIPTION
        Enforces four rules:
        1. When the manifest declares surfaceFilter, every per-item control MUST declare appliesTo
           and every appliesTo value MUST be a member of surfaceFilter.
        2. sciVariable, when set, MUST be one of E, I, M, R.
        3. measurementClass, when set, MUST be one of deterministic, estimated, heuristic, user-declared.
        4. appliesToPrinciples entries MUST match ^gsf-principles:[a-z0-9-]+$.
        Cross-resolution against the gsf-principles bundle (when loaded under .github/skills/sustainability/)
        emits warnings for unresolved references; skipped when the bundle is absent.
    .PARAMETER Manifest
        The raw manifest hashtable.
    .PARAMETER ItemFiles
        Collection of per-control YAML item file metadata.
    .PARAMETER Framework
        Framework identifier used in diagnostic messages.
    .PARAMETER RepoRoot
        Repository root used to resolve the optional gsf-principles bundle.
    .OUTPUTS
        [pscustomobject] with Errors (string[]) and Warnings (string[]).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        $Manifest,

        [Parameter(Mandatory = $false)]
        [System.IO.FileInfo[]]$ItemFiles = @(),

        [Parameter(Mandatory = $false)]
        [string]$Framework = '<unknown>',

        [Parameter(Mandatory = $false)]
        [string]$RepoRoot
    )

    $errors = @()
    $warnings = @()
    $allowedSurfaces = @('cloud', 'web', 'ml', 'fleet')
    $allowedSciVars = @('E', 'I', 'M', 'R')
    $allowedMeasurement = @('deterministic', 'estimated', 'heuristic', 'user-declared')

    if ($null -eq $Manifest -or $Manifest -isnot [System.Collections.IDictionary]) {
        return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
    }

    $surfaceFilter = $null
    if ($Manifest.ContainsKey('surfaceFilter')) {
        $sf = $Manifest['surfaceFilter']
        if ($sf -is [System.Collections.IEnumerable] -and -not ($sf -is [string])) {
            $surfaceFilter = @($sf | ForEach-Object { [string]$_ })
            foreach ($value in $surfaceFilter) {
                if ($allowedSurfaces -notcontains $value) {
                    $errors += "$Framework : manifest.surfaceFilter contains invalid surface '$value' (allowed: $($allowedSurfaces -join ', '))"
                }
            }
        } else {
            $errors += "$Framework : manifest.surfaceFilter must be an array"
            $surfaceFilter = $null
        }
    }

    # Optional cross-resolution: load gsf-principles item ids when the bundle is present.
    $principleIds = $null
    if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
        $principlesItemsDir = Join-Path $RepoRoot '.github/skills/sustainability/gsf-principles/items'
        if (Test-Path -LiteralPath $principlesItemsDir -PathType Container) {
            $principleIds = @{}
            Get-ChildItem -LiteralPath $principlesItemsDir -Filter '*.yml' -File -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    $raw = Get-Content -LiteralPath $_.FullName -Raw -Encoding utf8
                    $parsed = ConvertFrom-Yaml -Yaml $raw -ErrorAction Stop
                    if ($parsed -is [System.Collections.IDictionary] -and $parsed.ContainsKey('controls')) {
                        foreach ($ctrl in @($parsed['controls'])) {
                            if ($ctrl -is [System.Collections.IDictionary] -and $ctrl.ContainsKey('id')) {
                                $principleIds[[string]$ctrl['id']] = $true
                            }
                        }
                    }
                } catch {
                    # Tolerate parse failures: principles bundle has its own validation pass.
                }
            }
        }
    }

    foreach ($itemFile in $ItemFiles) {
        if ($null -eq $itemFile) { continue }
        $relPath = if ($RepoRoot) { [System.IO.Path]::GetRelativePath($RepoRoot, $itemFile.FullName) } else { $itemFile.FullName }
        try {
            $itemRaw = Get-Content -LiteralPath $itemFile.FullName -Raw -Encoding utf8
            $itemParsed = ConvertFrom-Yaml -Yaml $itemRaw -ErrorAction Stop
        } catch {
            continue
        }

        $controls = @()
        if ($itemParsed -is [System.Collections.IDictionary] -and $itemParsed.ContainsKey('controls')) {
            $controls = @($itemParsed['controls'])
        } elseif ($itemParsed -is [System.Collections.IDictionary] -and $itemParsed.ContainsKey('id')) {
            $controls = @($itemParsed)
        }

        foreach ($ctrl in $controls) {
            if ($ctrl -isnot [System.Collections.IDictionary]) { continue }
            $controlId = if ($ctrl.ContainsKey('id')) { [string]$ctrl['id'] } else { '<unknown>' }
            $locator = "$Framework : ${relPath}: control '$controlId'"

            $appliesTo = $null
            if ($ctrl.ContainsKey('appliesTo')) {
                $at = $ctrl['appliesTo']
                if ($at -is [System.Collections.IEnumerable] -and -not ($at -is [string])) {
                    $appliesTo = @($at | ForEach-Object { [string]$_ })
                    foreach ($value in $appliesTo) {
                        if ($allowedSurfaces -notcontains $value) {
                            $errors += "$locator : appliesTo contains invalid surface '$value' (allowed: $($allowedSurfaces -join ', '))"
                        } elseif ($null -ne $surfaceFilter -and $surfaceFilter -notcontains $value) {
                            $errors += "$locator : appliesTo value '$value' is not in manifest.surfaceFilter ($($surfaceFilter -join ', '))"
                        }
                    }
                } else {
                    $errors += "$locator : appliesTo must be an array"
                }
            } elseif ($null -ne $surfaceFilter) {
                $errors += "$locator : appliesTo is required when manifest.surfaceFilter is declared"
            }

            if ($ctrl.ContainsKey('sciVariable')) {
                $sv = [string]$ctrl['sciVariable']
                if ($allowedSciVars -notcontains $sv) {
                    $errors += "$locator : sciVariable '$sv' is not in $($allowedSciVars -join ', ')"
                }
            }

            if ($ctrl.ContainsKey('measurementClass')) {
                $mc = [string]$ctrl['measurementClass']
                if ($allowedMeasurement -notcontains $mc) {
                    $errors += "$locator : measurementClass '$mc' is not in $($allowedMeasurement -join ', ')"
                }
            }

            if ($ctrl.ContainsKey('appliesToPrinciples')) {
                $atp = $ctrl['appliesToPrinciples']
                if ($atp -is [System.Collections.IEnumerable] -and -not ($atp -is [string])) {
                    foreach ($ref in @($atp | ForEach-Object { [string]$_ })) {
                        if ($ref -notmatch '^gsf-principles:[a-z0-9-]+$') {
                            $errors += "$locator : appliesToPrinciples entry '$ref' must match ^gsf-principles:[a-z0-9-]+$"
                            continue
                        }
                        if ($null -ne $principleIds) {
                            $principleId = $ref.Substring('gsf-principles:'.Length)
                            if (-not $principleIds.ContainsKey($principleId)) {
                                $warnings += "$locator : appliesToPrinciples reference '$ref' does not resolve to any item id in the gsf-principles bundle"
                            }
                        }
                    }
                } else {
                    $errors += "$locator : appliesToPrinciples must be an array"
                }
            }
        }
    }

    return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
}

function Test-FsiPersistenceSanity {
    <#
    .SYNOPSIS
        Warns when a document-section input declares sensitive: true paired
        with persistence: user.
    .DESCRIPTION
        Walks each item file in a document-section bundle; for each input
        emits a warning when sensitive=true and persistence='user'. No-op
        for non-document-section bundles or when neither flag is set.
    .PARAMETER ItemFiles
        Array of FileInfo objects for the bundle's item YAML files.
    .PARAMETER Framework
        Framework identifier used in diagnostic messages.
    .PARAMETER RepoRoot
        Repository root path used to compute relative diagnostic paths.
    .OUTPUTS
        [pscustomobject] with Errors (string[]) and Warnings (string[]).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $false)]
        [System.IO.FileInfo[]]$ItemFiles = @(),

        [Parameter(Mandatory = $false)]
        [string]$Framework = '<unknown>',

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $errors = @()
    $warnings = @()

    foreach ($itemFile in $ItemFiles) {
        $item = $null
        try {
            $raw = Get-Content -LiteralPath $itemFile.FullName -Raw
            $item = ConvertFrom-Yaml -Yaml $raw
        }
        catch {
            continue
        }
        if ($item -isnot [System.Collections.IDictionary]) { continue }
        if (-not $item.ContainsKey('inputs')) { continue }
        $inputs = $item['inputs']
        if ($null -eq $inputs) { continue }

        $relPath = [System.IO.Path]::GetRelativePath($RepoRoot, $itemFile.FullName)
        $idx = -1
        foreach ($input in $inputs) {
            $idx++
            if ($input -isnot [System.Collections.IDictionary]) { continue }
            $name = if ($input.ContainsKey('name')) { [string]$input['name'] } else { "[$idx]" }
            $sensitive = $false
            if ($input.ContainsKey('sensitive')) { $sensitive = [bool]$input['sensitive'] }
            $persistence = if ($input.ContainsKey('persistence')) { [string]$input['persistence'] } else { 'session' }
            if ($sensitive -and $persistence -eq 'user') {
                $warnings += "$relPath : input '$name' declares sensitive: true with persistence: user (sensitive values should not persist beyond session scope)"
            }
        }
    }

    return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
}

function Test-FsiSigningAttestationConsistency {
    <#
    .SYNOPSIS
        Warns on incoherent signing/attestation declarations across a bundle.
    .DESCRIPTION
        Two checks:
         1. Manifest signing block: warn when 'required: true' is paired with
            'method: none' (operator must opt out via host --insecure-skip-signing).
         2. Per-item attestation.covers[]: each covered identifier MUST resolve
            to either a pipeline.stages[].produces[].id or a sibling item id
            within the bundle. Unresolved entries emit warnings.
    .PARAMETER Manifest
        The raw manifest hashtable.
    .PARAMETER Pipeline
        Optional pipeline hashtable returned by Get-FsiPipeline (may be $null).
    .PARAMETER ItemFiles
        Item YAML FileInfo array; used for sibling-id resolution and per-item
        attestation lookup.
    .PARAMETER Framework
        Framework identifier used in diagnostic messages.
    .PARAMETER RepoRoot
        Repository root path used to compute relative diagnostic paths.
    .OUTPUTS
        [pscustomobject] with Errors (string[]) and Warnings (string[]).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        $Manifest,

        [Parameter(Mandatory = $false)]
        $Pipeline = $null,

        [Parameter(Mandatory = $false)]
        [System.IO.FileInfo[]]$ItemFiles = @(),

        [Parameter(Mandatory = $false)]
        [string]$Framework = '<unknown>',

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $errors = @()
    $warnings = @()

    # Manifest signing block check
    if ($Manifest -is [System.Collections.IDictionary] -and $Manifest.ContainsKey('signing')) {
        $signing = $Manifest['signing']
        if ($signing -is [System.Collections.IDictionary]) {
            $required = $false
            if ($signing.ContainsKey('required')) { $required = [bool]$signing['required'] }
            $method = if ($signing.ContainsKey('method')) { [string]$signing['method'] } else { '' }
            if ($required -and $method -eq 'none') {
                $warnings += "$Framework : signing.required is true but signing.method is 'none' (no signature will be produced unless host overrides)"
            }
        }
    }

    # Build the resolvable id set: pipeline produces[].id + item ids
    $knownIds = @{}
    if ($Pipeline -is [System.Collections.IDictionary] -and $Pipeline.ContainsKey('stages')) {
        $stages = $Pipeline['stages']
        if ($null -ne $stages) {
            foreach ($stage in $stages) {
                if ($stage -isnot [System.Collections.IDictionary]) { continue }
                if (-not $stage.ContainsKey('produces')) { continue }
                $produces = $stage['produces']
                if ($null -eq $produces) { continue }
                foreach ($artifact in $produces) {
                    if ($artifact -isnot [System.Collections.IDictionary]) { continue }
                    if ($artifact.ContainsKey('id')) {
                        $knownIds[[string]$artifact['id']] = $true
                    }
                }
            }
        }
    }

    # Pre-parse items once for both id collection and per-item attestation walk
    $parsedItems = @()
    foreach ($itemFile in $ItemFiles) {
        $item = $null
        try {
            $raw = Get-Content -LiteralPath $itemFile.FullName -Raw
            $item = ConvertFrom-Yaml -Yaml $raw
        }
        catch {
            continue
        }
        if ($item -isnot [System.Collections.IDictionary]) { continue }
        if ($item.ContainsKey('id')) {
            $knownIds[[string]$item['id']] = $true
        }
        $parsedItems += [pscustomobject]@{ File = $itemFile; Item = $item }
    }

    foreach ($entry in $parsedItems) {
        $item = $entry.Item
        if (-not $item.ContainsKey('attestation')) { continue }
        $att = $item['attestation']
        if ($att -isnot [System.Collections.IDictionary]) { continue }
        if (-not $att.ContainsKey('covers')) { continue }
        $covers = $att['covers']
        if ($null -eq $covers) { continue }

        $relPath = [System.IO.Path]::GetRelativePath($RepoRoot, $entry.File.FullName)
        foreach ($coverId in $covers) {
            $idStr = [string]$coverId
            if (-not $knownIds.ContainsKey($idStr)) {
                $warnings += "$relPath : attestation.covers entry '$idStr' does not resolve to any pipeline produces[].id or sibling item id in bundle '$Framework'"
            }
        }
    }

    return [pscustomobject]@{ Errors = $errors; Warnings = $warnings }
}

function Invoke-FsiContentValidation {
    <#
    .SYNOPSIS
        Orchestrates Framework Skill content validation and returns an exit code.

    .DESCRIPTION
        Discovers all Framework Skills under SkillsPath, reads each manifest to
        determine itemKind, selects the corresponding per-item JSON Schema,
        and validates every item YAML file in the Framework Skill's items/ directory.

    .PARAMETER SkillsPath
        Root path to the skills directory.

    .PARAMETER WarningsAsErrors
        Treat warnings as errors for exit code calculation.

    .PARAMETER ChangedFilesOnly
        When set, only validate files changed relative to BaseBranch.

    .PARAMETER BaseBranch
        Git ref to diff against when ChangedFilesOnly is set.

    .PARAMETER OutputPath
        Output file path for validation results JSON.

    .OUTPUTS
        [int] Exit code: 0 for success, 1 for failure.

    .EXAMPLE
        $exitCode = Invoke-FsiContentValidation -SkillsPath '.github/skills'
    #>
    [CmdletBinding()]
    param(
        [string]$SkillsPath = '.github/skills',
        [switch]$WarningsAsErrors,
        [switch]$ChangedFilesOnly,
        [string]$BaseBranch = 'origin/main',
        [string]$OutputPath = 'logs/fsi-content-validation-results.json',
        [int]$MaxItemBodyChars = 200
    )

    try {
        $repoRoot = (git rev-parse --show-toplevel 2>$null)
        if (-not $repoRoot) { $repoRoot = (Get-Location).Path }

        $fullSkillsPath = Join-Path -Path $repoRoot -ChildPath $SkillsPath

        # Discover all Framework Skills by scanning for index.yml files
        $manifests = @()
        if (Test-Path -LiteralPath $fullSkillsPath -PathType Container) {
            $manifests = @(Get-ChildItem -Path $fullSkillsPath -Filter 'index.yml' -File -Recurse -ErrorAction SilentlyContinue)
        }

        $resolvedOutputPath = $OutputPath
        if (-not [System.IO.Path]::IsPathRooted($resolvedOutputPath)) {
            $resolvedOutputPath = Join-Path -Path $repoRoot -ChildPath $OutputPath
        }
        $outputDir = Split-Path -Parent $resolvedOutputPath
        if ($outputDir -and -not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        if ($manifests.Count -eq 0) {
            Write-Host '✅ No Framework Skills found - validation complete' -ForegroundColor Green
            @{
                timestamp    = (Get-Date -Format 'o')
                totalBundles = 0
                errors       = 0
                warnings     = 0
                results      = @()
            } | ConvertTo-Json -Depth 10 | Set-Content -Path $resolvedOutputPath -Encoding UTF8
            return 0
        }

        Write-Host "🔍 Validating $($manifests.Count) Framework Skill(s)..." -ForegroundColor Cyan

        $totalErrors = 0
        $totalWarnings = 0
        $bundleResults = @()

        foreach ($manifestFile in $manifests) {
            $bundle = Read-FrameworkSkillManifest -ManifestPath $manifestFile.FullName
            if ($null -eq $bundle) {
                $totalErrors++
                $relManifest = [System.IO.Path]::GetRelativePath($repoRoot, $manifestFile.FullName)
                Write-CIAnnotation -Message "$relManifest : manifest-unreadable" -Level Error
                $bundleResults += @{
                    bundle   = $relManifest
                    itemKind = 'unknown'
                    valid    = $false
                    errors   = @('manifest-unreadable')
                    warnings = @()
                    items    = @()
                }
                continue
            }

            $itemKind = $bundle.ItemKind
            $schemaPath = Get-ItemKindSchemaPath -RepoRoot $repoRoot -ItemKind $itemKind

            if ($null -eq $schemaPath) {
                $totalWarnings++
                Write-Host "  ⚠️  $($bundle.Framework): unknown itemKind '$itemKind' - skipping item validation" -ForegroundColor Yellow
                $bundleResults += @{
                    bundle   = $bundle.Framework
                    itemKind = $itemKind
                    valid    = $true
                    errors   = @()
                    warnings = @("unknown-item-kind: $itemKind")
                    items    = @()
                }
                continue
            }

            # Find all item YAML files in the items/ directory
            $itemsDir = Join-Path -Path $bundle.BundleDir -ChildPath 'items'
            if (-not (Test-Path -LiteralPath $itemsDir -PathType Container)) {
                $bundleResults += @{
                    bundle   = $bundle.Framework
                    itemKind = $itemKind
                    valid    = $true
                    errors   = @()
                    warnings = @()
                    items    = @()
                }
                continue
            }

            $itemFiles = @(Get-ChildItem -LiteralPath $itemsDir -Filter '*.yml' -File -ErrorAction SilentlyContinue)
            $bundleErrors = @()
            $bundleItems = @()

            foreach ($itemFile in $itemFiles) {
                $result = Test-FsiItemSchema -ItemPath $itemFile.FullName -SchemaPath $schemaPath
                $relPath = [System.IO.Path]::GetRelativePath($repoRoot, $itemFile.FullName)

                $bundleItems += @{ file = $relPath; valid = $result.Valid; errors = $result.Errors }

                if (-not $result.Valid) {
                    $totalErrors++
                    foreach ($err in $result.Errors) {
                        $bundleErrors += "$relPath : $err"
                        Write-CIAnnotation -Message "$relPath : $err" -Level Error
                    }
                }
            }

            # Variable-resolution lint for document-section Framework Skills
            $bundleWarnings = @()
            if ($itemKind -eq 'document-section') {
                $globals = @{}
                if ($bundle.Raw.ContainsKey('globals') -and $bundle.Raw['globals'] -is [System.Collections.IDictionary]) {
                    foreach ($key in $bundle.Raw['globals'].Keys) {
                        $globals[[string]$key] = $true
                    }
                }

                foreach ($itemFile in $itemFiles) {
                    $varResult = Test-FsiVariableResolution -ItemPath $itemFile.FullName -Globals $globals
                    $relPath = [System.IO.Path]::GetRelativePath($repoRoot, $itemFile.FullName)

                    foreach ($err in $varResult.Errors) {
                        $totalErrors++
                        $bundleErrors += "$relPath : $err"
                        Write-CIAnnotation -Message "$relPath : $err" -Level Error
                    }
                    foreach ($warn in $varResult.Warnings) {
                        $totalWarnings++
                        $bundleWarnings += "$relPath : $warn"
                        Write-CIAnnotation -Message "$relPath : $warn" -Level Warning
                    }
                }
            }

            # Pipeline-kind-compatibility lint (applies to any FSI bundle that declares pipeline)
            $pipeline = Get-FsiPipeline -Manifest $bundle.Raw
            if ($null -ne $pipeline) {
                $pipeResult = Test-FsiPipelineCompatibility -Pipeline $pipeline -Framework $bundle.Framework
                foreach ($err in $pipeResult.Errors) {
                    $totalErrors++
                    $bundleErrors += $err
                    Write-CIAnnotation -Message $err -Level Error
                }
                foreach ($warn in $pipeResult.Warnings) {
                    $totalWarnings++
                    $bundleWarnings += $warn
                    Write-CIAnnotation -Message $warn -Level Warning
                }

                # Binary-artifact cleanup lint
                $binResult = Test-FsiBinaryArtifactContract -Pipeline $pipeline -Framework $bundle.Framework
                foreach ($warn in $binResult.Warnings) {
                    $totalWarnings++
                    $bundleWarnings += $warn
                    Write-CIAnnotation -Message $warn -Level Warning
                }
            }

            # Skill-reference resolution lint
            $skillRefResult = Test-FsiSkillReferenceResolution -Manifest $bundle.Raw -Framework $bundle.Framework -RepoRoot $repoRoot
            foreach ($err in $skillRefResult.Errors) {
                $totalErrors++
                $bundleErrors += $err
                Write-CIAnnotation -Message $err -Level Error
            }
            foreach ($warn in $skillRefResult.Warnings) {
                $totalWarnings++
                $bundleWarnings += $warn
                Write-CIAnnotation -Message $warn -Level Warning
            }

            # Licensing presence, attribution coherence, and redistribution coherence
            $licenseResult = Test-FsiLicensePresence -Manifest $bundle.Raw -Framework $bundle.Framework
            foreach ($err in $licenseResult.Errors) {
                $totalErrors++
                $bundleErrors += $err
                Write-CIAnnotation -Message $err -Level Error
            }
            foreach ($warn in $licenseResult.Warnings) {
                $totalWarnings++
                $bundleWarnings += $warn
                Write-CIAnnotation -Message $warn -Level Warning
            }

            $attrResult = Test-FsiAttributionCoherence -Manifest $bundle.Raw -Framework $bundle.Framework
            foreach ($err in $attrResult.Errors) {
                $totalErrors++
                $bundleErrors += $err
                Write-CIAnnotation -Message $err -Level Error
            }
            foreach ($warn in $attrResult.Warnings) {
                $totalWarnings++
                $bundleWarnings += $warn
                Write-CIAnnotation -Message $warn -Level Warning
            }

            $redistResult = Test-FsiRedistributionCoherence -Manifest $bundle.Raw -Framework $bundle.Framework -ItemFiles $itemFiles -MaxItemBodyChars $MaxItemBodyChars -RepoRoot $repoRoot
            foreach ($err in $redistResult.Errors) {
                $totalErrors++
                $bundleErrors += $err
                Write-CIAnnotation -Message $err -Level Error
            }
            foreach ($warn in $redistResult.Warnings) {
                $totalWarnings++
                $bundleWarnings += $warn
                Write-CIAnnotation -Message $warn -Level Warning
            }

            # Governance review-currency lint
            $govResult = Test-FsiGovernanceReviewCurrency -Manifest $bundle.Raw -Framework $bundle.Framework
            foreach ($err in $govResult.Errors) {
                $totalErrors++
                $bundleErrors += $err
                Write-CIAnnotation -Message $err -Level Error
            }
            foreach ($warn in $govResult.Warnings) {
                $totalWarnings++
                $bundleWarnings += $warn
                Write-CIAnnotation -Message $warn -Level Warning
            }

            # FSI v1.0 sustainability surface-tagging lint
            $surfaceResult = Test-FsiSurfaceTagging -Manifest $bundle.Raw -ItemFiles $itemFiles -Framework $bundle.Framework -RepoRoot $repoRoot
            foreach ($err in $surfaceResult.Errors) {
                $totalErrors++
                $bundleErrors += $err
                Write-CIAnnotation -Message $err -Level Error
            }
            foreach ($warn in $surfaceResult.Warnings) {
                $totalWarnings++
                $bundleWarnings += $warn
                Write-CIAnnotation -Message $warn -Level Warning
            }

            # Persistence-sanity lint (document-section bundles)
            if ($itemKind -eq 'document-section') {
                $persistResult = Test-FsiPersistenceSanity -ItemFiles $itemFiles -Framework $bundle.Framework -RepoRoot $repoRoot
                foreach ($warn in $persistResult.Warnings) {
                    $totalWarnings++
                    $bundleWarnings += $warn
                    Write-CIAnnotation -Message $warn -Level Warning
                }
            }

            # Signing/attestation consistency lint (manifest-level signing block,
            # plus per-item attestation.covers[] resolution for document-section bundles)
            $signAttResult = Test-FsiSigningAttestationConsistency -Manifest $bundle.Raw -Pipeline $pipeline -ItemFiles $itemFiles -Framework $bundle.Framework -RepoRoot $repoRoot
            foreach ($err in $signAttResult.Errors) {
                $totalErrors++
                $bundleErrors += $err
                Write-CIAnnotation -Message $err -Level Error
            }
            foreach ($warn in $signAttResult.Warnings) {
                $totalWarnings++
                $bundleWarnings += $warn
                Write-CIAnnotation -Message $warn -Level Warning
            }

            $bundleValid = $bundleErrors.Count -eq 0
            Write-Host "  $(if ($bundleValid) { '✅' } else { '❌' }) $($bundle.Framework) ($itemKind): $($itemFiles.Count) item(s), $($bundleErrors.Count) error(s)" -ForegroundColor $(if ($bundleValid) { 'Green' } else { 'Red' })

            $bundleResults += @{
                bundle   = $bundle.Framework
                itemKind = $itemKind
                valid    = $bundleValid
                errors   = $bundleErrors
                warnings = $bundleWarnings
                items    = $bundleItems
            }
        }

        @{
            timestamp    = (Get-Date -Format 'o')
            totalBundles = $manifests.Count
            errors       = $totalErrors
            warnings     = $totalWarnings
            results      = $bundleResults
        } | ConvertTo-Json -Depth 10 | Set-Content -Path $resolvedOutputPath -Encoding UTF8

        $summaryColor = if ($totalErrors -gt 0) { 'Red' } else { 'Green' }
        Write-Host "✅ Framework Skill content validation complete ($($manifests.Count) Framework Skill(s), $totalErrors error(s), $totalWarnings warning(s))" -ForegroundColor $summaryColor

        if ($totalErrors -gt 0) { return 1 }
        if ($WarningsAsErrors -and $totalWarnings -gt 0) { return 1 }
        return 0
    }
    catch {
        Write-Error -ErrorAction Continue "Validate-FsiContent failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        return 1
    }
}

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    $exitCode = Invoke-FsiContentValidation `
        -SkillsPath $SkillsPath `
        -WarningsAsErrors:$WarningsAsErrors `
        -ChangedFilesOnly:$ChangedFilesOnly `
        -BaseBranch $BaseBranch `
        -OutputPath $OutputPath `
        -MaxItemBodyChars $MaxItemBodyChars
    exit $exitCode
}
#endregion Main Execution
