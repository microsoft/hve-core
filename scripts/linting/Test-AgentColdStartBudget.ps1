#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Enforces cold-start byte budgets for agents in the planning chain.

.DESCRIPTION
    For each agent in the budgets file, sums the bytes of the agent file, every file
    reached through `#file:` directives (followed recursively and resolved relative to
    the file that contains the directive), and every instruction file whose `applyTo`
    is always-on (`**` or `**/*`). Byte counts normalize CRLF to LF so results match
    across platforms.

    An agent above its `ceiling` fails. An agent above its `target` but at or below the
    ceiling passes with a warning. A missing agent or an unresolved `#file:` target is
    an error. This is a static proxy for host cold-start loading; it does not model
    host-specific `applyTo` matching against open editor files.

.PARAMETER RepoRoot
    Repository root. Defaults to the git top level.

.PARAMETER ConfigPath
    Budgets file. Defaults to `scripts/linting/agent-cold-start-budgets.json`.

.PARAMETER OutputPath
    JSON results path. Defaults to `logs/agent-cold-start-results.json`.

.EXAMPLE
    ./Test-AgentColdStartBudget.ps1

.NOTES
    Runs via: npm run lint:cold-start
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = ((git rev-parse --show-toplevel 2>$null) ?? (Join-Path $PSScriptRoot '../..')),

    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = '',

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Functions

function Get-NormalizedByteCount {
    <#
    .SYNOPSIS
        Returns the UTF-8 byte count of a file with CRLF normalized to LF.
    #>
    [CmdletBinding()]
    [OutputType([long])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $text = [System.IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    return [long][System.Text.Encoding]::UTF8.GetByteCount($text)
}

function ConvertTo-RepoRelativePath {
    <#
    .SYNOPSIS
        Converts an absolute path to a forward-slash repository-relative path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.Path]::GetRelativePath($RepoRoot, $Path).Replace('\', '/')
}

function Get-AlwaysOnInstructionPath {
    <#
    .SYNOPSIS
        Lists instruction files whose applyTo attaches to every file.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $instructionRoot = Join-Path $RepoRoot '.github/instructions'
    if (-not (Test-Path -Path $instructionRoot -PathType Container)) {
        return @()
    }

    $alwaysOn = foreach ($file in Get-ChildItem -Path $instructionRoot -Recurse -File -Filter '*.instructions.md') {
        $content = [System.IO.File]::ReadAllText($file.FullName)
        $frontmatter = [regex]::Match($content, '(?s)\A---\r?\n(.*?)\r?\n---')
        if (-not $frontmatter.Success) { continue }
        $applyTo = [regex]::Match($frontmatter.Groups[1].Value, '(?m)^applyTo:\s*(.+?)\s*$')
        if (-not $applyTo.Success) { continue }
        $patterns = $applyTo.Groups[1].Value.Trim().Trim("'", '"') -split ','
        if (@($patterns | Where-Object { $_.Trim() -in @('**', '**/*') }).Count -gt 0) {
            $file.FullName
        }
    }

    return @($alwaysOn | Sort-Object)
}

function Get-AgentColdStartSet {
    <#
    .SYNOPSIS
        Resolves the files an agent loads at cold start and their normalized byte counts.
    .OUTPUTS
        [hashtable] @{ Files = @(@{ Path; Bytes }); Bytes; Issues }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$AgentPath,

        [Parameter(Mandatory = $false)]
        [string[]]$AlwaysOnInstructions = @()
    )

    $issues = [System.Collections.Generic.List[string]]::new()
    $files = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $queue = [System.Collections.Generic.Queue[string]]::new()

    $agentFullPath = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $AgentPath))
    if (-not (Test-Path -Path $agentFullPath -PathType Leaf)) {
        $issues.Add("Agent not found: $AgentPath")
        return @{ Files = @(); Bytes = [long]0; Issues = $issues.ToArray() }
    }

    $queue.Enqueue($agentFullPath)
    foreach ($instruction in $AlwaysOnInstructions) { $queue.Enqueue([System.IO.Path]::GetFullPath($instruction)) }

    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        if (-not $seen.Add($current)) { continue }

        $relative = ConvertTo-RepoRelativePath -RepoRoot $RepoRoot -Path $current
        $files.Add(@{ Path = $relative; Bytes = (Get-NormalizedByteCount -Path $current) })

        $content = [System.IO.File]::ReadAllText($current)
        foreach ($match in [regex]::Matches($content, '#file:([^\s`''"()\[\]<>,]+)')) {
            $target = $match.Groups[1].Value.TrimEnd('.', ':', ';')
            $resolved = [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $current) $target))
            if (Test-Path -Path $resolved -PathType Leaf) {
                $queue.Enqueue($resolved)
            }
            else {
                $issues.Add("Unresolved #file: target '$target' in $relative")
            }
        }
    }

    $total = [long]0
    foreach ($entry in $files) { $total += $entry.Bytes }
    $sorted = @($files | Sort-Object { $_.Path })
    return @{ Files = $sorted; Bytes = $total; Issues = $issues.ToArray() }
}

