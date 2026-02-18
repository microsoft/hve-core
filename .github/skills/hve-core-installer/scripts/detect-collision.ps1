# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Detects collisions between HVE-Core source agents and existing agents
# in the target directory before copy operations.
# Usage: detect-collision.ps1 -Selection <rpi-core|collection> -HveCoreBasePath <path> [-CollectionAgents <files>]
#   Selection:        'rpi-core' or 'collection'
#   HveCoreBasePath:  Path to the HVE-Core clone root
#   CollectionAgents: Agent filenames when selection is 'collection'

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('rpi-core', 'collection')]
    [string]$Selection,

    [Parameter(Mandatory)]
    [string]$HveCoreBasePath,

    [Parameter()]
    [string[]]$CollectionAgents = @()
)

$ErrorActionPreference = 'Stop'

$sourceDir = "$HveCoreBasePath/.github/agents"
$targetDir = ".github/agents"

# Get files to copy based on selection
$filesToCopy = switch ($Selection) {
    "rpi-core" { @("task-researcher.agent.md", "task-planner.agent.md", "task-implementor.agent.md", "task-reviewer.agent.md", "rpi-agent.agent.md") }
    "collection" { $CollectionAgents }
}

# Check for collisions
$collisions = @()
foreach ($file in $filesToCopy) {
    $targetPath = Join-Path $targetDir $file
    if (Test-Path $targetPath) { $collisions += $targetPath }
}

if ($collisions.Count -gt 0) {
    Write-Host "COLLISIONS_DETECTED=true"
    Write-Host "COLLISION_FILES=$($collisions -join ',')"
} else {
    Write-Host "COLLISIONS_DETECTED=false"
}
