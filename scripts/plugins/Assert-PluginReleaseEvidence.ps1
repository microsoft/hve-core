#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Records and verifies deterministic evidence for a generated plugin snapshot.

.DESCRIPTION
    Binds four values into one invariant: the immutable source commit, the
    package version, the release locator, and a digest computed over the
    generated package tree. The digest covers repository-relative package paths
    and file content only, so it is reproducible from a clean checkout of the
    same source commit and never depends on committed generated output.

    Default mode records evidence. Supplying -ExpectedEvidencePath verifies a
    previously recorded document against freshly computed values and fails when
    the source commit, version, locator, package set, or digest disagree.

.PARAMETER RepoRoot
    Absolute path to the repository root. Defaults to the enclosing repository.

.PARAMETER PluginsDir
    Generated package tree, absolute or relative to RepoRoot. Defaults to plugins.

.PARAMETER SourceCommit
    Full 40-character commit id the snapshot was generated from. Resolved from
    git when omitted.

.PARAMETER Version
    Package version. Read from package.json when omitted.

.PARAMETER ReleaseTag
    Immutable 'plugins-v<version>' tag. Derived from Version when omitted.

.PARAMETER OutputPath
    Destination for the evidence document, absolute or relative to RepoRoot.

.PARAMETER ExpectedEvidencePath
    Previously recorded evidence document to verify against.

.PARAMETER ExpectedPackageCount
    Cutover precondition. When greater than zero, the snapshot must contain
    exactly this many packages.

.EXAMPLE
    ./Assert-PluginReleaseEvidence.ps1 -OutputPath logs/plugin-release-evidence.json

.EXAMPLE
    ./Assert-PluginReleaseEvidence.ps1 -ExpectedEvidencePath logs/plugin-release-evidence.json

.NOTES
    Runs via: npm run plugin:evidence
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$PluginsDir = 'plugins',

    [Parameter(Mandatory = $false)]
    [string]$SourceCommit,

    [Parameter(Mandatory = $false)]
    [string]$Version,

    [Parameter(Mandatory = $false)]
    [string]$ReleaseTag,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'logs/plugin-release-evidence.json',

    [Parameter(Mandatory = $false)]
    [string]$ExpectedEvidencePath,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 1000)]
    [int]$ExpectedPackageCount = 0
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/PluginHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

Set-Variable -Name PluginEvidenceSchema -Value 'hve-core/plugin-release-evidence/v1' -Option Constant -Scope Script -Force

#region Digest

function Get-PluginContentDigest {
    <#
    .SYNOPSIS
        Computes a deterministic digest over a directory tree.

    .DESCRIPTION
        Hashes an ordinal-sorted manifest of forward-slash relative paths paired
        with the SHA-256 of each file's bytes. Timestamps, permissions, sizes,
        and enumeration order are excluded so the digest reproduces across
        machines and clean checkouts.

    .PARAMETER Path
        Absolute path to the directory tree to digest.

    .OUTPUTS
        [hashtable] Report with Digest, FileCount, and TotalBytes keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $entries = [System.Collections.Generic.List[string]]::new()
    $totalBytes = [long]0
    $fileCount = 0

    if (Test-Path -LiteralPath $Path -PathType Container) {
        $rootLength = (Get-Item -LiteralPath $Path).FullName.TrimEnd([System.IO.Path]::DirectorySeparatorChar).Length + 1
        foreach ($file in Get-ChildItem -LiteralPath $Path -File -Recurse -Force) {
            $relative = $file.FullName.Substring($rootLength).Replace([System.IO.Path]::DirectorySeparatorChar, '/')
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            $contentHash = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
            $entries.Add("$relative $contentHash")
            $totalBytes += $bytes.LongLength
            $fileCount++
        }
    }

    $entries.Sort([System.StringComparer]::Ordinal)

    $manifest = if ($entries.Count -eq 0) { '' } else { ($entries -join "`n") + "`n" }
    $digest = [System.Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($manifest))
    ).ToLowerInvariant()

    return @{
        Digest     = $digest
        FileCount  = $fileCount
        TotalBytes = $totalBytes
    }
}

