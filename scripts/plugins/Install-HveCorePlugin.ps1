#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Installs HVE Core from an exact Git commit through a local Copilot marketplace.
.DESCRIPTION
    Fetches an exact 40-character commit from microsoft/hve-core into a durable,
    SHA-specific checkout, verifies the source and plugin metadata, generates a
    contained local marketplace, and installs the qualified HVE Core plugin.

    The script never follows a moving branch or tag and never removes or replaces
    an existing marketplace or plugin. Use -WhatIf to inspect prerequisites and
    an existing pin without creating files, mutating Git state, or invoking
    Copilot marketplace and plugin changes.
.PARAMETER CommitSha
    Full 40-character Git commit SHA to install. Defaults to the reviewed HVE
    Core commit selected for this installer.
.PARAMETER InstallRoot
    Absolute local filesystem directory that stores immutable plugin pins.
    Defaults to $HOME/.hve-core/copilot-plugin-pins.
.EXAMPLE
    ./Install-HveCorePlugin.ps1
.EXAMPLE
    ./Install-HveCorePlugin.ps1 -CommitSha 0c14eea959a5ff355871205acf14807c7fa7d4a7 -WhatIf
.NOTES
    Requires PowerShell 7.4, Git, network access to GitHub, and an authenticated
    GitHub Copilot CLI. The same script supports Windows and macOS.
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$CommitSha = '0c14eea959a5ff355871205acf14807c7fa7d4a7',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$InstallRoot = (Join-Path $HOME '.hve-core/copilot-plugin-pins')
)

$ErrorActionPreference = 'Stop'

$script:HveCoreRepositoryUrl = 'https://github.com/microsoft/hve-core.git'
$script:HveCorePluginName = 'hve-core'
$script:SourceDirectoryName = 'source'
$script:MarketplaceFileName = 'marketplace.json'
$script:SourceMarketplacePath = '.github/plugin/marketplace.json'
$script:RequiredSourceFile = @('plugin.json', 'README.md', 'LICENSE', $script:SourceMarketplacePath)
$script:PluginMetadataField = @('description', 'version', 'author', 'homepage', 'repository', 'license', 'keywords')

#region Input and path handling

function ConvertTo-NormalizedCommitSha {
    <#
    .SYNOPSIS
        Validates and normalizes a full Git commit SHA.
    .PARAMETER Value
        Candidate commit SHA.
    .OUTPUTS
        [string] Lowercase 40-character commit SHA.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Value
    )

    if ($Value -cnotmatch '^[0-9A-Fa-f]{40}$') {
        throw 'CommitSha must be a full 40-character hexadecimal Git object ID.'
    }

    return $Value.ToLowerInvariant()
}

function Resolve-LocalInstallRoot {
    <#
    .SYNOPSIS
        Resolves an absolute local filesystem installation root.
    .PARAMETER Path
        PowerShell path supplied by the caller.
    .OUTPUTS
        [string] Absolute filesystem path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $DriveName = $null
    if (-not $ExecutionContext.SessionState.Path.IsPSAbsolute($Path, [ref]$DriveName)) {
        throw "InstallRoot must be an absolute local filesystem path: $Path"
    }

    $Drive = if ([string]::IsNullOrWhiteSpace($DriveName)) {
        Get-PSDrive -PSProvider FileSystem | Select-Object -First 1
    }
    else {
        Get-PSDrive -Name $DriveName -ErrorAction SilentlyContinue
    }
    if ($null -eq $Drive -or $Drive.Provider.Name -ne 'FileSystem') {
        throw "InstallRoot must use the FileSystem provider: $Path"
    }

    $Resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    return [System.IO.Path]::GetFullPath($Resolved)
}

function Get-RequiredApplication {
    <#
    .SYNOPSIS
        Resolves an external application from PATH.
    .PARAMETER Name
        Command name to discover.
    .OUTPUTS
        [string] Resolved application path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $Command = Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -eq $Command) {
        throw "Required application '$Name' was not found on PATH."
    }

    return $Command.Path
}

