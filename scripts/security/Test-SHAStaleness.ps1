#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Monitors SHA-pinned dependencies for staleness and security vulnerabilities.

.DESCRIPTION
    This script scans all SHA-pinned dependencies across GitHub Actions workflows
    to identify stale or potentially vulnerable dependencies. It outputs results in structured formats
    that can be consumed by CI/CD systems to generate build warnings.

    Key features:
    - Detects outdated GitHub Actions SHAs
    - Outputs results for CI/CD integration
    - Supports multiple output formats (JSON, Azure DevOps, GitHub Actions)

.PARAMETER OutputFormat
    Output format: 'json', 'azdo', 'github', or 'console' (default: console)

.PARAMETER MaxAge
    Maximum age in days before considering a dependency stale (default: 30)

.PARAMETER LogPath
    Path for security logging (default: ./logs/sha-staleness-monitoring.log)

.PARAMETER OutputPath
    Path to write structured output file (default: ./logs/stale-dependencies.json)

.EXAMPLE
    ./Test-SHAStaleness.ps1 -OutputFormat github
    Check for stale SHAs and output GitHub Actions warnings

.EXAMPLE
    ./Test-SHAStaleness.ps1 -OutputFormat azdo -MaxAge 14
    Check for stale SHAs and output Azure DevOps warnings for dependencies older than 14 days

.EXAMPLE
    ./Test-SHAStaleness.ps1 -OutputFormat json -OutputPath ./security-report.json
    Generate JSON report of all stale dependencies

.EXAMPLE
    ./Test-SHAStaleness.ps1 -FailOnStale
    Fail the build if stale dependencies are found

.EXAMPLE
    ./Test-SHAStaleness.ps1 -GraphQLBatchSize 10
    Use smaller GraphQL batch size for rate-limited environments
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("json", "azdo", "github", "console", "BuildWarning", "Summary")]
    [string]$OutputFormat = "console",

    [Parameter(Mandatory = $false)]
    [int]$MaxAge = 30,

    [Parameter(Mandatory = $false)]
    [string]$LogPath = "./logs/sha-staleness-monitoring.log",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./logs/sha-staleness-results.json",

    [Parameter(Mandatory = $false)]
    [switch]$FailOnStale,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 50)]
    [int]$GraphQLBatchSize = 20
)

# Ensure logging directory exists
$LogDir = Split-Path -Parent $LogPath
if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-SecurityLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )

    if ([string]::IsNullOrWhiteSpace($Message)) {
        $Message = "Empty log message"
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    # Console output with colors (only in console mode)
    if ($OutputFormat -eq "console") {
        switch ($Level) {
            "Info" { Write-Host $logEntry -ForegroundColor Cyan }
            "Warning" { Write-Host $logEntry -ForegroundColor Yellow }
            "Error" { Write-Host $logEntry -ForegroundColor Red }
            "Success" { Write-Host $logEntry -ForegroundColor Green }
        }
    }

    # File logging
    try {
        Add-Content -Path $LogPath -Value $logEntry -ErrorAction SilentlyContinue
    }
    catch {
        Write-Error "Failed to write to log file: $($_.Exception.Message)" -ErrorAction SilentlyContinue
    }
}

# Structure to hold stale dependency information
$StaleDependencies = @()

