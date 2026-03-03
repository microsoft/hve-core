# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Detects file collisions before copying HVE-Core agents.
.DESCRIPTION
    Checks the target directory for existing agent files that would conflict
    with the selected agent bundle or collection.
.PARAMETER Selection
    Agent bundle to check. Use 'hve-core' for the default set or a collection identifier.
.PARAMETER CollectionAgents
    Array of agent file paths relative to the agents directory for non-default collections.
.EXAMPLE
    ./scripts/collision-detection.ps1 -Selection hve-core
.EXAMPLE
    ./scripts/collision-detection.ps1 -Selection my-collection -CollectionAgents @('my-collection/custom.agent.md')
.OUTPUTS
    COLLISIONS_DETECTED=true/false and COLLISION_FILES list.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Selection,

    [Parameter()]
    [string[]]$CollectionAgents = @()
)

$ErrorActionPreference = 'Stop'

$targetDir = ".github/agents"

# Get files to copy based on selection (paths relative to agents/)
$filesToCopy = switch ($selection) {
    "hve-core" { @("hve-core/task-researcher.agent.md", "hve-core/task-planner.agent.md", "hve-core/task-implementor.agent.md", "hve-core/task-reviewer.agent.md", "hve-core/rpi-agent.agent.md") }
    default {
        # Collection-based: paths from collection manifest relative to agents/
        $collectionAgents
    }
}

# Check for collisions (target uses filename only)
$collisions = @()
foreach ($file in $filesToCopy) {
    $fileName = Split-Path $file -Leaf
    $targetPath = Join-Path $targetDir $fileName
    if (Test-Path $targetPath) { $collisions += $targetPath }
}

if ($collisions.Count -gt 0) {
    Write-Host "COLLISIONS_DETECTED=true"
    Write-Host "COLLISION_FILES=$($collisions -join ',')"
} else {
    Write-Host "COLLISIONS_DETECTED=false"
}
