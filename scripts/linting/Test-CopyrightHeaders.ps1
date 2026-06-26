#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
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
    Array of file extensions to check. Defaults to @('*.ps1', '*.psm1', '*.psd1', '*.sh', '*.py').

.PARAMETER OutputPath
    Path where results should be saved. Defaults to 'logs/copyright-header-results.json'.

.PARAMETER FailOnMissing
    Exit with error code if any files are missing required headers. Default is false.

.PARAMETER ExcludePaths
    Array of paths to exclude from scanning (supports wildcards).

.PARAMETER Fix
    Rewrite non-canonical headers and insert missing headers in place using the
    comment prefix appropriate to each file. Idempotent. Default is validation-only.

.EXAMPLE
    ./Test-CopyrightHeaders.ps1
    Scan repository for copyright header compliance.

.EXAMPLE
    ./Test-CopyrightHeaders.ps1 -FailOnMissing
    Scan and fail if any files are missing headers.

.EXAMPLE
    ./Test-CopyrightHeaders.ps1 -Fix
    Normalize headers in place across the discovered files.

.EXAMPLE
    ./Test-CopyrightHeaders.ps1 -Path "./scripts" -FileExtensions @('*.ps1')
    Scan only PowerShell files in scripts directory.

.NOTES
    Requires PowerShell 7.0 or later for cross-platform compatibility.

    Expected header format:
    - Copyright line: # Copyright (c) 2026 Microsoft Corporation. All rights reserved.
    - SPDX line: # SPDX-License-Identifier: MIT

    Headers should appear within the first 15 lines of the file,
    accounting for shebang and #Requires statements.

.LINK
    https://spdx.dev/ids/
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Path = (git rev-parse --show-toplevel 2>$null),

    [Parameter(Mandatory = $false)]
    [string[]]$FileExtensions = @('*.ps1', '*.psm1', '*.psd1', '*.sh', '*.py'),

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "logs/copyright-header-results.json",

    [Parameter(Mandatory = $false)]
    [switch]$FailOnMissing,

    [Parameter(Mandatory = $false)]
    [string[]]$ExcludePaths,

    [Parameter(Mandatory = $false)]
    [switch]$Fix
)

