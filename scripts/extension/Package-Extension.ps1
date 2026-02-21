#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

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

.PARAMETER Collection
    Optional. Path to a collection manifest file (YAML or JSON). When specified, only
    collection-filtered artifacts are copied and the output filename uses the
    collection ID.

.PARAMETER DryRun
    Optional. Validates packaging orchestration without invoking vsce.

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
    [switch]$PreRelease,

    [Parameter(Mandatory = $false)]
    [string]$Collection = "",

    [Parameter(Mandatory = $false)]
    [Alias('dry-run')]
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot "../lib/Modules/CIHelpers.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "../plugins/Modules/PluginHelpers.psm1") -Force

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
        # --yes auto-confirms npx package installation for non-interactive CI environments
        return @{
            Executable = 'npx'
            Arguments  = @('--yes', '@vscode/vsce') + $vsceArgs
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

function Get-CollectionReadmePath {
    <#
    .SYNOPSIS
        Resolves the collection-specific README path from a collection manifest.
    .DESCRIPTION
        Maps a collection manifest to its collection-specific README file. Returns
        null when the collection is the flagship package (hve-core) or when no
        matching collection README exists on disk. Supports both YAML and JSON
        manifest formats.
    .PARAMETER CollectionPath
        Path to the collection manifest file (YAML or JSON).
    .PARAMETER ExtensionDirectory
        Path to the extension directory containing README files.
    .OUTPUTS
        String path to the collection README, or $null if not applicable.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectionPath,

        [Parameter(Mandatory = $true)]
        [string]$ExtensionDirectory
    )

    $manifest = Get-CollectionManifest -CollectionPath $CollectionPath
    $collectionId = $manifest.id

    # Flagship package uses the default README.md
    if ($collectionId -eq 'hve-core') {
        return $null
    }

    $collectionReadmePath = Join-Path $ExtensionDirectory "README.$collectionId.md"
    if (Test-Path $collectionReadmePath) {
        return $collectionReadmePath
    }

    return $null
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

function Test-PackagingInputsValid {
    <#
    .SYNOPSIS
        Validates all required paths for extension packaging.
    .DESCRIPTION
        Pure function that checks existence of ExtensionDirectory, package.json,
        .github directory, and CIHelpers.psm1 module. Returns resolved paths for use
        by downstream functions.
    .PARAMETER ExtensionDirectory
        Absolute path to the extension directory.
    .PARAMETER RepoRoot
        Absolute path to the repository root.
    .OUTPUTS
        Hashtable with IsValid, Errors array, and resolved paths.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExtensionDirectory,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $errors = @()

    if (-not (Test-Path $ExtensionDirectory)) {
        $errors += "Extension directory not found: $ExtensionDirectory"
    }

    $packageJsonPath = Join-Path $ExtensionDirectory "package.json"
    if (-not (Test-Path $packageJsonPath)) {
        $errors += "package.json not found: $packageJsonPath"
    }

    $githubDir = Join-Path $RepoRoot ".github"
    if (-not (Test-Path $githubDir)) {
        $errors += ".github directory not found: $githubDir"
    }

    $ciHelpersPath = Join-Path $RepoRoot "scripts/lib/Modules/CIHelpers.psm1"
    if (-not (Test-Path $ciHelpersPath)) {
        $errors += "CIHelpers.psm1 not found: $ciHelpersPath"
    }

    return @{
        IsValid         = ($errors.Count -eq 0)
        Errors          = $errors
        PackageJsonPath = $packageJsonPath
        GitHubDir       = $githubDir
        CIHelpersPath   = $ciHelpersPath
    }
}

function Get-PackagingDirectorySpec {
    <#
    .SYNOPSIS
        Returns specification for directories to copy during packaging.
    .DESCRIPTION
        Pure function that defines source to destination mappings without performing I/O.
        Each spec includes Source, Destination, Required flag, and optional IsFile flag.
    .PARAMETER RepoRoot
        Absolute path to the repository root.
    .PARAMETER ExtensionDirectory
        Absolute path to the extension directory.
    .OUTPUTS
        Array of hashtables with Source, Destination, Required, and IsFile properties.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$ExtensionDirectory
    )

    return @(
        @{
            Source      = Join-Path $RepoRoot ".github"
            Destination = Join-Path $ExtensionDirectory ".github"
            IsFile      = $false
        },
        @{
            Source      = Join-Path $RepoRoot "scripts/lib/Modules/CIHelpers.psm1"
            Destination = Join-Path $ExtensionDirectory "scripts/lib/Modules/CIHelpers.psm1"
            IsFile      = $true
        },
        @{
            Source      = Join-Path $RepoRoot "docs/templates"
            Destination = Join-Path $ExtensionDirectory "docs/templates"
            IsFile      = $false
        }
    )
}

