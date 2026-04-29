# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
# Licensed under the MIT license.

# SecurityHelpers.psm1
#
# Purpose: Shared security utility functions for hve-core security scripts.
# Author: HVE Core Team

#Requires -Version 7.0

# Omit -Force so the standalone CIHelpers export is not shadowed by a nested re-import.
Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/CIHelpers.psm1')

function Write-SecurityLog {
    <#
    .SYNOPSIS
        Writes a timestamped log entry with severity level.

    .DESCRIPTION
        Outputs formatted log messages to console with color coding
        and optionally to a log file.

    .PARAMETER Message
        Log message text. Empty/whitespace messages output a blank line.

    .PARAMETER Level
        Severity level: Info, Warning, Error, Success, Debug, Verbose.

    .PARAMETER LogPath
        Optional file path for persistent logging.

    .PARAMETER OutputFormat
        Controls console output. 'console' enables colored output.

    .EXAMPLE
        Write-SecurityLog -Message "Scanning workflows" -Level Info

    .PARAMETER CIAnnotation
        When set, forwards Warning and Error messages as CI annotations via Write-CIAnnotation.

    .EXAMPLE
        Write-SecurityLog -Message "Stale SHA detected" -Level Warning -LogPath "./logs/security.log"

    .EXAMPLE
        Write-SecurityLog -Message "Not pinned" -Level Warning -CIAnnotation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Debug', 'Verbose')]
        [string]$Level = 'Info',

        [Parameter()]
        [string]$LogPath,

        [Parameter()]
        [string]$OutputFormat = 'console',

        [Parameter()]
        [switch]$CIAnnotation
    )

    # Handle blank line requests
    if ([string]::IsNullOrWhiteSpace($Message)) {
        if ($OutputFormat -eq 'console') {
            Write-Host ''
        }
        return
    }

    $timestamp = Get-StandardTimestamp
    $logEntry = "[$timestamp] [$Level] $Message"

    # Console output with colors
    if ($OutputFormat -eq 'console') {
        $color = switch ($Level) {
            'Info' { 'Cyan' }
            'Warning' { 'Yellow' }
            'Error' { 'Red' }
            'Success' { 'Green' }
            'Debug' { 'Gray' }
            'Verbose' { 'Cyan' }
        }
        Write-Host $logEntry -ForegroundColor $color
    }

    # Forward warnings and errors as CI annotations
    if ($CIAnnotation -and ($Level -eq 'Warning' -or $Level -eq 'Error')) {
        Write-CIAnnotation -Message $Message -Level $Level
    }

    # File logging if path provided
    if ($LogPath) {
        try {
            $logDir = Split-Path -Parent $LogPath
            if ($logDir -and -not (Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }
            Add-Content -Path $LogPath -Value $logEntry -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to write to log file: $($_.Exception.Message)"
        }
    }
}

function New-SecurityIssue {
    <#
    .SYNOPSIS
        Creates a structured security issue object.

    .DESCRIPTION
        Returns a PSCustomObject representing a security finding with
        type, severity, location, and remediation information.

    .PARAMETER Type
        Category of security issue (e.g., 'UnpinnedAction', 'StaleSHA').

    .PARAMETER Severity
        Impact level: Low, Medium, High, Critical.

    .PARAMETER Title
        Brief issue title.

    .PARAMETER Description
        Detailed description of the issue.

    .PARAMETER File
        Source file where issue was found.

    .PARAMETER Line
        Line number in source file.

    .PARAMETER Recommendation
        Suggested remediation action.

    .EXAMPLE
        $issue = New-SecurityIssue -Type 'UnpinnedAction' -Severity 'High' -Title 'Action not pinned' -Description 'uses: actions/checkout@v4' -File '.github/workflows/ci.yml' -Line 15
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Type,

        [Parameter(Mandatory)]
        [ValidateSet('Low', 'Medium', 'High', 'Critical')]
        [string]$Severity,

        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Description,

        [Parameter()]
        [string]$File,

        [Parameter()]
        [int]$Line = 0,

        [Parameter()]
        [string]$Recommendation
    )

    return [PSCustomObject]@{
        Type           = $Type
        Severity       = $Severity
        Title          = $Title
        Description    = $Description
        File           = $File
        Line           = $Line
        Recommendation = $Recommendation
        Timestamp      = Get-StandardTimestamp
    }
}

