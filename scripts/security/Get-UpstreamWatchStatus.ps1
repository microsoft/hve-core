#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Get-UpstreamWatchStatus.ps1
#
# Purpose: Evaluate upstream catch-up watches so the weekly code-scanning workflow
#          can open an issue when a workaround or tracked exception can retire.
# Author: HVE Core Team

#Requires -Version 7.4

<#
.SYNOPSIS
    Evaluates each upstream catch-up watch and reports whether it has triggered.

.DESCRIPTION
    Reads security/upstream-watches.yml, validates every watch, and evaluates it:

      issue-closed     the upstream issue or pull request is closed
      release-newer    the upstream repository's latest release is newer than pinned
      runner-version   a job on the runner label reported at least the minimum version
      probe-outcome    the named capability probe reported an outcome other than baseline

    Each watch reports State 'triggered', 'waiting', or 'unknown' (the condition
    could not be observed). Unknown is reported, never treated as triggered.
    An invalid watches file fails the script.

    Runner versions come from the job logs of runner probe jobs in a workflow run
    (-RunId), read from the "Current runner version" line the runner writes at job
    start. Probe outcomes come from an observations file (-ObservationsPath).

    Writes a JSON array to standard output, or with -ListRunnerLabels, a JSON array
    of the distinct runner labels that runner-version watches need probed.

.PARAMETER Owner
    GitHub organization or user name of this repository.

.PARAMETER Repo
    Repository name without the owner.

.PARAMETER WatchesPath
    Watches file. Defaults to security/upstream-watches.yml at the repository root.

.PARAMETER ObservationsPath
    Optional JSON file with observed probe outcomes and runner versions:
    {"probes": {"probe-id": "pass"}, "runnerVersions": {"label": "2.336.0"}}.

.PARAMETER RunId
    Optional workflow run whose "Runner probe (<label>)" jobs supply runner versions.

.PARAMETER ListRunnerLabels
    Output the runner labels to probe instead of evaluating watches.

.EXAMPLE
    ./scripts/security/Get-UpstreamWatchStatus.ps1 -Owner microsoft -Repo hve-core

.EXAMPLE
    ./scripts/security/Get-UpstreamWatchStatus.ps1 -ListRunnerLabels
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$Owner,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [string]$WatchesPath,

    [Parameter(Mandatory = $false)]
    [string]$ObservationsPath,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, [long]::MaxValue)]
    [long]$RunId,

    [Parameter(Mandatory = $false)]
    [switch]$ListRunnerLabels
)

$ErrorActionPreference = 'Stop'

$script:CommonFields = @('id', 'kind', 'issue', 'action')
$script:KindFields = @{
    'issue-closed'   = @('url')
    'release-newer'  = @('repo', 'pinned')
    'runner-version' = @('label', 'minimum')
    'probe-outcome'  = @('probe', 'baseline')
}
$script:RunnerProbeJobPattern = 'Runner probe \((?<label>[^()]+)\)$'

function ConvertTo-ComparableVersion {
    <#
    .SYNOPSIS
        Parses a release tag or version string into a [version], or returns $null.
    #>
    [CmdletBinding()]
    [OutputType([version])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Text
    )

    $match = [regex]::Match("$Text", '(\d+)\.(\d+)(?:\.(\d+))?(?:\.(\d+))?')
    if (-not $match.Success) { return $null }
    $parts = @($match.Groups[1..4] | Where-Object Success | ForEach-Object Value)
    return [version]($parts -join '.')
}

