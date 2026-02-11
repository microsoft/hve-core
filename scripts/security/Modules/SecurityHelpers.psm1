# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
# Licensed under the MIT license.

# SecurityHelpers.psm1
#
# Purpose: Shared security utility functions for hve-core security scripts.
# Author: HVE Core Team

#Requires -Version 7.0

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

    .EXAMPLE
        Write-SecurityLog -Message "Stale SHA detected" -Level Warning -LogPath "./logs/security.log"
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
        [string]$OutputFormat = 'console'
    )

    # Handle blank line requests
    if ([string]::IsNullOrWhiteSpace($Message)) {
        if ($OutputFormat -eq 'console') {
            Write-Host ''
        }
        return
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"

    # Console output with colors
    if ($OutputFormat -eq 'console') {
        $color = switch ($Level) {
            'Info' { 'White' }
            'Warning' { 'Yellow' }
            'Error' { 'Red' }
            'Success' { 'Green' }
            'Debug' { 'Gray' }
            'Verbose' { 'Cyan' }
        }
        Write-Host $logEntry -ForegroundColor $color
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
        Timestamp      = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
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
                Timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
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

function Test-GitHubToken {
    <#
    .SYNOPSIS
        Validates a GitHub token and retrieves rate limit information.

    .DESCRIPTION
        Tests that a GitHub token is valid by making an API call to the
        rate_limit endpoint. Returns authentication status and rate limit details.

    .PARAMETER Token
        The GitHub token to validate.

    .OUTPUTS
        [hashtable] with keys: IsValid, RateLimit, Remaining, ResetTime, Message

    .EXAMPLE
        $result = Test-GitHubToken -Token $env:GITHUB_TOKEN
        if ($result.IsValid) { Write-Host "Token is valid, $($result.Remaining) requests remaining" }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Token
    )

    $result = @{
        IsValid   = $false
        RateLimit = 0
        Remaining = 0
        ResetTime = $null
        Message   = ''
    }

    if ([string]::IsNullOrEmpty($Token)) {
        $result.Message = 'Token is empty or null'
        return $result
    }

    try {
        $headers = @{
            Authorization  = "Bearer $Token"
            Accept         = 'application/vnd.github+json'
            'User-Agent'   = 'SecurityHelpers-PowerShell/1.0'
            'X-GitHub-Api-Version' = '2022-11-28'
        }

        $response = Invoke-RestMethod -Uri 'https://api.github.com/rate_limit' `
            -Headers $headers `
            -Method Get `
            -ErrorAction Stop

        $result.IsValid = $true
        $result.RateLimit = $response.rate.limit
        $result.Remaining = $response.rate.remaining
        $result.ResetTime = [DateTimeOffset]::FromUnixTimeSeconds($response.rate.reset).DateTime
        $result.Message = 'Token validated successfully'
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
        $response = Invoke-GitHubAPIWithRetry -Uri 'https://api.github.com/repos/owner/repo/commits' -Headers $headers
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
    'Test-GitHubToken'
    'Invoke-GitHubAPIWithRetry'
)