function Write-SecurityReport {
    <#
    .SYNOPSIS
        Outputs security scan results in the specified format.

    .DESCRIPTION
        Formats and outputs an array of security issues as JSON, console output,
        or markdown table. Optionally writes to a file.

    .PARAMETER Results
        Array of security issue objects from New-SecurityIssue.

    .PARAMETER Summary
        Summary text for the report header.

    .PARAMETER OutputFormat
        Output format: json, console, or markdown.

    .PARAMETER OutputPath
        File path to write results. If not specified, returns output.

    .EXAMPLE
        Write-SecurityReport -Results $issues -OutputFormat json -OutputPath './logs/security.json'

    .EXAMPLE
        Write-SecurityReport -Results $issues -Summary "Found 3 issues" -OutputFormat console
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [array]$Results = @(),

        [Parameter()]
        [string]$Summary = '',

        [Parameter(Mandatory)]
        [ValidateSet('json', 'console', 'markdown')]
        [string]$OutputFormat,

        [Parameter()]
        [string]$OutputPath
    )

    switch ($OutputFormat) {
        'json' {
            $output = @{
                Summary   = $Summary
                Issues    = $Results
                Timestamp = Get-StandardTimestamp
                Count     = @($Results).Count
            }
            $jsonOutput = $output | ConvertTo-Json -Depth 5

            if ($OutputPath) {
                $outputDir = Split-Path -Parent $OutputPath
                if ($outputDir -and -not (Test-Path $outputDir)) {
                    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
                }
                Set-Content -Path $OutputPath -Value $jsonOutput
                Write-SecurityLog -Message "JSON security report written to: $OutputPath" -Level Success
            }
            return $jsonOutput
        }
        'console' {
            if (@($Results).Count -eq 0) {
                Write-SecurityLog -Message 'No security issues found' -Level Success
                if ($Summary) {
                    Write-SecurityLog -Message $Summary -Level Info
                }
                return
            }

            Write-SecurityLog -Message '=== SECURITY ISSUES DETECTED ===' -Level Warning
            if ($Summary) {
                Write-SecurityLog -Message $Summary -Level Info
            }

            foreach ($issue in $Results) {
                Write-SecurityLog -Message "[$($issue.Severity)] $($issue.Type): $($issue.Title)" -Level Warning
                Write-SecurityLog -Message "  Description: $($issue.Description)" -Level Info
                if ($issue.File) {
                    $location = $issue.File
                    if ($issue.Line -gt 0) {
                        $location += ":$($issue.Line)"
                    }
                    Write-SecurityLog -Message "  Location: $location" -Level Info
                }
                if ($issue.Recommendation) {
                    Write-SecurityLog -Message "  Recommendation: $($issue.Recommendation)" -Level Info
                }
                Write-SecurityLog -Message '' -Level Info
            }

            Write-SecurityLog -Message "Total issues: $(@($Results).Count)" -Level Warning
            return
        }
        'markdown' {
            $md = @()

            if (@($Results).Count -eq 0) {
                $md += '## Security Scan Results'
                $md += ''
                $md += ':white_check_mark: No security issues found.'
                if ($Summary) {
                    $md += ''
                    $md += $Summary
                }
            }
            else {
                $md += '## Security Scan Results'
                $md += ''
                if ($Summary) {
                    $md += $Summary
                    $md += ''
                }
                $md += "**Total issues: $(@($Results).Count)**"
                $md += ''
                $md += '| Severity | Type | Title | File | Line |'
                $md += '|----------|------|-------|------|------|'

                foreach ($issue in $Results) {
                    $file = if ($issue.File) { $issue.File } else { '-' }
                    $line = if ($issue.Line -gt 0) { $issue.Line } else { '-' }
                    $md += "| $($issue.Severity) | $($issue.Type) | $($issue.Title) | $file | $line |"
                }
            }

            $content = $md -join "`n"

            if ($OutputPath) {
                $outputDir = Split-Path -Parent $OutputPath
                if ($outputDir -and -not (Test-Path $outputDir)) {
                    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
                }
                Set-Content -Path $OutputPath -Value $content
                Write-SecurityLog -Message "Markdown report written to: $OutputPath" -Level Success
            }
            return $content
        }
    }
}

function Get-GitHubApiBase {
    <#
    .SYNOPSIS
        Returns the GitHub API base URL, respecting HVE_GITHUB_API_URL.

    .OUTPUTS
        [string] The API base URL without a trailing slash.

    .EXAMPLE
        $apiBase = Get-GitHubApiBase
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($env:HVE_GITHUB_API_URL) { return $env:HVE_GITHUB_API_URL }
    return 'https://api.github.com'
}

function Get-PSGalleryApiBase {
    <#
    .SYNOPSIS
        Returns the PowerShell Gallery API base URL, respecting HVE_PSGALLERY_REPOSITORY.

    .DESCRIPTION
        Returns the OData v2 API base URL used for PowerShell Gallery queries
        (for example, package metadata lookups in staleness checks). When the
        HVE_PSGALLERY_REPOSITORY environment variable is set, its value is
        returned to support offline mirrors and test doubles.

    .OUTPUTS
        [string] The API base URL without a trailing slash.

    .EXAMPLE
        $apiBase = Get-PSGalleryApiBase

    .NOTES
        Mirrors the shape of Get-GitHubApiBase. Callers append OData query
        paths (for example, "/Packages()?`$filter=...") directly to the result.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($env:HVE_PSGALLERY_REPOSITORY) { return $env:HVE_PSGALLERY_REPOSITORY }
    return 'https://www.powershellgallery.com/api/v2'
}

