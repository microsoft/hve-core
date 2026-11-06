#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Synchronizes repository labels without deleting unrelated labels.
.DESCRIPTION
    Validates the complete YAML configuration, creates or updates canonical
    labels, and migrates configured aliases without replacing issue labels.
    An alias is deleted only after all its issue and pull-request assignments
    have been verified on the canonical label. Concurrent human edits are not
    transactional; a failed run can be rerun safely.
.PARAMETER Repository
    GitHub owner/repository. Defaults to GITHUB_REPOSITORY.
.PARAMETER ConfigPath
    YAML label list. Defaults to .github/labels.yml in this repository.
.EXAMPLE
    ./scripts/ci/Sync-RepositoryLabels.ps1 -Repository owner/repo -WhatIf
.EXAMPLE
    npm run labels:sync -- -Repository owner/repo
.NOTES
    Uses GH_TOKEN or GITHUB_TOKEN with repository issues write permission.
    WhatIf validates configuration without network calls. Results contain counts,
    not label names, tokens, or third-party diagnostic text.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter()]
    [string]$Repository = $env:GITHUB_REPOSITORY,

    [Parameter()]
    [string]$ConfigPath = (Join-Path $PSScriptRoot '../../.github/labels.yml')
)

$ErrorActionPreference = 'Stop'

#region Functions

function Get-RepositoryLabelConfiguration {
    <#
    .SYNOPSIS
        Validates and normalizes the entire label configuration before writes.
    .PARAMETER Path
        YAML file containing canonical labels and optional aliases.
    .OUTPUTS
        Object array containing normalized names, colors, descriptions and aliases.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param([Parameter(Mandatory)][string]$Path)

    Import-Module powershell-yaml -ErrorAction Stop
    try {
        $Document = ConvertFrom-Yaml -Yaml (Get-Content -Raw -LiteralPath $Path)
    }
    catch [System.IO.IOException], [System.UnauthorizedAccessException], [System.Management.Automation.RuntimeException] {
        throw [System.IO.InvalidDataException]::new('Cannot read or parse the label configuration.')
    }
    if ($Document -isnot [System.Collections.IList] -or $Document.Count -eq 0) {
        throw [System.IO.InvalidDataException]::new('Label configuration must be a nonempty YAML list.')
    }

    $Names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $Result = [System.Collections.Generic.List[object]]::new()
    foreach ($Entry in $Document) {
        if ($Entry -isnot [System.Collections.IDictionary] -or
            $Entry['name'] -isnot [string] -or [string]::IsNullOrWhiteSpace($Entry['name']) -or
            $Entry['name'] -cne $Entry['name'].Trim()) {
            throw [System.IO.InvalidDataException]::new('Every label requires a nonempty name without surrounding whitespace.')
        }
        if (-not $Names.Add($Entry['name'])) {
            throw [System.IO.InvalidDataException]::new('Canonical label names must be unique, ignoring case.')
        }
        if ($Entry['color'] -isnot [string] -or $Entry['color'] -notmatch '^#?[a-fA-F0-9]{6}\z') {
            throw [System.IO.InvalidDataException]::new('Every label requires a six-digit hexadecimal color.')
        }
        if ($null -ne $Entry['description'] -and
            ($Entry['description'] -isnot [string] -or $Entry['description'].Length -gt 100)) {
            throw [System.IO.InvalidDataException]::new('Label descriptions must be strings of at most 100 characters.')
        }
        $Aliases = @()
        if ($null -ne $Entry['aliases']) {
            if ($Entry['aliases'] -isnot [System.Collections.IList]) {
                throw [System.IO.InvalidDataException]::new('Label aliases must be a list.')
            }
            foreach ($Alias in $Entry['aliases']) {
                if ($Alias -isnot [string] -or [string]::IsNullOrWhiteSpace($Alias) -or $Alias -cne $Alias.Trim()) {
                    throw [System.IO.InvalidDataException]::new('Aliases must be nonempty strings without surrounding whitespace.')
                }
            }
            $Aliases = @($Entry['aliases'])
        }
        $Result.Add(@{
                name        = $Entry['name']
                color       = $Entry['color'].TrimStart('#').ToLowerInvariant()
                description = [string]$Entry['description']
                aliases     = $Aliases
            })
    }
    foreach ($Entry in $Result) {
        foreach ($Alias in $Entry.aliases) {
            if (-not $Names.Add($Alias)) {
                throw [System.IO.InvalidDataException]::new('Aliases must not overlap canonical names or other aliases, ignoring case.')
            }
        }
    }
    return ,$Result.ToArray()
}

