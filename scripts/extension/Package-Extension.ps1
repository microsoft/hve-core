#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Packages the HVE Core VS Code extension.

.DESCRIPTION
    This script packages the VS Code extension into a .vsix file.
    It uses the version from package.json or a specified version.
    Optionally adds a dev patch number for pre-release builds.

.PARAMETER Version
    Optional. The version to use for the package.
    If not specified, uses the version from package.json.

.PARAMETER DevPatchNumber
    Optional. Dev patch number to append (e.g., "123" creates "1.0.0-dev.123").

.PARAMETER ChangelogPath
    Optional. Path to a changelog file to include in the package.

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
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Version = "",

    [Parameter(Mandatory = $false)]
    [string]$DevPatchNumber = "",

    [Parameter(Mandatory = $false)]
    [string]$ChangelogPath = ""
)

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
$dirsToClean = @(".github", "scripts")
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

Write-Host "   ✅ Extension directory prepared" -ForegroundColor Green

# Package extension
Write-Host ""
Write-Host "📦 Packaging extension..." -ForegroundColor Yellow

# Initialize vsixFile variable to avoid scope issues
$vsixFile = $null

Push-Location $ExtensionDir

try {
    # Check if vsce is available
    $vsceCmd = Get-Command vsce -ErrorAction SilentlyContinue
    if (-not $vsceCmd) {
        $vsceCmd = Get-Command npx -ErrorAction SilentlyContinue
        if ($vsceCmd) {
            Write-Host "   Using npx @vscode/vsce..." -ForegroundColor Gray
            & npx @vscode/vsce package --no-dependencies
        } else {
            Write-Error "Neither vsce nor npx found. Please install @vscode/vsce globally or ensure npm is available."
            exit 1
        }
    } else {
        Write-Host "   Using vsce..." -ForegroundColor Gray
        & vsce package --no-dependencies
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
    } else {
        Write-Warning "Cannot write GITHUB_OUTPUT: vsix file not available"
    }
}

exit 0
