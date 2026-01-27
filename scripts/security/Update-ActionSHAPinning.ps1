#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Updates GitHub Actions workflows to use SHA-pinned action references for supply chain security.

.DESCRIPTION
    This script scans GitHub Actions workflows and replaces mutable tag references with immutable SHA commits.
    This prevents supply chain attacks through compromised action repositories by ensuring reproducible builds.

    With -UpdateStale, the script will fetch the latest commit SHAs from GitHub and update already-pinned actions.

.PARAMETER WorkflowPath
    Path to the .github/workflows directory. Defaults to current repository structure.

.PARAMETER OutputReport
    Generate detailed report of changes and pinning status.

.EXAMPLE
    ./Update-ActionSHAPinning.ps1 -OutputReport -WhatIf
    Preview SHA pinning changes and generate report without modifying files.

.EXAMPLE
    ./Update-ActionSHAPinning.ps1
    Apply SHA pinning to all workflows and update files.

.EXAMPLE
    ./Update-ActionSHAPinning.ps1 -UpdateStale
    Update already-pinned-but-stale GitHub Actions to their latest commit SHAs.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$WorkflowPath = ".github/workflows",

    [Parameter()]
    [switch]$OutputReport,

    [Parameter()]
    [ValidateSet("json", "azdo", "github", "console", "BuildWarning", "Summary")]
    [string]$OutputFormat = "console",

    [Parameter()]
    [switch]$UpdateStale
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Explicit parameter usage to satisfy static analyzer
Write-Debug "Parameters: WorkflowPath=$WorkflowPath, OutputReport=$OutputReport, OutputFormat=$OutputFormat, UpdateStale=$UpdateStale"

function Test-GitHubToken {
    <#
    .SYNOPSIS
        Validates GitHub token and checks API rate limits.
    
    .DESCRIPTION
        Tests if the provided GitHub token is valid and checks remaining rate limit.
        Returns detailed status including authentication, rate limit info, and actionable messages.
    
    .PARAMETER Token
        GitHub personal access token or GITHUB_TOKEN to validate
    
    .OUTPUTS
        Hashtable with keys: Valid, Authenticated, RateLimit, Remaining, ResetAt, User, Message
    #>
    param(
        [Parameter()]
        [string]$Token
    )

    $result = @{
        Valid         = $false
        Authenticated = $false
        RateLimit     = 0
        Remaining     = 0
        ResetAt       = $null
        User          = $null
        Message       = ""
    }

    try {
        $headers = @{
            "User-Agent" = "GitHub-Actions-Security-Scanner"
        }

        if ($Token) {
            $headers["Authorization"] = "Bearer $Token"
        }

        # Use GraphQL to check authentication and rate limits
        $query = @{
            query = "query { viewer { login } rateLimit { limit remaining resetAt } }"
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "https://api.github.com/graphql" -Method POST -Headers $headers -Body $query -ErrorAction Stop

        if ($response.data.viewer) {
            $result.Valid = $true
            $result.Authenticated = $true
            $result.User = $response.data.viewer.login
            $result.Message = "Authenticated as $($result.User)"
        }
        elseif ($response.data.rateLimit) {
            $result.Valid = $true
            $result.Authenticated = $false
            $result.Message = "Unauthenticated access - limited rate limits"
        }

        $result.RateLimit = $response.data.rateLimit.limit
        $result.Remaining = $response.data.rateLimit.remaining
        $result.ResetAt = $response.data.rateLimit.resetAt

        if ($result.Remaining -lt 100) {
            $result.Message += " | WARNING: Only $($result.Remaining) API calls remaining (resets at $($result.ResetAt))"
        }

        if (-not $result.Authenticated) {
            Write-Warning "SOLUTION: Set GITHUB_TOKEN environment variable for higher rate limits (5,000 vs 60 points/hour)"
            Write-Warning "CAUSE: Unauthenticated GitHub GraphQL API requests are heavily rate limited"
        }
    }
    catch {
        $result.Message = "Token validation failed: $($_.Exception.Message)"
        Write-Warning $result.Message
    }

    return $result
}

function Invoke-GitHubAPIWithRetry {
    <#
    .SYNOPSIS
        Invokes GitHub API with exponential backoff retry for rate limits.
    
    .DESCRIPTION
        Wraps Invoke-RestMethod with intelligent retry logic for rate-limited API calls.
        Implements exponential backoff when encountering 403/429 responses.
    
    .PARAMETER Uri
        GitHub API URI to call
    
    .PARAMETER Method
        HTTP method (GET, POST, etc.)
    
    .PARAMETER Headers
        HTTP headers hashtable
    
    .PARAMETER Body
        Request body (optional)
    
    .PARAMETER MaxRetries
        Maximum number of retry attempts (default: 3)
    
    .PARAMETER InitialDelaySeconds
        Initial delay in seconds before first retry (default: 5)
    
    .OUTPUTS
        API response object
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter(Mandatory)]
        [hashtable]$Headers,

        [Parameter()]
        [string]$Body,

        [Parameter()]
        [int]$MaxRetries = 3,

        [Parameter()]
        [int]$InitialDelaySeconds = 5
    )

    $attempt = 0
    $delay = $InitialDelaySeconds

    while ($attempt -lt $MaxRetries) {
        try {
            $params = @{
                Uri     = $Uri
                Method  = $Method
                Headers = $Headers
            }

            if ($Body) {
                $params['Body'] = $Body
                $params['ContentType'] = "application/json"
            }

            $response = Invoke-RestMethod @params -ErrorAction Stop
            return $response
        }
        catch {
            $statusCode = $null
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }

            # Check if rate limited (403 or 429)
            if ($statusCode -in 403, 429) {
                $attempt++
                if ($attempt -ge $MaxRetries) {
                    Write-Warning "CAUSE: Too many API requests in a short time period"
                    Write-Warning "SOLUTION: Wait for rate limit to reset or provide a GitHub token with higher limits"
                    throw
                }

                Write-Warning "Rate limited (HTTP $statusCode). Retrying in $delay seconds... (Attempt $attempt/$MaxRetries)"
                Start-Sleep -Seconds $delay
                $delay = $delay * 2  # Exponential backoff
            }
            else {
                # Non-rate-limit error, don't retry
                throw
            }
        }
    }

    throw "Max retries exceeded for API call to $Uri"
}

