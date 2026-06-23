# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# _AgentMatrixFixtures.psm1
#
# Purpose: Shared fixture builders and regex helpers for
# `New-AgentMatrixDashboard.ps1` Pester tests. Leading underscore keeps the
# filename out of Pester's default `*.Tests.ps1` discovery.
#

function New-FixtureRoot {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] [string]$Base)

    $root = Join-Path $Base ("amd-" + [Guid]::NewGuid().ToString('N'))
    $matrixRoot = Join-Path $root 'evals/results/agent-matrix'
    $surfaceRoot = Join-Path $root 'evals/baseline-equivalence/surface-signatures'
    $inventoryPath = Join-Path $root 'evals/agent-behavior/AGENTS.yml'
    New-Item -ItemType Directory -Path $matrixRoot, $surfaceRoot -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $inventoryPath) -Force | Out-Null
    return [pscustomobject]@{
        Root          = $root
        MatrixRoot    = $matrixRoot
        SurfaceRoot   = $surfaceRoot
        InventoryPath = $inventoryPath
    }
}

function New-FixtureInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [hashtable[]]$Agents
    )

    $lines = @('agents:')
    foreach ($a in $Agents) {
        $lines += "  - slug: $($a.slug)"
        $lines += "    class: $($a.class)"
        $lines += "    cost_tier: $($a.cost_tier)"
        $lines += "    path: .github/agents/$($a.slug).agent.md"
    }
    Set-Content -LiteralPath $Path -Value ($lines -join "`n") -Encoding utf8NoBOM
}

function New-FixtureDatedRun {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string]$MatrixRoot,
        [Parameter(Mandatory)] [string]$Date,
        [Parameter(Mandatory)] [hashtable[]]$Results,
        [string]$Tier = 'nightly',
        [string]$Mode = 'all',
        [string]$Overall = 'pass'
    )

    $runDir = Join-Path $MatrixRoot $Date
    New-Item -ItemType Directory -Path $runDir -Force | Out-Null

    foreach ($r in $Results) {
        $perAgent = [ordered]@{
            slug      = $r.slug
            class     = $r.class
            cost_tier = $r.cost_tier
            graders   = if ($r.ContainsKey('graders')) { $r.graders } else { @() }
            overall   = $r.overall
            exitCode  = if ($r.ContainsKey('exitCode')) { $r.exitCode } else { 0 }
            logPath   = "logs/agent-matrix/$($r.slug)-fake.log"
        }
        Set-Content `
            -LiteralPath (Join-Path $runDir "$($r.slug).json") `
            -Value ($perAgent | ConvertTo-Json -Depth 4) `
            -Encoding utf8NoBOM
    }

    $summary = [ordered]@{
        generatedAt     = "$($Date)T12:00:00Z"
        tier            = $Tier
        mode            = $Mode
        agentCount      = $Results.Count
        overall         = $Overall
        failures        = @($Results | Where-Object { $_.overall -eq 'fail' } | ForEach-Object { $_.slug })
        results         = @($Results | ForEach-Object {
            [ordered]@{
                slug      = $_.slug
                class     = $_.class
                cost_tier = $_.cost_tier
                graders   = if ($_.ContainsKey('graders')) { $_.graders } else { @() }
                overall   = $_.overall
                exitCode  = if ($_.ContainsKey('exitCode')) { $_.exitCode } else { 0 }
                logPath   = "logs/agent-matrix/$($_.slug)-fake.log"
            }
        })
        plannedCommands = @($Results | ForEach-Object { "npx vally eval --eval-spec evals/agent-behavior/stimuli/$($_.slug).yml" })
    }
    $summaryPath = Join-Path $runDir 'agent-matrix-summary.json'
    Set-Content -LiteralPath $summaryPath -Value ($summary | ConvertTo-Json -Depth 5) -Encoding utf8NoBOM
    return $summaryPath
}

function Get-DrillRowRegex {
    <#
    .SYNOPSIS
    Builds a regex string that anchors to a dashboard drill row for a given agent slug.

    .DESCRIPTION
    Returns a `(?s)`-prefixed pattern that locates the `<tr class="drill"
    data-drill-for="<slug>">` row in rendered dashboard HTML, then matches the
    caller-supplied `Inner` fragment anywhere inside that row. The slug is
    regex-escaped; `Inner` is appended as-is so callers can compose subpatterns.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string]$Slug,
        [Parameter(Mandatory)] [string]$Inner
    )

    return '(?s)data-drill-for="' + [regex]::Escape($Slug) + '"[^>]*>.*?' + $Inner
}

Export-ModuleMember -Function New-FixtureRoot, New-FixtureInventory, New-FixtureDatedRun, Get-DrillRowRegex
