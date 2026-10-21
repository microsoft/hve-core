#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Test-ActionPinProvenance.ps1
#
# Purpose: Verify every SHA-pinned action against its upstream repository: the
#          version comment must name a tag that points at the pinned commit, and
#          the commit must be reachable from a tag or the default branch.
# Author: HVE Core Team

#Requires -Version 7.4

<#
.SYNOPSIS
    Verifies SHA-pinned action references against upstream tags and history.

.DESCRIPTION
    Scans workflows and composite actions for `uses: owner/repo[/path]@<sha> # <comment>`
    and checks each pin against its upstream repository:

      action-pin/comment-mismatch      the comment names a tag that does not point at the
                                       pinned commit, a moving major or minor tag, a
                                       version that is not a tag at the commit, or free
                                       text when a release tag exists for the commit
      action-pin/comment-missing       a pinned commit has no comment
      action-pin/unreachable-commit    the commit is on no tag and not in the default
                                       branch history, which is how an impostor commit
                                       from a fork looks
      action-pin/tag-object            the pin names an annotated tag object instead of a
                                       commit; pin the commit the tag points at
      action-pin/upstream-unavailable  the upstream tags or history could not be read,
                                       so the pin could not be verified (fails closed)

    Tags and the default branch come from `git ls-remote` (one call each per
    repository, cached for the run, no API rate limit). The compare API is called
    only for a commit no tag points at. A free-text comment is allowed only for
    such an untagged commit that is reachable from the default branch, for example
    a reusable workflow pinned to a reviewed merge commit.

    Writes a console summary, optional SARIF (tool name hve-action-pin-provenance),
    and exits 1 when any finding exists.

.PARAMETER RepoRoot
    Repository root. Defaults to the git top-level directory.

.PARAMETER Paths
    Repository-relative directories or remediation-table files to scan. Defaults to .github/workflows,
    .github/actions, and the Update-ActionSHAPinning.ps1 remediation table.

.PARAMETER SarifPath
    Optional SARIF output path.

.PARAMETER GitHubToken
    Token for the compare API. Defaults to GITHUB_TOKEN; unauthenticated calls work at lower limits.

.EXAMPLE
    ./scripts/security/Test-ActionPinProvenance.ps1 -SarifPath logs/action-pin-provenance.sarif
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string[]]$Paths = @('.github/workflows', '.github/actions', 'scripts/security/Update-ActionSHAPinning.ps1'),

    [Parameter(Mandatory = $false)]
    [string]$SarifPath,

    [Parameter(Mandatory = $false)]
    [string]$GitHubToken = $env:GITHUB_TOKEN
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/SecurityHelpers.psm1') -Force

$script:ToolName = 'hve-action-pin-provenance'
$script:Rules = @(
    @{ id = 'action-pin/comment-mismatch'; name = 'CommentMismatch'; description = 'A pinned action version comment does not name a release tag that points at the pinned commit.'; level = 'error' }
    @{ id = 'action-pin/comment-missing'; name = 'CommentMissing'; description = 'A pinned action has no version comment.'; level = 'error' }
    @{ id = 'action-pin/unreachable-commit'; name = 'UnreachableCommit'; description = 'A pinned commit is on no upstream tag and not in the default branch history, which is how an impostor commit from a fork looks.'; level = 'error' }
    @{ id = 'action-pin/tag-object'; name = 'TagObject'; description = 'A pin names an annotated tag object instead of the commit the tag points at.'; level = 'error' }
    @{ id = 'action-pin/upstream-unavailable'; name = 'UpstreamUnavailable'; description = 'The upstream repository could not be read, so the pin could not be verified.'; level = 'error' }
)
$script:UpstreamCache = @{}
$script:ReachabilityCache = @{}

function New-PinFinding {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$RuleId,
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][string]$File,
        [Parameter()][int]$Line = 1
    )
    [pscustomobject]@{ RuleId = $RuleId; Message = $Message; File = $File; Line = $Line }
}