function Read-UpstreamWatch {
    <#
    .SYNOPSIS
        Reads and validates the watches file.
    .OUTPUTS
        PSCustomObject with Watches (valid entries as hashtables) and Errors.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $watches = [System.Collections.Generic.List[object]]::new()
    $errors = [System.Collections.Generic.List[string]]::new()

    if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
        Import-Module powershell-yaml -ErrorAction Stop
    }
    try {
        $document = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Yaml
    }
    catch {
        $errors.Add("Watches file is not valid YAML: $($_.Exception.Message)")
        return [pscustomobject]@{ Watches = $watches.ToArray(); Errors = $errors.ToArray() }
    }
    if ($null -eq $document -or $document -isnot [System.Collections.IDictionary] -or -not $document.Contains('watches')) {
        $errors.Add("Watches file must be a mapping with a 'watches' list.")
        return [pscustomobject]@{ Watches = $watches.ToArray(); Errors = $errors.ToArray() }
    }
    $list = $document['watches']
    if ($null -eq $list) { $list = @() }
    if ($list -is [System.Collections.IDictionary] -or $list -is [string] -or $list -isnot [System.Collections.IEnumerable]) {
        $errors.Add("'watches' must be a list.")
        return [pscustomobject]@{ Watches = $watches.ToArray(); Errors = $errors.ToArray() }
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $index = 0
    foreach ($item in $list) {
        $index++
        if ($item -isnot [System.Collections.IDictionary]) {
            $errors.Add("Watch #${index}: must be a mapping.")
            continue
        }
        $label = "Watch #$index ($($item['id']))"
        $entryErrors = [System.Collections.Generic.List[string]]::new()
        $kind = [string]$item['kind']
        $allowed = @($script:CommonFields)
        if ($script:KindFields.ContainsKey($kind)) {
            $allowed += $script:KindFields[$kind]
        }
        elseif ($kind) {
            $entryErrors.Add("'kind' must be one of: $(($script:KindFields.Keys | Sort-Object) -join ', ')")
        }
        # Field checks need a valid kind; an invalid kind is reported above.
        if ($script:KindFields.ContainsKey($kind) -or -not $kind) {
            foreach ($key in $item.Keys) {
                if ("$key" -notin $allowed) { $entryErrors.Add("unknown field '$key'") }
            }
        }
        foreach ($field in $allowed) {
            if (-not $item.Contains($field) -or $null -eq $item[$field] -or "$($item[$field])".Trim() -eq '') {
                $entryErrors.Add("missing required field '$field'")
            }
        }

        if ($item['id'] -and "$($item['id'])" -cnotmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
            $entryErrors.Add("'id' must be lowercase kebab-case")
        }
        $issue = 0
        if ($null -ne $item['issue'] -and -not ([int]::TryParse("$($item['issue'])", [ref]$issue) -and $issue -gt 0)) {
            $entryErrors.Add("'issue' must be a positive issue number")
        }
        switch ($kind) {
            'issue-closed' {
                if ($item['url'] -and "$($item['url'])" -notmatch '^https://github\.com/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+/(?:issues|pull)/\d+/?$') {
                    $entryErrors.Add("'url' must be a GitHub issue or pull request URL")
                }
            }
            'release-newer' {
                if ($item['repo'] -and "$($item['repo'])" -notmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$') {
                    $entryErrors.Add("'repo' must be owner/name")
                }
                if ($item['pinned'] -and $null -eq (ConvertTo-ComparableVersion -Text "$($item['pinned'])")) {
                    $entryErrors.Add("'pinned' must be a version")
                }
            }
            'runner-version' {
                if ($item['label'] -and "$($item['label'])" -notmatch '^[A-Za-z0-9._-]+$') {
                    $entryErrors.Add("'label' must be a runner label")
                }
                if ($item['minimum'] -and $null -eq (ConvertTo-ComparableVersion -Text "$($item['minimum'])")) {
                    $entryErrors.Add("'minimum' must be a version")
                }
            }
            'probe-outcome' {
                if ($item['baseline'] -and "$($item['baseline'])" -cnotin @('pass', 'fail')) {
                    $entryErrors.Add("'baseline' must be pass or fail")
                }
            }
        }

        if ($entryErrors.Count -gt 0) {
            $errors.Add("${label}: $($entryErrors -join '; ').")
            continue
        }
        if (-not $seen.Add([string]$item['id'])) {
            $errors.Add("${label}: duplicates an earlier id.")
            continue
        }
        $watches.Add($item)
    }

    return [pscustomobject]@{ Watches = $watches.ToArray(); Errors = $errors.ToArray() }
}

