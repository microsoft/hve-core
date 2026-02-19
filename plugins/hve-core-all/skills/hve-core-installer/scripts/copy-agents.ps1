# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Copies selected HVE-Core agent files to the target repository and creates
# a tracking manifest (.hve-tracking.json) for upgrade management.
# Usage: copy-agents.ps1 -Selection <rpi-core|collection> -HveCoreBasePath <path> -CollectionId <id> [-KeepExisting] [-CollectionAgents <files>]
#   Selection:        'rpi-core' or 'collection'
#   HveCoreBasePath:  Path to the HVE-Core clone root
#   CollectionId:     Collection identifier for manifest tracking
#   KeepExisting:     Skip files that already exist (collision resolution)
#   CollectionAgents: Agent filenames when selection is 'collection'

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('rpi-core', 'collection')]
    [string]$Selection,

    [Parameter(Mandatory)]
    [string]$HveCoreBasePath,

    [Parameter(Mandatory)]
    [string]$CollectionId,

    [Parameter()]
    [switch]$KeepExisting,

    [Parameter()]
    [string[]]$CollectionAgents = @()
)

$ErrorActionPreference = 'Stop'

$sourceDir = "$HveCoreBasePath/.github/agents"
$targetDir = ".github/agents"
$manifestPath = ".hve-tracking.json"

# Create target directory
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Write-Host "✅ Created $targetDir"
}

# Get files to copy based on selection
$filesToCopy = switch ($Selection) {
    "rpi-core" { @("task-researcher.agent.md", "task-planner.agent.md", "task-implementor.agent.md", "task-reviewer.agent.md", "rpi-agent.agent.md") }
    "collection" { $CollectionAgents }
}

# Initialize manifest
$manifest = @{
    source     = "microsoft/hve-core"
    version    = (Get-Content "$HveCoreBasePath/package.json" | ConvertFrom-Json).version
    installed  = (Get-Date -Format "o")
    collection = $CollectionId
    files      = @{}
    skip       = @()
}

# Copy files
foreach ($file in $filesToCopy) {
    $sourcePath = Join-Path $sourceDir $file
    $targetPath = Join-Path $targetDir $file
    $relPath = ".github/agents/$file"

    if ($KeepExisting -and (Test-Path $targetPath)) {
        Write-Host "⏭️ Kept existing: $file"
        continue
    }

    Set-Content -Path $targetPath -Value (Get-Content $sourcePath -Raw) -NoNewline
    $hash = (Get-FileHash -Path $targetPath -Algorithm SHA256).Hash.ToLower()
    $manifest.files[$relPath] = @{ version = $manifest.version; sha256 = $hash; status = "managed" }
    Write-Host "✅ Copied $file"
}

$manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath
Write-Host "✅ Created $manifestPath"
