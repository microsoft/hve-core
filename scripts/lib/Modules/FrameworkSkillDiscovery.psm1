# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# FrameworkSkillDiscovery.psm1
#
# Purpose: Host-agent-neutral discovery and validation utilities for Framework
# Framework Skills (Framework Skill). Any consuming agent — planner, reviewer, importer,
# generator, etc. — uses these functions to enumerate Framework Skills under a domain
# root, parse manifests, and resolve phase-scoped item file paths.
#
# Contract: see scripts/linting/schemas/framework-skill-manifest.schema.json.
# Phase labels and item file shapes are owned by the host agent; this module
# validates only structural shape and identifier hygiene.

#Requires -Version 7.0
#Requires -Modules powershell-yaml

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Get-FrameworkSkillRoot {
    <#
    .SYNOPSIS
    Resolves the conventional skills root for a given domain.

    .DESCRIPTION
    Returns the absolute path to .github/skills/<domain>/ relative to the
    supplied repository root. The host agent owns its domain identifier; this
    helper performs no validation that the directory exists.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-z][a-z0-9-]*$')]
        [string]$Domain
    )

    return (Join-Path -Path $RepoRoot -ChildPath ".github/skills/$Domain")
}

function Read-FrameworkSkillManifest {
    <#
    .SYNOPSIS
    Reads a single Framework Skill manifest (index.yml) and normalizes optional fields.

    .DESCRIPTION
    Parses the manifest with ConvertFrom-Yaml, applies documented defaults
    (status=published, itemKind=control), and surfaces the Framework Skill directory
    so callers can resolve item paths without repeating string math. Returns
    $null when the path is missing or unreadable.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath
    )

    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        return $null
    }

    try {
        $raw = Get-Content -LiteralPath $ManifestPath -Raw -Encoding utf8
        $data = $raw | ConvertFrom-Yaml
    }
    catch {
        return $null
    }

    if ($null -eq $data) { return $null }

    $bundleDir = Split-Path -Parent -Path $ManifestPath
    $domain = $null
    if ($data.ContainsKey('domain')) {
        $domain = [string]$data['domain']
    }
    else {
        # Infer from parent directory under .github/skills/<domain>/<framework>/.
        $parent = Split-Path -Parent -Path $bundleDir
        if ($parent) { $domain = Split-Path -Leaf -Path $parent }
    }

    return [pscustomobject]@{
        ManifestPath = $ManifestPath
        BundleDir    = $bundleDir
        Framework    = [string]$data['framework']
        Version      = [string]$data['version']
        Domain       = $domain
        ItemKind     = if ($data.ContainsKey('itemKind')) { [string]$data['itemKind'] } else { 'control' }
        Status       = if ($data.ContainsKey('status')) { [string]$data['status'] } else { 'published' }
        PhaseMap     = if ($data.ContainsKey('phaseMap')) { $data['phaseMap'] } else { @{} }
        Metadata     = if ($data.ContainsKey('metadata')) { $data['metadata'] } else { $null }
        Raw          = $data
    }
}