function Test-GitHubToken {
    param(
        [Parameter(Mandatory = $false)]
        [string]$Token
    )

    if (-not $Token) {
        Write-SecurityLog "No GitHub token found" -Level Warning
        Write-SecurityLog "SOLUTION: Set GITHUB_TOKEN environment variable for higher rate limits (5,000 vs 60 points/hour)" -Level Warning
        Write-SecurityLog "CAUSE: Unauthenticated GitHub GraphQL API requests are heavily rate limited" -Level Info
        return @{
            Valid         = $false
            Authenticated = $false
            RateLimit     = 60
            Message       = "No token provided - using unauthenticated API with 60 points/hour rate limit"
        }
    }

    try {
        $headers = @{
            "Authorization" = "Bearer $Token"
            "Content-Type"  = "application/json"
        }

        $query = @{
            query = "query { viewer { login } rateLimit { limit remaining resetAt } }"
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "https://api.github.com/graphql" -Method POST -Headers $headers -Body $query -ErrorAction Stop

        if ($response.data.viewer) {
            $rateLimit = $response.data.rateLimit
            Write-SecurityLog "GitHub token validated - User: $($response.data.viewer.login), Rate limit: $($rateLimit.remaining)/$($rateLimit.limit)" -Level Success
            
            if ($rateLimit.remaining -lt 100) {
                Write-SecurityLog "WARNING: GitHub API rate limit running low ($($rateLimit.remaining) remaining)" -Level Warning
                Write-SecurityLog "Rate limit resets at: $($rateLimit.resetAt)" -Level Info
            }

            return @{
                Valid         = $true
                Authenticated = $true
                RateLimit     = $rateLimit.limit
                Remaining     = $rateLimit.remaining
                ResetAt       = $rateLimit.resetAt
                User          = $response.data.viewer.login
                Message       = "Token valid - authenticated as $($response.data.viewer.login)"
            }
        }
    }
    catch {
        Write-SecurityLog "GitHub token validation failed: $($_.Exception.Message)" -Level Error
        Write-SecurityLog "CAUSE: Token may be expired, revoked, or have insufficient permissions" -Level Warning
        Write-SecurityLog "SOLUTION: Generate a new GitHub token with 'repo' scope at https://github.com/settings/tokens" -Level Warning
        return @{
            Valid         = $false
            Authenticated = $false
            Message       = "Token validation failed: $($_.Exception.Message)"
        }
    }

    return @{
        Valid         = $false
        Authenticated = $false
        Message       = "Token validation returned unexpected response"
    }
}

function Invoke-GitHubAPIWithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers,

        [Parameter(Mandatory = $false)]
        [string]$Body,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [int]$InitialDelaySeconds = 5
    )

    $attempt = 0
    $delay = $InitialDelaySeconds

    while ($attempt -lt $MaxRetries) {
        try {
            if ($Body) {
                $response = Invoke-RestMethod -Uri $Uri -Method $Method -Headers $Headers -Body $Body -ContentType "application/json" -ErrorAction Stop
            }
            else {
                $response = Invoke-RestMethod -Uri $Uri -Method $Method -Headers $Headers -ErrorAction Stop
            }
            return $response
        }
        catch {
            $statusCode = $null
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }

            # Check if it's a rate limit error (403 or 429)
            if ($statusCode -in 403, 429) {
                $attempt++
                if ($attempt -lt $MaxRetries) {
                    Write-SecurityLog "GitHub API rate limit hit (HTTP $statusCode). Retrying in $delay seconds (attempt $attempt/$MaxRetries)..." -Level Warning
                    Start-Sleep -Seconds $delay
                    $delay = $delay * 2  # Exponential backoff
                }
                else {
                    Write-SecurityLog "GitHub API rate limit exceeded after $MaxRetries attempts" -Level Error
                    Write-SecurityLog "CAUSE: Too many API requests in a short time period" -Level Warning
                    Write-SecurityLog "SOLUTION: Wait for rate limit to reset or provide a GitHub token with higher limits" -Level Warning
                    throw
                }
            }
            else {
                # Non-rate-limit error, throw immediately
                Write-SecurityLog "GitHub API request failed: $($_.Exception.Message)" -Level Error
                throw
            }
        }
    }

    throw "Failed to complete GitHub API request after $MaxRetries retries"
}