function Get-PluginTreeEvidence {
    <#
    .SYNOPSIS
        Digests a generated package tree and each package within it.

    .PARAMETER PluginsDir
        Absolute path to the generated package tree.

    .OUTPUTS
        [hashtable] Report with Digest, Packages, FileCount, and TotalBytes keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PluginsDir
    )

    if (-not (Test-Path -LiteralPath $PluginsDir -PathType Container)) {
        throw "Generated package tree not found: $PluginsDir"
    }

    $packages = @()
    $packageNames = [System.Collections.Generic.List[string]]::new()
    foreach ($dir in Get-ChildItem -LiteralPath $PluginsDir -Directory) {
        $packageNames.Add($dir.Name)
    }
    $packageNames.Sort([System.StringComparer]::Ordinal)

    foreach ($name in $packageNames) {
        $packageReport = Get-PluginContentDigest -Path (Join-Path -Path $PluginsDir -ChildPath $name)
        $packages += [ordered]@{
            name      = $name
            digest    = $packageReport.Digest
            fileCount = $packageReport.FileCount
        }
    }

    $treeReport = Get-PluginContentDigest -Path $PluginsDir

    return @{
        Digest     = $treeReport.Digest
        FileCount  = $treeReport.FileCount
        TotalBytes = $treeReport.TotalBytes
        Packages   = $packages
    }
}

#endregion Digest

#region Evidence

function New-PluginReleaseEvidenceDocument {
    <#
    .SYNOPSIS
        Builds the evidence document binding source, version, locator, and digest.

    .PARAMETER SourceCommit
        Full 40-character commit id the snapshot was generated from.

    .PARAMETER Version
        Package version of the snapshot.

    .PARAMETER Locator
        Release locator from New-PluginReleaseLocator.

    .PARAMETER TreeEvidence
        Report from Get-PluginTreeEvidence.

    .OUTPUTS
        [System.Collections.Specialized.OrderedDictionary] Evidence document.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceCommit,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [hashtable]$Locator,

        [Parameter(Mandatory = $true)]
        [hashtable]$TreeEvidence
    )

    if ($SourceCommit -cnotmatch '^[0-9a-f]{40}$') {
        throw "Source commit '$SourceCommit' must be a full 40-character lowercase commit id."
    }

    $expectedRef = "plugins-v$Version"
    if ($Locator.Ref -ne $expectedRef) {
        throw "Release locator '$($Locator.Ref)' does not match package version '$Version' (expected '$expectedRef')."
    }

    # generatedAt is recorded for operators and deliberately excluded from every
    # compared field, so it can never influence the deterministic invariant.
    return [ordered]@{
        schema       = $script:PluginEvidenceSchema
        sourceCommit = $SourceCommit
        version      = $Version
        locator      = [ordered]@{
            source = 'github'
            repo   = $Locator.Repo
            path   = $Locator.PathPrefix
            ref    = $Locator.Ref
        }
        packageCount = @($TreeEvidence.Packages).Count
        packages     = @($TreeEvidence.Packages)
        fileCount    = $TreeEvidence.FileCount
        totalBytes   = $TreeEvidence.TotalBytes
        digest       = $TreeEvidence.Digest
        generatedAt  = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function Compare-PluginReleaseEvidence {
    <#
    .SYNOPSIS
        Compares recorded evidence against freshly computed evidence.

    .DESCRIPTION
        Reports every disagreement across schema, source commit, version,
        locator, package set, and digest. Incidental metadata is not compared.

    .PARAMETER Expected
        Previously recorded evidence document.

    .PARAMETER Actual
        Freshly computed evidence document.

    .OUTPUTS
        [string[]] Disagreement messages, empty when the invariant holds.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Expected,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Actual
    )

    $differences = @()

    foreach ($field in @('schema', 'sourceCommit', 'version', 'digest')) {
        if ($null -eq $Expected[$field]) {
            $differences += "recorded evidence is missing required field '$field'"
            continue
        }

        if ([string]$Expected[$field] -cne [string]$Actual[$field]) {
            $differences += "$field disagreement: recorded '$($Expected[$field])', actual '$($Actual[$field])'"
        }
    }

    $expectedLocator = $Expected['locator']
    if ($expectedLocator -isnot [System.Collections.IDictionary]) {
        $differences += "recorded evidence is missing required field 'locator'"
    }
    else {
        foreach ($field in @('source', 'repo', 'path', 'ref')) {
            if ([string]$expectedLocator[$field] -cne [string]$Actual['locator'][$field]) {
                $differences += "locator.$field disagreement: recorded '$($expectedLocator[$field])', actual '$($Actual['locator'][$field])'"
            }
        }
    }

    $expectedPackages = @($Expected['packages'])
    $actualPackages = @($Actual['packages'])

    $expectedNames = @($expectedPackages | ForEach-Object { [string]$_['name'] })
    $actualNames = @($actualPackages | ForEach-Object { [string]$_['name'] })

    foreach ($missing in ($actualNames | Where-Object { $expectedNames -notcontains $_ })) {
        $differences += "package '$missing' is present in the snapshot but absent from recorded evidence"
    }

    foreach ($extra in ($expectedNames | Where-Object { $actualNames -notcontains $_ })) {
        $differences += "package '$extra' is recorded in evidence but absent from the snapshot"
    }

    foreach ($expectedPackage in $expectedPackages) {
        $name = [string]$expectedPackage['name']
        $actualPackage = @($actualPackages | Where-Object { [string]$_['name'] -eq $name })[0]
        if ($null -ne $actualPackage -and [string]$expectedPackage['digest'] -cne [string]$actualPackage['digest']) {
            $differences += "package '$name' digest disagreement: recorded '$($expectedPackage['digest'])', actual '$($actualPackage['digest'])'"
        }
    }

    return [string[]]$differences
}

