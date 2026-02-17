#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Validates copyright and SPDX license headers in source files.

.DESCRIPTION
    Cross-platform PowerShell script that scans source files for required copyright
    and SPDX license identifier headers. Integrates with the existing linting
    infrastructure and outputs results in JSON format.

.PARAMETER Path
    Root path to scan for source files. Defaults to repository root.

.PARAMETER FileExtensions
    Array of file extensions to check. Defaults to @('*.ps1', '*.psm1', '*.psd1', '*.sh').

.PARAMETER OutputPath
    Path where results should be saved. Defaults to 'logs/copyright-header-results.json'.

.PARAMETER FailOnMissing
    Exit with error code if any files are missing required headers. Default is false.

.PARAMETER ExcludePaths
    Array of paths to exclude from scanning (supports wildcards).

.EXAMPLE
    ./Test-CopyrightHeaders.ps1
    Scan repository for copyright header compliance.

.EXAMPLE
    ./Test-CopyrightHeaders.ps1 -FailOnMissing
    Scan and fail if any files are missing headers.

.EXAMPLE
    ./Test-CopyrightHeaders.ps1 -Path "./scripts" -FileExtensions @('*.ps1')
    Scan only PowerShell files in scripts directory.

.NOTES
    Requires PowerShell 7.0 or later for cross-platform compatibility.

    Expected header format:
    - Copyright line: # Copyright (c) Microsoft Corporation.
    - SPDX line: # SPDX-License-Identifier: MIT

    Headers should appear within the first 10 lines of the file,
    accounting for shebang and #Requires statements.

.LINK
    https://spdx.dev/ids/
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Path = (git rev-parse --show-toplevel 2>$null),

    [Parameter(Mandatory = $false)]
    [string[]]$FileExtensions = @('*.ps1', '*.psm1', '*.psd1', '*.sh'),

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "logs/copyright-header-results.json",

    [Parameter(Mandatory = $false)]
    [switch]$FailOnMissing,

    [Parameter(Mandatory = $false)]
    [string[]]$ExcludePaths = @('node_modules', '.git', 'vendor', 'logs')
)

# Import shared helpers if available
$helpersPath = Join-Path $PSScriptRoot "Modules/LintingHelpers.psm1"
if (Test-Path $helpersPath) {
    Import-Module $helpersPath -Force
}
Import-Module (Join-Path $PSScriptRoot "../lib/Modules/CIHelpers.psm1") -Force

# Header patterns to check
$CopyrightPattern = '^\s*#\s*Copyright\s*\(c\)\s*Microsoft\s+Corporation\.?\s*$'
$SpdxPattern = '^\s*#\s*SPDX-License-Identifier:\s*MIT\s*$'

# Lines to check (accounting for shebang, #Requires, etc.)
$MaxLinesToCheck = 15

#region Functions

function Test-FileHeaders {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $result = @{
        file = $FilePath -replace [regex]::Escape($Path), '' -replace '^[\\/]', ''
        hasCopyright = $false
        hasSpdx = $false
        valid = $false
        copyrightLine = $null
        spdxLine = $null
    }

    try {
        # Read first N lines of file
        $lines = Get-Content -Path $FilePath -TotalCount $MaxLinesToCheck -ErrorAction Stop

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $lineNum = $i + 1

            if ($line -match $CopyrightPattern) {
                $result.hasCopyright = $true
                $result.copyrightLine = $lineNum
            }

            if ($line -match $SpdxPattern) {
                $result.hasSpdx = $true
                $result.spdxLine = $lineNum
            }
        }

        $result.valid = $result.hasCopyright -and $result.hasSpdx
    }
    catch {
        Write-Warning "Failed to read file: $FilePath - $_"
        $result.error = $_.Exception.Message
    }

    return $result
}

function Get-FilesToCheck {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo[]])]
    param(
        [string]$RootPath,
        [string[]]$Extensions,
        [string[]]$Exclude
    )

    $files = @()

    foreach ($ext in $Extensions) {
        $found = Get-ChildItem -Path $RootPath -Filter $ext -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $filePath = $_.FullName
                $excluded = $false
                foreach ($excludePath in $Exclude) {
                    if ($filePath -like "*$excludePath*") {
                        $excluded = $true
                        break
                    }
                }
                -not $excluded
            }
        $files += $found
    }

    return $files | Sort-Object FullName -Unique
}