function Get-PinnedMarketplaceName {
    <#
    .SYNOPSIS
        Builds the deterministic marketplace name for a commit.
    .PARAMETER CommitSha
        Normalized full commit SHA.
    .OUTPUTS
        [string] SHA-specific marketplace name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-f]{40}$')]
        [string]$CommitSha
    )

    return "$script:HveCorePluginName-$CommitSha"
}

function Resolve-CanonicalPath {
    <#
    .SYNOPSIS
        Resolves links in every segment of an existing filesystem path.
    .PARAMETER Path
        Existing path to resolve.
    .OUTPUTS
        [string] Canonical absolute path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $FullPath = [System.IO.Path]::GetFullPath($Path)
    $PathRoot = [System.IO.Path]::GetPathRoot($FullPath)
    $Current = $PathRoot
    $Relative = $FullPath.Substring($PathRoot.Length)
    foreach ($Segment in $Relative.Split(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.StringSplitOptions]::RemoveEmptyEntries
        )) {
        $Current = Join-Path $Current $Segment
        $Item = Get-Item -LiteralPath $Current -Force
        if ($Item.LinkType) {
            $ResolvedTarget = $Item.ResolveLinkTarget($true)
            if ($null -eq $ResolvedTarget) {
                throw "Filesystem link cannot be resolved: $Current"
            }
            $Current = $ResolvedTarget.FullName
        }
    }

    return [System.IO.Path]::GetFullPath($Current)
}

function Test-ContainedPath {
    <#
    .SYNOPSIS
        Indicates whether an existing path resolves within an existing root.
    .PARAMETER Root
        Existing containment root.
    .PARAMETER Candidate
        Existing path expected beneath the root.
    .OUTPUTS
        [bool] True when the canonical candidate is contained by the root.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Candidate
    )

    $ResolvedRoot = (Resolve-CanonicalPath -Path $Root).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $ResolvedCandidate = Resolve-CanonicalPath -Path $Candidate
    $Comparison = if ($IsWindows) {
        [System.StringComparison]::OrdinalIgnoreCase
    }
    else {
        [System.StringComparison]::Ordinal
    }
    $Prefix = $ResolvedRoot + [System.IO.Path]::DirectorySeparatorChar

    return $ResolvedCandidate.Equals($ResolvedRoot, $Comparison) -or
        $ResolvedCandidate.StartsWith($Prefix, $Comparison)
}

function Get-RequiredRegularFile {
    <#
    .SYNOPSIS
        Returns a required nonempty regular file and rejects links.
    .PARAMETER Path
        Required file path.
    .OUTPUTS
        [System.IO.FileInfo] Validated file.
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required plugin file is missing or not a regular file: $Path"
    }

    $Item = Get-Item -LiteralPath $Path -Force
    if ($Item.LinkType -or $Item.Length -eq 0) {
        throw "Required plugin file must be nonempty and must not be a link: $Path"
    }

    return $Item
}

#endregion Input and path handling

#region External applications

function Invoke-ExternalApplication {
    <#
    .SYNOPSIS
        Invokes one external application with a discrete argument array.
    .PARAMETER FilePath
        Resolved application path.
    .PARAMETER ArgumentList
        Arguments passed directly to the application.
    .OUTPUTS
        [System.Collections.Specialized.OrderedDictionary] Exit code and output.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$ArgumentList = @()
    )

    $Output = @(& $FilePath @ArgumentList 2>&1)
    return [ordered]@{
        ExitCode = $LASTEXITCODE
        Output   = @($Output | ForEach-Object { $_.ToString() })
    }
}