function Get-ActionPinReference {
    <#
    .SYNOPSIS
        Lists SHA-pinned remote action references with their comments.
    .DESCRIPTION
        Directories are scanned for workflow and action YAML `uses:` lines. A
        PowerShell file is read as a remediation table of
        "owner/repo@<major>" = "owner/repo@<sha>" # <tag> rows, and each row's
        key is kept so its major can be checked against the tag.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string[]]$Paths
    )

    $rootFull = (Resolve-Path -LiteralPath $RepoRoot).Path
    $usesPattern = '^\s*(?:-\s+)?uses:\s*[''"]?(?<repo>[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)(?<path>/[^@\s''"]*)?@(?<sha>[0-9a-fA-F]{40})[''"]?(?:\s+#\s*(?<comment>.*?))?\s*$'
    $tablePattern = '^\s*"(?<key>[^"@]+@[^"]+)"\s*=\s*"(?<repo>[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)(?<path>/[^@"]*)?@(?<sha>[0-9a-fA-F]{40})"(?:\s*#\s*(?<comment>.*?))?\s*$'
    $references = [System.Collections.Generic.List[object]]::new()
    foreach ($relative in $Paths) {
        $target = Join-Path $RepoRoot $relative
        if (-not (Test-Path -LiteralPath $target)) { continue }
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            $files = @(Get-Item -LiteralPath $target)
        }
        else {
            $files = Get-ChildItem -LiteralPath $target -Recurse -File | Where-Object { $_.Extension -in '.yml', '.yaml' } | Sort-Object FullName
        }
        foreach ($file in $files) {
            $relativeFile = [System.IO.Path]::GetRelativePath($rootFull, $file.FullName) -replace '\\', '/'
            $pattern = if ($file.Extension -in '.ps1', '.psm1') { $tablePattern } else { $usesPattern }
            $lineNumber = 0
            foreach ($line in Get-Content -LiteralPath $file.FullName) {
                $lineNumber++
                $match = [regex]::Match($line, $pattern)
                if (-not $match.Success) { continue }
                $comment = $match.Groups['comment'].Value.Trim()
                $references.Add([pscustomobject]@{
                        File    = $relativeFile
                        Line    = $lineNumber
                        Repo    = $match.Groups['repo'].Value
                        Sha     = $match.Groups['sha'].Value.ToLowerInvariant()
                        Comment = $comment
                        Label   = $(if ($comment) { ($comment -split '\s+')[0] } else { '' })
                        Key     = $match.Groups['key'].Value
                    })
            }
        }
    }
    return $references.ToArray()
}

function Invoke-GitLsRemote {
    <#
    .SYNOPSIS
        Runs git ls-remote with retries and returns its output lines, or $null on failure.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)][string[]]$Arguments
    )

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $output = & git ls-remote @Arguments 2>$null
        if ($LASTEXITCODE -eq 0) { return @($output) }
        if ($attempt -lt 3) { Start-Sleep -Seconds ($attempt * 2) }
    }
    return $null
}

function Get-UpstreamRef {
    <#
    .SYNOPSIS
        Returns an upstream repository's tags (name to commit) and default branch, cached per run.
    .DESCRIPTION
        Annotated tags are peeled to their commit, and TagObjects maps each
        annotated tag object to its tag name. Returns Tags = $null when the
        repository cannot be read.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$Repo
    )

    if ($script:UpstreamCache.ContainsKey($Repo)) { return $script:UpstreamCache[$Repo] }

    $server = if ($env:GITHUB_SERVER_URL) { $env:GITHUB_SERVER_URL.TrimEnd('/') } else { 'https://github.com' }
    $url = "$server/$Repo.git"
    $result = [pscustomobject]@{ Tags = $null; TagObjects = @{}; DefaultBranch = $null }

    $tagLines = Invoke-GitLsRemote -Arguments @('--tags', $url)
    $headLines = Invoke-GitLsRemote -Arguments @('--symref', $url, 'HEAD')
    if ($null -ne $tagLines -and $null -ne $headLines) {
        $tags = @{}
        $objects = @{}
        foreach ($line in $tagLines) {
            $parts = $line -split "`t"
            if ($parts.Count -lt 2) { continue }
            $name = $parts[1] -replace '^refs/tags/', ''
            if ($name.EndsWith('^{}')) {
                $tags[$name.Substring(0, $name.Length - 3)] = $parts[0].ToLowerInvariant()
            }
            else {
                $objects[$name] = $parts[0].ToLowerInvariant()
                if (-not $tags.ContainsKey($name)) { $tags[$name] = $parts[0].ToLowerInvariant() }
            }
        }
        foreach ($name in @($objects.Keys)) {
            if ($tags[$name] -ne $objects[$name]) { $result.TagObjects[$objects[$name]] = $name }
        }
        $result.Tags = $tags
        foreach ($line in $headLines) {
            if ($line -match '^ref:\s+refs/heads/(?<branch>\S+)\s+HEAD$') { $result.DefaultBranch = $Matches['branch'] }
        }
    }

    $script:UpstreamCache[$Repo] = $result
    return $result
}