# Common GitHub Actions and their current SHA references
$ActionSHAMap = @{
    "actions/checkout@v4"                  = "actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332" # v4.1.7
    "actions/checkout@v3"                  = "actions/checkout@f43a0e5ff2bd294095638e18286ca9a3d1956744" # v3.6.0
    "actions/setup-node@v4"                = "actions/setup-node@1e60f620b9541d16bece96c5465dc8ee9832be0b" # v4.0.3
    "actions/setup-node@v3"                = "actions/setup-node@5e21ff4d9bc06a74674ebf3f11c5d9bb6f561e3b" # v3.8.2
    "actions/setup-python@v5"              = "actions/setup-python@39cd14951b08e74b54015e9e001cdefcf80e669f" # v5.1.1
    "actions/setup-python@v4"              = "actions/setup-python@65d7f2d534ac1bc67fcd62888c5f4f3d2cb2b236" # v4.8.0
    "actions/setup-dotnet@v4"              = "actions/setup-dotnet@6bd8b7f7774af54e05809fcc5431931b3eb1ddee" # v4.0.1
    "actions/setup-dotnet@v3"              = "actions/setup-dotnet@4d6c8fcf3c8f7a60068d26b594648e99df24cee3" # v3.2.0
    "actions/cache@v4"                     = "actions/cache@0c45773b623bea8c8e75f6c82b208c3cf94ea4f9" # v4.0.2
    "actions/cache@v3"                     = "actions/cache@88522ab9f39a2ea568f7027eddc7d8d8bc9d59c8" # v3.3.1
    "actions/upload-artifact@v4"           = "actions/upload-artifact@65462800fd760344b1a7b4382951275a0abb4808" # v4.3.6
    "actions/upload-artifact@v3"           = "actions/upload-artifact@5d5d22a31266ced268874388b861e4b58bb5c2f3" # v3.1.3
    "actions/download-artifact@v7"         = "actions/download-artifact@37930b1c2abaa49bbe596cd826c3c89aef350131" # v7.0.0
    "actions/download-artifact@v4"         = "actions/download-artifact@fa0a91b85d4f404e444e00e005971372dc801d16" # v4.1.8
    "actions/download-artifact@v3"         = "actions/download-artifact@9bc31d5ccc31df68ecc42ccf4149144866c47d8a" # v3.0.2
    "actions/attest-build-provenance@v2"   = "actions/attest-build-provenance@c074443f1aee8d4aeeae555aebba3282517141b2" # v2.2.3
    "github/super-linter@v6"               = "github/super-linter@4ac6c1e9bce95c4e5e456c8c2c6b468998248097" # v6.8.0
    "github/super-linter@v5"               = "github/super-linter@45fc0d88288beee4701c62761281edfee85655d7" # v5.7.2
    "hashicorp/setup-terraform@v3"         = "hashicorp/setup-terraform@651471c36a6092792c552e8b1bef71e592b462d8" # v3.1.1
    "hashicorp/setup-terraform@v2"         = "hashicorp/setup-terraform@633666f66e0061ca3b725c73b2ec20cd13a8fdd1" # v2.0.3
    "azure/login@v2"                       = "azure/login@6c251865b4e6290e7b78be643ea2d005bc51f69a" # v2.1.1
    "azure/login@v1"                       = "azure/login@92a5484dfaf04ca78a94597f4f19fea633851fa2" # v1.6.1
    "azure/CLI@v2"                         = "azure/CLI@965c8d7571d2231a54e321ddd07f7b10317f34d9" # v2.0.0
    "azure/CLI@v1"                         = "azure/CLI@4db43908b9df2e7ac93d6dcbdb02c7e9a4429c2a" # v1.0.9
    "docker/setup-buildx-action@v3"        = "docker/setup-buildx-action@4fd812986e6c8c2a69e18311145f9371337f27d4" # v3.4.0
    "docker/setup-buildx-action@v2"        = "docker/setup-buildx-action@885d1462b80bc1c1c7f0b00334ad271f09369c55" # v2.10.0
    "docker/build-push-action@v6"          = "docker/build-push-action@5176d81f87c23d6fc96624dfdbcd9f3830bbe445" # v6.6.1
    "docker/build-push-action@v5"          = "docker/build-push-action@2cdde995de11925a030ce8070c3d77a52ffcf1c0" # v5.4.0
    "docker/login-action@v3"               = "docker/login-action@9780b0c442fbb1117ed29e0efdff1e18412f7567" # v3.3.0
    "docker/login-action@v2"               = "docker/login-action@465a07811f14bebb1938fbed4728c6a1ff8901fc" # v2.2.0
    "peaceiris/actions-gh-pages@v4"        = "peaceiris/actions-gh-pages@4f9cc6602d3f66b9c108549d475ec49e8ef4d45e" # v4.0.0
    "peaceiris/actions-gh-pages@v3"        = "peaceiris/actions-gh-pages@373f7f263a76c20808c831209c920827a82a2847" # v3.9.3
    "coverallsapp/github-action@v2"        = "coverallsapp/github-action@643bc377ffa44ace6a3b31e8fd2cbb982c5f04f3" # v2.3.0
    "codecov/codecov-action@v4"            = "codecov/codecov-action@e28ff129e5465c2c0dcc6f003fc735cb6ae0c673" # v4.5.0
    "codecov/codecov-action@v3"            = "codecov/codecov-action@eaaf4bedf32dbdc6b720b63067d99c4d77d6047d" # v3.1.4
    "microsoft/setup-msbuild@v2"           = "microsoft/setup-msbuild@6fb02220983dee41ce7ae257b6f4d8f9bf5ed4ce" # v2.0.0
    "microsoft/setup-msbuild@v1"           = "microsoft/setup-msbuild@ab534842b4bdf384b8aaf93765dc6f721d9f5fab" # v1.3.1
    "dorny/paths-filter@v3"                = "dorny/paths-filter@de90cc6fb38fc0963ad72b210f1f284cd68cea36" # v3.0.2
    "dorny/paths-filter@v2"                = "dorny/paths-filter@4512585405083f25c027a35db413c2b3b9006d50" # v2.11.1

    # Additional actions requiring SHA pinning
    "actions/github-script@v7"             = "actions/github-script@60a0d83039c74a4aee543508d2ffcb1c3799cdea" # v7.0.1
    "actions/dependency-review-action@v3"  = "actions/dependency-review-action@72eb03d02c7872a771aacd928f3123ac62ad6d3a" # v3.1.0
    "actions/dependency-review-action@v4"  = "actions/dependency-review-action@5a2ce3f5b92ee19cbb1541a4984c76d921601d7c" # v4.3.4
    "github/codeql-action/init@v3"         = "github/codeql-action/init@294a9d92911152fe08befb9ec03e240add280cb3" # v3.26.8
    "github/codeql-action/autobuild@v3"    = "github/codeql-action/autobuild@294a9d92911152fe08befb9ec03e240add280cb3" # v3.26.8
    "github/codeql-action/analyze@v3"      = "github/codeql-action/analyze@294a9d92911152fe08befb9ec03e240add280cb3" # v3.26.8
    "github/codeql-action/upload-sarif@v3" = "github/codeql-action/upload-sarif@294a9d92911152fe08befb9ec03e240add280cb3" # v3.26.8
    "oxsecurity/megalinter@v8"             = "oxsecurity/megalinter@c217fe8f7bc9207062a084e989bd97efd56e7b9a" # v8.0.0
    "actions/deploy-pages@v4"              = "actions/deploy-pages@d6db90164ac5ed86f2b6aed7e0febac5b3c0c03e" # v4.0.5
    "actions/upload-pages-artifact@v3"     = "actions/upload-pages-artifact@56afc609e74202658d3ffba0e8f6dda462b719fa" # v3.0.1
    "actions/configure-pages@v4"           = "actions/configure-pages@983d7736d9b0ae728b81ab479565c72886d7745b" # v4.0.0
    "azure/powershell@v1"                  = "azure/powershell@1c589a2e445c71fe2cea92c69f7b80b572760c3b" # v1.5.0
    "azure/get-keyvault-secrets@v1"        = "azure/get-keyvault-secrets@b5c723b9ac7870c022b8c35befe620b7009b336f" # v1.2
}