function Get-BulkGitHubActionsStaleness {
    param(
        [Parameter(Mandatory = $true)]
        [array]$ActionRepos,

        [Parameter(Mandatory = $true)]
        [hashtable]$ShaToActionMap,

        [int]$BatchSize = 20
    )

    # Setup headers with authentication
    $headers = @{
        "Content-Type" = "application/json"
    }

    # Check multiple potential sources for GitHub token
    $githubToken = $null
    if ($env:GITHUB_TOKEN) {
        $githubToken = $env:GITHUB_TOKEN
    }
    elseif ($env:SYSTEM_ACCESSTOKEN -and $env:BUILD_REPOSITORY_PROVIDER -eq "GitHub") {
        $githubToken = $env:SYSTEM_ACCESSTOKEN
    }
    elseif ($env:GH_TOKEN) {
        $githubToken = $env:GH_TOKEN
    }

    # Validate token if provided
    $tokenStatus = Test-GitHubToken -Token $githubToken
    if ($tokenStatus.Valid) {
        $headers['Authorization'] = "Bearer $githubToken"
    }
    elseif ($githubToken) {
        Write-SecurityLog "Token validation failed, proceeding without authentication" -Level Warning
    }

    # Build GraphQL query for multiple repositories (batch 1: get default branches)
    $repoQueries = @()
    $aliasMap = @{}

    foreach ($i in 0..($ActionRepos.Count - 1)) {
        $repo = $ActionRepos[$i]
        $alias = "repo$i"
        $aliasMap[$alias] = $repo

        # Parse owner/repo (handle actions with subpaths like github/codeql-action/upload-sarif)
        $parts = $repo.Split('/')
        if ($parts.Count -lt 2) { continue }
        $owner = $parts[0]
        $repoName = $parts[1]

        $repoQueries += @"
        $alias`: repository(owner: "$owner", name: "$repoName") {
            name
            defaultBranchRef {
                target {
                    ... on Commit {
                        oid
                        committedDate
                    }
                }
            }
        }
"@
    }

    # Single GraphQL query for all repository default branches
    $graphqlQuery = @{
        query = @"
        query {
            $($repoQueries -join "`n            ")
            rateLimit {
                limit
                remaining
                used
                resetAt
            }
        }
"@
    } | ConvertTo-Json -Depth 10

    try {
        $repoResponse = Invoke-GitHubAPIWithRetry -Uri "https://api.github.com/graphql" -Method POST -Headers $headers -Body $graphqlQuery

        Write-SecurityLog "GraphQL Rate Limit: $($repoResponse.data.rateLimit.remaining)/$($repoResponse.data.rateLimit.limit) remaining" -Level Info

        if ($repoResponse.errors) {
            Write-SecurityLog "GraphQL errors: $($repoResponse.errors | ConvertTo-Json)" -Level Warning
        }
    }
    catch {
        $statusCode = $null
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }

        if ($statusCode -in 403, 429) {
            Write-SecurityLog "Repository GraphQL query hit rate limit ($statusCode). Falling back to REST checks." -Level Warning
            Write-SecurityLog "SOLUTION: Provide a GitHub token via GITHUB_TOKEN environment variable for higher rate limits" -Level Warning
        }
        else {
            Write-SecurityLog "Repository GraphQL query failed: $($_.Exception.Message)" -Level Error
            Write-SecurityLog "CAUSE: Network connectivity issue or GitHub API unavailable" -Level Warning
        }

        throw
    }

    # Collect commit queries for all current SHAs
    $commitQueries = @()
    $commitAliasMap = @{}
    $commitIndex = 0

    foreach ($key in $ShaToActionMap.Keys) {
        $action = $ShaToActionMap[$key]
        $alias = "commit$commitIndex"
        $commitAliasMap[$alias] = $key

        # Parse owner/repo (handle actions with subpaths like github/codeql-action/upload-sarif)
        $parts = $action.Repo.Split('/')
        if ($parts.Count -lt 2) {
            Write-SecurityLog "Invalid action repository format: $($action.Repo) - must be 'owner/repo'" -Level Warning
            Write-SecurityLog "SOLUTION: Verify action reference in workflow file follows correct format" -Level Warning
            continue
        }
        $owner = $parts[0]
        $repoName = $parts[1]

        $commitQueries += @"
        $alias`: repository(owner: "$owner", name: "$repoName") {
            object(oid: "$($action.SHA)") {
                ... on Commit {
                    oid
                    committedDate
                }
            }
        }
"@
        $commitIndex++
    }

    # Use configurable batch size from script parameter
    $allCommitResults = @{}

    for ($i = 0; $i -lt $commitQueries.Count; $i += $BatchSize) {
        $endIndex = [Math]::Min($i + $BatchSize - 1, $commitQueries.Count - 1)
        $batchQueries = $commitQueries[$i..$endIndex]

        $commitGraphqlQuery = @{
            query = @"
            query {
                $($batchQueries -join "`n                ")
                rateLimit {
                    remaining
                    cost
                }
            }
