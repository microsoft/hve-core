#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Packages the prepared HVE Core VS Code extension.
.DESCRIPTION
    Stages only git-tracked files referenced by the prepared contribution
    manifest plus explicit shared resources, then invokes the repository-pinned
    vsce executable without installing or downloading dependencies.
.PARAMETER Version
    Optional semantic version override.
.PARAMETER DevPatchNumber
    Optional development suffix number.
.PARAMETER ChangelogPath
    Optional changelog path.
.PARAMETER PreRelease
    Adds the vsce pre-release flag.
.PARAMETER DryRun
    Validates staging without invoking vsce.
.EXAMPLE
    ./Package-Extension.ps1 -DryRun
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)] [string]$Version = '',
    [Parameter(Mandatory = $false)] [string]$DevPatchNumber = '',
    [Parameter(Mandatory = $false)] [string]$ChangelogPath = '',
    [Parameter(Mandatory = $false)] [switch]$PreRelease,
    [Parameter(Mandatory = $false)] [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

function Test-ExtensionManifestValid {
    <#
    .SYNOPSIS
    Validates required extension manifest fields.
    .PARAMETER ManifestContent
    Parsed extension manifest.
    .OUTPUTS
    [hashtable] Validation state and errors.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$ManifestContent
    )

    $errors = @()
    foreach ($field in @('name', 'version', 'publisher', 'engines')) {
        if (-not $ManifestContent.PSObject.Properties[$field]) { $errors += "Missing required '$field' field" }
    }
    if ($ManifestContent.version -and $ManifestContent.version -notmatch '^\d+\.\d+\.\d+') {
        $errors += "Invalid version format: '$($ManifestContent.version)'"
    }
    if ($ManifestContent.engines -and -not $ManifestContent.engines.PSObject.Properties['vscode']) {
        $errors += "Missing required 'engines.vscode' field"
    }
    return @{ IsValid = ($errors.Count -eq 0); Errors = $errors }
}

function Get-ResolvedPackageVersion {
    <#
    .SYNOPSIS
    Resolves the package version.
    .PARAMETER SpecifiedVersion
    Optional version override.
    .PARAMETER ManifestVersion
    Manifest version.
    .PARAMETER DevPatchNumber
    Optional development suffix number.
    .OUTPUTS
    [hashtable] Resolved version state.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)] [string]$SpecifiedVersion = '',
        [Parameter(Mandatory = $true)] [string]$ManifestVersion,
        [Parameter(Mandatory = $false)] [string]$DevPatchNumber = ''
    )

    $baseVersion = if ($SpecifiedVersion) { $SpecifiedVersion } else { $ManifestVersion }
    if ($baseVersion -notmatch '^(\d+\.\d+\.\d+)') {
        return @{ IsValid = $false; BaseVersion = ''; PackageVersion = ''; ErrorMessage = "Invalid version format: '$baseVersion'" }
    }
    $baseVersion = $Matches[1]
    $packageVersion = if ($DevPatchNumber) { "$baseVersion-dev.$DevPatchNumber" } else { $baseVersion }
    return @{ IsValid = $true; BaseVersion = $baseVersion; PackageVersion = $packageVersion; ErrorMessage = '' }
}

function New-PackagingResult {
    <#
    .SYNOPSIS
    Creates a packaging result.
    .PARAMETER Success
    Success state.
    .PARAMETER OutputPath
    VSIX path.
    .PARAMETER Version
    Package version.
    .PARAMETER ErrorMessage
    Error message.
    .OUTPUTS
    [hashtable] Packaging result.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)] [bool]$Success,
        [Parameter(Mandatory = $false)] [string]$OutputPath = '',
        [Parameter(Mandatory = $false)] [string]$Version = '',
        [Parameter(Mandatory = $false)] [string]$ErrorMessage = ''
    )

    return @{ Success = $Success; OutputPath = $OutputPath; Version = $Version; ErrorMessage = $ErrorMessage }
}

function Test-PackagingInputsValid {
    <#
    .SYNOPSIS
    Validates packaging paths.
    .PARAMETER ExtensionDirectory
    Extension directory.
    .PARAMETER RepoRoot
    Repository root.
    .OUTPUTS
    [hashtable] Validation state and resolved package path.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)] [string]$ExtensionDirectory,
        [Parameter(Mandatory = $true)] [string]$RepoRoot
    )

    $errors = @()
    $packageJsonPath = Join-Path $ExtensionDirectory 'package.json'
    if (-not (Test-Path -LiteralPath $ExtensionDirectory -PathType Container)) { $errors += "Extension directory not found: $ExtensionDirectory" }
    if (-not (Test-Path -LiteralPath $packageJsonPath -PathType Leaf)) { $errors += "package.json not found: $packageJsonPath" }
    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot '.git'))) {
        $isWorktree = git -C $RepoRoot rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -ne 0 -or $isWorktree -ne 'true') { $errors += "Git worktree not found: $RepoRoot" }
    }
    return @{ IsValid = ($errors.Count -eq 0); Errors = $errors; PackageJsonPath = $packageJsonPath }
}