function Write-SecurityLog {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = "[$timestamp] [$Level]"

    # Handle empty strings for formatting (blank lines)
    if ([string]::IsNullOrWhiteSpace($Message)) {
        Write-Host ""
        return
    }

    Write-Host "$prefix $Message"
}

# Initialize security issues array at script scope
$script:SecurityIssues = @()

function Add-SecurityIssue {
    param(
        [Parameter(Mandatory)]
        [string]$Type,

        [Parameter(Mandatory)]
        [string]$Severity,

        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Description,

        [Parameter()]
        [string]$File,

        [Parameter()]
        [string]$Line,

        [Parameter()]
        [string]$Recommendation
    )

    $issue = @{
        Type           = $Type
        Severity       = $Severity
        Title          = $Title
        Description    = $Description
        File           = $File
        Line           = $Line
        Recommendation = $Recommendation
        Timestamp      = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }

    $script:SecurityIssues += $issue
}

function Write-OutputResult {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("json", "azdo", "github", "console", "BuildWarning", "Summary")]
        [string]$OutputFormat,

        [Parameter()]
        [array]$Results = @(),

        [Parameter()]
        [string]$Summary = "",

        [Parameter()]
        [string]$OutputPath
    )

    switch ($OutputFormat) {
        "json" {
            $output = @{
                Summary   = $Summary
                Issues    = $Results
                Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }
            $jsonOutput = $output | ConvertTo-Json -Depth 5
            if ($OutputPath) {
                $OutputDir = Split-Path -Parent $OutputPath
                if (!(Test-Path $OutputDir)) {
                    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
                }
                Set-Content -Path $OutputPath -Value $jsonOutput
                Write-SecurityLog "JSON security report written to: $OutputPath" -Level Success
            }
            return $jsonOutput
        }
        "BuildWarning" {
            if (@($Results).Count -eq 0) {
                Write-Output "##[section]No GitHub Actions security issues found"
                return
            }

            Write-Output "##[section]GitHub Actions Security Issues Found:"
            foreach ($issue in $Results) {
                $message = "$($issue.Title) - $($issue.Description)"
                if ($issue.File) {
                    $message += " (File: $($issue.File))"
                }
                if ($issue.Recommendation) {
                    $message += " Recommendation: $($issue.Recommendation)"
                }
                Write-Output "##[warning]$message"
            }
            return
        }
        "github" {
            if (@($Results).Count -eq 0) {
                Write-Output "::notice::No GitHub Actions security issues found"
                return
            }

            foreach ($issue in $Results) {
                $message = "[$($issue.Severity)] $($issue.Title) - $($issue.Description)"
                if ($issue.File) {
                    $normalizedPath = $issue.File -replace '\\', '/'
                    Write-Output "::warning file=$normalizedPath::$message"
                }
                else {
                    Write-Output "::warning::$message"
                }
            }
            return
        }
        "azdo" {
            if (@($Results).Count -eq 0) {
                Write-Output "##vso[task.logissue type=info]No GitHub Actions security issues found"
                return
            }

            foreach ($issue in $Results) {
                $message = "[$($issue.Severity)] $($issue.Title) - $($issue.Description)"
                $sourcePath = $issue.File
                if ($sourcePath) {
                    Write-Output "##vso[task.logissue type=warning;sourcepath=$sourcePath]$message"
                }
                else {
                    Write-Output "##vso[task.logissue type=warning]$message"
                }
            }
            Write-Output "##vso[task.complete result=SucceededWithIssues]"
            return
        }
        default {
            # Console format - existing behavior maintained
            if (@($script:SecurityIssues).Count -gt 0) {
                Write-SecurityLog "Security Issues Summary:" -Level 'Warning'
                foreach ($issue in $script:SecurityIssues) {
                    Write-SecurityLog "  $($issue.Title): $($issue.Description)" -Level 'Warning'
                }
            }
            return
        }
    }
}