"@
        } | ConvertTo-Json -Depth 10

        try {
            $commitResponse = Invoke-GitHubAPIWithRetry -Uri "https://api.github.com/graphql" -Method POST -Headers $headers -Body $commitGraphqlQuery

            # Merge results
            foreach ($property in $commitResponse.data.PSObject.Properties) {
                if ($property.Name -ne "rateLimit") {
                    $allCommitResults[$property.Name] = $property.Value
                }
            }

            Write-SecurityLog "GraphQL batch $([Math]::Floor($i / $BatchSize) + 1): Cost $($commitResponse.data.rateLimit.cost), $($commitResponse.data.rateLimit.remaining) remaining" -Level Info
        }
        catch {
            Write-SecurityLog "Commit GraphQL batch query failed: $($_.Exception.Message)" -Level Warning
            Write-SecurityLog "CAUSE: Network connectivity issue, rate limit exhausted, or malformed query" -Level Warning
            Write-SecurityLog "SOLUTION: Check GitHub API status or reduce -GraphQLBatchSize parameter (current: $BatchSize)" -Level Warning
        }
    }

    # Process results and return staleness information
    $results = @()

    foreach ($key in $ShaToActionMap.Keys) {
        $action = $ShaToActionMap[$key]

        # Find repository data
        $repoAlias = $null
        for ($i = 0; $i -lt $ActionRepos.Count; $i++) {
            if ($ActionRepos[$i] -eq $action.Repo) {
                $repoAlias = "repo$i"
                break
            }
        }

        if (-not $repoAlias -or -not $repoResponse.data.$repoAlias) {
            Write-SecurityLog "No repository data found for $($action.Repo)" -Level Warning
            continue
        }

        $repoData = $repoResponse.data.$repoAlias
        if (-not $repoData.defaultBranchRef) {
            Write-SecurityLog "No default branch found for $($action.Repo)" -Level Warning
            continue
        }

        $latestSHA = $repoData.defaultBranchRef.target.oid
        $latestDate = [DateTime]::Parse($repoData.defaultBranchRef.target.committedDate)

        # Find current commit data
        $commitAlias = $null
        foreach ($alias in $commitAliasMap.Keys) {
            if ($commitAliasMap[$alias] -eq $key) {
                $commitAlias = $alias
                break
            }
        }

        if ($commitAlias -and $allCommitResults[$commitAlias] -and $allCommitResults[$commitAlias].object) {
            $currentCommit = $allCommitResults[$commitAlias].object
            $currentDate = [DateTime]::Parse($currentCommit.committedDate)
            $daysOld = [Math]::Round((Get-Date).Subtract($currentDate).TotalDays)

            $results += @{
                ActionRepo  = $action.Repo
                CurrentSHA  = $action.SHA
                LatestSHA   = $latestSHA
                CurrentDate = $currentDate
                LatestDate  = $latestDate
                DaysOld     = $daysOld
                IsStale     = $action.SHA -ne $latestSHA -and $daysOld -gt $MaxAge
                File        = $action.File
            }
        }
        else {
            Write-SecurityLog "No commit data found for $($action.Repo)@$($action.SHA)" -Level Warning
        }
    }

    $totalCalls = 1 + [Math]::Ceiling($commitQueries.Count / $BatchSize)
    $originalCalls = $ShaToActionMap.Count * 3
    $reduction = [Math]::Round((1 - ($totalCalls / $originalCalls)) * 100, 1)

    Write-SecurityLog "GraphQL optimization: Reduced from ~$originalCalls REST calls to $totalCalls GraphQL calls ($reduction% reduction)" -Level Success

    return $results
}

