#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Writes one version across the repository's version-tracked files.

.DESCRIPTION
    Updates exactly these fields and nothing else:

    - package.json $.version
    - package-lock.json $.version and $.packages[""].version
    - extension/templates/package.template.json $.version
    - $.version in each catalog source's plugin.json, including the root
    - .github/plugin/marketplace.json $.metadata.version and $.plugins[*].version

    Each field is replaced in place, so surrounding formatting is preserved and
    reapplying the same version produces no diff. The script performs no source
    ref transform, records no release candidate, and generates nothing.

.PARAMETER Version
    The version string to write, for example '3.3.0'.

.PARAMETER RepoRoot
    Root directory of the repository. Defaults to the git working tree root.

.EXAMPLE
    ./Set-RepositoryVersion.ps1 -Version '3.3.0'

.NOTES
    Release-please owns release PRs, tags, and versions; this script normalizes
    the same files during reviewed branch promotion.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+\z')]
    [string]$Version,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = ((git rev-parse --show-toplevel 2>$null) ?? (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path)
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../plugins/PluginCatalog.psm1') -Force

# Each target names the exact member locations that carry the repository
# version. Locations are walked structurally, so a shape change fails loudly
# instead of rewriting a same-named member nested elsewhere.
$script:VersionTarget = @(
    [ordered]@{
        Path     = 'package.json'
        Location = @(, @('version'))
    }
    [ordered]@{
        Path     = 'package-lock.json'
        Location = @(
            , @('version')
            , @('packages', '', 'version')
        )
    }
    [ordered]@{
        Path     = 'extension/templates/package.template.json'
        Location = @(, @('version'))
    }
)

#region Functions

function Get-JsonValueEnd {
    <#
    .SYNOPSIS
        Returns the index just past a complete JSON value.

    .PARAMETER Content
        File content.

    .PARAMETER Start
        Index of the value's first character.

    .OUTPUTS
        [int] Index just past the value.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [int]$Start
    )

    $Index = $Start
    if ($Content[$Index] -eq '"') {
        for ($Index++; $Index -lt $Content.Length; $Index++) {
            if ($Content[$Index] -eq '\') { $Index++; continue }
            if ($Content[$Index] -eq '"') { return $Index + 1 }
        }
        throw 'Unterminated JSON string.'
    }

    if ($Content[$Index] -eq '{' -or $Content[$Index] -eq '[') {
        $Depth = 0
        while ($Index -lt $Content.Length) {
            $Character = $Content[$Index]
            if ($Character -eq '"') {
                $Index = Get-JsonValueEnd -Content $Content -Start $Index
                continue
            }
            if ($Character -eq '{' -or $Character -eq '[') { $Depth++ }
            elseif ($Character -eq '}' -or $Character -eq ']') {
                $Depth--
                if ($Depth -eq 0) { return $Index + 1 }
            }
            $Index++
        }
        throw 'Unterminated JSON container.'
    }

    while ($Index -lt $Content.Length -and $Content[$Index] -notmatch '[,\}\]\s]') { $Index++ }
    return $Index
}

function Get-JsonMemberValueSpan {
    <#
    .SYNOPSIS
        Locates a string member value at an exact JSON location.

    .DESCRIPTION
        Walks containers by member name and array index, so a same-named member
        nested elsewhere is never selected.

    .PARAMETER Content
        File content.

    .PARAMETER Location
        Ordered member names and array indices naming exactly one member.

    .OUTPUTS
        [int[]] Start index and length of the value text inside its quotes.
    #>
    [CmdletBinding()]
    [OutputType([int[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [object[]]$Location
    )

    if ($Location.Count -eq 0) { throw 'JSON member location must not be empty.' }
    $Description = ($Location | ForEach-Object { "$_" }) -join '.'
    $Index = 0
    while ($Index -lt $Content.Length -and [char]::IsWhiteSpace($Content[$Index])) { $Index++ }

    foreach ($Segment in $Location) {
        if ($Index -ge $Content.Length) { throw "Member location '$Description' is not present." }

        if ($Segment -is [int]) {
            if ($Content[$Index] -ne '[') { throw "Member location '$Description' expects an array at element $Segment." }
            $Index++
            for ($Element = 0; ; $Element++) {
                while ($Index -lt $Content.Length -and $Content[$Index] -match '[\s,]') { $Index++ }
                if ($Index -ge $Content.Length -or $Content[$Index] -eq ']') {
                    throw "Member location '$Description' has no element $Segment."
                }
                if ($Element -eq $Segment) { break }
                $Index = Get-JsonValueEnd -Content $Content -Start $Index
            }
            continue
        }

        if ($Content[$Index] -ne '{') { throw "Member location '$Description' expects an object at member '$Segment'." }
        $Index++
        $Found = $false
        while (-not $Found) {
            while ($Index -lt $Content.Length -and $Content[$Index] -match '[\s,]') { $Index++ }
            if ($Index -ge $Content.Length -or $Content[$Index] -ne '"') {
                throw "Member location '$Description' has no member '$Segment'."
            }
            $KeyEnd = Get-JsonValueEnd -Content $Content -Start $Index
            $Key = $Content.Substring($Index + 1, $KeyEnd - $Index - 2)
            $Index = $KeyEnd
            while ($Index -lt $Content.Length -and $Content[$Index] -match '[\s:]') { $Index++ }
            if ($Key -ceq [string]$Segment) { $Found = $true; continue }
            $Index = Get-JsonValueEnd -Content $Content -Start $Index
        }
    }

    if ($Index -ge $Content.Length -or $Content[$Index] -ne '"') {
        throw "Member location '$Description' is not a string value."
    }
    $End = Get-JsonValueEnd -Content $Content -Start $Index
    return , [int[]]@(($Index + 1), ($End - $Index - 2))
}

function Set-JsonMemberValue {
    <#
    .SYNOPSIS
        Replaces one string member value at an exact JSON location.

    .PARAMETER Content
        File content.

    .PARAMETER Location
        Ordered member names and array indices naming exactly one member.

    .PARAMETER Value
        Replacement value.

    .OUTPUTS
        [string] Updated content.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [object[]]$Location,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Value
    )

    $Span = Get-JsonMemberValueSpan -Content $Content -Location $Location
    return $Content.Substring(0, $Span[0]) + $Value + $Content.Substring($Span[0] + $Span[1])
}

function Set-RepositoryVersion {
    <#
    .SYNOPSIS
        Writes one version across the repository's version-tracked files.

    .PARAMETER RepoRoot
        Root directory of the repository.

    .PARAMETER Version
        Version string to write.

    .OUTPUTS
        [System.Collections.Specialized.OrderedDictionary[]] Per-file path and
        changed flag.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\d+\.\d+\.\d+\z')]
        [string]$Version
    )

    $Catalog = Get-PluginCatalog -RepoRoot $RepoRoot
    if ($Catalog.Violations.Count -gt 0) { throw ($Catalog.Violations -join [Environment]::NewLine) }
    $Targets = $script:VersionTarget
    $CatalogLocations = @(, @('metadata', 'version'))
    for ($i = 0; $i -lt $Catalog.Entries.Count; $i++) {
        $Targets += @{ Path = $Catalog.Entries[$i].ManifestPath; Location = @(, @('version')) }
        $CatalogLocations += , @('plugins', $i, 'version')
    }
    $Targets += @{ Path = '.github/plugin/marketplace.json'; Location = $CatalogLocations }

    $Planned = @()
    foreach ($Target in $Targets) {
        $Path = Join-Path $RepoRoot $Target.Path
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            throw "Version-tracked file not found: $($Target.Path)"
        }

        $Original = Get-Content -LiteralPath $Path -Raw
        $Updated = $Original
        foreach ($Location in $Target.Location) {
            $Updated = Set-JsonMemberValue -Content $Updated -Location $Location -Value $Version
        }

        $Json = $Updated | ConvertFrom-Json -AsHashtable
        foreach ($Location in $Target.Location) {
            $Actual = $Json
            foreach ($Segment in $Location) { $Actual = $Actual[$Segment] }
            if ($Actual -cne $Version) {
                throw "$($Target.Path) $($Location -join '.') is '$Actual' after update; expected '$Version'"
            }
        }

        $Planned += [ordered]@{
            Path     = $Target.Path
            FullPath = $Path
            Content  = $Updated
            Changed  = $Updated -ne $Original
        }
    }

    $Results = @()
    foreach ($Plan in $Planned) {
        if ($Plan.Changed) {
            Set-Content -LiteralPath $Plan.FullPath -Value $Plan.Content -Encoding UTF8 -NoNewline
        }
        $Results += [ordered]@{
            Path    = $Plan.Path
            Changed = $Plan.Changed
        }
    }

    return $Results
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $results = Set-RepositoryVersion -RepoRoot $RepoRoot -Version $Version
        foreach ($result in $results) {
            $state = if ($result.Changed) { 'updated' } else { 'already current' }
            Write-Host "  $($result.Path) $state" -ForegroundColor Green
        }
        Write-Host "Repository version set to $Version." -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Set-RepositoryVersion failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main Execution