function Get-ActionReference {
    param(
        [Parameter(Mandatory)]
        [string]$WorkflowContent
    )

    # Match GitHub Actions usage patterns with uses: keyword
    $actionPattern = '(?m)^\s*uses:\s*([^\s@]+@[^\s]+)'
    $actionMatches = [regex]::Matches($WorkflowContent, $actionPattern)

    $actions = @()
    foreach ($match in $actionMatches) {
        $actionRef = $match.Groups[1].Value.Trim()
        # Skip local actions (starting with ./)
        if (-not $actionRef.StartsWith('./')) {
            $actions += @{
                OriginalRef = $actionRef
                LineNumber  = ($WorkflowContent.Substring(0, $match.Index).Split("`n").Count)
                StartIndex  = $match.Groups[1].Index
                Length      = $match.Groups[1].Length
            }
        }
    }

    return $actions
}

function Get-LatestCommitSHA {
    param(
        [Parameter(Mandatory)]
        [string]$Owner,

        [Parameter(Mandatory)]
        [string]$Repo,

        [Parameter()]
        [string]$Branch
    )

    try {
        $headers = @{
            'Accept'     = 'application/vnd.github+json'
            'User-Agent' = 'hve-core-sha-pinning-updater'
        }

        # Check GitHub token and validate it
        $githubToken = $env:GITHUB_TOKEN
        if ($githubToken) {
            $tokenStatus = Test-GitHubToken -Token $githubToken
            if ($tokenStatus.Valid) {
                $headers['Authorization'] = "Bearer $githubToken"
            }
            else {
                Write-SecurityLog "Token validation failed, proceeding without authentication" -Level Warning
                Write-SecurityLog "CAUSE: Invalid or expired GitHub token" -Level Warning
                Write-SecurityLog "SOLUTION: Generate new token at https://github.com/settings/tokens" -Level Warning
            }
        }

        # If no branch specified, detect the repository's default branch
        if (-not $Branch) {
            $repoApiUrl = "https://api.github.com/repos/$Owner/$Repo"
            $repoInfo = Invoke-GitHubAPIWithRetry -Uri $repoApiUrl -Method GET -Headers $headers
            $Branch = $repoInfo.default_branch
            Write-SecurityLog "Detected default branch for $Owner/$Repo : $Branch" -Level 'Info'
        }

        $apiUrl = "https://api.github.com/repos/$Owner/$Repo/commits/$Branch"
        $response = Invoke-GitHubAPIWithRetry -Uri $apiUrl -Method GET -Headers $headers
        return $response.sha
    }
    catch {
        $statusCode = $null
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }

        if ($statusCode -eq 404) {
            Write-SecurityLog "Failed to fetch latest SHA for $Owner/$Repo : Repository or branch not found" -Level 'Warning'
            Write-SecurityLog "CAUSE: Repository does not exist, is private, or branch name is incorrect" -Level 'Warning'
            Write-SecurityLog "SOLUTION: Verify repository exists and branch name is correct" -Level 'Warning'
        }
        else {
            Write-SecurityLog "Failed to fetch latest SHA for $Owner/$Repo : $($_.Exception.Message)" -Level 'Warning'
            Write-SecurityLog "CAUSE: Network connectivity issue or GitHub API unavailable" -Level 'Warning'
        }
        return $null
    }
}