function Invoke-CheckedApplication {
    <#
    .SYNOPSIS
        Invokes an external application and requires a zero exit code.
    .PARAMETER FilePath
        Resolved application path.
    .PARAMETER ArgumentList
        Arguments passed directly to the application.
    .PARAMETER Operation
        Safe operation label used in error messages.
    .OUTPUTS
        [string[]] Application output lines.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$ArgumentList = @(),

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Operation
    )

    $Result = Invoke-ExternalApplication -FilePath $FilePath -ArgumentList $ArgumentList
    if ($Result.ExitCode -ne 0) {
        $Detail = @($Result.Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Last 1)
        $Suffix = if ($Detail.Count -gt 0) { " $($Detail[0])" } else { '' }
        throw "$Operation failed with exit code $($Result.ExitCode).$Suffix"
    }

    return @($Result.Output)
}

#endregion External applications

#region Source and marketplace validation

function ConvertTo-DeterministicJson {
    <#
    .SYNOPSIS
        Serializes an object as newline-normalized JSON.
    .PARAMETER InputObject
        Object to serialize.
    .OUTPUTS
        [string] JSON with LF endings and one trailing newline.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$InputObject
    )

    $Json = ($InputObject | ConvertTo-Json -Depth 10) -replace "`r`n", "`n"
    return $Json.TrimEnd("`n") + "`n"
}

function New-PinnedMarketplaceContent {
    <#
    .SYNOPSIS
        Validates plugin metadata and builds the SHA-specific marketplace JSON.
    .PARAMETER SourceRoot
        Exact HVE Core checkout root.
    .PARAMETER CommitSha
        Normalized full commit SHA.
    .OUTPUTS
        [string] Deterministic marketplace JSON.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceRoot,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-f]{40}$')]
        [string]$CommitSha
    )

    foreach ($RelativePath in $script:RequiredSourceFile) {
        $File = Get-RequiredRegularFile -Path (Join-Path $SourceRoot $RelativePath)
        if (-not (Test-ContainedPath -Root $SourceRoot -Candidate $File.FullName)) {
            throw "Required plugin file resolves outside the source root: $RelativePath"
        }
    }

    try {
        $Manifest = Get-Content -LiteralPath (Join-Path $SourceRoot 'plugin.json') -Raw |
            ConvertFrom-Json -AsHashtable
        $Catalog = Get-Content -LiteralPath (Join-Path $SourceRoot $script:SourceMarketplacePath) -Raw |
            ConvertFrom-Json -AsHashtable
    }
    catch {
        throw "Pinned plugin metadata is not valid JSON: $($_.Exception.Message)"
    }

    if ($Manifest['name'] -cne $script:HveCorePluginName) {
        throw "Pinned plugin manifest name must be '$script:HveCorePluginName'."
    }

    $Entries = @($Catalog['plugins'])
    if ($Entries.Count -ne 1) {
        throw 'Pinned marketplace must contain exactly one plugin entry.'
    }
    $SourceEntry = $Entries[0]
    if ($SourceEntry['name'] -cne $script:HveCorePluginName -or $SourceEntry['source'] -cne '.') {
        throw "Pinned marketplace must locate '$script:HveCorePluginName' at canonical source '.'."
    }
    if ([string]::IsNullOrWhiteSpace($Manifest['version']) -or
        $SourceEntry['version'] -cne $Manifest['version'] -or
        $Catalog['metadata']['version'] -cne $Manifest['version']) {
        throw 'Pinned plugin and marketplace versions must agree.'
    }

    foreach ($Field in $script:PluginMetadataField) {
        $ManifestHasField = $Manifest.ContainsKey($Field)
        $EntryHasField = $SourceEntry.ContainsKey($Field)
        if ($ManifestHasField -ne $EntryHasField) {
            throw "Pinned marketplace field '$Field' presence must match plugin.json."
        }
        if ($ManifestHasField) {
            $ManifestValue = ConvertTo-Json $Manifest[$Field] -Depth 10 -Compress
            $EntryValue = ConvertTo-Json $SourceEntry[$Field] -Depth 10 -Compress
            if ($ManifestValue -cne $EntryValue) {
                throw "Pinned marketplace field '$Field' must match plugin.json."
            }
        }
    }

    $MarketplaceName = Get-PinnedMarketplaceName -CommitSha $CommitSha
    $GeneratedEntry = [ordered]@{
        name   = $script:HveCorePluginName
        source = './source'
    }
    foreach ($Field in $script:PluginMetadataField) {
        if ($SourceEntry.ContainsKey($Field)) {
            $GeneratedEntry[$Field] = $SourceEntry[$Field]
        }
    }

    $GeneratedCatalog = [ordered]@{
        name     = $MarketplaceName
        metadata = [ordered]@{
            description = "HVE Core pinned to commit $CommitSha"
            version     = $Manifest['version']
        }
        owner    = [ordered]@{ name = 'Microsoft' }
        plugins  = @($GeneratedEntry)
    }

    return ConvertTo-DeterministicJson -InputObject $GeneratedCatalog
}