function Test-DistributionPath {
    <#
    .SYNOPSIS
    Checks whether a tracked path is distributable.
    .PARAMETER Path
    Repository-relative path.
    .OUTPUTS
    [bool] True when the path is distributable.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)] [string]$Path
    )

    return ($Path -notmatch '(^|/)(tests|\.venv|node_modules|__pycache__|\.ruff_cache|\.pytest_cache)(/|$)')
}

function Get-TrackedFilesForSource {
    <#
    .SYNOPSIS
    Returns distributable tracked files under one source path.
    .PARAMETER RepoRoot
    Repository root.
    .PARAMETER SourcePath
    Repository-relative file or directory.
    .OUTPUTS
    [string[]] Tracked file paths.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)] [string]$RepoRoot,
        [Parameter(Mandatory = $true)] [string]$SourcePath
    )

    $normalized = (($SourcePath -replace '\\', '/') -replace '^\./', '').TrimEnd('/')
    $files = @(git -C $RepoRoot ls-files -- $normalized)
    if ($LASTEXITCODE -ne 0) { throw "Failed to enumerate tracked files for '$normalized'." }
    $files = @($files | Where-Object { Test-DistributionPath -Path $_ } | Sort-Object -Unique)
    if ($files.Count -eq 0) { throw "Prepared source '$normalized' has no distributable tracked files." }
    return [string[]]$files
}

function Test-PreparedContributionPath {
    <#
    .SYNOPSIS
    Tests whether a prepared contribution path is contained and well shaped.
    .PARAMETER Path
    Repository-relative contribution path.
    .PARAMETER Shape
    Anchored expression describing the expected artifact shape.
    .OUTPUTS
    [bool] True when the path is contained and matches the expected shape.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] [string]$Shape
    )

    if ($Path -match '[\\:]' -or $Path -match '[\x00-\x1f]' -or $Path.IndexOfAny([char[]]'*?[]') -ge 0) { return $false }
    foreach ($segment in ($Path -split '/')) {
        if ([string]::IsNullOrEmpty($segment) -or $segment -eq '.' -or $segment -eq '..') { return $false }
    }
    return [bool]($Path -match $Shape)
}

function Get-PreparedSourceRoots {
    <#
    .SYNOPSIS
    Reads contribution source roots from a prepared extension manifest.
    .PARAMETER PackageJson
    Prepared package manifest.
    .OUTPUTS
    [string[]] Repository-relative source roots.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)] [psobject]$PackageJson
    )

    $roots = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $propertyShape = [ordered]@{
        chatAgents       = '^\.github/agents/[^/]+/.+\.agent\.md$'
        chatPromptFiles  = '^\.github/prompts/[^/]+/.+\.prompt\.md$'
        chatInstructions = '^\.github/instructions/[^/]+/.+\.instructions\.md$'
    }
    foreach ($property in $propertyShape.Keys) {
        foreach ($item in @($PackageJson.contributes.$property)) {
            if (-not $item.path) { continue }
            $path = ([string]$item.path -replace '^\./', '')
            if (-not (Test-PreparedContributionPath -Path $path -Shape $propertyShape[$property])) {
                throw "Prepared $property contribution '$path' is not a contained artifact path."
            }
            [void]$roots.Add($path)
        }
    }
    foreach ($skill in @($PackageJson.contributes.chatSkills)) {
        if ($skill.path) {
            $path = ([string]$skill.path -replace '^\./', '')
            if (-not (Test-PreparedContributionPath -Path $path -Shape '^\.github/skills/[^/]+/[^/]+/SKILL\.md$')) {
                throw "Prepared chatSkills contribution '$path' is not a contained artifact path."
            }
            [void]$roots.Add(((Split-Path -Parent $path) -replace '\\', '/'))
        }
    }
    return [string[]]@($roots | Sort-Object)
}