function Get-SHAForAction {
    param(
        [Parameter(Mandatory)]
        [string]$ActionRef
    )

    # Check if already SHA-pinned (40-character hex string)
    if ($ActionRef -match '@[a-fA-F0-9]{40}$') {
        # If UpdateStale is enabled, fetch the latest SHA and compare
        if ($UpdateStale) {
            # Extract owner/repo from action reference (supports subpaths)
            if ($ActionRef -match '^([^@]+)@([a-fA-F0-9]{40})$') {
                $actionPath = $matches[1]
                $currentSHA = $matches[2]

                # Handle actions with subpaths (e.g., github/codeql-action/init)
                $parts = $actionPath -split '/'
                
                # Validate action reference format
                if ($parts.Count -lt 2) {
                    Write-SecurityLog "Invalid action reference format: $ActionRef - must be 'owner/repo' or 'owner/repo/path'" -Level 'Warning'
                    Write-SecurityLog "CAUSE: Malformed action path missing owner or repository name" -Level 'Warning'
                    Write-SecurityLog "SOLUTION: Verify action reference follows GitHub Actions format (e.g., actions/checkout@v4)" -Level 'Warning'
                    return $null
                }
                
                $owner = $parts[0]
                $repo = $parts[1]

                Write-SecurityLog "Checking for updates: $actionPath (current: $($currentSHA.Substring(0,8))...)" -Level 'Info'

                # Fetch latest SHA from GitHub
                $latestSHA = Get-LatestCommitSHA -Owner $owner -Repo $repo

                if ($latestSHA -and $latestSHA -ne $currentSHA) {
                    Write-SecurityLog "Update available: $actionPath ($($currentSHA.Substring(0,8))... -> $($latestSHA.Substring(0,8))...)" -Level 'Success'
                    return "$actionPath@$latestSHA"
                }
                elseif ($latestSHA -eq $currentSHA) {
                    Write-SecurityLog "Already up-to-date: $actionPath" -Level 'Info'
                }
                elseif (-not $latestSHA) {
                    Write-SecurityLog "Failed to fetch latest SHA for $actionPath - keeping current SHA (likely rate limited)" -Level 'Warning'
                }

                return $ActionRef
            }
        }

        Write-SecurityLog "Action already SHA-pinned: $ActionRef" -Level 'Info'
        return $ActionRef
    }

    # Look up in pre-defined SHA map
    if ($ActionSHAMap.ContainsKey($ActionRef)) {
        $pinnedRef = $ActionSHAMap[$ActionRef]

        # If UpdateStale is enabled, check if we should fetch the latest SHA instead
        if ($UpdateStale) {
            # Extract owner/repo from the pinned reference
            if ($pinnedRef -match '^([^/]+/[^/@]+)@([a-fA-F0-9]{40})$') {
                $actionPath = $matches[1]
                $mappedSHA = $matches[2]

                $parts = $actionPath -split '/'
                $owner = $parts[0]
                $repo = $parts[1]

                Write-SecurityLog "Checking ActionSHAMap entry for updates: $ActionRef (mapped: $($mappedSHA.Substring(0,8))...)" -Level 'Info'

                # Fetch latest SHA from GitHub
                $latestSHA = Get-LatestCommitSHA -Owner $owner -Repo $repo

                if ($latestSHA -and $latestSHA -ne $mappedSHA) {
                    Write-SecurityLog "Update available for mapping: $ActionRef ($($mappedSHA.Substring(0,8))... -> $($latestSHA.Substring(0,8))...)" -Level 'Success' | Out-Null
                    return "$actionPath@$latestSHA"
                }
                elseif ($latestSHA -eq $mappedSHA) {
                    Write-SecurityLog "ActionSHAMap entry up-to-date: $ActionRef" -Level 'Info' | Out-Null
                }
                elseif (-not $latestSHA) {
                    Write-SecurityLog "Failed to fetch latest SHA for $ActionRef mapping - keeping mapped SHA (likely rate limited)" -Level 'Warning' | Out-Null
                }
            }
        }

        Write-SecurityLog "Found SHA mapping: $ActionRef -> $pinnedRef" -Level 'Success'
        return $pinnedRef
    }

    # For unmapped actions, suggest manual review
    Write-SecurityLog "No SHA mapping found for: $ActionRef - requires manual review" -Level 'Warning'
    return $null
}