#endregion Pure Functions

#region I/O Functions

function Copy-CollectionArtifacts {
    <#
    .SYNOPSIS
        Copies only collection-filtered artifacts to the extension directory.
    .DESCRIPTION
        Reads the prepared package.json to determine which artifacts were selected
        by collection filtering, then copies only those files instead of the entire
        .github directory.
    .PARAMETER RepoRoot
        Absolute path to the repository root.
    .PARAMETER ExtensionDirectory
        Absolute path to the extension directory.
    .PARAMETER PrepareResult
        Result hashtable from Invoke-PrepareExtension. Reserved for future collection metadata handling.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'PrepareResult', Justification = 'Reserved for future collection metadata handling')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$ExtensionDirectory,

        [Parameter(Mandatory = $true)]
        [hashtable]$PrepareResult
    )

    $preparedPkgJson = Get-Content -Path (Join-Path $ExtensionDirectory "package.json") -Raw | ConvertFrom-Json

    # Copy filtered agents
    if ($preparedPkgJson.contributes.chatAgents) {
        foreach ($agent in $preparedPkgJson.contributes.chatAgents) {
            $srcPath = Join-Path $RepoRoot ($agent.path -replace '^\.[\\/]', '')
            if (-not (Test-Path $srcPath)) {
                Write-Warning "Skipping missing collection artifact: $srcPath (referenced by contributes.chatAgents in package.json)"
                continue
            }
            $destPath = Join-Path $ExtensionDirectory ($agent.path -replace '^\.[\\/]', '')
            $destDir = Split-Path $destPath -Parent
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
            Copy-Item -Path $srcPath -Destination $destPath -Force
        }
    }

    # Copy filtered prompts
    if ($preparedPkgJson.contributes.chatPromptFiles) {
        foreach ($prompt in $preparedPkgJson.contributes.chatPromptFiles) {
            $srcPath = Join-Path $RepoRoot ($prompt.path -replace '^\.[\\/]', '')
            if (-not (Test-Path $srcPath)) {
                Write-Warning "Skipping missing collection artifact: $srcPath (referenced by contributes.chatPromptFiles in package.json)"
                continue
            }
            $destPath = Join-Path $ExtensionDirectory ($prompt.path -replace '^\.[\\/]', '')
            $destDir = Split-Path $destPath -Parent
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
            Copy-Item -Path $srcPath -Destination $destPath -Force
        }
    }

    # Copy filtered instructions
    if ($preparedPkgJson.contributes.chatInstructions) {
        foreach ($instr in $preparedPkgJson.contributes.chatInstructions) {
            $srcPath = Join-Path $RepoRoot ($instr.path -replace '^\.[\\/]', '')
            if (-not (Test-Path $srcPath)) {
                Write-Warning "Skipping missing collection artifact: $srcPath (referenced by contributes.chatInstructions in package.json)"
                continue
            }
            $destPath = Join-Path $ExtensionDirectory ($instr.path -replace '^\.[\\/]', '')
            $destDir = Split-Path $destPath -Parent
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
            Copy-Item -Path $srcPath -Destination $destPath -Force
        }
    }

    # Copy filtered skills
    if ($preparedPkgJson.contributes.chatSkills) {
        foreach ($skill in $preparedPkgJson.contributes.chatSkills) {
            $srcPath = Join-Path $RepoRoot ($skill.path -replace '^\.[\\/]', '')
            if (-not (Test-Path $srcPath)) {
                Write-Warning "Skipping missing collection artifact: $srcPath (referenced by contributes.chatSkills in package.json)"
                continue
            }
            # Copy the full skill directory, not just SKILL.md
            $srcDir = Split-Path $srcPath -Parent
            $destPath = Join-Path $ExtensionDirectory ($skill.path -replace '^\.[\\/]', '')
            $destDir = Split-Path $destPath -Parent
            $destParent = Split-Path $destDir -Parent
            New-Item -Path $destParent -ItemType Directory -Force | Out-Null
            Copy-Item -Path $srcDir -Destination $destParent -Recurse -Force

            # Remove co-located test directories from packaged skills
            Get-ChildItem -Path $destDir -Directory -Filter 'tests' -Recurse -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force
        }
    }
}