function Invoke-RepositoryLabelApi {
    <#
    .SYNOPSIS
        Calls GitHub with bounded retries and fixed, credential-safe errors.
    .PARAMETER Path
        Relative GitHub API path, including any encoded query.
    .PARAMETER Method
        HTTP method for the label operation.
    .PARAMETER Body
        Optional object serialized as JSON.
    .OUTPUTS
        Parsed JSON, or null for a successful no-content response.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter()][ValidateSet('GET', 'POST', 'PATCH', 'DELETE')][string]$Method = 'GET',
        [Parameter()][hashtable]$Body
    )

    $Token = $env:GH_TOKEN
    if ([string]::IsNullOrWhiteSpace($Token)) { $Token = $env:GITHUB_TOKEN }
    if ([string]::IsNullOrWhiteSpace($Token)) {
        throw [System.IO.InvalidDataException]::new('GH_TOKEN or GITHUB_TOKEN is required for label synchronization.')
    }
    if ($Token -match '\s') {
        throw [System.IO.InvalidDataException]::new('The GitHub token must not contain whitespace.')
    }
    $Arguments = @{
        Uri         = "https://api.github.com/$Path"
        Method      = $Method
        Headers     = @{
            Authorization          = "Bearer $Token"
            Accept                 = 'application/vnd.github+json'
            'X-GitHub-Api-Version' = '2022-11-28'
        }
        TimeoutSec  = 30
        ErrorAction = 'Stop'
    }
    if ($null -ne $Body) {
        $Arguments.ContentType = 'application/json; charset=utf-8'
        $Arguments.Body = [System.Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 8 -Compress))
    }

    for ($Attempt = 1; $Attempt -le 3; $Attempt++) {
        try {
            $Response = Invoke-WebRequest @Arguments
        }
        catch [Microsoft.PowerShell.Commands.HttpResponseException] {
            $Status = [int]$_.Exception.Response.StatusCode
            if (($Status -eq 429 -or $Status -ge 500) -and $Attempt -lt 3) {
                $Delay = [int][Math]::Pow(2, $Attempt)
                $RetryAfter = $_.Exception.Response.Headers.RetryAfter
                if ($null -ne $RetryAfter -and $null -ne $RetryAfter.Delta) {
                    $Delay = [Math]::Max($Delay, [int][Math]::Ceiling($RetryAfter.Delta.TotalSeconds))
                }
                elseif ($null -ne $RetryAfter -and $null -ne $RetryAfter.Date) {
                    $Delay = [Math]::Max($Delay, [int][Math]::Ceiling(($RetryAfter.Date - [datetimeoffset]::UtcNow).TotalSeconds))
                }
                if ($Delay -le 30) {
                    Start-Sleep -Seconds $Delay
                    continue
                }
            }
            throw [System.IO.InvalidDataException]::new("GitHub label API $Method failed (HTTP $Status).")
        }
        catch [System.Net.Http.HttpRequestException], [System.Threading.Tasks.TaskCanceledException] {
            throw [System.IO.InvalidDataException]::new('GitHub label API transport failed or timed out.')
        }
        catch [System.FormatException] {
            throw [System.IO.InvalidDataException]::new('GitHub label API request headers are invalid.')
        }
        if ([int]$Response.StatusCode -eq 204) { return $null }
        try {
            $Data = ConvertFrom-Json -InputObject $Response.Content -AsHashtable -NoEnumerate -ErrorAction Stop
        }
        catch [System.ArgumentException], [System.Management.Automation.RuntimeException] {
            throw [System.IO.InvalidDataException]::new('GitHub label API returned invalid JSON.')
        }
        return ,$Data
    }
}