function Test-GitHubActionsForStaleness {
    Write-SecurityLog "Scanning GitHub Actions workflows for stale SHAs..." -Level Info

    $WorkflowFiles = Get-ChildItem -Path ".github/workflows" -Filter "*.yml" -ErrorAction SilentlyContinue
    $allActionRepos = @()
    $shaToActionMap = @{}

    # First pass: collect all unique repositories and SHAs
    foreach ($File in $WorkflowFiles) {
        $Content = Get-Content -Path $File.FullName -Raw
        $SHAMatches = [regex]::Matches($Content, "uses:\s*([^@\s]+)@([a-fA-F0-9]{40})")

        foreach ($Match in $SHAMatches) {
            $ActionRepo = $Match.Groups[1].Value
            $CurrentSHA = $Match.Groups[2].Value

            if ($ActionRepo -notin $allActionRepos) {
                $allActionRepos += $ActionRepo
            }

            $shaToActionMap["$ActionRepo@$CurrentSHA"] = @{
                Repo = $ActionRepo
                SHA  = $CurrentSHA
                File = $File.FullName
            }
        }
    }

    if ($allActionRepos.Count -eq 0) {
        Write-SecurityLog "No SHA-pinned GitHub Actions found" -Level Info
        return
    }

    Write-SecurityLog "Found $($allActionRepos.Count) unique repositories with $($shaToActionMap.Count) SHA-pinned actions" -Level Info

    # Bulk query for all actions using GraphQL optimization
    try {
        $bulkResults = Get-BulkGitHubActionsStaleness -ActionRepos $allActionRepos -ShaToActionMap $shaToActionMap -BatchSize $GraphQLBatchSize

        foreach ($result in $bulkResults) {
            if ($result.IsStale) {
                $script:StaleDependencies += [PSCustomObject]@{
                    Type           = "GitHubAction"
                    File           = $result.File
                    Name           = $result.ActionRepo
                    CurrentVersion = $result.CurrentSHA
                    LatestVersion  = $result.LatestSHA
                    DaysOld        = $result.DaysOld
                    Severity       = if ($result.DaysOld -gt 90) { "High" } elseif ($result.DaysOld -gt 60) { "Medium" } else { "Low" }
                    Message        = "GitHub Action is $($result.DaysOld) days old (current: $($result.CurrentSHA.Substring(0,8)), latest: $($result.LatestSHA.Substring(0,8)))"
                }

                Write-SecurityLog "Found stale GitHub Action: $($result.ActionRepo) ($($result.DaysOld) days old)" -Level Warning
            }
            else {
                Write-SecurityLog "GitHub Action is up-to-date: $($result.ActionRepo)" -Level Info
            }
        }
    }
    catch {
        Write-SecurityLog "Bulk GraphQL check failed, falling back to individual checks: $($_.Exception.Message)" -Level Warning

        # Fallback to individual REST API calls if GraphQL fails
        $defaultBranchCache = @{}
        $rateLimitExceeded = $false
        foreach ($key in $shaToActionMap.Keys) {
            $action = $shaToActionMap[$key]

            Write-SecurityLog "Checking GitHub Action (fallback): $($action.Repo)@$($action.SHA)" -Level Info

            # Individual REST API call as fallback
            try {
                $headers = @{}
                if ($env:GITHUB_TOKEN) {
                    $headers['Authorization'] = "token $env:GITHUB_TOKEN"
                }

                $repoSegments = $action.Repo.Split('/')
                if ($repoSegments.Count -lt 2) {
                    Write-SecurityLog "Invalid GitHub Action repository format: $($action.Repo)" -Level Warning
                    continue
                }

                $owner = $repoSegments[0]
                $repoName = $repoSegments[1]
                $repoLookup = "$owner/$repoName"

                if (-not $defaultBranchCache.ContainsKey($repoLookup)) {
                    try {
                        $repoInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoLookup" -Headers $headers -ErrorAction Stop
                        $defaultBranch = if ($repoInfo.default_branch) { $repoInfo.default_branch } else { "main" }
                        $defaultBranchCache[$repoLookup] = $defaultBranch
                    }
                    catch {
                        Write-SecurityLog "Failed to discover default branch for $repoLookup, defaulting to 'main': $($_.Exception.Message)" -Level Warning
                        $defaultBranchCache[$repoLookup] = "main"
                    }
                }

                $branchName = $defaultBranchCache[$repoLookup]

                $BranchInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoLookup/branches/$branchName" -Headers $headers -ErrorAction Stop
                $LatestSHA = $BranchInfo.commit.sha

                if ($action.SHA -ne $LatestSHA) {
                    $CurrentCommit = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoLookup/commits/$($action.SHA)" -Headers $headers -ErrorAction Stop
                    $CurrentDate = [DateTime]::Parse($CurrentCommit.commit.author.date)
                    $DaysOld = [Math]::Round((Get-Date).Subtract($CurrentDate).TotalDays)

                    if ($DaysOld -gt $MaxAge) {
                        $script:StaleDependencies += [PSCustomObject]@{
                            Type           = "GitHubAction"
                            File           = $action.File
                            Name           = $action.Repo
                            CurrentVersion = $action.SHA
                            LatestVersion  = $LatestSHA
                            DaysOld        = $DaysOld
                            Severity       = if ($DaysOld -gt 90) { "High" } elseif ($DaysOld -gt 60) { "Medium" } else { "Low" }
                            Message        = "GitHub Action is $DaysOld days old (current: $($action.SHA.Substring(0,8)), latest: $($LatestSHA.Substring(0,8)))"
                        }

                        Write-SecurityLog "Found stale GitHub Action (fallback): $($action.Repo) ($DaysOld days old)" -Level Warning
                    }
                }
            }
            catch {
                $statusCode = $null
                if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                    $statusCode = [int]$_.Exception.Response.StatusCode
                }
                elseif ($_.Exception.StatusCode) {
                    $statusCode = [int]$_.Exception.StatusCode
                }

                if ($statusCode -eq 403 -or $statusCode -eq 429) {
                    Write-SecurityLog "GitHub API rate limit exceeded for $($action.Repo) - skipping remaining GitHub Action checks" -Level Warning
                    $rateLimitExceeded = $true
                }
                else {
                    Write-SecurityLog "Failed to check GitHub Action $($action.Repo): $($_.Exception.Message)" -Level Warning
                }
            }

            if ($rateLimitExceeded) {
                break
            }
        }

        if ($rateLimitExceeded) {
            Write-SecurityLog "GitHub Action staleness results are incomplete due to API rate limiting. Provide a token via GITHUB_TOKEN to enable full coverage." -Level Warning
        }
    }
}