function Test-GitHubToken {
    <#
    .SYNOPSIS
        Validates a GitHub token and retrieves rate limit information.

    .DESCRIPTION
        Tests that a GitHub token is valid by querying the GitHub GraphQL API
        for the authenticated viewer and rate limit details.

    .PARAMETER Token
        The GitHub token to validate.

    .OUTPUTS
        [hashtable] with keys: Valid, Authenticated, RateLimit, Remaining, ResetAt, User, Message

    .EXAMPLE
        $result = Test-GitHubToken -Token $env:GITHUB_TOKEN
        if ($result.Valid) { Write-Host "Token is valid, $($result.Remaining) requests remaining" }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Token
    )

    $result = @{
        Valid         = $false
        Authenticated = $false
        RateLimit     = 0
        Remaining     = 0
        ResetAt       = $null
        User          = $null
        Message       = ''
    }

    if ([string]::IsNullOrEmpty($Token)) {
        $result.Message = 'Token is empty or null'
        return $result
    }

    try {
        $headers = @{
            Authorization          = "Bearer $Token"
            Accept                 = 'application/vnd.github+json'
            'User-Agent'           = 'SecurityHelpers-PowerShell/1.0'
            'X-GitHub-Api-Version' = '2022-11-28'
        }

        $query = @{
            query = 'query { viewer { login } rateLimit { limit remaining resetAt } }'
        } | ConvertTo-Json

        $apiBase = Get-GitHubApiBase
        $response = Invoke-RestMethod -Uri "$apiBase/graphql" -Method Post -Headers $headers -Body $query -ErrorAction Stop

        $data = $null
        if ($response -is [hashtable]) {
            $data = $response['data']
        }
        elseif ($response.PSObject.Properties.Name -contains 'data') {
            $data = $response.data
        }

        $viewer = $null
        $rateLimit = $null
        if ($data) {
            if ($data -is [hashtable]) {
                $viewer = $data['viewer']
                $rateLimit = $data['rateLimit']
            }
            else {
                if ($data.PSObject.Properties.Name -contains 'viewer') {
                    $viewer = $data.viewer
                }
                if ($data.PSObject.Properties.Name -contains 'rateLimit') {
                    $rateLimit = $data.rateLimit
                }
            }
        }

        if ($viewer) {
            $result.Valid = $true
            $result.Authenticated = $true
            if ($viewer -is [hashtable]) {
                $result.User = $viewer['login']
            }
            elseif ($viewer.PSObject.Properties.Name -contains 'login') {
                $result.User = $viewer.login
            }
            $result.Message = "Authenticated as $($result.User)"
        }
        elseif ($rateLimit) {
            $result.Valid = $true
            $result.Authenticated = $false
            $result.Message = 'Unauthenticated access - limited rate limits'
        }

        if ($rateLimit) {
            if ($rateLimit -is [hashtable]) {
                $result.RateLimit = $rateLimit['limit']
                $result.Remaining = $rateLimit['remaining']
                $result.ResetAt = $rateLimit['resetAt']
            }
            else {
                if ($rateLimit.PSObject.Properties.Name -contains 'limit') {
                    $result.RateLimit = $rateLimit.limit
                }
                if ($rateLimit.PSObject.Properties.Name -contains 'remaining') {
                    $result.Remaining = $rateLimit.remaining
                }
                if ($rateLimit.PSObject.Properties.Name -contains 'resetAt') {
                    $result.ResetAt = $rateLimit.resetAt
                }
            }
        }

        if ($result.Remaining -lt 100 -and $result.Valid) {
            $result.Message += " | WARNING: Only $($result.Remaining) API calls remaining (resets at $($result.ResetAt))"
        }

        if (-not $result.Authenticated -and $result.Valid) {
            Write-Warning 'Unauthenticated GitHub GraphQL API requests are heavily rate limited'
        }
    }
    catch {
        $result.Message = "Token validation failed: $($_.Exception.Message)"
        $statusCode = $null
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        if ($statusCode -eq 401) {
            $result.Message = 'Token is invalid or expired'
        }
        elseif ($statusCode -eq 403) {
            $result.Message = 'Token lacks required permissions or rate limit exceeded'
        }
    }

    return $result
}