function Update-WorkflowFile {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    Write-SecurityLog "Processing workflow: $FilePath" -Level 'Info'

    try {
        $content = Get-Content -Path $FilePath -Raw
        $originalContent = $content
        $actions = Get-ActionReference -WorkflowContent $content

        if (@($actions).Count -eq 0) {
            Write-SecurityLog "No GitHub Actions found in $FilePath" -Level 'Info'
            return @{
                FilePath         = $FilePath
                ActionsProcessed = 0
                ActionsPinned    = 0
                ActionsSkipped   = 0
                Changes          = @()
            }
        }

        $changes = @()
        $actionsPinned = 0
        $actionsSkipped = 0

        # Sort by StartIndex in descending order to avoid offset issues
        $sortedActions = $actions | Sort-Object StartIndex -Descending

        foreach ($action in $sortedActions) {
            $originalRef = $action.OriginalRef
            $pinnedRef = Get-SHAForAction -ActionRef $originalRef

            if ($pinnedRef -and $pinnedRef -ne $originalRef) {
                # Replace the action reference
                $content = $content.Substring(0, $action.StartIndex) + $pinnedRef + $content.Substring($action.StartIndex + $action.Length)

                $changes += @{
                    LineNumber = $action.LineNumber
                    Original   = $originalRef
                    Pinned     = $pinnedRef
                    ChangeType = 'SHA-Pinned'
                }
                $actionsPinned++
                Write-SecurityLog "Pinned: $originalRef -> $pinnedRef" -Level 'Success' | Out-Null
            }
            elseif ($pinnedRef -eq $originalRef) {
                $changes += @{
                    LineNumber = $action.LineNumber
                    Original   = $originalRef
                    Pinned     = $originalRef
                    ChangeType = 'Already-Pinned'
                }
            }
            else {
                $changes += @{
                    LineNumber = $action.LineNumber
                    Original   = $originalRef
                    Pinned     = $null
                    ChangeType = 'Requires-Manual-Review'
                }
                $actionsSkipped++
            }
        }

        # Write updated content if changes were made and not in WhatIf mode
        if ($content -ne $originalContent) {
            if ($PSCmdlet.ShouldProcess($FilePath, "Update SHA pinning")) {
                Set-ContentPreservePermission -Path $FilePath -Value $content -NoNewline
                Write-SecurityLog "Updated workflow file: $FilePath" -Level 'Success'
            }
        }

        return @{
            FilePath         = $FilePath
            ActionsProcessed = @($actions).Count
            ActionsPinned    = $actionsPinned
            ActionsSkipped   = $actionsSkipped
            Changes          = $changes
            ContentChanged   = ($content -ne $originalContent)
        }
    }
    catch {
        Write-SecurityLog "Error processing $FilePath : $($_.Exception.Message)" -Level 'Error'
        return @{
            FilePath         = $FilePath
            ActionsProcessed = 0
            ActionsPinned    = 0
            ActionsSkipped   = 0
            Changes          = @()
            ContentChanged   = $false
            Error            = $_.Exception.Message
        }
    }
}