function Write-OutputResult {
    param(
        [Parameter(Mandatory = $false)]
        [array]$Dependencies = @(),

        [Parameter(Mandatory)]
        [ValidateSet("json", "azdo", "github", "console", "BuildWarning", "Summary")]
        [string]$OutputFormat,

        [Parameter()]
        [string]$OutputPath
    )

    switch ($OutputFormat) {
        "json" {
            $JsonOutput = @{
                Timestamp       = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                MaxAgeThreshold = $MaxAge
                TotalStaleItems = $Dependencies.Count
                Dependencies    = $Dependencies
            } | ConvertTo-Json -Depth 10

            try {
                # Ensure output directory exists
                $OutputDir = Split-Path -Parent $OutputPath
                if (!(Test-Path $OutputDir)) {
                    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
                    Write-SecurityLog "Created output directory: $OutputDir" -Level Info
                }

                Set-Content -Path $OutputPath -Value $JsonOutput
                Write-SecurityLog "JSON report written to: $OutputPath" -Level Success
            }
            catch {
                Write-SecurityLog "Failed to write JSON output: $($_.Exception.Message)" -Level Error
                Write-SecurityLog "CAUSE: Insufficient permissions or invalid path" -Level Warning
                Write-SecurityLog "SOLUTION: Verify OutputPath is writable: $OutputPath" -Level Warning
            }
        }

        "github" {
            foreach ($Dep in $Dependencies) {
                $Message = "::warning file=$($Dep.File.Replace('\', '/'))::[$($Dep.Severity)] $($Dep.Message)"
                Write-Output $Message
            }

            if ($Dependencies.Count -eq 0) {
                Write-Output "::notice::No stale dependencies detected"
            }
            else {
                Write-Output "::error::Found $($Dependencies.Count) stale dependencies that may pose security risks"
            }
        }

        "azdo" {
            foreach ($Dep in $Dependencies) {
                $Message = "##vso[task.logissue type=warning;sourcepath=$($Dep.File);][$($Dep.Severity)] $($Dep.Message)"
                Write-Output $Message
            }

            if ($Dependencies.Count -eq 0) {
                Write-Output "##vso[task.logissue type=info]No stale dependencies detected"
            }
            else {
                Write-Output "##vso[task.logissue type=error]Found $($Dependencies.Count) stale dependencies that may pose security risks"
                Write-Output "##vso[task.complete result=SucceededWithIssues]"
            }
        }

        "console" {
            if ($Dependencies.Count -eq 0) {
                Write-SecurityLog "No stale dependencies detected!" -Level Success
            }
            else {
                Write-SecurityLog "=== STALE DEPENDENCIES DETECTED ===" -Level Warning
                foreach ($Dep in $Dependencies) {
                    Write-SecurityLog "[$($Dep.Severity)] $($Dep.Type): $($Dep.Name)" -Level Warning
                    Write-SecurityLog "  File: $($Dep.File)" -Level Info
                    Write-SecurityLog "  Message: $($Dep.Message)" -Level Info
                    Write-Information "" -InformationAction Continue
                }
                Write-SecurityLog "Total stale dependencies: $($Dependencies.Count)" -Level Warning
            }
        }

        "Summary" {
            if ($Dependencies.Count -eq 0) {
                Write-Output "No stale dependencies detected!"
            }
            else {
                Write-Output "=== SHA Staleness Summary ==="
                Write-Output "Total stale dependencies: $($Dependencies.Count)"
                $ByType = $Dependencies | Group-Object Type
                foreach ($Group in $ByType) {
                    Write-Output "$($Group.Name): $($Group.Count)"
                }
            }
        }
    }
}

