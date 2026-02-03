#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
    Packages the HVE Core VS Code extension.

.DESCRIPTION
    This script packages the VS Code extension into a .vsix file.
    It uses the version from package.json or a specified version.
    Optionally adds a dev patch number for pre-release builds.
    Supports VS Code Marketplace pre-release channel with -PreRelease switch.

.PARAMETER Version
    Optional. The version to use for the package.
    If not specified, uses the version from package.json.

.PARAMETER DevPatchNumber
    Optional. Dev patch number to append (e.g., "123" creates "1.0.0-dev.123").

.PARAMETER ChangelogPath
    Optional. Path to a changelog file to include in the package.

.PARAMETER PreRelease
    Optional. When specified, packages the extension for VS Code Marketplace pre-release channel.
    Uses vsce --pre-release flag which marks the extension for the pre-release track.

.EXAMPLE
    ./Package-Extension.ps1
    # Packages using version from package.json

.EXAMPLE
    ./Package-Extension.ps1 -Version "2.0.0"
    # Packages with specific version

.EXAMPLE
    ./Package-Extension.ps1 -DevPatchNumber "123"
    # Packages with dev version (e.g., 1.0.0-dev.123)

.EXAMPLE
    ./Package-Extension.ps1 -Version "1.1.0" -DevPatchNumber "456"
    # Packages with specific dev version (1.1.0-dev.456)

.EXAMPLE
    ./Package-Extension.ps1 -PreRelease
    # Packages for VS Code Marketplace pre-release channel

.EXAMPLE
    ./Package-Extension.ps1 -Version "1.1.0" -PreRelease
    # Packages with ODD minor version for pre-release channel

.EXAMPLE
    . ./Package-Extension.ps1
    # Dot-source to import functions for testing without executing packaging.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Version = "",

    [Parameter(Mandatory = $false)]
    [string]$DevPatchNumber = "",

    [Parameter(Mandatory = $false)]
    [string]$ChangelogPath = "",

    [Parameter(Mandatory = $false)]
    [switch]$PreRelease
)

Import-Module (Join-Path $PSScriptRoot "../lib/Modules/CIHelpers.psm1") -Force

#region Pure Functions

function Test-VsceAvailable {
    <#
    .SYNOPSIS
        Checks if vsce or npx is available for packaging.
    .OUTPUTS
        Hashtable with IsAvailable, CommandType ('vsce', 'npx', or $null), and Command path.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $vsceCmd = Get-Command vsce -ErrorAction SilentlyContinue
    if ($vsceCmd) {
        return @{
            IsAvailable = $true
            CommandType = 'vsce'
            Command     = $vsceCmd.Source
        }
    }

    $npxCmd = Get-Command npx -ErrorAction SilentlyContinue
    if ($npxCmd) {
        return @{
            IsAvailable = $true
            CommandType = 'npx'
            Command     = $npxCmd.Source
        }
    }

    return @{
        IsAvailable = $false
        CommandType = $null
        Command     = $null
    }
}

function Get-ExtensionOutputPath {
    <#
    .SYNOPSIS
        Constructs the expected .vsix output path from extension directory and version.
    .PARAMETER ExtensionDirectory
        The path to the extension directory.
    .PARAMETER ExtensionName
        The name of the extension (from package.json).
    .PARAMETER PackageVersion
        The version string to use in the filename.
    .OUTPUTS
        String path to the expected .vsix file.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExtensionDirectory,

        [Parameter(Mandatory = $true)]
        [string]$ExtensionName,

        [Parameter(Mandatory = $true)]
        [string]$PackageVersion
    )

    $vsixFileName = "$ExtensionName-$PackageVersion.vsix"
    return Join-Path $ExtensionDirectory $vsixFileName
}