function Copy-PreparedArtifacts {
    <#
    .SYNOPSIS
    Copies tracked prepared artifacts and explicit shared resources.
    .PARAMETER RepoRoot
    Repository root.
    .PARAMETER ExtensionDirectory
    Extension directory.
    .OUTPUTS
    [string[]] Copied repository-relative paths.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)] [string]$RepoRoot,
        [Parameter(Mandatory = $true)] [string]$ExtensionDirectory
    )

    $packageJson = Get-Content -LiteralPath (Join-Path $ExtensionDirectory 'package.json') -Raw -Encoding utf8 | ConvertFrom-Json
    $sourceRoots = @(Get-PreparedSourceRoots -PackageJson $packageJson)
    $sourceRoots += @('scripts/lib/Modules/CIHelpers.psm1', 'docs/templates')
    $tracked = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($root in $sourceRoots) {
        foreach ($file in Get-TrackedFilesForSource -RepoRoot $RepoRoot -SourcePath $root) { [void]$tracked.Add($file) }
    }

    foreach ($relative in $tracked) {
        $source = Join-Path $RepoRoot $relative
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Tracked prepared file is missing: $relative" }
        $destination = Join-Path $ExtensionDirectory $relative
        $parent = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -Path $parent -ItemType Directory -Force | Out-Null }
        Copy-Item -LiteralPath $source -Destination $destination -Force
    }
    return [string[]]@($tracked | Sort-Object)
}

function Get-PinnedVsceCommand {
    <#
    .SYNOPSIS
    Resolves an available vsce command matching the repository pin.
    .PARAMETER RepoRoot
    Repository root.
    .OUTPUTS
    [hashtable] Availability, command, and expected version.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)] [string]$RepoRoot
    )

    $rootPackage = Get-Content -LiteralPath (Join-Path $RepoRoot 'package.json') -Raw -Encoding utf8 | ConvertFrom-Json
    $expected = [string]$rootPackage.devDependencies.'@vscode/vsce'
    $local = Join-Path $RepoRoot 'node_modules/.bin/vsce'
    $command = if (Test-Path -LiteralPath $local -PathType Leaf) { $local } else { (Get-Command vsce -ErrorAction SilentlyContinue).Source }
    if (-not $command) { return @{ IsAvailable = $false; Command = ''; ExpectedVersion = $expected; ActualVersion = '' } }
    $actual = (& $command --version 2>$null | Select-Object -First 1).Trim()
    return @{ IsAvailable = ($actual -eq $expected); Command = $command; ExpectedVersion = $expected; ActualVersion = $actual }
}

function Get-VscePackageArguments {
    <#
    .SYNOPSIS
    Returns deterministic vsce package arguments.
    .PARAMETER PreRelease
    Adds pre-release packaging.
    .OUTPUTS
    [string[]] vsce arguments.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $false)] [switch]$PreRelease
    )

    $arguments = @('package', '--no-dependencies')
    if ($PreRelease) { $arguments += '--pre-release' }
    return [string[]]$arguments
}

function Invoke-VsceCommand {
    <#
    .SYNOPSIS
    Invokes vsce in the extension directory.
    .PARAMETER Executable
    vsce executable.
    .PARAMETER Arguments
    vsce arguments.
    .PARAMETER WorkingDirectory
    Extension directory.
    .OUTPUTS
    [hashtable] Process result.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)] [string]$Executable,
        [Parameter(Mandatory = $true)] [string[]]$Arguments,
        [Parameter(Mandatory = $true)] [string]$WorkingDirectory
    )

    Push-Location $WorkingDirectory
    try {
        $global:LASTEXITCODE = 0
        & $Executable @Arguments
        return @{ Success = ($LASTEXITCODE -eq 0); ExitCode = $LASTEXITCODE }
    }
    finally { Pop-Location }
}

function Remove-PackagingArtifacts {
    <#
    .SYNOPSIS
    Removes staged resource directories.
    .PARAMETER ExtensionDirectory
    Extension directory.
    .OUTPUTS
    [void]
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)] [string]$ExtensionDirectory
    )

    foreach ($directory in @('.github', 'docs', 'scripts')) {
        $path = Join-Path $ExtensionDirectory $directory
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
    }
}