function Set-CollectionReadme {
    <#
    .SYNOPSIS
        Swaps or restores the collection-specific README for extension packaging.
    .DESCRIPTION
        In swap mode, backs up the original README.md and copies the collection
        README in its place. In restore mode, copies the backup back and removes it.
    .PARAMETER ExtensionDirectory
        Path to the extension directory.
    .PARAMETER CollectionReadmePath
        Path to the collection-specific README file. Required for Swap operation.
    .PARAMETER Operation
        Either 'Swap' to replace README.md with collection content, or 'Restore'
        to revert README.md from backup.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExtensionDirectory,

        [Parameter(Mandatory = $false)]
        [string]$CollectionReadmePath = "",

        [Parameter(Mandatory = $true)]
        [ValidateSet('Swap', 'Restore')]
        [string]$Operation
    )

    $readmePath = Join-Path $ExtensionDirectory "README.md"
    $backupPath = Join-Path $ExtensionDirectory "README.md.bak"

    if ($Operation -eq 'Swap') {
        if (-not $CollectionReadmePath -or $CollectionReadmePath -eq "") {
            Write-Warning "No collection README path provided for swap operation"
            return
        }
        Copy-Item -Path $readmePath -Destination $backupPath -Force
        Copy-Item -Path $CollectionReadmePath -Destination $readmePath -Force
        Write-Host "   Swapped README.md with $(Split-Path $CollectionReadmePath -Leaf)" -ForegroundColor Green
    }
    elseif ($Operation -eq 'Restore') {
        if (Test-Path $backupPath) {
            Copy-Item -Path $backupPath -Destination $readmePath -Force
            Remove-Item -Path $backupPath -Force
            Write-Host "   Restored original README.md" -ForegroundColor Green
        }
    }
}

function Invoke-VsceCommand {
    <#
    .SYNOPSIS
        Executes vsce package command with platform-appropriate wrapper.
    .DESCRIPTION
        Abstracts platform-specific execution of vsce/npx commands. On Windows with npx,
        uses cmd /c to avoid PowerShell misinterpreting @ in @vscode/vsce as splatting.
        The UseWindowsWrapper parameter enables deterministic platform behavior in tests.
    .PARAMETER Executable
        The executable to run ('vsce' or 'npx').
    .PARAMETER Arguments
        Array of arguments to pass to the executable.
    .PARAMETER WorkingDirectory
        Directory to execute the command in.
    .PARAMETER UseWindowsWrapper
        When true and Executable is 'npx', uses cmd /c wrapper for Windows compatibility.
    .OUTPUTS
        Hashtable with Success boolean and ExitCode integer.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Executable,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory,

        [Parameter(Mandatory = $false)]
        [switch]$UseWindowsWrapper
    )

    Push-Location $WorkingDirectory
    try {
        $global:LASTEXITCODE = 0

        if ($UseWindowsWrapper -and $Executable -eq 'npx') {
            $cmdArgs = @('/c', 'npx') + $Arguments
            & cmd @cmdArgs
        } else {
            & $Executable @Arguments
        }

        return @{
            Success  = ($LASTEXITCODE -eq 0)
            ExitCode = $LASTEXITCODE
        }
    }
    finally {
        Pop-Location
    }
}