function Invoke-CopyrightHeaderCheck {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path = $(if ($p = git rev-parse --show-toplevel 2>$null) { $p } else { '.' }),

        [Parameter(Mandatory = $false)]
        [string[]]$FileExtensions = @('*.ps1', '*.psm1', '*.psd1', '*.sh'),

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "logs/copyright-header-results.json",

        [Parameter(Mandatory = $false)]
        [switch]$FailOnMissing,

        [Parameter(Mandatory = $false)]
        [string[]]$ExcludePaths = @('node_modules', '.git', 'vendor', 'logs')
    )

    Write-Host "📄 Validating copyright headers..." -ForegroundColor Cyan

    # Ensure output directory exists
    $outputDir = Split-Path -Parent $OutputPath
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    # Get files to check
    Write-Host "Scanning for source files in: $Path" -ForegroundColor Gray
    $filesToCheck = Get-FilesToCheck -RootPath $Path -Extensions $FileExtensions -Exclude $ExcludePaths

    if ($filesToCheck.Count -eq 0) {
        Write-Host "⚠️  No files found matching criteria" -ForegroundColor Yellow
        return
    }

    Write-Host "Found $($filesToCheck.Count) files to check" -ForegroundColor Gray

    # Check each file
    $results = @()
    $filesWithHeaders = 0
    $filesMissingHeaders = 0

    foreach ($file in $filesToCheck) {
        $fileResult = Test-FileHeaders -FilePath $file.FullName

        if ($fileResult.valid) {
            $filesWithHeaders++
            Write-Host "  ✅ $($fileResult.file)" -ForegroundColor Green
        }
        else {
            $filesMissingHeaders++
            $missing = @()
            if (-not $fileResult.hasCopyright) { $missing += "copyright" }
            if (-not $fileResult.hasSpdx) { $missing += "SPDX" }
            Write-Host "  ❌ $($fileResult.file) (missing: $($missing -join ', '))" -ForegroundColor Red
            Write-CIAnnotation `
                -Message "Missing required headers: $($missing -join ', ')" `
                -Level Warning `
                -File $file.FullName `
                -Line 1
        }

        $results += $fileResult
    }

    # Build output object
    $output = @{
        timestamp = (Get-Date -Format "o")
        totalFiles = $filesToCheck.Count
        filesWithHeaders = $filesWithHeaders
        filesMissingHeaders = $filesMissingHeaders
        compliancePercentage = if ($filesToCheck.Count -gt 0) {
            [math]::Round(($filesWithHeaders / $filesToCheck.Count) * 100, 2)
        } else { 100 }
        results = $results
    }

    # Write results to file
    $output | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
    Write-Host "`n📊 Results written to: $OutputPath" -ForegroundColor Cyan

    # Summary
    Write-Host "`n📋 Summary:" -ForegroundColor Cyan
    Write-Host "   Total files:    $($output.totalFiles)" -ForegroundColor Gray
    Write-Host "   With headers:   $($output.filesWithHeaders)" -ForegroundColor Green
    Write-Host "   Missing headers: $($output.filesMissingHeaders)" -ForegroundColor $(if ($output.filesMissingHeaders -gt 0) { 'Red' } else { 'Green' })
    Write-Host "   Compliance:     $($output.compliancePercentage)%" -ForegroundColor $(if ($output.compliancePercentage -eq 100) { 'Green' } else { 'Yellow' })

    # CI step summary
    Write-CIStepSummary -Content "## Copyright Header Validation`n"

    if ($output.filesMissingHeaders -eq 0) {
        Write-CIStepSummary -Content "✅ **Status**: Passed`n`nAll $($output.totalFiles) files have required copyright headers."
    }
    else {
        $failingFiles = ($results | Where-Object { -not $_.valid } | ForEach-Object {
            $m = @()
            if (-not $_.hasCopyright) { $m += 'copyright' }
            if (-not $_.hasSpdx) { $m += 'SPDX' }
            "| ``$($_.file)`` | $($m -join ', ') |"
        }) -join "`n"

        Write-CIStepSummary -Content @"
❌ **Status**: Failed

| Metric | Count |
|--------|-------|
| Total Files | $($output.totalFiles) |
| With Headers | $($output.filesWithHeaders) |
| Missing Headers | $($output.filesMissingHeaders) |
| Compliance | $($output.compliancePercentage)% |

### Files Missing Headers

| File | Missing |
|------|--------|
$failingFiles
"@
    }

    # Throw if requested and files are missing headers
    if ($FailOnMissing -and $filesMissingHeaders -gt 0) {
        throw "Validation failed: $filesMissingHeaders file(s) missing required headers"
    }

    Write-Host "`n✅ Copyright header validation complete" -ForegroundColor Green
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-CopyrightHeaderCheck -Path $Path -FileExtensions $FileExtensions -OutputPath $OutputPath -FailOnMissing:$FailOnMissing -ExcludePaths $ExcludePaths
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Copyright header validation failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}

#endregion Main Execution