function Compare-ToolVersion {
    <#
    .SYNOPSIS
        Compares two version strings using semantic versioning rules.
    .DESCRIPTION
        Normalizes version strings by removing v-prefix and pre-release metadata,
        then compares using System.Version when possible.
    .OUTPUTS
        Returns $true if Latest is newer than Current, $false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Current,

        [Parameter(Mandatory)]
        [string]$Latest
    )

    # Normalize: strip v prefix, remove pre-release/build metadata
    $normCurrent = $Current -replace '^v', '' -replace '[-+].*$', ''
    $normLatest = $Latest -replace '^v', '' -replace '[-+].*$', ''

    $currentVersion = $null
    $latestVersion = $null

    if ([System.Version]::TryParse($normCurrent, [ref]$currentVersion) -and
        [System.Version]::TryParse($normLatest, [ref]$latestVersion)) {
        return $latestVersion -gt $currentVersion
    }

    # Fallback: string comparison (not ideal but better than nothing)
    Write-Verbose "Version parsing failed, falling back to string comparison"
    return $normLatest -ne $normCurrent
}

function Get-ToolStaleness {
    <#
    .SYNOPSIS
        Checks tool versions against their latest GitHub releases.

    .DESCRIPTION
        Reads the tool-checksums.json manifest and queries the GitHub Releases API
        to detect when tracked tools have newer versions available.

    .PARAMETER ManifestPath
        Path to the tool-checksums.json manifest file.

    .PARAMETER GitHubToken
        GitHub API token for authenticated requests (higher rate limits).
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ManifestPath = (Join-Path $PSScriptRoot "tool-checksums.json"),

        [Parameter()]
        [string]$GitHubToken = $env:GITHUB_TOKEN
    )

    if (-not (Test-Path $ManifestPath)) {
        Write-Warning "Tool manifest not found: $ManifestPath"
        return @()
    }

    $manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    $results = @()

    $headers = @{
        'Accept'               = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
    }
    if ($GitHubToken) {
        $headers['Authorization'] = "Bearer $GitHubToken"
    }

    foreach ($tool in $manifest.tools) {
        try {
            $uri = "https://api.github.com/repos/$($tool.repo)/releases/latest"
            $latestRelease = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
            $latestVersion = $latestRelease.tag_name -replace '^v', ''

            $isStale = Compare-ToolVersion -Current $tool.version -Latest $latestVersion

            $results += [PSCustomObject]@{
                Tool           = $tool.name
                Repository     = $tool.repo
                CurrentVersion = $tool.version
                LatestVersion  = $latestVersion
                IsStale        = $isStale
                CurrentSHA256  = $tool.sha256
                Notes          = $tool.notes
                Error          = $null
            }
        }
        catch {
            $errorMsg = "Failed to check $($tool.name): $_"
            Write-Warning $errorMsg

            $results += [PSCustomObject]@{
                Tool           = $tool.name
                Repository     = $tool.repo
                CurrentVersion = $tool.version
                LatestVersion  = $null
                IsStale        = $null  # Unknown due to error
                CurrentSHA256  = $tool.sha256
                Notes          = $tool.notes
                Error          = $errorMsg
            }
        }
    }

    return $results
}

