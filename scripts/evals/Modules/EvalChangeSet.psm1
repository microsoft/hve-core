# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# EvalChangeSet.psm1
# Purpose: Share immutable Git comparison evidence across evaluation selectors.
#Requires -Version 7.4

Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'ArtifactDetection.psm1')

function Invoke-EvalGit {
    <#
    .SYNOPSIS
    Runs Git with separate output streams and throws on failure.
    .PARAMETER RepoRoot
    Repository working directory.
    .PARAMETER Arguments
    Literal Git arguments.
    .PARAMETER GitCommand
    Git executable, overridable for deterministic failure tests.
    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string[]]$Arguments,
        [string]$GitCommand = 'git'
    )

    $StartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $StartInfo.FileName = $GitCommand
    $StartInfo.WorkingDirectory = (Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop).ProviderPath
    $StartInfo.UseShellExecute = $false
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.RedirectStandardError = $true
    $StartInfo.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $StartInfo.StandardErrorEncoding = [System.Text.UTF8Encoding]::new($false)
    $StartInfo.ArgumentList.Add('--no-pager')
    foreach ($Argument in $Arguments) { $StartInfo.ArgumentList.Add($Argument) }
    $Process = [System.Diagnostics.Process]::new()
    $Process.StartInfo = $StartInfo
    try {
        $null = $Process.Start()
        $Stdout = $Process.StandardOutput.ReadToEndAsync()
        $Stderr = $Process.StandardError.ReadToEndAsync()
        $Process.WaitForExit()
        $OutputText = $Stdout.GetAwaiter().GetResult()
        $ErrorText = $Stderr.GetAwaiter().GetResult()
        if ($Process.ExitCode -ne 0) {
            throw "git $($Arguments -join ' ') failed (exit $($Process.ExitCode)): $ErrorText$OutputText"
        }
        if (-not [string]::IsNullOrWhiteSpace($ErrorText)) { Write-Warning $ErrorText.Trim() }
        return $OutputText
    }
    finally { $Process.Dispose() }
}

function Assert-EvalChangeSet {
    <#
    .SYNOPSIS
    Rejects malformed comparison evidence instead of interpreting it as no changes.
    .PARAMETER ChangeSet
    Deserialized versioned change set.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$ChangeSet)

    if ($ChangeSet['schemaVersion'] -cne '1.0') { throw 'Unsupported eval change-set schemaVersion.' }
    foreach ($Name in @('baseRef', 'headRef', 'comparisonBase')) {
        if ($ChangeSet[$Name] -isnot [string] -or $ChangeSet[$Name] -cnotmatch '^[0-9a-f]{40}$') {
            throw "Eval change-set $Name must be a resolved commit SHA."
        }
    }
    if ($ChangeSet['changes'] -isnot [array]) { throw 'Eval change-set changes must be an array.' }
    $Seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($Change in $ChangeSet['changes']) {
        if ($Change -isnot [System.Collections.IDictionary] -or $Change['status'] -cnotmatch '^[AMDTRC]$') {
            throw 'Invalid eval change-set record status.'
        }
        $Paths = @($Change['path'])
        if ($Change['status'] -in @('R', 'C')) {
            $Paths += $Change['previousPath']
        }
        elseif (-not $Change.Contains('previousPath') -or $null -ne $Change['previousPath']) {
            throw 'Non-rename eval change-set record must have a null previousPath.'
        }
        foreach ($Path in $Paths) {
            if ($Path -isnot [string] -or [string]::IsNullOrWhiteSpace($Path) -or
                $Path -match '[\\:\x00]|^/|/$|//|(^|/)\.\.?(/|$)') {
                throw "Invalid repository-relative eval change-set path '$Path'."
            }
        }
        if (-not $Seen.Add($Change['path'])) { throw "Duplicate eval change-set path '$($Change['path'])'." }
    }
}

