#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0
<#
.SYNOPSIS
    Builds customer cards as a PPTX deck.
.DESCRIPTION
    Runs two sequential steps:
      1. Generates per-slide content YAML from canonical markdown using generate_cards.py.
      2. Builds customer-cards.pptx using the PowerPoint skill pipeline.
    Requires Python 3.11+ and the PowerPoint skill pipeline.
.PARAMETER OutputPath
    Destination path for the output PPTX file.
    Default: <script-dir>/output/customer-cards.pptx
.PARAMETER CanonicalDir
    Path to the canonical markdown source directory.
    Default: <script-dir>/../canonical
.PARAMETER ContentDir
    Directory where generated per-slide YAML content is written.
    Default: <script-dir>/content
.EXAMPLE
    ./build-cards.ps1
    Generates YAML and builds PPTX using default paths.
.EXAMPLE
    ./build-cards.ps1 -OutputPath C:\Decks\customer-cards.pptx
    Writes the PPTX to a custom path.
.NOTES
    The PowerPoint pipeline script is resolved relative to this script's location.
    Path: ../../scripts/Invoke-PptxPipeline.ps1
    For DT project usage, pass explicit -CanonicalDir, -ContentDir, and -OutputPath.
#>
[CmdletBinding()]
param(
    [string]$OutputPath = "$PSScriptRoot/output/customer-cards.pptx",
    [string]$CanonicalDir = "$PSScriptRoot/../canonical",
    [string]$ContentDir = "$PSScriptRoot/content"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Pre-flight: verify required dependencies
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Python is not installed or not on PATH." -ForegroundColor Red
    Write-Host "   Install Python 3.11+ from https://python.org or via your package manager." -ForegroundColor Yellow
    exit 1
}

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "❌ uv is not installed or not on PATH." -ForegroundColor Red
    Write-Host "   Install uv: irm https://astral.sh/uv/install.ps1 | iex" -ForegroundColor Yellow
    exit 1
}

$SkillScript = Join-Path $PSScriptRoot "../../scripts/Invoke-PptxPipeline.ps1"

# Ensure output/content directories exist
$OutputDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
if (-not (Test-Path $ContentDir)) {
    New-Item -ItemType Directory -Path $ContentDir -Force | Out-Null
}

# Step 1: Generate content YAML from canonical markdown
Write-Host "==> Step 1: Generate card content YAML" -ForegroundColor Cyan
python "$PSScriptRoot/generate_cards.py" --canonical-dir $CanonicalDir --output-dir $ContentDir
if ($LASTEXITCODE -ne 0) {
    Write-Error "generate_cards.py failed with exit code $LASTEXITCODE"
}

# Step 2: Build PPTX deck
Write-Host "`n==> Step 2: Build PPTX deck" -ForegroundColor Cyan
& $SkillScript `
    -Action Build `
    -ContentDir $ContentDir `
    -StylePath (Join-Path $ContentDir "global/style.yaml") `
    -OutputPath $OutputPath

Write-Host "`n==> Complete." -ForegroundColor Green
Write-Host "  PPTX   : $OutputPath"