function Test-PinnedCheckout {
    <#
    .SYNOPSIS
        Validates the Git and filesystem identity of an exact checkout.
    .PARAMETER GitPath
        Resolved Git application path.
    .PARAMETER PinRoot
        Pin root containing the source directory.
    .PARAMETER CommitSha
        Normalized expected commit SHA.
    .OUTPUTS
        [bool] True when every checkout invariant passes.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$GitPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PinRoot,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-f]{40}$')]
        [string]$CommitSha
    )

    $PinItem = Get-Item -LiteralPath $PinRoot -Force
    if (-not $PinItem.PSIsContainer -or $PinItem.LinkType) {
        throw "Pin root must be a regular directory and must not be a link: $PinRoot"
    }

    $SourceRoot = Join-Path $PinRoot $script:SourceDirectoryName
    $SourceItem = Get-Item -LiteralPath $SourceRoot -Force -ErrorAction SilentlyContinue
    if ($null -eq $SourceItem -or -not $SourceItem.PSIsContainer -or $SourceItem.LinkType -or
        -not (Test-ContainedPath -Root $PinRoot -Candidate $SourceRoot)) {
        throw "Pinned source must be a regular directory inside the pin root: $SourceRoot"
    }

    $Inside = Invoke-CheckedApplication -FilePath $GitPath `
        -ArgumentList @('-C', $SourceRoot, 'rev-parse', '--is-inside-work-tree') `
        -Operation 'Git worktree validation'
    if (($Inside -join '').Trim() -cne 'true') {
        throw 'Pinned source is not a Git worktree.'
    }

    $Bare = Invoke-CheckedApplication -FilePath $GitPath `
        -ArgumentList @('-C', $SourceRoot, 'rev-parse', '--is-bare-repository') `
        -Operation 'Git bare-repository validation'
    if (($Bare -join '').Trim() -cne 'false') {
        throw 'Pinned source must not be a bare repository.'
    }

    $Origin = Invoke-CheckedApplication -FilePath $GitPath `
        -ArgumentList @('-C', $SourceRoot, 'remote', 'get-url', 'origin') `
        -Operation 'Git origin validation'
    if (($Origin -join '').Trim() -cne $script:HveCoreRepositoryUrl) {
        throw "Pinned source origin must be $script:HveCoreRepositoryUrl."
    }

    $ObjectType = Invoke-CheckedApplication -FilePath $GitPath `
        -ArgumentList @('-C', $SourceRoot, 'cat-file', '-t', $CommitSha) `
        -Operation 'Git object validation'
    if (($ObjectType -join '').Trim() -cne 'commit') {
        throw "Pinned object is not a commit: $CommitSha"
    }

    $Head = Invoke-CheckedApplication -FilePath $GitPath `
        -ArgumentList @('-C', $SourceRoot, 'rev-parse', 'HEAD') `
        -Operation 'Git HEAD validation'
    if (($Head -join '').Trim().ToLowerInvariant() -cne $CommitSha) {
        throw "Pinned HEAD does not match requested commit $CommitSha."
    }

    $Branch = Invoke-CheckedApplication -FilePath $GitPath `
        -ArgumentList @('-C', $SourceRoot, 'branch', '--show-current') `
        -Operation 'Git detached-HEAD validation'
    if (-not [string]::IsNullOrWhiteSpace(($Branch -join '').Trim())) {
        throw 'Pinned source must use a detached HEAD.'
    }

    $Status = Invoke-CheckedApplication -FilePath $GitPath `
        -ArgumentList @('-C', $SourceRoot, '-c', 'core.longpaths=true', 'status', '--porcelain=v1', '--untracked-files=all') `
        -Operation 'Git worktree cleanliness validation'
    if (-not [string]::IsNullOrWhiteSpace(($Status -join '').Trim())) {
        $DirtyPath = @($Status | Select-Object -First 5) -join ', '
        throw "Pinned source worktree must be clean, including untracked files: $DirtyPath"
    }

    $Index = Invoke-CheckedApplication -FilePath $GitPath `
        -ArgumentList @('-C', $SourceRoot, 'ls-files', '-s') `
        -Operation 'Git link validation'
    if (@($Index | Where-Object { $_ -match '^120000 ' }).Count -gt 0) {
        throw 'Pinned source must not contain tracked symbolic links.'
    }

    return $true
}