function Get-UpstreamWatchStatus {
    <#
    .SYNOPSIS
        Evaluates validated watches against looked-up and observed state.
    .OUTPUTS
        PSCustomObject[] with Id, Kind, Subject, Issue, Action, State, Triggered,
        Detail, and Marker.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Watches,

        # Issue URL to 'open', 'closed', or 'unknown'.
        [Parameter(Mandatory = $false)]
        [hashtable]$IssueStates = @{},

        # owner/name to latest release tag.
        [Parameter(Mandatory = $false)]
        [hashtable]$LatestReleases = @{},

        # Runner label to observed runner version.
        [Parameter(Mandatory = $false)]
        [hashtable]$RunnerVersions = @{},

        # Probe id to 'pass' or 'fail'.
        [Parameter(Mandatory = $false)]
        [hashtable]$ProbeOutcomes = @{}
    )

    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($watch in $Watches) {
        $kind = [string]$watch['kind']
        $state = 'unknown'
        $subject = ''
        $detail = ''
        switch ($kind) {
            'issue-closed' {
                $subject = [string]$watch['url']
                $observed = if ($IssueStates.ContainsKey($subject)) { [string]$IssueStates[$subject] } else { 'unknown' }
                $state = switch ($observed) { 'closed' { 'triggered' } 'open' { 'waiting' } default { 'unknown' } }
                $detail = "upstream is $observed"
            }
            'release-newer' {
                $subject = [string]$watch['repo']
                $pinned = ConvertTo-ComparableVersion -Text "$($watch['pinned'])"
                $tag = if ($LatestReleases.ContainsKey($subject)) { [string]$LatestReleases[$subject] } else { '' }
                $latest = ConvertTo-ComparableVersion -Text $tag
                if ($null -ne $latest) {
                    $state = if ($latest -gt $pinned) { 'triggered' } else { 'waiting' }
                    $detail = "latest release $tag, pinned $($watch['pinned'])"
                }
                else {
                    $detail = "latest release unavailable, pinned $($watch['pinned'])"
                }
            }
            'runner-version' {
                $subject = [string]$watch['label']
                $minimum = ConvertTo-ComparableVersion -Text "$($watch['minimum'])"
                $text = if ($RunnerVersions.ContainsKey($subject)) { [string]$RunnerVersions[$subject] } else { '' }
                $observed = ConvertTo-ComparableVersion -Text $text
                if ($null -ne $observed) {
                    $state = if ($observed -ge $minimum) { 'triggered' } else { 'waiting' }
                    $detail = "runner $text, minimum $($watch['minimum'])"
                }
                else {
                    $detail = "runner version not observed, minimum $($watch['minimum'])"
                }
            }
            'probe-outcome' {
                $subject = [string]$watch['probe']
                $observed = if ($ProbeOutcomes.ContainsKey($subject)) { [string]$ProbeOutcomes[$subject] } else { '' }
                if ($observed -in @('pass', 'fail')) {
                    $state = if ($observed -cne [string]$watch['baseline']) { 'triggered' } else { 'waiting' }
                    $detail = "probe reported $observed, baseline $($watch['baseline'])"
                }
                else {
                    $detail = "probe outcome not observed, baseline $($watch['baseline'])"
                }
            }
        }

        $records.Add([pscustomobject]@{
                Id        = [string]$watch['id']
                Kind      = $kind
                Subject   = $subject
                Issue     = [int]"$($watch['issue'])"
                Action    = [string]$watch['action']
                State     = $state
                Triggered = $state -eq 'triggered'
                Detail    = $detail
                Marker    = "automation:upstream-watch:$($watch['id'])"
            })
    }
    return , $records.ToArray()
}

function Get-RunnerVersionFromLog {
    <#
    .SYNOPSIS
        Extracts the runner version from a job log, or returns $null.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$LogText
    )

    $match = [regex]::Match("$LogText", "Current runner version: '(?<version>\d+(?:\.\d+)+)'")
    if ($match.Success) { return $match.Groups['version'].Value }
    return $null
}

function Get-RunnerProbeLabel {
    <#
    .SYNOPSIS
        Returns the runner label from a runner probe job name, or $null.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$JobName
    )

    $match = [regex]::Match("$JobName", $script:RunnerProbeJobPattern)
    if ($match.Success) { return $match.Groups['label'].Value.Trim() }
    return $null
}

function Get-RunnerVersionObservation {
    <#
    .SYNOPSIS
        Reads runner versions from the runner probe jobs of a workflow run.
    .OUTPUTS
        Hashtable of runner label to version.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Owner,

        [Parameter(Mandatory = $true)]
        [string]$Repo,

        [Parameter(Mandatory = $true)]
        [long]$RunId
    )

    $versions = @{}
    $raw = gh api "repos/$Owner/$Repo/actions/runs/$RunId/jobs?per_page=100" --paginate --jq '.jobs[] | {id, name, conclusion}'
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Could not list jobs for run ${RunId}; runner versions are unobserved."
        return $versions
    }
    foreach ($job in @($raw | Where-Object { $_ } | ConvertFrom-Json)) {
        $label = Get-RunnerProbeLabel -JobName $job.name
        if (-not $label -or $job.conclusion -ne 'success') { continue }
        $log = gh api "repos/$Owner/$Repo/actions/jobs/$($job.id)/logs" 2>$null
        if ($LASTEXITCODE -ne 0) { continue }
        $version = Get-RunnerVersionFromLog -LogText ($log -join "`n")
        if ($version) { $versions[$label] = $version }
    }
    return $versions
}

