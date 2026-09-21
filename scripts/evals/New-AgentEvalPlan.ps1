#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Builds a deterministic execution plan for PR agent evaluations.
.DESCRIPTION
    Merges changed-artifact and changed-spec manifests, resolves ordinary agent
    run keys through the shared stimulus index, assigns complete artifact
    components to bounded weighted shards, and records conditional baseline
    applicability in a digest-covered JSON plan.
.PARAMETER ManifestPath
    Changed AI artifact manifest path.
.PARAMETER ChangedSpecManifestPath
    Changed-spec synthetic artifact manifest path.
.PARAMETER EvalRoot
    Eval specification root.
.PARAMETER OutputPath
    Destination for the canonical plan JSON.
.PARAMETER OrdinaryShardCount
    Maximum ordinary agent shard count. Supported values are 1 and 4.
.PARAMETER InstructionShardCount
    Maximum instruction shard count. Supported values are 1 and 2.
.PARAMETER SkillShardCount
    Maximum skill shard count. Supported values are 1 and 2.
.PARAMETER BaselineSubject
    Agent whose affected status requires baseline equivalence.
.PARAMETER RepoRoot
    Repository root.
.EXAMPLE
    ./New-AgentEvalPlan.ps1 -ManifestPath logs/changed-ai-artifacts.json `
        -ChangedSpecManifestPath logs/changed-spec-stimuli.json
.NOTES
    Runs before model-backed eval jobs in Eval Validation.
#>
[CmdletBinding()]
param(
    [string]$ManifestPath = 'logs/changed-ai-artifacts.json',
    [string]$ChangedSpecManifestPath = 'logs/changed-spec-stimuli.json',
    [string]$EvalRoot = 'evals',
    [string]$OutputPath = 'logs/agent-eval-plan.json',
    [ValidateSet(1, 4)]
    [int]$OrdinaryShardCount = 4,
    [ValidateSet(1, 2)]
    [int]$InstructionShardCount = 2,
    [ValidateSet(1, 2)]
    [int]$SkillShardCount = 2,
    [ValidateNotNullOrEmpty()]
    [string]$BaselineSubject = 'rpi-agent',
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/StimulusIndex.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/VallyRunner.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/ArtifactDetection.psm1') -Force
if (-not (Get-Module -Name powershell-yaml)) {
    Import-Module powershell-yaml -ErrorAction Stop
}

#region Functions

function Resolve-AgentEvalPlanPath {
    <#
    .SYNOPSIS
        Resolves a path relative to the repository root.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )

    if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
    return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Get-AgentEvalArtifacts {
    <#
    .SYNOPSIS
        Merges changed and synthetic manifests into unique active artifacts.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)][psobject]$Manifest,
        [Parameter(Mandatory = $true)][psobject]$ChangedSpecManifest
    )

    $byKey = [ordered]@{}
    foreach ($artifact in @($Manifest.artifacts) + @($ChangedSpecManifest.artifacts)) {
        if ($null -eq $artifact -or [string]$artifact.status -eq 'D') { continue }
        $kind = [string]$artifact.kind
        $artifactId = [string]$artifact.artifactId
        if ([string]::IsNullOrWhiteSpace($kind) -or [string]::IsNullOrWhiteSpace($artifactId)) { continue }
        if (Test-RepoRootArtifact -Kind $kind -Path ([string]$artifact.path)) { continue }
        $key = "$kind`:$artifactId"
        if (-not $byKey.Contains($key)) { $byKey[$key] = $artifact }
    }
    return @($byKey.Keys | Sort-Object | ForEach-Object { $byKey[$_] })
}