# Import shared helpers if available
$helpersPath = Join-Path $PSScriptRoot "Modules/LintingHelpers.psm1"
if (Test-Path $helpersPath) {
    Import-Module $helpersPath -Force
}
Import-Module (Join-Path $PSScriptRoot "../lib/Modules/CIHelpers.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "../lib/Modules/CopyrightHeader.psm1") -Force

# Canonical default exclusions shared between script-level param and Invoke-CopyrightHeaderCheck
$DefaultExcludePaths = @('node_modules', '.git', 'vendor', 'logs', '.venv', '.copilot-tracking', 'plugins')

if (-not $PSBoundParameters.ContainsKey('ExcludePaths')) {
    $ExcludePaths = $DefaultExcludePaths
}

# Lines to check (accounting for shebang, #Requires, etc.)
$MaxLinesToCheck = 15

#region Functions

function Get-CommentPrefixForFile {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $extension = [System.IO.Path]::GetExtension($FilePath)
    switch ($extension.ToLowerInvariant()) {
        '.ps1' { return '#' }
        '.psm1' { return '#' }
        '.psd1' { return '#' }
        '.sh' { return '#' }
        '.py' { return '#' }
        '.yml' { return '#' }
        '.yaml' { return '#' }
        '.ts' { return '//' }
        '.tsx' { return '//' }
        '.js' { return '//' }
        '.jsx' { return '//' }
        default { return '#' }
    }
}

function Repair-FileHeaders {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $commentPrefix = Get-CommentPrefixForFile -FilePath $FilePath
    $canonical = Get-CanonicalHeaderLines -CommentPrefix $commentPrefix
    $escapedPrefix = [regex]::Escape($commentPrefix)
    $copyrightLoose = "^\s*$escapedPrefix\s*Copyright\s*\(c\)"
    $licenseLoose = "^\s*$escapedPrefix\s*(?:SPDX-License-Identifier:|Licensed under)"
    $extension = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()

    $raw = Get-Content -Path $FilePath -Raw -ErrorAction Stop
    if ($null -eq $raw) { $raw = '' }
    $newline = if ($raw -match "`r`n") { "`r`n" } else { "`n" }
    $lines = [System.Collections.Generic.List[string]]@($raw -split "`r?`n")

    # Determine insertion index (after a shebang or a YAML document marker)
    $startIdx = 0
    if ($lines.Count -gt 0 -and $lines[0] -match '^#!') {
        $startIdx = 1
    }
    elseif (($extension -eq '.yml' -or $extension -eq '.yaml') -and $lines.Count -gt 0 -and $lines[0] -match '^---\s*$') {
        $startIdx = 1
    }

    # Locate an existing copyright line within the scan window
    $windowEnd = [math]::Min($lines.Count, $startIdx + $MaxLinesToCheck)
    $cpIdx = -1
    for ($i = $startIdx; $i -lt $windowEnd; $i++) {
        if ($lines[$i] -match $copyrightLoose) { $cpIdx = $i; break }
    }

    $original = ($lines.ToArray()) -join $newline

    if ($cpIdx -ge 0) {
        $lines[$cpIdx] = $canonical[0]
        if (($cpIdx + 1) -lt $lines.Count -and $lines[$cpIdx + 1] -match $licenseLoose) {
            $lines[$cpIdx + 1] = $canonical[1]
        }
        else {
            $lines.Insert($cpIdx + 1, $canonical[1])
        }
    }
    else {
        $lines.Insert($startIdx, $canonical[1])
        $lines.Insert($startIdx, $canonical[0])
    }

    $updated = ($lines.ToArray()) -join $newline
    if ($updated -ne $original) {
        # Preserve a BOM on files containing non-ASCII characters so PSScriptAnalyzer's
        # PSUseBOMForUnicodeEncodedFile rule stays satisfied; emit BOM-less UTF-8 otherwise.
        $encoding = if ($updated -match '[^\x00-\x7F]') { 'utf8BOM' } else { 'utf8' }
        Set-Content -Path $FilePath -Value $updated -NoNewline -Encoding $encoding
        return $true
    }

    return $false
}

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
        $commentPrefix = Get-CommentPrefixForFile -FilePath $FilePath
        $copyrightRegex = Get-CopyrightLineRegex -CommentPrefix $commentPrefix
        $spdxRegex = Get-SpdxLineRegex -CommentPrefix $commentPrefix

        # Read first N lines of file
        $lines = Get-Content -Path $FilePath -TotalCount $MaxLinesToCheck -ErrorAction Stop

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $lineNum = $i + 1

            if ($line -match $copyrightRegex) {
                $result.hasCopyright = $true
                $result.copyrightLine = $lineNum
            }

            if ($line -match $spdxRegex) {
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

    $excludeRegex = $null
    $validExcludes = @($Exclude | Where-Object { $_ })
    if ($validExcludes.Count -gt 0) {
        $sepPattern = '[/\\]'
        $excludeAlternation = ($validExcludes | ForEach-Object { [regex]::Escape($_) }) -join '|'
        $excludeRegex = "${sepPattern}(?:${excludeAlternation})(?:${sepPattern}|$)"
    }

    foreach ($ext in $Extensions) {
        $found = Get-ChildItem -Path $RootPath -Filter $ext -Recurse -File -Force -ErrorAction SilentlyContinue

        if ($excludeRegex) {
            $found = $found | Where-Object { $_.FullName -notmatch $excludeRegex }
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
        [string[]]$FileExtensions = @('*.ps1', '*.psm1', '*.psd1', '*.sh', '*.py'),

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "logs/copyright-header-results.json",

        [Parameter(Mandatory = $false)]
        [switch]$FailOnMissing,

        [Parameter(Mandatory = $false)]
        [string[]]$ExcludePaths = $script:DefaultExcludePaths,

        [Parameter(Mandatory = $false)]
        [switch]$Fix
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
    $filesFixed = 0

    foreach ($file in $filesToCheck) {
        if ($Fix) {
            if (Repair-FileHeaders -FilePath $file.FullName) {
                $filesFixed++
                Write-Host "  🔧 Fixed: $($file.FullName -replace [regex]::Escape($Path), '' -replace '^[\\/]', '')" -ForegroundColor Yellow
            }
        }

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
        Timestamp = Get-StandardTimestamp
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

    if ($Fix) {
        Write-Host "🔧 Files fixed: $filesFixed" -ForegroundColor Yellow
    }

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
        Invoke-CopyrightHeaderCheck -Path $Path -FileExtensions $FileExtensions -OutputPath $OutputPath -FailOnMissing:$FailOnMissing -ExcludePaths $ExcludePaths -Fix:$Fix
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Copyright header validation failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}

#endregion Main Execution