function Invoke-GitHubAPIWithRetry {
    <#
    .SYNOPSIS
        Invokes a GitHub API call with automatic retry on rate limits.

    .DESCRIPTION
        Makes HTTP requests to the GitHub API with exponential backoff retry
        logic for handling rate limit (429) and server error (5xx) responses.

    .PARAMETER Uri
        The GitHub API endpoint URI.

    .PARAMETER Method
        HTTP method: GET, POST, PUT, PATCH, DELETE.

    .PARAMETER Headers
        Hashtable of HTTP headers including Authorization.

    .PARAMETER Body
        Request body for POST/PUT/PATCH requests.

    .PARAMETER MaxRetries
        Maximum number of retry attempts. Default: 3.

    .PARAMETER InitialDelaySeconds
        Initial delay between retries in seconds. Default: 2.

    .OUTPUTS
        API response object or $null on failure.

    .EXAMPLE
        $headers = @{ Authorization = "Bearer $token"; Accept = 'application/vnd.github+json' }
        $apiBase = Get-GitHubApiBase
        $response = Invoke-GitHubAPIWithRetry -Uri "$apiBase/repos/owner/repo/commits" -Headers $headers
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter()]
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
        [string]$Method = 'GET',

        [Parameter(Mandatory)]
        [hashtable]$Headers,

        [Parameter()]
        [string]$Body,

        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$MaxRetries = 3,

        [Parameter()]
        [ValidateRange(1, 60)]
        [int]$InitialDelaySeconds = 2
    )

    $attempt = 0
    $delay = $InitialDelaySeconds

    while ($attempt -lt $MaxRetries) {
        $attempt++
        try {
            $params = @{
                Uri         = $Uri
                Method      = $Method
                Headers     = $Headers
                ErrorAction = 'Stop'
            }

            if ($Body) {
                $params['Body'] = $Body
                $params['ContentType'] = 'application/json'
            }

            $response = Invoke-RestMethod @params
            return $response
        }
        catch {
            $statusCode = $null
            # Try multiple methods to extract HTTP status code (cross-platform compatibility)
            # Method 1: Direct StatusCode property access
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                # StatusCode might be an enum - try value__ first, then direct cast
                $statusCode = $_.Exception.Response.StatusCode.value__ -as [int]
                if (-not $statusCode) {
                    $statusCode = $_.Exception.Response.StatusCode -as [int]
                }
            }
            # Method 2: Parse status code from exception message (e.g., "404 (Not Found)" or "Response status code does not indicate success: 429")
            if (-not $statusCode -and $_.Exception.Message -match '\b([45]\d{2})\b') {
                $statusCode = [int]$Matches[1]
            }
            # Method 3: Map common HTTP status text to codes
            if (-not $statusCode) {
                $messageUpper = $_.Exception.Message.ToUpper()
                if ($messageUpper -match 'UNAUTHORIZED') { $statusCode = 401 }
                elseif ($messageUpper -match 'NOT\s*FOUND') { $statusCode = 404 }
                elseif ($messageUpper -match 'TOO\s*MANY\s*REQUESTS|RATE\s*LIMIT') { $statusCode = 429 }
                elseif ($messageUpper -match 'FORBIDDEN') { $statusCode = 403 }
                elseif ($messageUpper -match 'SERVER\s*ERROR|INTERNAL\s*SERVER') { $statusCode = 500 }
                elseif ($messageUpper -match 'BAD\s*GATEWAY') { $statusCode = 502 }
                elseif ($messageUpper -match 'SERVICE\s*UNAVAILABLE') { $statusCode = 503 }
                elseif ($messageUpper -match 'GATEWAY\s*TIMEOUT') { $statusCode = 504 }
            }

            # Check if it's a rate limit error (403 or 429) or server error (5xx)
            $isRetryable = $statusCode -in 403, 429 -or ($statusCode -ge 500 -and $statusCode -lt 600)

            if ($isRetryable -and $attempt -lt $MaxRetries) {
                Write-Warning "GitHub API request failed (HTTP $statusCode). Retrying in $delay seconds (attempt $attempt/$MaxRetries)..."
                Start-Sleep -Seconds $delay
                $delay = $delay * 2  # Exponential backoff
            }
            else {
                if ($attempt -ge $MaxRetries -and $isRetryable) {
                    Write-Error "GitHub API request failed after $MaxRetries attempts: $($_.Exception.Message)" -ErrorAction Continue
                }
                else {
                    Write-Error "GitHub API request failed: $($_.Exception.Message)" -ErrorAction Continue
                }
                return $null
            }
        }
    }

    return $null
}

Export-ModuleMember -Function @(
    'Write-SecurityLog'
    'New-SecurityIssue'
    'Write-SecurityReport'
    'Get-GitHubApiBase'
    'Get-PSGalleryApiBase'
    'Test-GitHubToken'
    'Invoke-GitHubAPIWithRetry'
)