function Test-ExtensionManifestValid {
    <#
    .SYNOPSIS
        Validates an extension manifest (package.json content) for required fields and format.
    .PARAMETER ManifestContent
        The parsed package.json content as a PSObject.
    .OUTPUTS
        Hashtable with IsValid boolean and Errors array.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$ManifestContent
    )

    $errors = @()

    # Check required fields
    if (-not $ManifestContent.PSObject.Properties['name']) {
        $errors += "Missing required 'name' field"
    }

    if (-not $ManifestContent.PSObject.Properties['version']) {
        $errors += "Missing required 'version' field"
    } elseif ($ManifestContent.version -notmatch '^\d+\.\d+\.\d+') {
        $errors += "Invalid version format: '$($ManifestContent.version)'. Expected semantic version (e.g., 1.0.0)"
    }

    if (-not $ManifestContent.PSObject.Properties['publisher']) {
        $errors += "Missing required 'publisher' field"
    }

    if (-not $ManifestContent.PSObject.Properties['engines']) {
        $errors += "Missing required 'engines' field"
    } elseif (-not $ManifestContent.engines.PSObject.Properties['vscode']) {
        $errors += "Missing required 'engines.vscode' field"
    }

    return @{
        IsValid = ($errors.Count -eq 0)
        Errors  = $errors
    }
}

function Get-VscePackageCommand {
    <#
    .SYNOPSIS
        Builds the vsce package command arguments without executing.
    .PARAMETER CommandType
        The type of command to use ('vsce' or 'npx').
    .PARAMETER PreRelease
        Whether to include the --pre-release flag.
    .OUTPUTS
        Hashtable with Executable and Arguments array.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('vsce', 'npx')]
        [string]$CommandType,

        [Parameter(Mandatory = $false)]
        [switch]$PreRelease
    )

    $vsceArgs = @('package', '--no-dependencies')
    if ($PreRelease) {
        $vsceArgs += '--pre-release'
    }

    if ($CommandType -eq 'npx') {
        return @{
            Executable = 'npx'
            Arguments  = @('@vscode/vsce') + $vsceArgs
        }
    }

    return @{
        Executable = 'vsce'
        Arguments  = $vsceArgs
    }
}

function New-PackagingResult {
    <#
    .SYNOPSIS
        Creates a standardized packaging result object.
    .PARAMETER Success
        Whether the packaging operation succeeded.
    .PARAMETER OutputPath
        Path to the generated .vsix file (if successful).
    .PARAMETER Version
        The package version used.
    .PARAMETER ErrorMessage
        Error message if the operation failed.
    .OUTPUTS
        Hashtable with Success, OutputPath, Version, and ErrorMessage.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Success,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "",

        [Parameter(Mandatory = $false)]
        [string]$Version = "",

        [Parameter(Mandatory = $false)]
        [string]$ErrorMessage = ""
    )

    return @{
        Success      = $Success
        OutputPath   = $OutputPath
        Version      = $Version
        ErrorMessage = $ErrorMessage
    }
}

function Get-ResolvedPackageVersion {
    <#
    .SYNOPSIS
        Resolves the package version from parameters or manifest content.
    .PARAMETER SpecifiedVersion
        Version specified via parameter (may be empty).
    .PARAMETER ManifestVersion
        Version from the package.json manifest.
    .PARAMETER DevPatchNumber
        Optional dev patch number to append.
    .OUTPUTS
        Hashtable with IsValid, BaseVersion, PackageVersion, and ErrorMessage.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SpecifiedVersion = "",

        [Parameter(Mandatory = $true)]
        [string]$ManifestVersion,

        [Parameter(Mandatory = $false)]
        [string]$DevPatchNumber = ""
    )

    $baseVersion = ""

    if ($SpecifiedVersion -and $SpecifiedVersion -ne "") {
        # Validate specified version format
        if ($SpecifiedVersion -notmatch '^\d+\.\d+\.\d+$') {
            return @{
                IsValid        = $false
                BaseVersion    = ""
                PackageVersion = ""
                ErrorMessage   = "Invalid version format specified: '$SpecifiedVersion'. Expected semantic version format (e.g., 1.0.0)."
            }
        }
        $baseVersion = $SpecifiedVersion
    } else {
        # Validate manifest version
        if ($ManifestVersion -notmatch '^\d+\.\d+\.\d+') {
            return @{
                IsValid        = $false
                BaseVersion    = ""
                PackageVersion = ""
                ErrorMessage   = "Invalid version format in package.json: '$ManifestVersion'. Expected semantic version format (e.g., 1.0.0)."
            }
        }
        # Extract base version
        $ManifestVersion -match '^(\d+\.\d+\.\d+)' | Out-Null
        $baseVersion = $Matches[1]
    }

    # Apply dev patch number if provided
    $packageVersion = if ($DevPatchNumber -and $DevPatchNumber -ne "") {
        "$baseVersion-dev.$DevPatchNumber"
    } else {
        $baseVersion
    }

    return @{
        IsValid        = $true
        BaseVersion    = $baseVersion
        PackageVersion = $packageVersion
        ErrorMessage   = ""
    }
}