function Test-PinnedMarketplaceRoot {
    <#
    .SYNOPSIS
        Validates an immutable pin and its deterministic marketplace wrapper.
    .PARAMETER GitPath
        Resolved Git application path.
    .PARAMETER PinRoot
        Existing final or staging pin root.
    .PARAMETER CommitSha
        Normalized expected commit SHA.
    .OUTPUTS
        [bool] True when checkout and wrapper invariants pass.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$GitPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PinRoot,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-f]{40}$')]
        [string]$CommitSha
    )

    [void](Test-PinnedCheckout -GitPath $GitPath -PinRoot $PinRoot -CommitSha $CommitSha)
    $SourceRoot = Join-Path $PinRoot $script:SourceDirectoryName
    $Expected = New-PinnedMarketplaceContent -SourceRoot $SourceRoot -CommitSha $CommitSha
    $MarketplacePath = Join-Path $PinRoot $script:MarketplaceFileName
    $MarketplaceFile = Get-RequiredRegularFile -Path $MarketplacePath
    if (-not (Test-ContainedPath -Root $PinRoot -Candidate $MarketplaceFile.FullName)) {
        throw 'Generated marketplace resolves outside the pin root.'
    }

    $Actual = (Get-Content -LiteralPath $MarketplacePath -Raw) -replace "`r`n", "`n"
    if ($Actual -cne $Expected) {
        throw 'Existing pinned marketplace content does not match the verified source.'
    }

    return $true
}

#endregion Source and marketplace validation

#region Acquisition and installation