function Export-SecurityReport {
    param(
        [Parameter(Mandatory)]
        [array]$Results
    )

    $reportPath = "scripts/security/sha-pinning-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

    $report = @{
        GeneratedAt     = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
        Summary         = @{
            TotalWorkflows   = @($Results).Count
            WorkflowsChanged = @($Results | Where-Object { $_.PSObject.Properties.Name -contains 'ContentChanged' -and $_.ContentChanged }).Count
            TotalActions     = ($Results | Measure-Object ActionsProcessed -Sum).Sum
            ActionsPinned    = ($Results | Measure-Object ActionsPinned -Sum).Sum
            ActionsSkipped   = ($Results | Measure-Object ActionsSkipped -Sum).Sum
        }
        WorkflowResults = $Results
        SHAMappings     = $ActionSHAMap
    }

    $report | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath
    Write-SecurityLog "Security report exported to: $reportPath" -Level 'Success'

    return $reportPath
}

# Add Set-ContentPreservePermission function for cross-platform compatibility
function Set-ContentPreservePermission {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Value,

        [Parameter(Mandatory = $false)]
        [switch]$NoNewline
    )

    # Get original file permissions before writing
    $OriginalMode = $null
    if (Test-Path $Path) {
        try {
            # Get file mode using Get-Item (cross-platform)
            $item = Get-Item -Path $Path -ErrorAction SilentlyContinue
            if ($item -and $item.Mode) {
                $OriginalMode = $item.Mode
            }
        }
        catch {
            Write-SecurityLog "Warning: Could not determine original file permissions for $Path" -Level 'Warning'
        }
    }

    # Write content
    if ($NoNewline) {
        Set-Content -Path $Path -Value $Value -NoNewline
    }
    else {
        Set-Content -Path $Path -Value $Value
    }

    # Restore original permissions if they were executable
    if ($OriginalMode -and $OriginalMode -match '^-rwxr-xr-x') {
        try {
            & chmod +x $Path 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-SecurityLog "Restored execute permissions for $Path" -Level 'Info'
            }
        }
        catch {
            Write-SecurityLog "Warning: Could not restore execute permissions for $Path" -Level 'Warning'
        }
    }
}