#endregion Evidence

#region Orchestration

function Invoke-PluginReleaseEvidence {
    <#
    .SYNOPSIS
        Records or verifies deterministic plugin release evidence.

    .PARAMETER RepoRoot
        Absolute path to the repository root directory.

    .PARAMETER PluginsDir
        Generated package tree, absolute or relative to RepoRoot.

    .PARAMETER SourceCommit
        Full commit id. Resolved from git when omitted.

    .PARAMETER Version
        Package version. Read from package.json when omitted.

    .PARAMETER ReleaseTag
        Immutable release tag. Derived from the version when omitted.

    .PARAMETER OutputPath
        Destination for the evidence document.

    .PARAMETER ExpectedEvidencePath
        Recorded evidence document to verify against.

    .PARAMETER ExpectedPackageCount
        Cutover precondition on the number of packages in the snapshot.

    .OUTPUTS
        [hashtable] Report with Success, ErrorCount, Errors, and Evidence keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$PluginsDir = 'plugins',

        [Parameter(Mandatory = $false)]
        [string]$SourceCommit,

        [Parameter(Mandatory = $false)]
        [string]$Version,

        [Parameter(Mandatory = $false)]
        [string]$ReleaseTag,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [string]$ExpectedEvidencePath,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 1000)]
        [int]$ExpectedPackageCount = 0
    )

    $resolvedPluginsDir = if ([System.IO.Path]::IsPathRooted($PluginsDir)) {
        $PluginsDir
    }
    else {
        Join-Path -Path $RepoRoot -ChildPath $PluginsDir
    }

    if ([string]::IsNullOrWhiteSpace($Version)) {
        $packageJsonPath = Join-Path -Path $RepoRoot -ChildPath 'package.json'
        if (-not (Test-Path -LiteralPath $packageJsonPath)) {
            throw "package.json not found at $packageJsonPath."
        }
        $Version = (Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json).version
    }

    if ([string]::IsNullOrWhiteSpace($SourceCommit)) {
        $SourceCommit = (git -C $RepoRoot rev-parse HEAD 2>$null)
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($SourceCommit)) {
            throw 'Source commit could not be resolved from git. Pass -SourceCommit explicitly.'
        }
        $SourceCommit = $SourceCommit.Trim()
    }

    $locator = if ([string]::IsNullOrWhiteSpace($ReleaseTag)) {
        New-PluginReleaseLocator -Version $Version
    }
    else {
        New-PluginReleaseLocator -Tag $ReleaseTag
    }

    $treeEvidence = Get-PluginTreeEvidence -PluginsDir $resolvedPluginsDir
    $evidence = New-PluginReleaseEvidenceDocument `
        -SourceCommit $SourceCommit `
        -Version $Version `
        -Locator $locator `
        -TreeEvidence $treeEvidence

    Write-Host 'Plugin release evidence' -ForegroundColor Cyan
    Write-Host "  Source commit: $($evidence.sourceCommit)"
    Write-Host "  Version:       $($evidence.version)"
    Write-Host "  Locator:       $($evidence.locator.repo)@$($evidence.locator.ref) ($($evidence.locator.path))"
    Write-Host "  Packages:      $($evidence.packageCount)"
    Write-Host ("  Size:          {0:N1} MB in {1} files" -f ($evidence.totalBytes / 1MB), $evidence.fileCount)
    Write-Host "  Digest:        $($evidence.digest)"

    $errors = @()

    if ($ExpectedPackageCount -gt 0 -and $evidence.packageCount -ne $ExpectedPackageCount) {
        $errors += "package count precondition failed: expected $ExpectedPackageCount, snapshot has $($evidence.packageCount)"
    }

    if (-not [string]::IsNullOrWhiteSpace($ExpectedEvidencePath)) {
        $resolvedExpectedPath = if ([System.IO.Path]::IsPathRooted($ExpectedEvidencePath)) {
            $ExpectedEvidencePath
        }
        else {
            Join-Path -Path $RepoRoot -ChildPath $ExpectedEvidencePath
        }

        if (-not (Test-Path -LiteralPath $resolvedExpectedPath -PathType Leaf)) {
            $errors += "recorded evidence not found: $ExpectedEvidencePath"
        }
        else {
            $expected = $null
            try {
                $expected = Get-Content -LiteralPath $resolvedExpectedPath -Raw | ConvertFrom-Json -AsHashtable
            }
            catch {
                $errors += "recorded evidence is not valid JSON: $($_.Exception.Message)"
            }

            if ($expected -isnot [System.Collections.IDictionary]) {
                if ($errors.Count -eq 0) {
                    $errors += 'recorded evidence is not an evidence document'
                }
            }
            else {
                $errors += @(Compare-PluginReleaseEvidence -Expected $expected -Actual $evidence)
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
            $OutputPath
        }
        else {
            Join-Path -Path $RepoRoot -ChildPath $OutputPath
        }

        $outputDir = Split-Path -Path $resolvedOutputPath -Parent
        if (-not [string]::IsNullOrWhiteSpace($outputDir) -and -not (Test-Path -LiteralPath $outputDir -PathType Container)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        $evidence | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8
        Write-Host "  Evidence:      $resolvedOutputPath"
    }

    foreach ($validationError in $errors) {
        Write-Host "    x $validationError" -ForegroundColor Red
    }

    return @{
        Success    = ($errors.Count -eq 0)
        ErrorCount = $errors.Count
        Errors     = @($errors)
        Evidence   = $evidence
    }
}

#endregion Orchestration

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        $resolvedRepoRoot = if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
            (Get-Item "$ScriptDir/../..").FullName
        }
        else {
            $RepoRoot
        }

        $result = Invoke-PluginReleaseEvidence `
            -RepoRoot $resolvedRepoRoot `
            -PluginsDir $PluginsDir `
            -SourceCommit $SourceCommit `
            -Version $Version `
            -ReleaseTag $ReleaseTag `
            -OutputPath $OutputPath `
            -ExpectedEvidencePath $ExpectedEvidencePath `
            -ExpectedPackageCount $ExpectedPackageCount

        if (-not $result.Success) {
            throw "Plugin release evidence disagreement: $($result.ErrorCount) finding(s)."
        }

        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Plugin release evidence failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
#endregion