function Get-RepositoryLabelCollection {
    <#
    .SYNOPSIS
        Reads every page of a GitHub label or issue collection.
    .PARAMETER Path
        Relative API path, optionally containing a query.
    .OUTPUTS
        Object array containing all pages without search-result limits.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param([Parameter(Mandatory)][string]$Path)

    $Items = [System.Collections.Generic.List[object]]::new()
    $Separator = if ($Path.Contains('?')) { '&' } else { '?' }
    for ($Page = 1; ; $Page++) {
        $Batch = Invoke-RepositoryLabelApi -Path "${Path}${Separator}per_page=100&page=$Page"
        if ($Batch -isnot [System.Collections.IList]) {
            throw [System.IO.InvalidDataException]::new('GitHub label API returned an invalid collection.')
        }
        foreach ($Item in $Batch) { $Items.Add($Item) }
        if ($Batch.Count -lt 100) { break }
    }
    return ,$Items.ToArray()
}

function Get-RepositoryAliasIssues {
    <#
    .SYNOPSIS
        Finds open and closed issues and PRs assigned an alias.
    .PARAMETER Prefix
        Repository-scoped API prefix.
    .PARAMETER Alias
        Alias label name, encoded only at the request boundary.
    .OUTPUTS
        Object array of all affected issues and pull requests.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][string]$Prefix,
        [Parameter(Mandatory)][string]$Alias
    )
    $Encoded = [uri]::EscapeDataString($Alias)
    # GitHub treats commas as label-filter separators, even inside one label name.
    $Path = if ($Alias.Contains(',')) { "$Prefix/issues?state=all" } else { "$Prefix/issues?state=all&labels=$Encoded" }
    $Issues = Get-RepositoryLabelCollection -Path $Path
    $MatchingIssues = [System.Collections.Generic.List[object]]::new()
    foreach ($Issue in $Issues) {
        if ($Issue -isnot [System.Collections.IDictionary] -or $Issue.labels -isnot [System.Collections.IList]) {
            throw [System.IO.InvalidDataException]::new('GitHub returned invalid alias assignments.')
        }
        if ($Alias -in @($Issue.labels | ForEach-Object { $_.name })) { $MatchingIssues.Add($Issue) }
    }
    return ,$MatchingIssues.ToArray()
}