function Get-WatchLookup {
    <#
    .SYNOPSIS
        Looks up upstream issue states and latest releases with the gh CLI.
    .OUTPUTS
        PSCustomObject with IssueStates and LatestReleases hashtables.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Watches
    )

    $issueStates = @{}
    $latestReleases = @{}
    foreach ($watch in $Watches) {
        switch ([string]$watch['kind']) {
            'issue-closed' {
                $url = [string]$watch['url']
                if ($issueStates.ContainsKey($url)) { continue }
                $null = $url -match '^https://github\.com/([^/]+)/([^/]+)/(?:issues|pull)/(\d+)'
                $state = gh api "repos/$($Matches[1])/$($Matches[2])/issues/$($Matches[3])" --jq '.state' 2>$null
                $issueStates[$url] = if ($LASTEXITCODE -eq 0 -and "$state".Trim() -in @('open', 'closed')) { "$state".Trim() } else { 'unknown' }
            }
            'release-newer' {
                $repoName = [string]$watch['repo']
                if ($latestReleases.ContainsKey($repoName)) { continue }
                $tag = gh api "repos/$repoName/releases/latest" --jq '.tag_name' 2>$null
                $latestReleases[$repoName] = if ($LASTEXITCODE -eq 0) { "$tag".Trim() } else { '' }
            }
        }
    }
    return [pscustomobject]@{ IssueStates = $issueStates; LatestReleases = $latestReleases }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        if (-not $WatchesPath) {
            $repoRoot = git rev-parse --show-toplevel 2>$null
            if (-not $repoRoot) { $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent }
            $WatchesPath = Join-Path $repoRoot 'security/upstream-watches.yml'
        }
        if (-not (Test-Path -LiteralPath $WatchesPath -PathType Leaf)) {
            throw "Watches file not found: $WatchesPath"
        }
        $read = Read-UpstreamWatch -Path $WatchesPath
        if ($read.Errors.Count -gt 0) {
            throw "Invalid watches file: $($read.Errors -join ' ')"
        }

        if ($ListRunnerLabels) {
            $labels = @($read.Watches | Where-Object { $_['kind'] -eq 'runner-version' } | ForEach-Object { [string]$_['label'] } | Sort-Object -Unique)
            ConvertTo-Json -InputObject @($labels) -Compress
            exit 0
        }

        $env:GH_PAGER = ''
        $probeOutcomes = @{}
        $runnerVersions = @{}
        if ($ObservationsPath) {
            $observations = Get-Content -Raw -LiteralPath $ObservationsPath | ConvertFrom-Json -AsHashtable
            if ($observations['probes'] -is [System.Collections.IDictionary]) { $probeOutcomes = [hashtable]$observations['probes'] }
            if ($observations['runnerVersions'] -is [System.Collections.IDictionary]) { $runnerVersions = [hashtable]$observations['runnerVersions'] }
        }
        if ($RunId) {
            if (-not $Owner -or -not $Repo) { throw 'Owner and Repo are required with RunId.' }
            $observed = Get-RunnerVersionObservation -Owner $Owner -Repo $Repo -RunId $RunId
            foreach ($key in $observed.Keys) { $runnerVersions[$key] = $observed[$key] }
        }

        $lookup = Get-WatchLookup -Watches $read.Watches
        $status = Get-UpstreamWatchStatus -Watches $read.Watches -IssueStates $lookup.IssueStates -LatestReleases $lookup.LatestReleases -RunnerVersions $runnerVersions -ProbeOutcomes $probeOutcomes
        # The array wrapper keeps the output a JSON array for every result size.
        ConvertTo-Json -InputObject @($status) -Depth 3
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Get-UpstreamWatchStatus failed: $($_.Exception.Message)"
        exit 1
    }
}