function Remove-PackagingArtifacts {
    <#
    .SYNOPSIS
        Removes temporary directories created during packaging.
    .DESCRIPTION
        Cleans up directories copied to the extension folder during the packaging process.
        Silently skips directories that do not exist.
    .PARAMETER ExtensionDirectory
        Absolute path to the extension directory.
    .PARAMETER DirectoryNames
        Array of directory names to remove. Defaults to .github, docs, scripts.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExtensionDirectory,

        [Parameter(Mandatory = $false)]
        [string[]]$DirectoryNames = @(".github", "docs", "scripts")
    )

    foreach ($dir in $DirectoryNames) {
        $dirPath = Join-Path $ExtensionDirectory $dir
        if (Test-Path $dirPath) {
            Remove-Item -Path $dirPath -Recurse -Force
            Write-Host "   Removed $dir" -ForegroundColor Gray
        }
    }
}

function Restore-PackageJsonVersion {
    <#
    .SYNOPSIS
        Restores original version in package.json after packaging.
    .DESCRIPTION
        Writes the original version back to package.json if it was temporarily modified
        during packaging. Safely handles null inputs by returning early.
    .PARAMETER PackageJsonPath
        Absolute path to the package.json file.
    .PARAMETER PackageJson
        The parsed package.json object to modify.
    .PARAMETER OriginalVersion
        The original version string to restore.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$PackageJsonPath,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [PSObject]$PackageJson,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$OriginalVersion
    )

    # Handle null coercion: PowerShell converts $null to empty string for [string] params
    if ([string]::IsNullOrEmpty($OriginalVersion) -or $null -eq $PackageJson -or [string]::IsNullOrEmpty($PackageJsonPath)) {
        return
    }

    try {
        $PackageJson.version = $OriginalVersion
        $PackageJson | ConvertTo-Json -Depth 10 | Set-Content -Path $PackageJsonPath -Encoding UTF8NoBOM
        Write-Host "   Version restored to: $OriginalVersion" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to restore original package.json version to '$OriginalVersion': $($_.Exception.Message)"
    }
}