function Sync-RepositoryLabels {
    <#
    .SYNOPSIS
        Reconciles labels and preserves assignments before removing aliases.
    .PARAMETER Repository
        GitHub owner/repository identifier.
    .PARAMETER ConfigPath
        Validated YAML label configuration.
    .OUTPUTS
        Summary with Status, Created, Updated, Renamed, MigratedIssues,
        DeletedAliases and Unchanged counts.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][string]$ConfigPath
    )
    if ($Repository -notmatch '^[a-zA-Z0-9][a-zA-Z0-9-]*/[a-zA-Z0-9_.-]+\z' -or
        ($Repository -split '/')[1] -in @('.', '..')) {
        throw [System.IO.InvalidDataException]::new('Repository must be a GitHub owner/repository identifier.')
    }
    $Desired = Get-RepositoryLabelConfiguration -Path $ConfigPath
    $Summary = [pscustomobject][ordered]@{
        Status = 'Complete'; Created = 0; Updated = 0; Renamed = 0
        MigratedIssues = 0; DeletedAliases = 0; Unchanged = 0
    }
    if (-not $PSCmdlet.ShouldProcess('repository label configuration', 'Synchronize labels and configured aliases')) {
        $Summary.Status = 'Skipped'
        return $Summary
    }

    $Prefix = "repos/$Repository"
    $Existing = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($Label in (Get-RepositoryLabelCollection -Path "$Prefix/labels")) {
        if ($Label -isnot [System.Collections.IDictionary] -or [string]::IsNullOrWhiteSpace($Label['name']) -or
            -not $Existing.TryAdd($Label['name'], $Label)) {
            throw [System.IO.InvalidDataException]::new('GitHub returned invalid or duplicate repository labels.')
        }
    }

    foreach ($Label in $Desired) {
        $Name = $Label.name
        $Body = @{ color = $Label.color; description = $Label.description }
        $PresentAliases = @($Label.aliases | Where-Object { $Existing.ContainsKey($_) })
        if (-not $Existing.ContainsKey($Name)) {
            if ($PresentAliases.Count -gt 0) {
                $Alias = $PresentAliases[0]
                $Body.new_name = $Name
                $null = Invoke-RepositoryLabelApi -Path "$Prefix/labels/$([uri]::EscapeDataString($Alias))" -Method PATCH -Body $Body
                $null = $Existing.Remove($Alias)
                $Summary.Renamed++
            }
            else {
                $Body.name = $Name
                $null = Invoke-RepositoryLabelApi -Path "$Prefix/labels" -Method POST -Body $Body
                $Summary.Created++
            }
            $Existing[$Name] = @{ name = $Name; color = $Label.color; description = $Label.description }
        }
        else {
            $Current = $Existing[$Name]
            if ($Current.name -cne $Name -or $Current.color -ine $Label.color -or [string]$Current.description -cne $Label.description) {
                $Body.new_name = $Name
                $null = Invoke-RepositoryLabelApi -Path "$Prefix/labels/$([uri]::EscapeDataString($Current.name))" -Method PATCH -Body $Body
                $Summary.Updated++
                $Existing[$Name] = @{ name = $Name; color = $Label.color; description = $Label.description }
            }
            else { $Summary.Unchanged++ }
        }

        foreach ($Alias in $PresentAliases) {
            if (-not $Existing.ContainsKey($Alias)) { continue }
            $Issues = Get-RepositoryAliasIssues -Prefix $Prefix -Alias $Alias
            foreach ($Issue in $Issues) {
                if ($Issue.number -isnot [long] -and $Issue.number -isnot [int] -or $Issue.number -le 0 -or
                    $Issue.labels -isnot [System.Collections.IList]) {
                    throw [System.IO.InvalidDataException]::new('GitHub returned invalid alias assignments.')
                }
                if ($Name -notin @($Issue.labels | ForEach-Object { $_.name })) {
                    $null = Invoke-RepositoryLabelApi -Path "$Prefix/issues/$($Issue.number)/labels" -Method POST -Body @{ labels = @($Name) }
                    $Summary.MigratedIssues++
                }
            }
            foreach ($Issue in (Get-RepositoryAliasIssues -Prefix $Prefix -Alias $Alias)) {
                if ($Issue.labels -isnot [System.Collections.IList] -or $Name -notin @($Issue.labels | ForEach-Object { $_.name })) {
                    throw [System.IO.InvalidDataException]::new('Alias assignments changed or migration is incomplete; alias retained.')
                }
            }
            $null = Invoke-RepositoryLabelApi -Path "$Prefix/labels/$([uri]::EscapeDataString($Alias))" -Method DELETE
            $null = $Existing.Remove($Alias)
            $Summary.DeletedAliases++
        }
    }
    return $Summary
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Sync-RepositoryLabels -Repository $Repository -ConfigPath $ConfigPath -WhatIf:$WhatIfPreference |
            ConvertTo-Json -Compress
    }
    catch [System.IO.InvalidDataException] {
        Write-Error -Message $_.Exception.Message -ErrorAction Continue
        exit 1
    }
}

#endregion Main Execution
