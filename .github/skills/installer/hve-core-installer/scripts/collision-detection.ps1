<#
.SYNOPSIS
    Detects file collisions before copying HVE-Core agents.
.DESCRIPTION
    Checks the target directory for existing agent files that would conflict
    with the selected agent bundle or collection.
.NOTES
    Set $hveCoreBasePath, $selection ('hve-core' or collection id),
    and optionally $collectionAgents (array of relative paths) before running.
.OUTPUTS
    COLLISIONS_DETECTED=true/false and COLLISION_FILES list.
#>
$ErrorActionPreference = 'Stop'

$sourceBase = "$hveCoreBasePath/.github/agents"
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