#region Main Execution
try {
    Write-SecurityLog "Starting SHA staleness monitoring..." -Level Info
    Write-SecurityLog "Max age threshold: $MaxAge days" -Level Info
    Write-SecurityLog "GraphQL batch size: $GraphQLBatchSize queries per request" -Level Info
    Write-SecurityLog "Output format: $OutputFormat" -Level Info

    # Run staleness check for GitHub Actions
    Test-GitHubActionsForStaleness

    # Run staleness check for tools from tool-checksums.json
    Write-SecurityLog "Checking tool staleness from tool-checksums.json" -Level Info

    $toolResults = Get-ToolStaleness
    if ($toolResults) {
        $staleTools = $toolResults | Where-Object { $_.IsStale -eq $true }
        if ($staleTools.Count -gt 0) {
            Write-SecurityLog "Found $($staleTools.Count) stale tool(s):" -Level Warning
            foreach ($tool in $staleTools) {
                Write-SecurityLog "  - $($tool.Tool): $($tool.CurrentVersion) -> $($tool.LatestVersion)" -Level Warning
                
                # Add to global stale dependencies for output
                $script:StaleDependencies += [PSCustomObject]@{
                    Type           = "Tool"
                    File           = "scripts/security/tool-checksums.json"
                    Name           = $tool.Tool
                    CurrentVersion = $tool.CurrentVersion
                    LatestVersion  = $tool.LatestVersion
                    DaysOld        = $null  # Not tracked for tools
                    Severity       = "Medium"
                    Message        = "Tool has newer version available: $($tool.CurrentVersion) -> $($tool.LatestVersion)"
                }
            }
        }
        else {
            Write-SecurityLog "All tools are up to date" -Level Info
        }

        # Check for errors
        $errorTools = $toolResults | Where-Object { $null -ne $_.Error }
        if ($errorTools.Count -gt 0) {
            Write-SecurityLog "Failed to check $($errorTools.Count) tool(s)" -Level Warning
        }
    }

    # Output results
    Write-OutputResult -Dependencies $StaleDependencies -OutputFormat $OutputFormat -OutputPath $OutputPath

    Write-SecurityLog "SHA staleness monitoring completed" -Level Success
    Write-SecurityLog "Stale dependencies found: $($StaleDependencies.Count)" -Level Info

    # Exit with appropriate code based on findings and -FailOnStale parameter
    if ($StaleDependencies.Count -gt 0) {
        if ($FailOnStale) {
            Write-SecurityLog "Exiting with status 1 due to stale dependencies (-FailOnStale specified)" -Level Warning
            exit 1
        }
        else {
            Write-SecurityLog "Stale dependencies found but exiting with status 0 (use -FailOnStale to fail build)" -Level Warning
            exit 0
        }
    }
    exit 0  # All good
}
catch {
    Write-Error "Test SHA Staleness failed: $($_.Exception.Message)"
    if ($env:GITHUB_ACTIONS -eq 'true') {
        Write-Output "::error::$($_.Exception.Message)"
    }
    exit 1
}
#endregion