function Get-AgentEvalRunWeight {
    <#
    .SYNOPSIS
        Calculates selected stimulus count multiplied by declared runs.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param([Parameter(Mandatory = $true)][hashtable]$Run)

    $parsed = ConvertFrom-Yaml (Get-Content -LiteralPath $Run.specAbs -Raw -Encoding utf8)
    $runCount = 1
    if ($parsed -is [System.Collections.IDictionary] -and $parsed.Contains('defaults') -and
        $parsed.defaults -is [System.Collections.IDictionary] -and $parsed.defaults.Contains('runs')) {
        $declaredRuns = [int]$parsed.defaults.runs
        if ($declaredRuns -gt 0) { $runCount = $declaredRuns }
    }

    $stimuli = @($parsed.stimuli)
    if (-not [string]::IsNullOrWhiteSpace([string]$Run.tag)) {
        $parts = ([string]$Run.tag) -split '=', 2
        $tagKind = $parts[0]
        $tagValue = $parts[1]
        $stimuli = @($stimuli | Where-Object {
                if ($_ -isnot [System.Collections.IDictionary] -or -not $_.Contains('tags')) { return $false }
                $tags = $_.tags
                if ($tags -isnot [System.Collections.IDictionary] -or -not $tags.Contains($tagKind)) { return $false }
                return @($tags[$tagKind]) -contains $tagValue
            })
    }
    return [int]($stimuli.Count * $runCount)
}

function New-AgentEvalKindPlan {
    <#
    .SYNOPSIS
        Builds deterministic weighted shards for one artifact kind.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)][ValidateSet('agent', 'instruction', 'skill')][string]$Kind,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Artifact,
        [Parameter(Mandatory = $true)][hashtable]$Index,
        [Parameter(Mandatory = $true)][hashtable]$BacklinkCount,
        [Parameter(Mandatory = $true)][int]$ShardCount,
        [Parameter(Mandatory = $true)][string]$ShardPrefix,
        [switch]$PreserveEmptyProducer
    )

    $descriptors = @(
        foreach ($artifactItem in @($Artifact | Where-Object { [string]$_.kind -eq $Kind })) {
            $coverage = Test-StimulusCoverage -Index $Index -Kind $Kind -ArtifactId ([string]$artifactItem.artifactId)
            [ordered]@{
                kind       = $Kind
                artifactId = [string]$artifactItem.artifactId
                path       = [string]$artifactItem.path
                status     = [string]$artifactItem.status
                specs      = $coverage
            }
        }
    )
    $runPlan = Get-VallySpecRunPlan -Artifact $descriptors -SpecBacklinkCount $BacklinkCount -IndexRoot $Index.root
    if (@($runPlan.missingSpecs).Count -gt 0) {
        throw "Cannot plan $Kind evals: $(@($runPlan.missingSpecs).Count) artifact(s) have no covering spec."
    }

    $ordinaryRuns = @{}
    foreach ($runKey in @($runPlan.uniqueSpecRuns.Keys | Sort-Object)) {
        $run = $runPlan.uniqueSpecRuns[$runKey]
        if (($run.specRel -replace '\\', '/') -match '(^|/)baseline-equivalence/') { continue }
        $ordinaryRuns[$runKey] = $run
    }
    $ordinaryArtifactPlan = @(
        foreach ($artifactItem in @($runPlan.artifactPlan)) {
            $runKeys = @($artifactItem.specRuns | Where-Object { $ordinaryRuns.ContainsKey([string]$_) } | Sort-Object -Unique)
            if ($runKeys.Count -eq 0) { continue }
            [pscustomobject][ordered]@{
                kind       = [string]$artifactItem.kind
                artifactId = [string]$artifactItem.artifactId
                specRuns   = $runKeys
            }
        }
    )

    $weightedComponents = @(
        foreach ($component in @(Get-AgentEvalOwnershipComponent -ArtifactPlan $ordinaryArtifactPlan)) {
            $weight = 0
            foreach ($runKey in $component.RunKeys) { $weight += Get-AgentEvalRunWeight -Run $ordinaryRuns[$runKey] }
            [pscustomobject][ordered]@{
                ArtifactKeys = $component.ArtifactKeys
                RunKeys      = $component.RunKeys
                Weight       = $weight
                StableKey    = $component.ArtifactKeys[0]
            }
        }
    )
    $weightedComponents = @($weightedComponents | Sort-Object @{ Expression = 'Weight'; Descending = $true }, @{ Expression = 'StableKey'; Ascending = $true })

    $shards = @(
        for ($indexValue = 1; $indexValue -le $ShardCount; $indexValue++) {
            [pscustomobject][ordered]@{
                id                  = '{0}-{1:d2}' -f $ShardPrefix, $indexValue
                kind                = $Kind
                expectedTrialWeight = 0
                artifacts           = [System.Collections.Generic.List[string]]::new()
                runKeys             = [System.Collections.Generic.List[string]]::new()
            }
        }
    )
    foreach ($component in $weightedComponents) {
        $target = @($shards | Sort-Object expectedTrialWeight, id)[0]
        $target.expectedTrialWeight += $component.Weight
        foreach ($artifactKey in $component.ArtifactKeys) { $target.artifacts.Add($artifactKey) }
        foreach ($runKey in $component.RunKeys) { $target.runKeys.Add($runKey) }
    }

    $selectedShards = @($shards | Where-Object { $_.artifacts.Count -gt 0 } | Sort-Object id)
    if ($selectedShards.Count -eq 0 -and $PreserveEmptyProducer) { $selectedShards = @($shards[0]) }
    return @{
        Shards = @(
            foreach ($shard in $selectedShards) {
                [ordered]@{
                    id                  = $shard.id
                    kind                = $shard.kind
                    expectedTrialWeight = [int]$shard.expectedTrialWeight
                    artifacts           = @($shard.artifacts | Sort-Object)
                    runKeys             = @($shard.runKeys | Sort-Object -Unique)
                }
            }
        )
        ArtifactKeys = @($ordinaryArtifactPlan | ForEach-Object { "$($_.kind):$($_.artifactId)" } | Sort-Object -Unique)
        RunKeys      = @($ordinaryRuns.Keys | Sort-Object)
    }
}