function Invoke-CompareRequest {
    <#
    .SYNOPSIS
        Calls the compare API and returns the HTTP status and body, retrying rate-limit and server errors.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][hashtable]$Headers
    )

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $status = 0
        $body = $null
        try {
            $body = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method GET -SkipHttpErrorCheck -StatusCodeVariable status -ErrorAction Stop
        }
        catch {
            $status = 0
        }
        if ($status -eq 200 -or $status -in 404, 422) { return [pscustomobject]@{ Status = [int]$status; Body = $body } }
        if ($attempt -lt 3) { Start-Sleep -Seconds ($attempt * 2) }
    }
    return [pscustomobject]@{ Status = [int]$status; Body = $null }
}

function Test-CommitInDefaultBranch {
    <#
    .SYNOPSIS
        Returns $true when a commit is in the default branch history, $false when not, $null when unknown.
    .DESCRIPTION
        A 404 or 422 from the compare API means the commit does not exist in the
        repository, which is reported as not reachable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$Sha,
        [Parameter(Mandatory)][string]$Branch,
        [Parameter()][string]$Token
    )

    $key = "$Repo@$Sha"
    if ($script:ReachabilityCache.ContainsKey($key)) { return $script:ReachabilityCache[$key] }

    $headers = @{ 'Accept' = 'application/vnd.github+json'; 'X-GitHub-Api-Version' = '2022-11-28' }
    if ($Token) { $headers['Authorization'] = "Bearer $Token" }
    $response = Invoke-CompareRequest -Uri "$(Get-GitHubApiBase)/repos/$Repo/compare/$([uri]::EscapeDataString($Branch))...$Sha" -Headers $headers
    $answer = switch ($response.Status) {
        200 { [bool]($response.Body.status -in 'behind', 'identical') }
        { $_ -in 404, 422 } { $false }
        default { $null }
    }
    $script:ReachabilityCache[$key] = $answer
    return $answer
}

function Get-PinFinding {
    <#
    .SYNOPSIS
        Evaluates pinned references against upstream tags and history.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$References,
        [Parameter()][string]$Token
    )

    $findings = [System.Collections.Generic.List[object]]::new()
    foreach ($group in ($References | Group-Object Repo, Sha)) {
        $first = $group.Group[0]
        $upstream = Get-UpstreamRef -Repo $first.Repo
        if ($null -eq $upstream.Tags) {
            foreach ($reference in $group.Group) {
                $findings.Add((New-PinFinding -RuleId 'action-pin/upstream-unavailable' -File $reference.File -Line $reference.Line `
                            -Message "Could not read tags for $($first.Repo), so $($first.Sha.Substring(0, 12)) was not verified."))
            }
            continue
        }

        if ($upstream.TagObjects.ContainsKey($first.Sha)) {
            $tagName = $upstream.TagObjects[$first.Sha]
            $commit = $upstream.Tags[$tagName]
            $commitTags = @($upstream.Tags.GetEnumerator() | Where-Object Value -EQ $commit | ForEach-Object Key | Where-Object { $_ -match '^v?\d+\.\d+\.\d+' } | Sort-Object)
            foreach ($reference in $group.Group) {
                $findings.Add((New-PinFinding -RuleId 'action-pin/tag-object' -File $reference.File -Line $reference.Line `
                            -Message "$($first.Repo)@$($first.Sha.Substring(0, 12)) is the annotated tag object of '$tagName', not a commit. Pin commit $commit$(if ($commitTags.Count) { " labeled $($commitTags -join ', ')" })."))
            }
            continue
        }

        $tagsAtSha = @($upstream.Tags.GetEnumerator() | Where-Object Value -EQ $first.Sha | ForEach-Object Key | Sort-Object)
        $releaseTags = @($tagsAtSha | Where-Object { $_ -match '^v?\d+\.\d+\.\d+' })
        $suggestion = if ($releaseTags.Count) { $releaseTags -join ', ' } elseif ($tagsAtSha.Count) { $tagsAtSha -join ', ' } else { 'none' }

        if ($tagsAtSha.Count -eq 0) {
            $reachable = $null
            if ($upstream.DefaultBranch) {
                $reachable = Test-CommitInDefaultBranch -Repo $first.Repo -Sha $first.Sha -Branch $upstream.DefaultBranch -Token $Token
            }
            if ($null -eq $reachable) {
                foreach ($reference in $group.Group) {
                    $findings.Add((New-PinFinding -RuleId 'action-pin/upstream-unavailable' -File $reference.File -Line $reference.Line `
                                -Message "No tag in $($first.Repo) points at $($first.Sha.Substring(0, 12)), and its default branch history could not be checked."))
                }
                continue
            }
            if (-not $reachable) {
                foreach ($reference in $group.Group) {
                    $findings.Add((New-PinFinding -RuleId 'action-pin/unreachable-commit' -File $reference.File -Line $reference.Line `
                                -Message "$($first.Repo)@$($first.Sha.Substring(0, 12)) is on no tag and not in the $($upstream.DefaultBranch) history; it may be an impostor commit from a fork. Pin a commit from a release tag."))
                }
                continue
            }
        }

        foreach ($reference in $group.Group) {
            $label = $reference.Label
            $where = "$($reference.Repo)@$($reference.Sha.Substring(0, 12))"
            if (-not $label) {
                $findings.Add((New-PinFinding -RuleId 'action-pin/comment-missing' -File $reference.File -Line $reference.Line `
                            -Message "$where has no version comment. Tags at this commit: $suggestion."))
                continue
            }
            if ($tagsAtSha -ccontains $label) {
                if ($label -match '^v?\d+(\.\d+)?$') {
                    $findings.Add((New-PinFinding -RuleId 'action-pin/comment-mismatch' -File $reference.File -Line $reference.Line `
                                -Message "$where is labeled with the moving tag '$label'. Use the exact release tag: $suggestion."))
                }
                elseif ($releaseTags.Count -and $releaseTags -cnotcontains $label) {
                    $findings.Add((New-PinFinding -RuleId 'action-pin/comment-mismatch' -File $reference.File -Line $reference.Line `
                                -Message "$where is labeled '$label', but release tags point at this commit: $suggestion. Use the release tag so updates can be tracked."))
                }
                elseif ($reference.Key) {
                    $keyRef = ($reference.Key -split '@', 2)[1]
                    if ($label -cne $keyRef -and -not $label.StartsWith("$keyRef.", [System.StringComparison]::Ordinal)) {
                        $findings.Add((New-PinFinding -RuleId 'action-pin/comment-mismatch' -File $reference.File -Line $reference.Line `
                                    -Message "Remediation entry '$($reference.Key)' maps to $label, outside the $keyRef line. Map it to a $keyRef release."))
                    }
                }
                continue
            }
            if ($upstream.Tags.ContainsKey($label)) {
                $findings.Add((New-PinFinding -RuleId 'action-pin/comment-mismatch' -File $reference.File -Line $reference.Line `
                            -Message "$where is labeled '$label', but $label points at $($upstream.Tags[$label].Substring(0, 12)). Tags at the pinned commit: $suggestion."))
                continue
            }
            if ($label -match '^v?\d+(\.\d+)*$' -or $tagsAtSha.Count) {
                $findings.Add((New-PinFinding -RuleId 'action-pin/comment-mismatch' -File $reference.File -Line $reference.Line `
                            -Message "$where is labeled '$label', which is not a tag at this commit. Tags at the pinned commit: $suggestion."))
            }
        }
    }
    return $findings.ToArray()
}