function New-PinnedCheckout {
    <#
    .SYNOPSIS
        Acquires and atomically publishes one exact HVE Core pin.
    .PARAMETER GitPath
        Resolved Git application path.
    .PARAMETER InstallRoot
        Absolute installation root.
    .PARAMETER CommitSha
        Normalized expected commit SHA.
    .OUTPUTS
        [string] Final pin root.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$GitPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$InstallRoot,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-f]{40}$')]
        [string]$CommitSha
    )

    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
    $StagingRoot = Join-Path $InstallRoot ".staging-$CommitSha-$([guid]::NewGuid().ToString('N'))"
    $SourceRoot = Join-Path $StagingRoot $script:SourceDirectoryName
    $FinalRoot = Join-Path $InstallRoot $CommitSha
    $Promoted = $false

    try {
        New-Item -ItemType Directory -Path $SourceRoot -Force | Out-Null
        [void](Invoke-CheckedApplication -FilePath $GitPath -ArgumentList @('init', $SourceRoot) -Operation 'Git initialization')
        [void](Invoke-CheckedApplication -FilePath $GitPath -ArgumentList @('-C', $SourceRoot, 'remote', 'add', 'origin', $script:HveCoreRepositoryUrl) -Operation 'Git origin configuration')
        [void](Invoke-CheckedApplication -FilePath $GitPath -ArgumentList @('-C', $SourceRoot, 'fetch', '--depth', '1', 'origin', $CommitSha) -Operation 'Exact commit fetch')

        $Fetched = Invoke-CheckedApplication -FilePath $GitPath `
            -ArgumentList @('-C', $SourceRoot, 'rev-parse', 'FETCH_HEAD') `
            -Operation 'Fetched commit validation'
        if (($Fetched -join '').Trim().ToLowerInvariant() -cne $CommitSha) {
            throw "Fetched object does not match requested commit $CommitSha."
        }

        [void](Invoke-CheckedApplication -FilePath $GitPath `
            -ArgumentList @('-C', $SourceRoot, '-c', 'core.longpaths=true', 'checkout', '--detach', 'FETCH_HEAD') `
            -Operation 'Detached checkout')
        $MarketplaceContent = New-PinnedMarketplaceContent -SourceRoot $SourceRoot -CommitSha $CommitSha
        Set-Content -LiteralPath (Join-Path $StagingRoot $script:MarketplaceFileName) `
            -Value $MarketplaceContent -Encoding UTF8 -NoNewline
        [void](Test-PinnedMarketplaceRoot -GitPath $GitPath -PinRoot $StagingRoot -CommitSha $CommitSha)

        if (Test-Path -LiteralPath $FinalRoot) {
            throw "Final pin path appeared during acquisition and was not replaced: $FinalRoot"
        }
        Move-Item -LiteralPath $StagingRoot -Destination $FinalRoot
        $Promoted = $true
        [void](Test-PinnedMarketplaceRoot -GitPath $GitPath -PinRoot $FinalRoot -CommitSha $CommitSha)
        return $FinalRoot
    }
    catch {
        if (Test-Path -LiteralPath $StagingRoot) {
            Remove-Item -LiteralPath $StagingRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        if ($Promoted -and (Test-Path -LiteralPath $FinalRoot)) {
            Remove-Item -LiteralPath $FinalRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

function Invoke-HveCorePluginInstall {
    <#
    .SYNOPSIS
        Acquires, registers, and installs an exact HVE Core plugin commit.
    .PARAMETER CommitSha
        Full commit SHA to install.
    .PARAMETER InstallRoot
        Absolute durable installation root.
    .OUTPUTS
        [System.Collections.Specialized.OrderedDictionary] Installation result.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CommitSha,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$InstallRoot
    )

    $NormalizedSha = ConvertTo-NormalizedCommitSha -Value $CommitSha
    $ResolvedInstallRoot = Resolve-LocalInstallRoot -Path $InstallRoot
    $GitPath = Get-RequiredApplication -Name 'git'
    $CopilotPath = Get-RequiredApplication -Name 'copilot'
    $PinRoot = Join-Path $ResolvedInstallRoot $NormalizedSha
    $MarketplaceName = Get-PinnedMarketplaceName -CommitSha $NormalizedSha
    $QualifiedPlugin = "$script:HveCorePluginName@$MarketplaceName"
    $PinExists = Test-Path -LiteralPath $PinRoot
    $PlannedActions = [System.Collections.Generic.List[string]]::new()
    if (-not $PinExists) {
        $PlannedActions.Add("Acquire and verify HVE Core commit $NormalizedSha in a staging directory")
        $PlannedActions.Add("Publish the verified pin at $PinRoot")
    }
    $PlannedActions.Add("Register local marketplace $MarketplaceName at $PinRoot")
    $PlannedActions.Add("Install qualified plugin $QualifiedPlugin")

    if ($PinExists) {
        [void](Test-PinnedMarketplaceRoot -GitPath $GitPath -PinRoot $PinRoot -CommitSha $NormalizedSha)
    }
    elseif (-not $PSCmdlet.ShouldProcess($PinRoot, "Acquire and verify HVE Core commit $NormalizedSha")) {
        return [ordered]@{
            Status              = 'Planned'
            CommitSha           = $NormalizedSha
            PinRoot             = $PinRoot
            Marketplace         = $MarketplaceName
            Plugin              = $QualifiedPlugin
            VerificationPending = $true
            WhatIf              = [bool]$WhatIfPreference
            PlannedActions      = @($PlannedActions)
        }
    }
    else {
        $PinRoot = New-PinnedCheckout -GitPath $GitPath -InstallRoot $ResolvedInstallRoot -CommitSha $NormalizedSha
    }

    if (-not $PSCmdlet.ShouldProcess($MarketplaceName, "Register local marketplace at $PinRoot")) {
        return [ordered]@{
            Status              = 'Planned'
            CommitSha           = $NormalizedSha
            PinRoot             = $PinRoot
            Marketplace         = $MarketplaceName
            Plugin              = $QualifiedPlugin
            VerificationPending = $false
            WhatIf              = [bool]$WhatIfPreference
            PlannedActions      = @($PlannedActions)
        }
    }

    $AddResult = Invoke-ExternalApplication -FilePath $CopilotPath `
        -ArgumentList @('plugin', 'marketplace', 'add', $PinRoot)
    if ($AddResult.ExitCode -ne 0) {
        throw "Copilot marketplace registration failed with exit code $($AddResult.ExitCode). The SHA-specific marketplace may already exist. Inspect it before removing or replacing anything: $MarketplaceName"
    }

    if (-not $PSCmdlet.ShouldProcess($QualifiedPlugin, 'Install qualified HVE Core plugin')) {
        return [ordered]@{
            Status              = 'MarketplaceRegistered'
            CommitSha           = $NormalizedSha
            PinRoot             = $PinRoot
            Marketplace         = $MarketplaceName
            Plugin              = $QualifiedPlugin
            VerificationPending = $false
            WhatIf              = [bool]$WhatIfPreference
            PlannedActions      = @($PlannedActions)
        }
    }

    $InstallResult = Invoke-ExternalApplication -FilePath $CopilotPath `
        -ArgumentList @('plugin', 'install', $QualifiedPlugin)
    if ($InstallResult.ExitCode -ne 0) {
        throw "Copilot plugin installation failed with exit code $($InstallResult.ExitCode). The verified marketplace remains registered. Retry explicitly with: copilot plugin install $QualifiedPlugin"
    }

    return [ordered]@{
        Status              = 'Installed'
        CommitSha           = $NormalizedSha
        PinRoot             = $PinRoot
        Marketplace         = $MarketplaceName
        Plugin              = $QualifiedPlugin
        VerificationPending = $false
    }
}

#endregion Acquisition and installation

#region Main execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $Result = Invoke-HveCorePluginInstall `
            -CommitSha $CommitSha `
            -InstallRoot $InstallRoot `
            -WhatIf:$WhatIfPreference

        switch ($Result.Status) {
            'Installed' {
                Write-Host "Installed $($Result.Plugin) from commit $($Result.CommitSha)." -ForegroundColor Green
                Write-Host "Pinned source: $($Result.PinRoot)" -ForegroundColor Green
            }
            'MarketplaceRegistered' {
                Write-Host "Registered $($Result.Marketplace); plugin installation was not approved." -ForegroundColor Yellow
            }
            default {
                if ($Result.WhatIf) {
                    Write-Host 'Planned action sequence:' -ForegroundColor Yellow
                    foreach ($Action in $Result.PlannedActions) {
                        Write-Host "  - $Action" -ForegroundColor Yellow
                    }
                }
                else {
                    Write-Host "Installation was not performed for $($Result.Plugin)." -ForegroundColor Yellow
                }
                if ($Result.VerificationPending) {
                    Write-Host 'Remote commit and plugin metadata verification remain pending because the pin does not exist.' -ForegroundColor Yellow
                }
            }
        }
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Install-HveCorePlugin failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main execution