#endregion I/O Functions

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
    .PARAMETER Collection
        Optional path to a collection manifest file (YAML or JSON). When specified, only
        collection-filtered artifacts are copied and the output filename uses the
        collection ID.
    .PARAMETER DryRun
        When specified, validates packaging orchestration without invoking vsce.
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
        [switch]$PreRelease,

        [Parameter(Mandatory = $false)]
        [string]$Collection = "",

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    $dirsToClean = @(".github", "docs", "scripts")
    $originalVersion = $null
    $packageJson = $null
    $PackageJsonPath = $null
    $packageVersion = $null
    $versionWasModified = $false

    try {
        # Validate all inputs using pure function
        $inputValidation = Test-PackagingInputsValid -ExtensionDirectory $ExtensionDirectory -RepoRoot $RepoRoot
        if (-not $inputValidation.IsValid) {
            return New-PackagingResult -Success $false -ErrorMessage ($inputValidation.Errors -join '; ')
        }

        $PackageJsonPath = $inputValidation.PackageJsonPath

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
            $versionWasModified = $true
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

        # Get and execute copy specifications
        $copySpecs = Get-PackagingDirectorySpec -RepoRoot $RepoRoot -ExtensionDirectory $ExtensionDirectory

        if ($Collection -and $Collection -ne "") {
            # Collection mode: copy only filtered artifacts for .github content
            Write-Host "   Using collection-filtered artifact copy..." -ForegroundColor Gray

            # Copy non-.github specs normally
            foreach ($spec in $copySpecs) {
                if ($spec.Source -like "*/.github*" -or $spec.Source -like "*\.github*") {
                    continue
                }
                $specName = Split-Path $spec.Source -Leaf
                Write-Host "   Copying $specName..." -ForegroundColor Gray

                if ($spec.IsFile) {
                    $parentDir = Split-Path $spec.Destination -Parent
                    New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
                    Copy-Item -Path $spec.Source -Destination $spec.Destination -Force
                } else {
                    $parentDir = Split-Path $spec.Destination -Parent
                    if (-not (Test-Path $parentDir)) {
                        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
                    }
                    Copy-Item -Path $spec.Source -Destination $spec.Destination -Recurse -Force
                }
            }

            # Copy collection-specific artifacts
            Copy-CollectionArtifacts -RepoRoot $RepoRoot -ExtensionDirectory $ExtensionDirectory -PrepareResult @{}
        } else {
            # Full mode: copy everything as before
            foreach ($spec in $copySpecs) {
                $specName = Split-Path $spec.Source -Leaf
                Write-Host "   Copying $specName..." -ForegroundColor Gray

                if ($spec.IsFile) {
                    $parentDir = Split-Path $spec.Destination -Parent
                    New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
                    Copy-Item -Path $spec.Source -Destination $spec.Destination -Force
                } else {
                    $parentDir = Split-Path $spec.Destination -Parent
                    if (-not (Test-Path $parentDir)) {
                        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
                    }
                    Copy-Item -Path $spec.Source -Destination $spec.Destination -Recurse -Force
                }
            }
        }

        Write-Host "   ✅ Extension directory prepared" -ForegroundColor Green

        # Swap collection README if collection specifies one
        if ($Collection -and $Collection -ne "") {
            $collectionReadmePath = Get-CollectionReadmePath -CollectionPath $Collection -ExtensionDirectory $ExtensionDirectory
            if ($collectionReadmePath) {
                Write-Host ""
                Write-Host "📄 Applying collection README..." -ForegroundColor Yellow
                Set-CollectionReadme -ExtensionDirectory $ExtensionDirectory -CollectionReadmePath $collectionReadmePath -Operation Swap
            }
        }

        if ($DryRun) {
            Write-Host ""
            Write-Host "🧪 Dry-run complete: packaging orchestration validated without VSIX creation." -ForegroundColor Yellow
            return New-PackagingResult -Success $true -Version $packageVersion
        }

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

        # Execute vsce command using I/O function
        $useWindowsWrapper = ($IsWindows -or $env:OS -eq 'Windows_NT') -and ($vsceCommand.Executable -eq 'npx')
        $vsceResult = Invoke-VsceCommand `
            -Executable $vsceCommand.Executable `
            -Arguments $vsceCommand.Arguments `
            -WorkingDirectory $ExtensionDirectory `
            -UseWindowsWrapper:$useWindowsWrapper

        if (-not $vsceResult.Success) {
            return New-PackagingResult -Success $false -ErrorMessage "vsce package command failed with exit code $($vsceResult.ExitCode)"
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
        # Restore canonical package.json from collection template backup
        $backupPath = Join-Path $ExtensionDirectory "package.json.bak"
        if (Test-Path $backupPath) {
            Copy-Item -Path $backupPath -Destination $PackageJsonPath -Force
            Remove-Item -Path $backupPath -Force
            Write-Host "   Restored canonical package.json from backup" -ForegroundColor Green

            # Re-read restored package.json for downstream restore steps
            $packageJson = Get-Content -Path $PackageJsonPath -Raw | ConvertFrom-Json
        }

        # Restore collection README if it was swapped
        Set-CollectionReadme -ExtensionDirectory $ExtensionDirectory -Operation Restore

        # Cleanup copied directories using I/O function
        Write-Host ""
        Write-Host "🧹 Cleaning up..." -ForegroundColor Yellow
        Remove-PackagingArtifacts -ExtensionDirectory $ExtensionDirectory -DirectoryNames $dirsToClean

        # Restore original version if it was changed using I/O function
        if ($versionWasModified) {
            Write-Host ""
            Write-Host "🔄 Restoring original package.json version..." -ForegroundColor Yellow
            Restore-PackageJsonVersion -PackageJsonPath $PackageJsonPath -PackageJson $packageJson -OriginalVersion $originalVersion
        }
    }
}

#endregion Orchestration Functions

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        $RepoRoot = (Get-Item "$ScriptDir/../..").FullName
        $ExtensionDir = Join-Path $RepoRoot "extension"

        $result = Invoke-PackageExtension `
            -ExtensionDirectory $ExtensionDir `
            -RepoRoot $RepoRoot `
            -Version $Version `
            -DevPatchNumber $DevPatchNumber `
            -ChangelogPath $ChangelogPath `
            -PreRelease:$PreRelease `
            -Collection $Collection `
            -DryRun:$DryRun

        if (-not $result.Success) {
            Write-Error -ErrorAction Continue $result.ErrorMessage
            exit 1
        }
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Package-Extension failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
#endregion Main Execution