function New-AgentEvalPlanValue {
    <#
    .SYNOPSIS
        Constructs the canonical plan value from manifests and eval specs.
    #>
    [CmdletBinding()]
    [OutputType([ordered])]
    param(
        [Parameter(Mandatory = $true)][string]$ManifestPath,
        [Parameter(Mandatory = $true)][string]$ChangedSpecManifestPath,
        [Parameter(Mandatory = $true)][string]$EvalRoot,
        [Parameter(Mandatory = $true)][ValidateSet(1, 4)][int]$ShardCount,
        [ValidateSet(1, 2)][int]$InstructionShardCount = 2,
        [ValidateSet(1, 2)][int]$SkillShardCount = 2,
        [Parameter(Mandatory = $true)][string]$BaselineSubject
    )

    $manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding utf8 | ConvertFrom-Json -Depth 20
    $changedSpecManifest = Get-Content -LiteralPath $ChangedSpecManifestPath -Raw -Encoding utf8 | ConvertFrom-Json -Depth 20
    $artifacts = @(Get-AgentEvalArtifacts -Manifest $manifest -ChangedSpecManifest $changedSpecManifest)
    $index = New-StimulusIndex -EvalRoot $EvalRoot
    if (@($index.errors).Count -gt 0) { throw "Stimulus index contains $(@($index.errors).Count) parse error(s)." }
    $backlinkCounts = Get-VallySpecBacklinkCount -Index $index
    $ordinaryShards = [System.Collections.Generic.List[object]]::new()
    $expectedArtifactKeys = [System.Collections.Generic.List[string]]::new()
    $expectedRunKeys = [System.Collections.Generic.List[string]]::new()
    foreach ($definition in @(
            @{ Kind = 'agent'; ShardCount = $ShardCount; ShardPrefix = 'ordinary'; PreserveEmptyProducer = $false }
            @{ Kind = 'instruction'; ShardCount = $InstructionShardCount; ShardPrefix = 'instruction'; PreserveEmptyProducer = $true }
            @{ Kind = 'skill'; ShardCount = $SkillShardCount; ShardPrefix = 'skill'; PreserveEmptyProducer = $true }
        )) {
        $kindPlan = New-AgentEvalKindPlan `
            -Kind $definition.Kind `
            -Artifact $artifacts `
            -Index $index `
            -BacklinkCount $backlinkCounts `
            -ShardCount $definition.ShardCount `
            -ShardPrefix $definition.ShardPrefix `
            -PreserveEmptyProducer:$definition.PreserveEmptyProducer
        foreach ($shard in $kindPlan.Shards) { $ordinaryShards.Add($shard) }
        foreach ($artifactKey in $kindPlan.ArtifactKeys) { $expectedArtifactKeys.Add($artifactKey) }
        foreach ($runKey in $kindPlan.RunKeys) { $expectedRunKeys.Add($runKey) }
    }
    Assert-AgentEvalOwnership `
        -ExpectedArtifact @($expectedArtifactKeys | Sort-Object -Unique) `
        -ExpectedRunKey @($expectedRunKeys | Sort-Object -Unique) `
        -Shard @($ordinaryShards)

    $affectedAgents = @($manifest.affectedAgents | ForEach-Object { [string]$_ } | Sort-Object -Unique)
    $baselineRequired = $affectedAgents -contains $BaselineSubject
    $baselineModels = [System.Collections.Generic.List[string]]::new()
    if ($baselineRequired) {
        $baselineModels.Add('gpt-5.6-luna')
        $baselineModels.Add('claude-sonnet-5')
    }
    $baseline = [ordered]@{
        required = $baselineRequired
        reason   = if ($baselineRequired) { "affected-agent:$BaselineSubject" } else { "agent-not-affected:$BaselineSubject" }
        models   = $baselineModels
    }
    $expectedProducers = [System.Collections.Generic.List[string]]::new()
    foreach ($shard in $ordinaryShards) { $expectedProducers.Add([string]$shard.id) }
    $expectedProducers.Add('prompt')
    if ($baselineRequired) {
        $expectedProducers.Add('baseline:gpt-5.6-luna')
        $expectedProducers.Add('baseline:claude-sonnet-5')
    }

    $digestPayload = [ordered]@{
        schemaVersion   = '1.1.0'
        manifestDigests = [ordered]@{
            changedArtifacts = Get-AgentEvalFileDigest -Path $ManifestPath
            changedSpecs     = Get-AgentEvalFileDigest -Path $ChangedSpecManifestPath
        }
        baseline        = $baseline
        ordinaryShards  = @($ordinaryShards)
        expectedProducers = $expectedProducers
    }
    return [ordered]@{
        schemaVersion   = $digestPayload.schemaVersion
        manifestDigests = $digestPayload.manifestDigests
        planDigest      = Get-AgentEvalValueDigest -Value $digestPayload
        baseline        = $digestPayload.baseline
        ordinaryShards  = $digestPayload.ordinaryShards
        expectedProducers = $digestPayload.expectedProducers
    }
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $resolvedRoot = if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
            (Resolve-Path (git rev-parse --show-toplevel)).ProviderPath
        }
        else {
            (Resolve-Path -LiteralPath $RepoRoot).ProviderPath
        }
        $resolvedManifest = Resolve-AgentEvalPlanPath -Path $ManifestPath -Root $resolvedRoot
        $resolvedChangedSpec = Resolve-AgentEvalPlanPath -Path $ChangedSpecManifestPath -Root $resolvedRoot
        $resolvedEvalRoot = Resolve-AgentEvalPlanPath -Path $EvalRoot -Root $resolvedRoot
        $resolvedOutput = Resolve-AgentEvalPlanPath -Path $OutputPath -Root $resolvedRoot
        $plan = New-AgentEvalPlanValue `
            -ManifestPath $resolvedManifest `
            -ChangedSpecManifestPath $resolvedChangedSpec `
            -EvalRoot $resolvedEvalRoot `
            -ShardCount $OrdinaryShardCount `
            -InstructionShardCount $InstructionShardCount `
            -SkillShardCount $SkillShardCount `
            -BaselineSubject $BaselineSubject
        $outputDirectory = Split-Path -Parent $resolvedOutput
        if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
            New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
        }
        $plan | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $resolvedOutput -Encoding utf8NoBOM
        Write-Host "Agent eval plan: $resolvedOutput ($(@($plan.ordinaryShards).Count) ordinary shard(s), baseline required=$($plan.baseline.required))"
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "New-AgentEvalPlan failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main Execution