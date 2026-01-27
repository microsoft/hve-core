#!/usr/bin/env pwsh

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

#region Main Execution
try {
    # Only execute main logic when run directly, not when dot-sourced
    if ($MyInvocation.InvocationName -ne '.') {
        $ErrorActionPreference = "Stop"

        # Determine script and repo paths
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        $RepoRoot = (Get-Item "$ScriptDir/../..").FullName
        $ExtensionDir = Join-Path $RepoRoot "extension"
        $GitHubDir = Join-Path $RepoRoot ".github"
        $PackageJsonPath = Join-Path $ExtensionDir "package.json"

        Write-Host "📦 HVE Core Extension Packager" -ForegroundColor Cyan
        Write-Host "==============================" -ForegroundColor Cyan
        Write-Host ""

        # Verify paths exist
        if (-not (Test-Path $ExtensionDir)) {
            Write-Error "Extension directory not found: $ExtensionDir"
            exit 1
        }

        if (-not (Test-Path $PackageJsonPath)) {
            Write-Error "package.json not found: $PackageJsonPath"
            exit 1
        }

        if (-not (Test-Path $GitHubDir)) {
            Write-Error ".github directory not found: $GitHubDir"
            exit 1
        }

        # Read current package.json
        Write-Host "📖 Reading package.json..." -ForegroundColor Yellow
        try {
            $packageJson = Get-Content -Path $PackageJsonPath -Raw | ConvertFrom-Json
        } catch {
            Write-Error "Failed to parse package.json: $_`nPlease check $PackageJsonPath for JSON syntax errors."
            exit 1
        }

        # Validate package.json has required version field
        if (-not $packageJson.PSObject.Properties['version']) {
            Write-Error "package.json is missing required 'version' field"
            exit 1
        }

        # Determine version
        $baseVersion = if ($Version -and $Version -ne "") {
            # Validate specified version format
            if ($Version -notmatch '^\d+\.\d+\.\d+$') {
                Write-Error "Invalid version format specified: '$Version'. Expected semantic version format (e.g., 1.0.0).`nPre-release suffixes like '-dev.123' should be added via -DevPatchNumber parameter, not in the version itself."
                exit 1
            }
            $Version
        } else {
            # Use version from package.json
            $currentVersion = $packageJson.version
            if ($currentVersion -notmatch '^\d+\.\d+\.\d+') {
                $errorMessage = @(
                    "Invalid version format in package.json: '$currentVersion'.",
                    "Expected semantic version format (e.g., 1.0.0).",
                    "Pre-release suffixes should not be committed to package.json.",
                    "Use -DevPatchNumber parameter to add '-dev.N' suffix during packaging."
                ) -join "`n"
                Write-Error $errorMessage
                exit 1
            }
            # Extract base version (validation above ensures this will match)
            $currentVersion -match '^(\d+\.\d+\.\d+)' | Out-Null
            $Matches[1]
        }

        # Apply dev patch number if provided
        $packageVersion = if ($DevPatchNumber -and $DevPatchNumber -ne "") {
            "$baseVersion-dev.$DevPatchNumber"
        } else {
            $baseVersion
        }

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
                $changelogDest = Join-Path $ExtensionDir "CHANGELOG.md"
                Copy-Item -Path $ChangelogPath -Destination $changelogDest -Force
                Write-Host "   Copied changelog to extension directory" -ForegroundColor Green
            } else {
                Write-Warning "Changelog file not found: $ChangelogPath"
            }
        }

        # Prepare extension directory
        Write-Host ""
        Write-Host "🗂️  Preparing extension directory..." -ForegroundColor Yellow

        # Clean any existing copied directories
        $dirsToClean = @(".github", "docs", "scripts")
        foreach ($dir in $dirsToClean) {
            $dirPath = Join-Path $ExtensionDir $dir
            if (Test-Path $dirPath) {
                Remove-Item -Path $dirPath -Recurse -Force
                Write-Host "   Cleaned existing $dir directory" -ForegroundColor Gray
            }
        }

        # Copy required directories
        Write-Host "   Copying .github..." -ForegroundColor Gray
        Copy-Item -Path "$RepoRoot/.github" -Destination "$ExtensionDir/.github" -Recurse

        Write-Host "   Copying scripts/dev-tools..." -ForegroundColor Gray
        New-Item -Path "$ExtensionDir/scripts" -ItemType Directory -Force | Out-Null
        Copy-Item -Path "$RepoRoot/scripts/dev-tools" -Destination "$ExtensionDir/scripts/dev-tools" -Recurse

        Write-Host "   Copying docs/templates..." -ForegroundColor Gray
        New-Item -Path "$ExtensionDir/docs" -ItemType Directory -Force | Out-Null
        Copy-Item -Path "$RepoRoot/docs/templates" -Destination "$ExtensionDir/docs/templates" -Recurse

        Write-Host "   ✅ Extension directory prepared" -ForegroundColor Green

        # Package extension
        Write-Host ""
        Write-Host "📦 Packaging extension..." -ForegroundColor Yellow

        if ($PreRelease) {
            Write-Host "   Mode: Pre-release channel" -ForegroundColor Magenta
        }

        # Initialize vsixFile variable to avoid scope issues
        $vsixFile = $null

        # Build vsce arguments
        $vsceArgs = @('package', '--no-dependencies')
        if ($PreRelease) {
            $vsceArgs += '--pre-release'
        }

        Push-Location $ExtensionDir

        try {
            # Check if vsce is available
            $vsceCmd = Get-Command vsce -ErrorAction SilentlyContinue
            if (-not $vsceCmd) {
                $vsceCmd = Get-Command npx -ErrorAction SilentlyContinue
                if ($vsceCmd) {
                    Write-Host "   Using npx @vscode/vsce..." -ForegroundColor Gray
                    & npx @vscode/vsce @vsceArgs
                } else {
                    Write-Error "Neither vsce nor npx found. Please install @vscode/vsce globally or ensure npm is available."
                    exit 1
                }
            } else {
                Write-Host "   Using vsce..." -ForegroundColor Gray
                & vsce @vsceArgs
            }

            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to package extension"
                exit 1
            }

            # Find the generated vsix file
            $vsixFile = Get-ChildItem -Path $ExtensionDir -Filter "*.vsix" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

            if ($vsixFile) {
                Write-Host ""
                Write-Host "✅ Extension packaged successfully!" -ForegroundColor Green
                Write-Host "   File: $($vsixFile.Name)" -ForegroundColor Cyan
                Write-Host "   Size: $([math]::Round($vsixFile.Length / 1KB, 2)) KB" -ForegroundColor Cyan
                Write-Host "   Version: $packageVersion" -ForegroundColor Cyan
            } else {
                Write-Error "No .vsix file found after packaging"
                exit 1
            }

        } finally {
            Pop-Location

            # Cleanup copied directories
            Write-Host ""
            Write-Host "🧹 Cleaning up..." -ForegroundColor Yellow

            foreach ($dir in $dirsToClean) {
                $dirPath = Join-Path $ExtensionDir $dir
                if (Test-Path $dirPath) {
                    Remove-Item -Path $dirPath -Recurse -Force
                    Write-Host "   Removed $dir" -ForegroundColor Gray
                }
            }

            # Restore original version if it was changed
            if ($packageVersion -ne $originalVersion) {
                Write-Host ""
                Write-Host "🔄 Restoring original package.json version..." -ForegroundColor Yellow
                $packageJson.version = $originalVersion
                $packageJson | ConvertTo-Json -Depth 10 | Set-Content -Path $PackageJsonPath -Encoding UTF8NoBOM
                Write-Host "   Version restored to: $originalVersion" -ForegroundColor Green
            }
        }

        Write-Host ""
        Write-Host "🎉 Done!" -ForegroundColor Green
        Write-Host ""

        # Output for CI/CD consumption
        if ($env:GITHUB_OUTPUT) {
            if ($vsixFile) {
                "version=$packageVersion" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
                "vsix-file=$($vsixFile.Name)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
                "pre-release=$($PreRelease.IsPresent)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
            } else {
                Write-Warning "Cannot write GITHUB_OUTPUT: vsix file not available"
            }
        }

        exit 0
    }
}
catch {
    Write-Error "Package Extension failed: $($_.Exception.Message)"
    if ($env:GITHUB_ACTIONS -eq 'true') {
        Write-Output "::error::$($_.Exception.Message)"
    }
    exit 1
}
#endregion