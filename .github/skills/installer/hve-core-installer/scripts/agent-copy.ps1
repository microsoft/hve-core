# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Copies selected HVE-Core agents to the target repository.
.DESCRIPTION
    Creates .github/agents/ directory, copies agent files, computes SHA256 hashes,
    and writes .hve-tracking.json manifest for upgrade tracking.
.PARAMETER HveCoreBasePath
    Root path of the local HVE-Core clone used as the copy source.
.PARAMETER CollectionId
    Collection identifier recorded in the tracking manifest.
.PARAMETER FilesToCopy
    Array of agent file paths relative to the source agents directory.
.PARAMETER KeepExisting
    When set, existing files listed in Collisions are preserved instead of overwritten.
.PARAMETER Collisions
    Array of target file paths that already exist and may conflict.
.EXAMPLE
    ./scripts/agent-copy.ps1 -HveCoreBasePath ../hve-core -CollectionId hve-core -FilesToCopy @('hve-core/task-researcher.agent.md')
.OUTPUTS
    Per-file copy status and manifest creation confirmation.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ })]
    [string]$HveCoreBasePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$CollectionId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$FilesToCopy,

    [Parameter()]
    [switch]$KeepExisting,

    [Parameter()]
    [string[]]$Collisions = @()
)

$ErrorActionPreference = 'Stop'

$sourceBase = "$hveCoreBasePath/.github/agents"
$targetDir = ".github/agents"
$manifestPath = ".hve-tracking.json"

# Create target directory
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Write-Host "✅ Created $targetDir"
}

# Initialize manifest
$manifest = @{
    source = "microsoft/hve-core"
    version = (Get-Content "$hveCoreBasePath/package.json" | ConvertFrom-Json).version
    installed = (Get-Date -Format "o")
    collection = $collectionId  # "hve-core" or collection id(s) e.g. "developer" or "developer,devops"
    files = @{}; skip = @()
}

# Copy files (source paths are relative to agents/, target is flat)
foreach ($file in $filesToCopy) {
    $fileName = Split-Path $file -Leaf
    $sourcePath = Join-Path $sourceBase $file
    $targetPath = Join-Path $targetDir $fileName
    $relPath = ".github/agents/$fileName"

    if ($keepExisting -and $collisions -contains $targetPath) {
        Write-Host "⏭️ Kept existing: $fileName"; continue
    }

    Set-Content -Path $targetPath -Value (Get-Content $sourcePath -Raw) -NoNewline
    $hash = (Get-FileHash -Path $targetPath -Algorithm SHA256).Hash.ToLower()
    $manifest.files[$relPath] = @{ version = $manifest.version; sha256 = $hash; status = "managed" }
    Write-Host "✅ Copied $fileName"
}

$manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath
Write-Host "✅ Created $manifestPath"
