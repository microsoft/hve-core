#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Enforces cold-start byte budgets for agents in the planning chain.

.DESCRIPTION
    For each agent in the budgets file, sums the bytes of what the Copilot agent harness
    loads when the agent starts: the agent file, the SKILL.md of every skill named in its
    `skills` list, and every instruction file that loads into every main session (no
    `applyTo`, or an `applyTo` of `**` or `**/*`). Skills the agent activates by name
    load later and are not counted, and `#file:` directives load nothing. Byte counts
    normalize CRLF to LF so results match across platforms.

    An agent above its `ceiling` fails. An agent above its `target` but at or below the
    ceiling passes with a warning. A missing agent or an unresolved preloaded skill is an
    error. This is a static proxy for host cold-start loading; it does not model
    host-specific `applyTo` matching against files read during the session.

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

Import-Module (Join-Path $PSScriptRoot '../lib/Modules/ArtifactHelpers.psm1') -Force

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
        Lists instruction files that load into every main session.
    .DESCRIPTION
        Copilot inlines instructions that have no applyTo into every main session. An applyTo of
        '**' or '**/*' attaches as soon as any file is read, so those count as always-on too.
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
        if (-not $applyTo.Success) {
            $file.FullName
            continue
        }
        $patterns = $applyTo.Groups[1].Value.Trim().Trim("'", '"') -split ','
        if (@($patterns | Where-Object { $_.Trim() -in @('**', '**/*') }).Count -gt 0) {
            $file.FullName
        }
    }

    return @($alwaysOn | Sort-Object)
}

function Get-PreloadedSkillName {
    <#
    .SYNOPSIS
        Reads the skill names an agent preloads through its frontmatter skills list.
    .DESCRIPTION
        Parses the frontmatter as YAML, so comments, blank lines, and quoting don't change
        the result. Throws when the frontmatter is not valid YAML.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content
    )

    $frontmatter = [regex]::Match($Content, '(?s)\A---\r?\n(.*?)\r?\n---')
    if (-not $frontmatter.Success) { return @() }
    return @(Get-YamlFrontmatterList -Yaml $frontmatter.Groups[1].Value -Field 'skills')
}

function Get-AgentColdStartSet {
    <#
    .SYNOPSIS
        Resolves the files an agent loads at cold start and their normalized byte counts.
    .DESCRIPTION
        The set is the agent file, the SKILL.md of every skill named in its skills list, and the
        always-on instructions. Skills an agent activates by name load later and are not counted.
        `#file:` directives load nothing in Copilot, so they are not followed; the portability
        linter reports them.
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

    $agentFullPath = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $AgentPath))
    if (-not (Test-Path -Path $agentFullPath -PathType Leaf)) {
        $issues.Add("Agent not found: $AgentPath")
        return @{ Files = @(); Bytes = [long]0; Issues = $issues.ToArray() }
    }

    $members = [System.Collections.Generic.List[string]]::new()
    $members.Add($agentFullPath)

    $skillRoot = Join-Path $RepoRoot '.github/skills'
    $preloaded = @()
    try {
        $preloaded = @(Get-PreloadedSkillName -Content ([System.IO.File]::ReadAllText($agentFullPath)))
    }
    catch {
        $issues.Add("Unreadable frontmatter in ${AgentPath}: $($_.Exception.Message)")
    }
    foreach ($name in $preloaded) {
        $skillFile = $null
        if (Test-Path -Path $skillRoot -PathType Container) {
            $skillFile = Get-ChildItem -Path $skillRoot -Recurse -File -Filter 'SKILL.md' |
                Where-Object { $_.Directory.Name -eq $name } |
                Select-Object -First 1
        }
        if ($skillFile) { $members.Add($skillFile.FullName) }
        else { $issues.Add("Unresolved preloaded skill '$name' in $AgentPath") }
    }

    foreach ($instruction in $AlwaysOnInstructions) { $members.Add([System.IO.Path]::GetFullPath($instruction)) }

    foreach ($member in $members) {
        if (-not $seen.Add($member)) { continue }
        $files.Add(@{ Path = (ConvertTo-RepoRelativePath -RepoRoot $RepoRoot -Path $member); Bytes = (Get-NormalizedByteCount -Path $member) })
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