function Invoke-ActionPinProvenance {
    <#
    .SYNOPSIS
        Runs the provenance check.
    .OUTPUTS
        PSCustomObject with Findings, References, and ExitCode.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter()][string[]]$Paths = @('.github/workflows', '.github/actions', 'scripts/security/Update-ActionSHAPinning.ps1'),
        [Parameter()][string]$SarifPath,
        [Parameter()][string]$Token
    )

    $references = @(Get-ActionPinReference -RepoRoot $RepoRoot -Paths $Paths)
    $findings = @(Get-PinFinding -References $references -Token $Token)

    if ($SarifPath) {
        $directory = Split-Path -Parent $SarifPath
        if ($directory -and -not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
        ConvertTo-SecuritySarif -ToolName $script:ToolName -Rules $script:Rules -Findings $findings |
            ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $SarifPath -Encoding utf8NoBOM
    }

    return [pscustomobject]@{
        Findings   = $findings
        References = $references
        ExitCode   = $(if ($findings.Count -eq 0) { 0 } else { 1 })
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        if (-not $RepoRoot) {
            $RepoRoot = git rev-parse --show-toplevel 2>$null
            if (-not $RepoRoot) { $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent }
        }
        $result = Invoke-ActionPinProvenance -RepoRoot $RepoRoot -Paths $Paths -SarifPath $SarifPath -Token $GitHubToken
        foreach ($finding in $result.Findings) {
            Write-Output "$($finding.File):$($finding.Line): [$($finding.RuleId)] $($finding.Message)"
        }
        $repoCount = @($result.References | Select-Object -ExpandProperty Repo -Unique).Count
        Write-Output "Action pin provenance: $(@($result.Findings).Count) finding(s) across $(@($result.References).Count) pinned reference(s) in $repoCount repositor$(if ($repoCount -eq 1) { 'y' } else { 'ies' })."
        exit $result.ExitCode
    }
    catch {
        Write-Error -ErrorAction Continue "Test-ActionPinProvenance failed: $($_.Exception.Message)"
        exit 1
    }
}