function Invoke-PackageExtension {
    <#
    .SYNOPSIS
    Stages and packages the prepared hve-core extension.
    .PARAMETER ExtensionDirectory
    Extension directory.
    .PARAMETER RepoRoot
    Repository root.
    .PARAMETER Version
    Optional version override.
    .PARAMETER DevPatchNumber
    Optional development suffix.
    .PARAMETER ChangelogPath
    Optional changelog.
    .PARAMETER PreRelease
    Adds pre-release packaging.
    .PARAMETER DryRun
    Skips VSIX creation.
    .OUTPUTS
    [hashtable] Packaging result.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)] [string]$ExtensionDirectory,
        [Parameter(Mandatory = $true)] [string]$RepoRoot,
        [Parameter(Mandatory = $false)] [string]$Version = '',
        [Parameter(Mandatory = $false)] [string]$DevPatchNumber = '',
        [Parameter(Mandatory = $false)] [string]$ChangelogPath = '',
        [Parameter(Mandatory = $false)] [switch]$PreRelease,
        [Parameter(Mandatory = $false)] [switch]$DryRun
    )

    $packagePath = Join-Path $ExtensionDirectory 'package.json'
    $originalVersion = ''
    $versionChanged = $false
    try {
        $inputs = Test-PackagingInputsValid -ExtensionDirectory $ExtensionDirectory -RepoRoot $RepoRoot
        if (-not $inputs.IsValid) { return New-PackagingResult -Success $false -ErrorMessage ($inputs.Errors -join '; ') }
        $package = Get-Content -LiteralPath $packagePath -Raw -Encoding utf8 | ConvertFrom-Json
        $manifest = Test-ExtensionManifestValid -ManifestContent $package
        if (-not $manifest.IsValid) { return New-PackagingResult -Success $false -ErrorMessage ($manifest.Errors -join '; ') }
        $resolved = Get-ResolvedPackageVersion -SpecifiedVersion $Version -ManifestVersion ([string]$package.version) -DevPatchNumber $DevPatchNumber
        if (-not $resolved.IsValid) { return New-PackagingResult -Success $false -ErrorMessage $resolved.ErrorMessage }

        $originalVersion = [string]$package.version
        if ($resolved.PackageVersion -ne $originalVersion) {
            $package.version = $resolved.PackageVersion
            $package | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $packagePath -Encoding utf8NoBOM
            $versionChanged = $true
        }
        if ($ChangelogPath -and (Test-Path -LiteralPath $ChangelogPath -PathType Leaf)) {
            Copy-Item -LiteralPath $ChangelogPath -Destination (Join-Path $ExtensionDirectory 'CHANGELOG.md') -Force
        }

        Remove-PackagingArtifacts -ExtensionDirectory $ExtensionDirectory
        $copied = @(Copy-PreparedArtifacts -RepoRoot $RepoRoot -ExtensionDirectory $ExtensionDirectory)
        Write-Host "Staged $($copied.Count) tracked files"
        if ($DryRun) { return New-PackagingResult -Success $true -Version $resolved.PackageVersion }

        $vsce = Get-PinnedVsceCommand -RepoRoot $RepoRoot
        if (-not $vsce.IsAvailable) {
            return New-PackagingResult -Success $false -ErrorMessage "Pinned vsce $($vsce.ExpectedVersion) is unavailable (found '$($vsce.ActualVersion)')."
        }
        $process = Invoke-VsceCommand -Executable $vsce.Command -Arguments (Get-VscePackageArguments -PreRelease:$PreRelease) -WorkingDirectory $ExtensionDirectory
        if (-not $process.Success) { return New-PackagingResult -Success $false -ErrorMessage "vsce failed with exit code $($process.ExitCode)" }
        $vsix = Get-ChildItem -LiteralPath $ExtensionDirectory -Filter '*.vsix' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $vsix) { return New-PackagingResult -Success $false -ErrorMessage 'No .vsix file found after packaging' }
        Set-CIOutput -Name version -Value $resolved.PackageVersion
        Set-CIOutput -Name vsix-file -Value $vsix.Name
        Set-CIOutput -Name pre-release -Value $PreRelease.IsPresent
        return New-PackagingResult -Success $true -OutputPath $vsix.FullName -Version $resolved.PackageVersion
    }
    catch { return New-PackagingResult -Success $false -ErrorMessage $_.Exception.Message }
    finally {
        Remove-PackagingArtifacts -ExtensionDirectory $ExtensionDirectory
        if ($versionChanged -and (Test-Path -LiteralPath $packagePath)) {
            $package = Get-Content -LiteralPath $packagePath -Raw -Encoding utf8 | ConvertFrom-Json
            $package.version = $originalVersion
            $package | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $packagePath -Encoding utf8NoBOM
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $repoRoot = (Get-Item (Join-Path $PSScriptRoot '../..')).FullName
    $result = Invoke-PackageExtension -ExtensionDirectory (Join-Path $repoRoot 'extension') -RepoRoot $repoRoot `
        -Version $Version -DevPatchNumber $DevPatchNumber -ChangelogPath $ChangelogPath `
        -PreRelease:$PreRelease -DryRun:$DryRun
    if (-not $result.Success) {
        Write-CIAnnotation -Message $result.ErrorMessage -Level Error
        Write-Error -ErrorAction Continue "Package-Extension failed: $($result.ErrorMessage)"
        exit 1
    }
    exit 0
}