function New-EvalChangeSet {
    <#
    .SYNOPSIS
    Resolves two commits and freezes their three-dot comparison.
    .PARAMETER BaseRef
    Explicit base revision.
    .PARAMETER MergeRef
    Pull request test-merge commit; its first parent becomes the base after its
    second parent is verified to equal HeadRef.
    .PARAMETER HeadRef
    Explicit head revision, never inferred from the checkout.
    .PARAMETER RepoRoot
    Repository working directory.
    .PARAMETER GitCommand
    Git executable.
    .OUTPUTS
    System.Collections.IDictionary
    #>
    [CmdletBinding(DefaultParameterSetName = 'Base')]
    [OutputType([System.Collections.IDictionary])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Base')][string]$BaseRef,
        [Parameter(Mandatory, ParameterSetName = 'Merge')][string]$MergeRef,
        [Parameter(Mandatory)][string]$HeadRef,
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$GitCommand = 'git'
    )

    $Git = @{ RepoRoot = $RepoRoot; GitCommand = $GitCommand }
    $Head = (Invoke-EvalGit @Git -Arguments @('rev-parse', '--verify', '--end-of-options', "$HeadRef^{commit}")).Trim()
    if ($PSCmdlet.ParameterSetName -eq 'Merge') {
        $Merge = (Invoke-EvalGit @Git -Arguments @('rev-parse', '--verify', '--end-of-options', "$MergeRef^{commit}")).Trim()
        $Parents = @((Invoke-EvalGit @Git -Arguments @('rev-list', '--parents', '-n', '1', $Merge)).Trim() -split '\s+' | Select-Object -Skip 1)
        if ($Parents.Count -ne 2) {
            throw "Merge ref $Merge must have exactly two parents; found $($Parents.Count)."
        }
        if ($Parents[1] -ne $Head) {
            throw "Merge ref $Merge second parent $($Parents[1]) does not match head $Head."
        }
        $Base = $Parents[0]
    }
    else {
        $Base = (Invoke-EvalGit @Git -Arguments @('rev-parse', '--verify', '--end-of-options', "$BaseRef^{commit}")).Trim()
    }
    $MergeBases = (Invoke-EvalGit @Git -Arguments @('merge-base', '--all', $Base, $Head)).Trim() -split '\r?\n'
    if ($MergeBases.Count -ne 1) { throw 'Eval comparison requires exactly one merge base.' }
    $ComparisonBase = $MergeBases[0]
    $Diff = Invoke-EvalGit @Git -Arguments @('diff', '--no-ext-diff', '--no-textconv', '--name-status', '-z', '-M', $ComparisonBase, $Head, '--')
    $Records = ConvertFrom-GitDiffNameStatus -Lines @($Diff) -NullTerminated
    $Changes = @($Records | Sort-Object -Property path -CaseSensitive | ForEach-Object {
            [ordered]@{ status = $_.status; path = $_.path; previousPath = $_.previousPath }
        })
    $Result = [ordered]@{
        schemaVersion = '1.0'
        baseRef = $Base
        headRef = $Head
        comparisonBase = $ComparisonBase
        changes = $Changes
    }
    Assert-EvalChangeSet -ChangeSet $Result
    return $Result
}

function Read-EvalChangeSet {
    <#
    .SYNOPSIS
    Reads and validates a required canonical change-set file.
    .PARAMETER Path
    Literal manifest path.
    .OUTPUTS
    System.Collections.IDictionary
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.IDictionary])]
    param([Parameter(Mandatory)][string]$Path)

    $Result = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    if ($Result -isnot [System.Collections.IDictionary]) { throw "Invalid eval change-set object in '$Path'." }
    Assert-EvalChangeSet -ChangeSet $Result
    return $Result
}

function Test-EvalChangeSetRelevance {
    <#
    .SYNOPSIS
    Applies the existing eval path and package-content gates to frozen changes.
    .PARAMETER ChangeSet
    Canonical change set.
    .PARAMETER RepoRoot
    Repository used for revision-scoped package patches.
    .PARAMETER GitCommand
    Git executable.
    .OUTPUTS
    System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$ChangeSet,
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$GitCommand = 'git'
    )

    Assert-EvalChangeSet -ChangeSet $ChangeSet
    foreach ($Change in $ChangeSet.changes) {
        foreach ($Path in @($Change.path, $Change.previousPath)) {
            if (-not $Path) { continue }
            if ($Path -match '^(evals/|scripts/evals/|\.github/(agents|prompts|instructions|skills)/)') {
                Write-Host "Eval-relevant change: $Path"
                return $true
            }
            if ($Path -in @('package.json', 'package-lock.json')) {
                $Diff = Invoke-EvalGit -RepoRoot $RepoRoot -GitCommand $GitCommand -Arguments @(
                    'diff', '--no-ext-diff', '--no-textconv', $ChangeSet.comparisonBase, $ChangeSet.headRef, '--', $Path
                )
                $ChangedLines = @($Diff -split '\r?\n' | Where-Object { $_ -match '^[+-]' -and $_ -notmatch '^(\+\+\+|---)' })
                if ($ChangedLines -match 'vally|"ci:eval:') {
                    Write-Host "Eval-relevant package change: $Path"
                    return $true
                }
            }
        }
    }
    return $false
}

Export-ModuleMember -Function @('Invoke-EvalGit', 'Assert-EvalChangeSet', 'New-EvalChangeSet', 'Read-EvalChangeSet', 'Test-EvalChangeSetRelevance')
