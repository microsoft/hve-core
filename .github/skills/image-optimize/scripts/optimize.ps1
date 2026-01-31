#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Optimize images for web and documentation using ImageMagick.

.DESCRIPTION
    Compresses, resizes, and converts images for optimal web delivery.
    Supports PNG, JPEG, WebP, and GIF formats.

.PARAMETER InputPath
    Source image file or directory to optimize.

.PARAMETER OutputPath
    Destination path for optimized images. Defaults to 'optimized/'.

.PARAMETER Quality
    JPEG/WebP quality level (1-100). Default is 85.

.PARAMETER Format
    Output format: png, jpg, webp. Default preserves original format.

.PARAMETER Width
    Maximum width in pixels. Maintains aspect ratio.

.PARAMETER Height
    Maximum height in pixels. Maintains aspect ratio.

.PARAMETER Recursive
    Process subdirectories when input is a directory.

.PARAMETER Strip
    Remove metadata (EXIF, etc.). Default is true.

.EXAMPLE
    ./optimize.ps1 -InputPath screenshot.png
    Optimize a single image with default settings.

.EXAMPLE
    ./optimize.ps1 -InputPath ./images -Recursive -Quality 80
    Batch optimize all images in a directory.

.EXAMPLE
    ./optimize.ps1 -InputPath photo.jpg -Format webp -Width 1200
    Convert to WebP and resize to max 1200px width.

.NOTES
    Requires ImageMagick (magick command) in PATH.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$InputPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "optimized",

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 100)]
    [int]$Quality = 85,

    [Parameter(Mandatory = $false)]
    [ValidateSet('png', 'jpg', 'jpeg', 'webp', '')]
    [string]$Format = '',

    [Parameter(Mandatory = $false)]
    [int]$Width,

    [Parameter(Mandatory = $false)]
    [int]$Height,

    [Parameter(Mandatory = $false)]
    [switch]$Recursive,

    [Parameter(Mandatory = $false)]
    [bool]$Strip = $true
)

function Test-ImageMagick {
    try {
        $null = & magick -version 2>&1
        return $true
    }
    catch {
        return $false
    }
}

function Get-FormattedSize {
    param([long]$Bytes)
    
    if ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    }
    elseif ($Bytes -ge 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    }
    else {
        return "$Bytes bytes"
    }
}

function Optimize-SingleImage {
    param(
        [string]$Input,
        [string]$Output,
        [int]$Quality,
        [string]$Format,
        [int]$Width,
        [int]$Height,
        [bool]$Strip
    )

    $args = @($Input)

    # Resize if dimensions specified
    if ($Width -and $Height) {
        $args += @('-resize', "${Width}x${Height}>")
    }
    elseif ($Width) {
        $args += @('-resize', "${Width}x>")
    }
    elseif ($Height) {
        $args += @('-resize', "x${Height}>")
    }

    # Strip metadata
    if ($Strip) {
        $args += '-strip'
    }

    # Quality setting
    $args += @('-quality', $Quality)

    # Determine output filename
    $outputFile = $Output
    if ($Format) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($Output)
        $outputDir = [System.IO.Path]::GetDirectoryName($Output)
        $outputFile = Join-Path $outputDir "$baseName.$Format"
    }

    $args += $outputFile

    # Run ImageMagick
    & magick @args

    return $outputFile
}

function Process-ImageFile {
    param(
        [string]$InputFile,
        [string]$OutputDir,
        [int]$Quality,
        [string]$Format,
        [int]$Width,
        [int]$Height,
        [bool]$Strip,
        [string]$BaseInputDir
    )

    # Determine relative path for output structure
    $relPath = ''
    if ($BaseInputDir) {
        $relPath = [System.IO.Path]::GetRelativePath($BaseInputDir, [System.IO.Path]::GetDirectoryName($InputFile))
        if ($relPath -eq '.') {
            $relPath = ''
        }
    }

    $filename = [System.IO.Path]::GetFileName($InputFile)
    
    $outputSubDir = $OutputDir
    if ($relPath) {
        $outputSubDir = Join-Path $OutputDir $relPath
    }

    if (-not (Test-Path $outputSubDir)) {
        New-Item -ItemType Directory -Path $outputSubDir -Force | Out-Null
    }

    $outputFile = Join-Path $outputSubDir $filename
    $originalSize = (Get-Item $InputFile).Length

    $result = Optimize-SingleImage -Input $InputFile -Output $outputFile -Quality $Quality -Format $Format -Width $Width -Height $Height -Strip $Strip

    $newSize = (Get-Item $result).Length
    $reduction = 0
    if ($originalSize -gt 0) {
        $reduction = [math]::Round((($originalSize - $newSize) / $originalSize) * 100)
    }

    Write-Host "  $filename: $(Get-FormattedSize $originalSize) → $(Get-FormattedSize $newSize) ($reduction% reduction)"
}

# Check dependencies
if (-not (Test-ImageMagick)) {
    Write-Error "ImageMagick is required. Install via: choco install imagemagick (Windows) or brew install imagemagick (macOS)"
    exit 1
}

# Validate input
if (-not (Test-Path $InputPath)) {
    Write-Error "Input not found: $InputPath"
    exit 1
}

Write-Host "🖼️  Optimizing images..." -ForegroundColor Cyan
Write-Host "   Quality: $Quality" -ForegroundColor Gray
if ($Format) { Write-Host "   Format: $Format" -ForegroundColor Gray }
if ($Width) { Write-Host "   Max width: ${Width}px" -ForegroundColor Gray }
if ($Height) { Write-Host "   Max height: ${Height}px" -ForegroundColor Gray }
Write-Host ""

# Process input
$count = 0
$inputItem = Get-Item $InputPath

if ($inputItem.PSIsContainer) {
    # Directory processing
    $searchOption = if ($Recursive) { 'AllDirectories' } else { 'TopDirectoryOnly' }
    $extensions = @('*.png', '*.jpg', '*.jpeg', '*.webp', '*.gif')
    
    $files = @()
    foreach ($ext in $extensions) {
        $files += Get-ChildItem -Path $InputPath -Filter $ext -Recurse:$Recursive -File -ErrorAction SilentlyContinue
    }

    foreach ($file in $files) {
        Process-ImageFile -InputFile $file.FullName -OutputDir $OutputPath -Quality $Quality -Format $Format -Width $Width -Height $Height -Strip $Strip -BaseInputDir $InputPath
        $count++
    }
}
else {
    # Single file processing
    Process-ImageFile -InputFile $InputPath -OutputDir $OutputPath -Quality $Quality -Format $Format -Width $Width -Height $Height -Strip $Strip -BaseInputDir ''
    $count = 1
}

Write-Host ""
Write-Host "✅ Optimized $count image(s)" -ForegroundColor Green
Write-Host "   Output: $(Resolve-Path $OutputPath)" -ForegroundColor Gray