#endregion Pure Functions

#region Orchestration Functions

function Invoke-PackageExtension {
    <#
    .SYNOPSIS
        Orchestrates VS Code extension packaging with full error handling.
    .DESCRIPTION
        Executes the complete packaging workflow: validates paths, resolves version,
        prepares directories, invokes vsce, and handles cleanup.
    .PARAMETER ExtensionDirectory
        Absolute path to the extension directory containing package.json.
    .PARAMETER RepoRoot
        Absolute path to the repository root directory.
    .PARAMETER Version
        Optional explicit version string (e.g., "1.2.3").
    .PARAMETER DevPatchNumber
        Optional dev build patch number for pre-release versions.
    .PARAMETER ChangelogPath
        Optional path to changelog file to include in package.
    .PARAMETER PreRelease
        Switch to mark the package as a pre-release version.
    .OUTPUTS
        Hashtable with Success, OutputPath, Version, and ErrorMessage properties.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ExtensionDirectory,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$Version = "",

        [Parameter(Mandatory = $false)]
        [string]$DevPatchNumber = "",

        [Parameter(Mandatory = $false)]
        [string]$ChangelogPath = "",

        [Parameter(Mandatory = $false)]
        [switch]$PreRelease
    )

    $dirsToClean = @(".github", "docs", "scripts")
    $originalVersion = $null
    $packageJson = $null
    $PackageJsonPath = $null
    $packageVersion = $null

    try {
        # Validate extension directory
        if (-not (Test-Path $ExtensionDirectory)) {
            return New-PackagingResult -Success $false -ErrorMessage "Extension directory not found: $ExtensionDirectory"
        }

        $PackageJsonPath = Join-Path $ExtensionDirectory "package.json"
        if (-not (Test-Path $PackageJsonPath)) {
            return New-PackagingResult -Success $false -ErrorMessage "package.json not found: $PackageJsonPath"
        }

        $GitHubDir = Join-Path $RepoRoot ".github"
        if (-not (Test-Path $GitHubDir)) {
            return New-PackagingResult -Success $false -ErrorMessage ".github directory not found: $GitHubDir"
        }

        Write-Host "📦 HVE Core Extension Packager" -ForegroundColor Cyan
        Write-Host "==============================" -ForegroundColor Cyan
        Write-Host ""

        # Read and validate package.json
        Write-Host "📖 Reading package.json..." -ForegroundColor Yellow
        try {
            $packageJson = Get-Content -Path $PackageJsonPath -Raw | ConvertFrom-Json
        }
        catch {
            return New-PackagingResult -Success $false -ErrorMessage "Failed to parse package.json: $($_.Exception.Message)"
        }

        $manifestValidation = Test-ExtensionManifestValid -ManifestContent $packageJson
        if (-not $manifestValidation.IsValid) {
            return New-PackagingResult -Success $false -ErrorMessage "Invalid package.json: $($manifestValidation.Errors -join '; ')"
        }

        # Resolve version using pure function
        $versionResult = Get-ResolvedPackageVersion `
            -SpecifiedVersion $Version `
            -ManifestVersion $packageJson.version `
            -DevPatchNumber $DevPatchNumber

        if (-not $versionResult.IsValid) {
            return New-PackagingResult -Success $false -ErrorMessage $versionResult.ErrorMessage
        }

        $packageVersion = $versionResult.PackageVersion
        Write-Host "   Using version: $packageVersion" -ForegroundColor Green

        # Handle temporary version update for dev builds
        $originalVersion = $packageJson.version

        if ($packageVersion -ne $originalVersion) {
            Write-Host ""
            Write-Host "📝 Temporarily updating package.json version..." -ForegroundColor Yellow
            $packageJson.version = $packageVersion
            $packageJson | ConvertTo-Json -Depth 10 | Set-Content -Path $PackageJsonPath -Encoding UTF8NoBOM
            Write-Host "   Version: $originalVersion -> $packageVersion" -ForegroundColor Green
        }

        # Handle changelog if provided
        if ($ChangelogPath -and $ChangelogPath -ne "") {
            Write-Host ""
            Write-Host "📋 Processing changelog..." -ForegroundColor Yellow

            if (Test-Path $ChangelogPath) {
                $changelogDest = Join-Path $ExtensionDirectory "CHANGELOG.md"
                Copy-Item -Path $ChangelogPath -Destination $changelogDest -Force
                Write-Host "   Copied changelog to extension directory" -ForegroundColor Green
            }
            else {
                Write-Warning "Changelog file not found: $ChangelogPath"
            }
        }

        # Prepare extension directory
        Write-Host ""
        Write-Host "🗂️  Preparing extension directory..." -ForegroundColor Yellow

        # Clean any existing copied directories
        foreach ($dir in $dirsToClean) {
            $dirPath = Join-Path $ExtensionDirectory $dir
            if (Test-Path $dirPath) {
                Remove-Item -Path $dirPath -Recurse -Force
                Write-Host "   Cleaned existing $dir directory" -ForegroundColor Gray
            }
        }

        # Copy required directories
        Write-Host "   Copying .github..." -ForegroundColor Gray
        Copy-Item -Path "$RepoRoot/.github" -Destination "$ExtensionDirectory/.github" -Recurse

        Write-Host "   Copying scripts/dev-tools..." -ForegroundColor Gray
        New-Item -Path "$ExtensionDirectory/scripts" -ItemType Directory -Force | Out-Null
        Copy-Item -Path "$RepoRoot/scripts/dev-tools" -Destination "$ExtensionDirectory/scripts/dev-tools" -Recurse

        Write-Host "   Copying docs/templates..." -ForegroundColor Gray
        New-Item -Path "$ExtensionDirectory/docs" -ItemType Directory -Force | Out-Null
        Copy-Item -Path "$RepoRoot/docs/templates" -Destination "$ExtensionDirectory/docs/templates" -Recurse

        Write-Host "   ✅ Extension directory prepared" -ForegroundColor Green

        # Check vsce availability using pure function
        $vsceAvailability = Test-VsceAvailable
        if (-not $vsceAvailability.IsAvailable) {
            return New-PackagingResult -Success $false -ErrorMessage "Neither vsce nor npx found. Please install @vscode/vsce globally or ensure npm is available."
        }

        # Build vsce command using pure function
        $vsceCommand = Get-VscePackageCommand -CommandType $vsceAvailability.CommandType -PreRelease:$PreRelease

        # Package extension
        Write-Host ""
        Write-Host "📦 Packaging extension..." -ForegroundColor Yellow

        if ($PreRelease) {
            Write-Host "   Mode: Pre-release channel" -ForegroundColor Magenta
        }

        Write-Host "   Using $($vsceAvailability.CommandType)..." -ForegroundColor Gray

        Push-Location $ExtensionDirectory
        try {
            $global:LASTEXITCODE = 0  # Reset before native call for test reliability
            & $vsceCommand.Executable @($vsceCommand.Arguments)

            if ($LASTEXITCODE -ne 0) {
                return New-PackagingResult -Success $false -ErrorMessage "vsce package command failed with exit code $LASTEXITCODE"
            }
        }
        finally {
            Pop-Location
        }

        # Find the generated vsix file
        $vsixFile = Get-ChildItem -Path $ExtensionDirectory -Filter "*.vsix" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

        if (-not $vsixFile) {
            return New-PackagingResult -Success $false -ErrorMessage "No .vsix file found after packaging"
        }

        Write-Host ""
        Write-Host "✅ Extension packaged successfully!" -ForegroundColor Green
        Write-Host "   File: $($vsixFile.Name)" -ForegroundColor Cyan
        Write-Host "   Size: $([math]::Round($vsixFile.Length / 1KB, 2)) KB" -ForegroundColor Cyan
        Write-Host "   Version: $packageVersion" -ForegroundColor Cyan

        # Output for CI/CD consumption
        Set-CIOutput -Name 'version' -Value $packageVersion
        Set-CIOutput -Name 'vsix-file' -Value $vsixFile.Name
        Set-CIOutput -Name 'pre-release' -Value $PreRelease.IsPresent

        Write-Host ""
        Write-Host "🎉 Done!" -ForegroundColor Green
        Write-Host ""

        return New-PackagingResult -Success $true -OutputPath $vsixFile.FullName -Version $packageVersion
    }
    catch {
        return New-PackagingResult -Success $false -ErrorMessage $_.Exception.Message
    }
    finally {
        # Cleanup copied directories
        Write-Host ""
        Write-Host "🧹 Cleaning up..." -ForegroundColor Yellow

        foreach ($dir in $dirsToClean) {
            $dirPath = Join-Path $ExtensionDirectory $dir
            if (Test-Path $dirPath) {
                Remove-Item -Path $dirPath -Recurse -Force
                Write-Host "   Removed $dir" -ForegroundColor Gray
            }
        }

        # Restore original version if it was changed
        if ($null -ne $originalVersion -and $null -ne $packageVersion -and $packageVersion -ne $originalVersion -and $null -ne $PackageJsonPath) {
            Write-Host ""
            Write-Host "🔄 Restoring original package.json version..." -ForegroundColor Yellow
            try {
                $packageJson.version = $originalVersion
                $packageJson | ConvertTo-Json -Depth 10 | Set-Content -Path $PackageJsonPath -Encoding UTF8NoBOM
                Write-Host "   Version restored to: $originalVersion" -ForegroundColor Green
            }
            catch {
                Write-Warning "Failed to restore original package.json version to '$originalVersion': $($_.Exception.Message)"
            }
        }
    }
}

#endregion Orchestration Functions

#region Main Execution
try {
    # Only execute main logic when run directly, not when dot-sourced
    if ($MyInvocation.InvocationName -ne '.') {
        $ErrorActionPreference = "Stop"

        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        $RepoRoot = (Get-Item "$ScriptDir/../..").FullName
        $ExtensionDir = Join-Path $RepoRoot "extension"

        $result = Invoke-PackageExtension `
            -ExtensionDirectory $ExtensionDir `
            -RepoRoot $RepoRoot `
            -Version $Version `
            -DevPatchNumber $DevPatchNumber `
            -ChangelogPath $ChangelogPath `
            -PreRelease:$PreRelease

        if (-not $result.Success) {
            Write-Error $result.ErrorMessage
            exit 1
        }
        exit 0
    }
}
catch {
    Write-Error "Package Extension failed: $($_.Exception.Message)"
    Write-CIAnnotation -Message $_.Exception.Message -Level Error
    exit 1
}
#endregion
