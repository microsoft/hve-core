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
    - .github/plugin.json $.version
    - .github/plugin/marketplace.json $.metadata.version and the sole
      $.plugins[0].version

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

# Each target names the exact members that carry the repository version. Every
# pattern is structurally anchored and must match once, so a shape change fails
# loudly instead of rewriting an unintended member.
$script:VersionTarget = @(
    [ordered]@{
        Path    = 'package.json'
        Pattern = @('(?s)\A\{.*?"version":\s*"(?<value>[^"]*)"')
        Assert  = @('$.version')
    }
    [ordered]@{
        Path    = 'package-lock.json'
        Pattern = @(
            '(?s)\A\{.*?"version":\s*"(?<value>[^"]*)"',
            '(?s)"packages":\s*\{\s*"":\s*\{.*?"version":\s*"(?<value>[^"]*)"'
        )
        Assert  = @('$.version', '$.packages[""].version')
    }
    [ordered]@{
        Path    = 'extension/templates/package.template.json'
        Pattern = @('(?s)\A\{.*?"version":\s*"(?<value>[^"]*)"')
        Assert  = @('$.version')
    }
    [ordered]@{
        Path    = '.github/plugin.json'
        Pattern = @('(?s)\A\{.*?"version":\s*"(?<value>[^"]*)"')
        Assert  = @('$.version')
    }
    [ordered]@{
        Path    = '.github/plugin/marketplace.json'
        Pattern = @(
            '(?s)"metadata":\s*\{.*?"version":\s*"(?<value>[^"]*)"',
            '(?s)"plugins":\s*\[\s*\{.*?"version":\s*"(?<value>[^"]*)"'
        )
        Assert  = @('$.metadata.version', '$.plugins[0].version')
    }
)

#region Functions

function Set-JsonMemberValue {
    <#
    .SYNOPSIS
        Replaces one JSON member value identified by a structural pattern.

    .PARAMETER Content
        File content.

    .PARAMETER Pattern
        Regular expression with a 'value' capture group. It must match once.

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
        [ValidateNotNullOrEmpty()]
        [string]$Pattern,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Value
    )

    $matched = [regex]::Matches($Content, $Pattern)
    if ($matched.Count -ne 1) {
        throw "Pattern matched $($matched.Count) members; exactly one is required: $Pattern"
    }

    $group = $matched[0].Groups['value']
    return $Content.Substring(0, $group.Index) + $Value + $Content.Substring($group.Index + $group.Length)
}

function Get-JsonMemberValue {
    <#
    .SYNOPSIS
        Reads one of the supported version members from parsed JSON.

    .PARAMETER Json
        Parsed JSON content read as a hashtable.

    .PARAMETER Path
        Supported member expression.

    .OUTPUTS
        [string] Member value.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Json,

        [Parameter(Mandatory = $true)]
        [ValidateSet('$.version', '$.packages[""].version', '$.metadata.version', '$.plugins[0].version')]
        [string]$Path
    )

    switch ($Path) {
        '$.version' { return [string]$Json['version'] }
        '$.packages[""].version' { return [string]$Json['packages']['']['version'] }
        '$.metadata.version' { return [string]$Json['metadata']['version'] }
        '$.plugins[0].version' { return [string]@($Json['plugins'])[0]['version'] }
    }
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

    $results = @()

    foreach ($target in $script:VersionTarget) {
        $path = Join-Path $RepoRoot $target.Path
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Version-tracked file not found: $($target.Path)"
        }

        $original = Get-Content -LiteralPath $path -Raw
        $updated = $original
        foreach ($pattern in $target.Pattern) {
            $updated = Set-JsonMemberValue -Content $updated -Pattern $pattern -Value $Version
        }

        if ($updated -ne $original) {
            Set-Content -LiteralPath $path -Value $updated -Encoding UTF8 -NoNewline
        }

        $json = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
        foreach ($assertion in $target.Assert) {
            $actual = Get-JsonMemberValue -Json $json -Path $assertion
            if ($actual -ne $Version) {
                throw "$($target.Path) $assertion is '$actual' after update; expected '$Version'"
            }
        }

        $results += [ordered]@{
            Path    = $target.Path
            Changed = $updated -ne $original
        }
    }

    return $results
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