function Test-AgentColdStartBudget {
    <#
    .SYNOPSIS
        Evaluates every configured agent against its cold-start byte budget.
    .OUTPUTS
        [hashtable] @{ Passed; Agents; Issues; Warnings }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath
    )

    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
    $issues = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $agents = [System.Collections.Generic.List[object]]::new()
    $alwaysOn = Get-AlwaysOnInstructionPath -RepoRoot $RepoRoot

    foreach ($agentPath in @($config.agents.Keys | Sort-Object)) {
        $budget = $config.agents[$agentPath]
        $target = [long]$budget.target
        $ceiling = [long]$budget.ceiling
        if ($ceiling -lt $target) { $issues.Add("$agentPath ceiling $ceiling is below target $target") }
        if ([string]::IsNullOrWhiteSpace([string]$budget.rationale)) { $issues.Add("$agentPath has no budget rationale") }

        $set = Get-AgentColdStartSet -RepoRoot $RepoRoot -AgentPath $agentPath -AlwaysOnInstructions $alwaysOn
        foreach ($issue in $set.Issues) { $issues.Add($issue) }

        $status = if ($set.Issues.Count -gt 0) { 'error' }
        elseif ($set.Bytes -gt $ceiling) { 'over-ceiling' }
        elseif ($set.Bytes -gt $target) { 'within-tolerance' }
        else { 'within-target' }

        if ($status -eq 'over-ceiling') { $issues.Add("$agentPath cold-start set is $($set.Bytes) bytes, above its $ceiling-byte ceiling") }
        if ($status -eq 'within-tolerance') { $warnings.Add("$agentPath cold-start set is $($set.Bytes) bytes, above its $target-byte target") }

        $agents.Add([ordered]@{
                agent   = $agentPath
                bytes   = $set.Bytes
                target  = $target
                ceiling = $ceiling
                status  = $status
                files   = $set.Files
            })
    }

    return @{
        Passed   = ($issues.Count -eq 0)
        Agents   = $agents.ToArray()
        Issues   = $issues.ToArray()
        Warnings = $warnings.ToArray()
    }
}

function Invoke-AgentColdStartBudgetCheck {
    <#
    .SYNOPSIS
        Runs the budget check, writes JSON results, reports each agent, and returns the process exit code.
    .OUTPUTS
        [int] 0 when every budget passes; 1 when any issue is found or the check fails.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = '',

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = ''
    )

    try {
        if ([string]::IsNullOrWhiteSpace($ConfigPath)) { $ConfigPath = Join-Path $RepoRoot 'scripts/linting/agent-cold-start-budgets.json' }
        if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $RepoRoot 'logs/agent-cold-start-results.json' }

        $result = Test-AgentColdStartBudget -RepoRoot $RepoRoot -ConfigPath $ConfigPath
        New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
        $result | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8

        foreach ($agent in $result.Agents) {
            Write-Host ('{0,-14} {1,8:N0} / {2,8:N0} bytes  {3}' -f $agent.status, $agent.bytes, $agent.ceiling, $agent.agent)
        }
        foreach ($warning in $result.Warnings) { Write-Warning $warning }

        if (-not $result.Passed) {
            foreach ($issue in $result.Issues) { Write-Error -ErrorAction Continue $issue }
            return 1
        }

        Write-Host 'Agent cold-start budget check passed.' -ForegroundColor Green
        return 0
    }
    catch {
        Write-Error -ErrorAction Continue "Test-AgentColdStartBudget failed: $($_.Exception.Message)"
        return 1
    }
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-AgentColdStartBudgetCheck -RepoRoot $RepoRoot -ConfigPath $ConfigPath -OutputPath $OutputPath)
}

#endregion Main Execution