function Get-FrameworkSkill {
    <#
    .SYNOPSIS
    Enumerates Framework Skills under one or more roots.

    .DESCRIPTION
    Discovers every <root>/*/index.yml across the conventional repo root
    (.github/skills/<Domain>/) plus any additional roots supplied by the host
    agent. Additional roots let users keep custom Framework Skills outside the repo
    (org-shared paths, .copilot-tracking/framework-imports/, etc.) without
    forking. Each parsed Framework Skill is filtered to the requested Domain (matched
    against the manifest's declared or inferred domain). Drafts (status=draft)
    are excluded by default; pass -IncludeDrafts to surface them. Bundles whose
    manifest fails to parse are silently skipped; pair with
    Test-FrameworkSkillInterface when strict validation is required. Duplicate
    Framework Skills (same Framework id) are de-duplicated by first-seen wins, with the
    repo root searched first so additional roots cannot shadow built-ins.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-z][a-z0-9-]*$')]
        [string]$Domain,

        [Parameter(Mandatory = $false)]
        [string[]]$AdditionalRoots,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeDrafts
    )

    $roots = @(Get-FrameworkSkillRoot -RepoRoot $RepoRoot -Domain $Domain)
    if ($AdditionalRoots) {
        foreach ($extra in $AdditionalRoots) {
            if ([string]::IsNullOrWhiteSpace($extra)) { continue }
            if ([System.IO.Path]::IsPathRooted($extra)) {
                $roots += $extra
            }
            else {
                $roots += (Join-Path -Path $RepoRoot -ChildPath $extra)
            }
        }
    }

    $results = @()
    $seenFrameworks = @{}
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }

        $manifests = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path -Path $_.FullName -ChildPath 'index.yml' } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }

        foreach ($manifest in $manifests) {
            $bundle = Read-FrameworkSkillManifest -ManifestPath $manifest
            if ($null -eq $bundle) { continue }
            if ($bundle.Domain -ne $Domain) { continue }
            if (-not $IncludeDrafts -and $bundle.Status -eq 'draft') { continue }
            if ($seenFrameworks.ContainsKey($bundle.Framework)) { continue }
            $seenFrameworks[$bundle.Framework] = $true
            $results += $bundle
        }
    }

    return $results
}

function Resolve-FrameworkSkillPhaseItem {
    <#
    .SYNOPSIS
    Resolves a phase label to absolute item file paths within a Framework Skill.

    .DESCRIPTION
    Looks up Bundle.PhaseMap[Phase], resolves each id to items/<id>.yml,
    and returns one [pscustomobject] per item id with Id, Path, and Exists.
    The host agent owns the semantics of the phase string; this helper makes
    no judgement about whether the phase is recognized.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Bundle,

        [Parameter(Mandatory = $true)]
        [string]$Phase
    )

    $phaseMap = $Bundle.PhaseMap
    if ($null -eq $phaseMap -or -not $phaseMap.ContainsKey($Phase)) {
        return @()
    }

    $ids = @($phaseMap[$Phase])
    $results = @()
    foreach ($id in $ids) {
        $path = Join-Path -Path $Bundle.BundleDir -ChildPath "items/$id.yml"
        $results += [pscustomobject]@{
            Id     = $id
            Path   = $path
            Exists = [bool](Test-Path -LiteralPath $path -PathType Leaf)
        }
    }

    return $results
}

function Test-FrameworkSkillInterface {
    <#
    .SYNOPSIS
    Validates a single Framework Skill manifest against the manifest schema.

    .DESCRIPTION
    Loads scripts/linting/schemas/framework-skill-manifest.schema.json relative
    to the supplied repo root, converts the parsed manifest to JSON, and runs
    Test-Json. Returns a result object with Valid (bool) and Errors (string[]).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$ManifestPath
    )

    $bundle = Read-FrameworkSkillManifest -ManifestPath $ManifestPath
    if ($null -eq $bundle) {
        return [pscustomobject]@{ Valid = $false; Errors = @('manifest-unreadable') }
    }

    $schemaPath = Join-Path -Path $RepoRoot -ChildPath 'scripts/linting/schemas/framework-skill-manifest.schema.json'
    if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) {
        return [pscustomobject]@{ Valid = $false; Errors = @("schema-missing: $schemaPath") }
    }

    $json = $bundle.Raw | ConvertTo-Json -Depth 20
    $errors = @()
    try {
        $valid = Test-Json -Json $json -SchemaFile $schemaPath -ErrorVariable validationErrors -ErrorAction SilentlyContinue
        if ($validationErrors) { $errors = $validationErrors | ForEach-Object { $_.ToString() } }
    }
    catch {
        $valid = $false
        $errors = @($_.Exception.Message)
    }

    return [pscustomobject]@{ Valid = [bool]$valid; Errors = $errors }
}

function Get-FsiPipeline {
    <#
    .SYNOPSIS
        Returns the pipeline block from a framework skill manifest.
    .DESCRIPTION
        Returns the manifest's pipeline object when present, otherwise $null.
        Accepts either the raw manifest hashtable or the wrapped bundle object
        produced by Read-FrameworkSkillManifest (which exposes the manifest via
        the Raw property).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Manifest
    )

    $source = $Manifest
    if ($Manifest -isnot [System.Collections.IDictionary] -and $Manifest.PSObject.Properties['Raw']) {
        $source = $Manifest.Raw
    }
    if ($null -eq $source -or $source -isnot [System.Collections.IDictionary]) { return $null }
    if (-not $source.ContainsKey('pipeline')) { return $null }
    $pipeline = $source['pipeline']
    if ($pipeline -isnot [System.Collections.IDictionary]) { return $null }
    return $pipeline
}

function Get-FsiGovernance {
    <#
    .SYNOPSIS
        Returns governance metadata from a framework skill manifest.
    .DESCRIPTION
        Returns the manifest's governance block (owners, review_cadence,
        last_reviewed, optional deprecation, optional style_guide), or $null
        when absent.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Manifest
    )
    if (-not $Manifest.ContainsKey('governance')) { return $null }
    $gov = $Manifest['governance']
    if ($gov -isnot [System.Collections.IDictionary]) { return $null }
    return $gov
}

function Get-FsiAttestation {
    <#
    .SYNOPSIS
        Returns the attestation block from a document-section item.
    .DESCRIPTION
        Returns the per-item attestation hashtable (required, covers[]) when
        present; returns $null when absent or malformed. Operates on a single
        item, not a manifest, because attestation is declared per item under
        the document-section schema.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Item
    )
    if (-not $Item.ContainsKey('attestation')) { return $null }
    $att = $Item['attestation']
    if ($att -isnot [System.Collections.IDictionary]) { return $null }
    return $att
}

function Get-FsiSigning {
    <#
    .SYNOPSIS
        Returns the signing block from a framework skill manifest.
    .DESCRIPTION
        Returns the manifest's signing block (required, method, identity,
        transparency_log, optional verify recipe) when present; returns $null
        when absent or malformed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Manifest
    )
    if (-not $Manifest.ContainsKey('signing')) { return $null }
    $signing = $Manifest['signing']
    if ($signing -isnot [System.Collections.IDictionary]) { return $null }
    return $signing
}

function Get-FsiSelectWhen {
    <#
    .SYNOPSIS
        Returns select-when criteria from a framework skill manifest.
    .DESCRIPTION
        Stub accessor. Returns $null until the selectWhen manifest field lands.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Manifest
    )
    return $null
}

function Get-FsiBinaryArtifacts {
    <#
    .SYNOPSIS
        Returns the flat list of binary artifacts produced anywhere in the
        manifest's pipeline.
    .DESCRIPTION
        Walks pipeline.stages[].produces[] and emits one record per artifact
        whose kind begins with 'binary/'. Each record exposes the originating
        stage id, the artifact id, the kind, and the optional cleanup hint
        (ephemeral|retained, or $null when undeclared).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Manifest
    )

    $source = $Manifest
    if ($Manifest -isnot [System.Collections.IDictionary] -and $Manifest.PSObject.Properties['Raw']) {
        $source = $Manifest.Raw
    }
    if ($null -eq $source -or $source -isnot [System.Collections.IDictionary]) { return @() }
    if (-not $source.ContainsKey('pipeline')) { return @() }
    $pipeline = $source['pipeline']
    if ($pipeline -isnot [System.Collections.IDictionary] -or -not $pipeline.ContainsKey('stages')) { return @() }

    $results = @()
    foreach ($stage in $pipeline['stages']) {
        if ($stage -isnot [System.Collections.IDictionary] -or -not $stage.ContainsKey('produces')) { continue }
        $stageId = if ($stage.ContainsKey('id')) { [string]$stage['id'] } else { $null }
        foreach ($produce in $stage['produces']) {
            if ($produce -isnot [System.Collections.IDictionary]) { continue }
            $kind = if ($produce.ContainsKey('kind')) { [string]$produce['kind'] } else { '' }
            if (-not $kind.StartsWith('binary/')) { continue }
            $results += [pscustomobject]@{
                StageId = $stageId
                Id      = if ($produce.ContainsKey('id')) { [string]$produce['id'] } else { $null }
                Kind    = $kind
                Cleanup = if ($produce.ContainsKey('cleanup')) { [string]$produce['cleanup'] } else { $null }
            }
        }
    }
    return $results
}

function Get-FsiSkillReferences {
    <#
    .SYNOPSIS
        Returns the manifest's requiredSkills[] list (or empty when absent).
    .DESCRIPTION
        Hosts call this to discover companion skills declared by a Framework
        Skill. Each returned record is the raw manifest entry; callers may
        inspect ref / scope / reason / usedByStages directly.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Manifest
    )

    $source = $Manifest
    if ($Manifest -isnot [System.Collections.IDictionary] -and $Manifest.PSObject.Properties['Raw']) {
        $source = $Manifest.Raw
    }
    if ($null -eq $source -or $source -isnot [System.Collections.IDictionary]) { return @() }
    if (-not $source.ContainsKey('requiredSkills')) { return @() }
    $refs = $source['requiredSkills']
    if ($null -eq $refs) { return @() }
    return @($refs)
}

Export-ModuleMember -Function @(
    'Get-FrameworkSkillRoot',
    'Read-FrameworkSkillManifest',
    'Get-FrameworkSkill',
    'Resolve-FrameworkSkillPhaseItem',
    'Test-FrameworkSkillInterface',
    'Get-FsiPipeline',
    'Get-FsiGovernance',
    'Get-FsiAttestation',
    'Get-FsiSigning',
    'Get-FsiSelectWhen',
    'Get-FsiBinaryArtifacts',
    'Get-FsiSkillReferences'
)
