# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Compares current agent files against the tracking manifest to determine
# file status for upgrade operations (managed, modified, ejected, missing).
# Usage: check-file-status.ps1

$ErrorActionPreference = 'Stop'

$manifest = Get-Content ".hve-tracking.json" | ConvertFrom-Json -AsHashtable
$statusReport = @()

foreach ($file in $manifest.files.Keys) {
    $entry = $manifest.files[$file]
    $status = $entry.status

    if ($status -eq "ejected") {
        $statusReport += @{
            file   = $file
            status = "ejected"
            action = "Skip (user owns this file)"
        }
        continue
    }

    if (-not (Test-Path $file)) {
        $statusReport += @{
            file   = $file
            status = "missing"
            action = "Will restore"
        }
        continue
    }

    $currentHash = (Get-FileHash -Path $file -Algorithm SHA256).Hash.ToLower()
    if ($currentHash -ne $entry.sha256) {
        $statusReport += @{
            file        = $file
            status      = "modified"
            action      = "Requires decision"
            currentHash = $currentHash
            storedHash  = $entry.sha256
        }
    } else {
        $statusReport += @{
            file   = $file
            status = "managed"
            action = "Will update"
        }
    }
}

$statusReport | ForEach-Object {
    Write-Host "FILE=$($_.file)|STATUS=$($_.status)|ACTION=$($_.action)"
}