#region Main Execution
try {
    if ($UpdateStale) {
        Write-SecurityLog "Starting GitHub Actions SHA update process (updating stale pins)..." -Level 'Info'
    }
    else {
        Write-SecurityLog "Starting GitHub Actions SHA pinning process..." -Level 'Info'
    }

    if (-not (Test-Path -Path $WorkflowPath)) {
        throw "Workflow path not found: $WorkflowPath"
    }

    $workflowFiles = Get-ChildItem -Path $WorkflowPath -Filter "*.yml" -File

    if (@($workflowFiles).Count -eq 0) {
        Write-SecurityLog "No YAML workflow files found in $WorkflowPath" -Level 'Warning'
        return
    }

    Write-SecurityLog "Found $(@($workflowFiles).Count) workflow files" -Level 'Info'

    $results = @()
    foreach ($workflowFile in $workflowFiles) {
        $result = Update-WorkflowFile -FilePath $workflowFile.FullName
        $results += $result
    }

    # Generate summary
    $totalActions = ($results | Measure-Object ActionsProcessed -Sum).Sum
    $totalPinned = ($results | Measure-Object ActionsPinned -Sum).Sum
    $totalSkipped = ($results | Measure-Object ActionsSkipped -Sum).Sum
    $workflowsChanged = @($results | Where-Object { $_.PSObject.Properties.Name -contains 'ContentChanged' -and $_.ContentChanged }).Count

    Write-SecurityLog "" -Level 'Info'  # Empty line for formatting
    Write-SecurityLog "=== SHA Pinning Summary ===" -Level 'Info'
    Write-SecurityLog "Workflows processed: $(@($workflowFiles).Count)" -Level 'Info'
    Write-SecurityLog "Workflows changed: $workflowsChanged" -Level 'Success'
    Write-SecurityLog "Total actions found: $totalActions" -Level 'Info'
    Write-SecurityLog "Actions SHA-pinned: $totalPinned" -Level 'Success'
    Write-SecurityLog "Actions requiring manual review: $totalSkipped" -Level 'Warning'

    # Export report if requested
    if ($OutputReport) {
        $reportPath = Export-SecurityReport -Results $results
        Write-SecurityLog "Detailed report available at: $reportPath" -Level 'Info'
    }

    # Show actions requiring manual review and add as security issues
    # Get manual review actions with their workflow file context
    $manualReviewActions = @()
    foreach ($result in $results) {
        if ($result.PSObject.Properties.Name -contains 'Changes') {
            foreach ($change in $result.Changes) {
                if ($change.ChangeType -eq 'Requires-Manual-Review') {
                    $manualReviewActions += @{
                        Original     = $change.Original
                        WorkflowFile = $result.FilePath
                        LineNumber   = $change.LineNumber
                    }
                }
            }
        }
    }

    if ($manualReviewActions) {
        Write-SecurityLog "" -Level 'Info'  # Empty line for formatting
        Write-SecurityLog "=== Actions Requiring Manual SHA Pinning ===" -Level 'Warning'
        foreach ($action in $manualReviewActions) {
            Write-SecurityLog "  - $($action.Original)" -Level 'Warning'

            # Add security issue for unpinned action
            Add-SecurityIssue -Type "GitHub Actions Security" `
                -Severity "Medium" `
                -Title "Unpinned GitHub Action" `
                -Description "Action '$($action.Original)' requires manual SHA pinning for supply chain security" `
                -File $action.WorkflowFile `
                -Recommendation "Research the action's repository and add SHA mapping to ActionSHAMap"
        }
        Write-SecurityLog "Please research and add SHA mappings for these actions manually." -Level 'Warning'
    }

    # Output results in requested format
    $summaryText = "Processed $(@($workflowFiles).Count) workflows, pinned $totalPinned actions, $totalSkipped require manual review"
    Write-OutputResult -OutputFormat $OutputFormat -Results $script:SecurityIssues -Summary $summaryText

    if ($WhatIfPreference) {
        Write-SecurityLog "" -Level 'Info'  # Empty line for formatting
        Write-SecurityLog "WhatIf mode: No files were modified. Run without -WhatIf to apply changes." -Level 'Info'
    }
    exit 0
}
catch {
    Write-SecurityLog "Critical error in SHA pinning process: $($_.Exception.Message)" -Level 'Error'
    if ($env:GITHUB_ACTIONS -eq 'true') {
        Write-Output "::error::$($_.Exception.Message)"
    }
    exit 1
}
