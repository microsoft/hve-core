#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

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

$ErrorActionPreference = 'Stop'

# Import shared modules
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/SecurityHelpers.psm1') -Force

# Explicit parameter usage to satisfy static analyzer
Write-Debug "Parameters: WorkflowPath=$WorkflowPath, OutputReport=$OutputReport, OutputFormat=$OutputFormat, UpdateStale=$UpdateStale"

# GitHub Actions SHA references matching current workflow usage
$ActionSHAMap = @{
    # Core setup and checkout
    "actions/checkout@v4"                  = "actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd" # v4.2.2
    "actions/setup-node@v6"                = "actions/setup-node@53b83947a5a98c8d113130e565377fae1a50d02f" # v6.3.0
    "actions/setup-python@v6"              = "actions/setup-python@a309ff8b426b58ec0e2a45f0f869d46889d02405" # v6.2.0

    # Artifact management
    "actions/upload-artifact@v4"           = "actions/upload-artifact@bbbca2ddaa5d8feaa63e36b76fdaad77386f024f" # v4.4.3
    "actions/download-artifact@v8"         = "actions/download-artifact@70fc10c6e5e1ce46ad2ea6f2b72d43f7d47b13c3" # v8.0.0

    # GitHub Pages
    "actions/configure-pages@v5"           = "actions/configure-pages@983d7736d9b0ae728b81ab479565c72886d7745b" # v5.0.0
    "actions/upload-pages-artifact@v4"     = "actions/upload-pages-artifact@7b1f4a764d45c48632c6b24a0339c27f5614fb0b" # v4.0.0
    "actions/deploy-pages@v4"              = "actions/deploy-pages@d6db90164ac5ed86f2b6aed7e0febac5b3c0c03e" # v4.0.5

    # Attestation and provenance
    "actions/attest@v4"                    = "actions/attest@59d89421af93a897026c735860bf21b6eb4f7b26" # v4.1.0
    "actions/attest-build-provenance@v4"   = "actions/attest-build-provenance@a2bbfa25375fe432b6a289bc6b6cd05ecd0c4c32" # v4.1.0

    # Security and code analysis
    "actions/dependency-review-action@v4"  = "actions/dependency-review-action@05fe4576374b728f0c523d6a13d64c25081e0803" # v4.3.4
    "github/codeql-action/init@v3"         = "github/codeql-action/init@ce729e4d353d580e6cacd6a8cf2921b72e5e310a" # v3.27.0
    "github/codeql-action/autobuild@v3"    = "github/codeql-action/autobuild@ce729e4d353d580e6cacd6a8cf2921b72e5e310a" # v3.27.0
    "github/codeql-action/analyze@v3"      = "github/codeql-action/analyze@ce729e4d353d580e6cacd6a8cf2921b72e5e310a" # v3.27.0
    "github/codeql-action/upload-sarif@v3" = "github/codeql-action/upload-sarif@ce729e4d353d580e6cacd6a8cf2921b72e5e310a" # v3.27.0
    "ossf/scorecard-action@v2"             = "ossf/scorecard-action@4eaacf0543bb3f2c246792bd56e8cdeffafb205a" # v2.4.3

    # Azure
    "azure/login@v2"                       = "azure/login@a457da9ea143d694b1b9c7c869ebb04ebe844ef5" # v2.3.0

    # Third-party
    "actions/create-github-app-token@v2"   = "actions/create-github-app-token@29824e69f54612133e76f7eaac726eef6c875baf" # v2.0.0
    "codecov/codecov-action@v5"            = "codecov/codecov-action@671740ac38dd9b0130fbe1cec585b89eea48d3de" # v5.5.2
    "googleapis/release-please-action@v4"  = "googleapis/release-please-action@16a9c90856f42705d54a6fda1823352bdc62cf38" # v4.4.0
    "anchore/sbom-action@v0"               = "anchore/sbom-action@17ae1740179002c89186b61233e0f892c3118b11" # v0.23.0
}

# Initialize security issues collection
$SecurityIssues = [System.Collections.Generic.List[PSCustomObject]]::new()

function Write-SecurityOutput {
    <#
    .SYNOPSIS
        Formats and emits security scan results in the requested CI or local format.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('json', 'azdo', 'github', 'console', 'BuildWarning', 'Summary')]
        [string]$OutputFormat,

        [Parameter()]
        [array]$Results = @(),

        [Parameter()]
        [string]$Summary = '',

        [Parameter()]
        [string]$OutputPath
    )

    switch ($OutputFormat) {
        'json' {
            Write-SecurityReport -Results $Results -Summary $Summary -OutputFormat json -OutputPath $OutputPath
            return
        }
        'console' {
            Write-SecurityReport -Results $Results -Summary $Summary -OutputFormat console
            return
        }
        'BuildWarning' {
            if (@($Results).Count -eq 0) {
                Write-Output '##[section]No GitHub Actions security issues found'
                return
            }
            Write-Output '##[section]GitHub Actions Security Issues Found:'
            foreach ($issue in $Results) {
                $message = "$($issue.Title) - $($issue.Description)"
                if ($issue.File) { $message += " (File: $($issue.File))" }
                if ($issue.Recommendation) { $message += " Recommendation: $($issue.Recommendation)" }
                Write-Output "##[warning]$message"
            }
            return
        }
        'github' {
            if (@($Results).Count -eq 0) {
                Write-CIAnnotation -Message 'No GitHub Actions security issues found' -Level Notice
                return
            }
            foreach ($issue in $Results) {
                $message = "[$($issue.Severity)] $($issue.Title) - $($issue.Description)"
                $file = if ($issue.File) { $issue.File -replace '\\', '/' } else { $null }
                Write-CIAnnotation -Message $message -Level Warning -File $file
            }
            return
        }
        'azdo' {
            if (@($Results).Count -eq 0) {
                Write-CIAnnotation -Message 'No GitHub Actions security issues found' -Level Notice
                return
            }
            foreach ($issue in $Results) {
                $message = "[$($issue.Severity)] $($issue.Title) - $($issue.Description)"
                $file = if ($issue.File) { $issue.File } else { $null }
                Write-CIAnnotation -Message $message -Level Warning -File $file
            }
            Set-CITaskResult -Result SucceededWithIssues
            return
        }
        'Summary' {
            if (@($Results).Count -eq 0) {
                Write-SecurityLog -Message 'No security issues found' -Level Success
                return
            }
            $Results | Group-Object -Property Type | ForEach-Object {
                Write-Output "=== $($_.Name) ==="
                foreach ($issue in $_.Group) {
                    Write-Output "  [$($issue.Severity)] $($issue.Title): $($issue.Description)"
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

        $apiBase = Get-GitHubApiBase

        # If no branch specified, detect the repository's default branch
        if (-not $Branch) {
            $repoApiUrl = "$apiBase/repos/$Owner/$Repo"
            $repoInfo = Invoke-GitHubAPIWithRetry -Uri $repoApiUrl -Method GET -Headers $headers
            if ($null -eq $repoInfo) { throw "GitHub API returned no response for $repoApiUrl" }
            $Branch = $repoInfo.default_branch
            Write-SecurityLog "Detected default branch for $Owner/$Repo : $Branch" -Level 'Info'
        }

        $apiUrl = "$apiBase/repos/$Owner/$Repo/commits/$Branch"
        $response = Invoke-GitHubAPIWithRetry -Uri $apiUrl -Method GET -Headers $headers
        if ($null -eq $response) { throw "GitHub API returned no response for $apiUrl" }
        return $response.sha
    }
    catch {
        $statusCode = $null
        if ($_.Exception.PSObject.Properties.Name -contains 'Response') {
            $response = $_.Exception.Response
            if ($response -and $response.PSObject.Properties.Name -contains 'StatusCode') {
                $statusCode = [int]$response.StatusCode
            }
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
    [OutputType([PSCustomObject])]
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
            return [PSCustomObject]@{
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

        return [PSCustomObject]@{
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
        return [PSCustomObject]@{
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

    $sumActionsProcessed = 0
    $sumActionsPinned = 0
    $sumActionsSkipped = 0
    foreach ($result in $Results) {
        if ($result -is [hashtable]) {
            if ($result.ContainsKey('ActionsProcessed') -and $null -ne $result['ActionsProcessed']) {
                $sumActionsProcessed += [int]$result['ActionsProcessed']
            }
            if ($result.ContainsKey('ActionsPinned') -and $null -ne $result['ActionsPinned']) {
                $sumActionsPinned += [int]$result['ActionsPinned']
            }
            if ($result.ContainsKey('ActionsSkipped') -and $null -ne $result['ActionsSkipped']) {
                $sumActionsSkipped += [int]$result['ActionsSkipped']
            }
        }
        else {
            if ($result.PSObject.Properties.Name -contains 'ActionsProcessed' -and $null -ne $result.ActionsProcessed) {
                $sumActionsProcessed += [int]$result.ActionsProcessed
            }
            if ($result.PSObject.Properties.Name -contains 'ActionsPinned' -and $null -ne $result.ActionsPinned) {
                $sumActionsPinned += [int]$result.ActionsPinned
            }
            if ($result.PSObject.Properties.Name -contains 'ActionsSkipped' -and $null -ne $result.ActionsSkipped) {
                $sumActionsSkipped += [int]$result.ActionsSkipped
            }
        }
    }

    $report = @{
        GeneratedAt     = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
        Summary         = @{
            TotalWorkflows   = @($Results).Count
            WorkflowsChanged = @($Results | Where-Object { $_.PSObject.Properties.Name -contains 'ContentChanged' -and $_.ContentChanged }).Count
            TotalActions     = $sumActionsProcessed
            ActionsPinned    = $sumActionsPinned
            ActionsSkipped   = $sumActionsSkipped
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

function Invoke-ActionSHAPinningUpdate {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
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

    $totalActions = ($results | Measure-Object ActionsProcessed -Sum).Sum
    $totalPinned = ($results | Measure-Object ActionsPinned -Sum).Sum
    $totalSkipped = ($results | Measure-Object ActionsSkipped -Sum).Sum
    $workflowsChanged = @($results | Where-Object { $_.PSObject.Properties.Name -contains 'ContentChanged' -and $_.ContentChanged }).Count

    Write-SecurityLog "" -Level 'Info'
    Write-SecurityLog "=== SHA Pinning Summary ===" -Level 'Info'
    Write-SecurityLog "Workflows processed: $(@($workflowFiles).Count)" -Level 'Info'
    Write-SecurityLog "Workflows changed: $workflowsChanged" -Level 'Success'
    Write-SecurityLog "Total actions found: $totalActions" -Level 'Info'
    Write-SecurityLog "Actions SHA-pinned: $totalPinned" -Level 'Success'
    Write-SecurityLog "Actions requiring manual review: $totalSkipped" -Level 'Warning'

    if ($OutputReport) {
        $reportPath = Export-SecurityReport -Results $results
        Write-SecurityLog "Detailed report available at: $reportPath" -Level 'Info'
    }

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
        Write-SecurityLog "" -Level 'Info'
        Write-SecurityLog "=== Actions Requiring Manual SHA Pinning ===" -Level 'Warning'
        foreach ($action in $manualReviewActions) {
            Write-SecurityLog "  - $($action.Original)" -Level 'Warning'

            $SecurityIssues.Add((New-SecurityIssue -Type "GitHub Actions Security" `
                -Severity "Medium" `
                -Title "Unpinned GitHub Action" `
                -Description "Action '$($action.Original)' requires manual SHA pinning for supply chain security" `
                -File $action.WorkflowFile `
                -Recommendation "Research the action's repository and add SHA mapping to ActionSHAMap"))
        }
        Write-SecurityLog "Please research and add SHA mappings for these actions manually." -Level 'Warning'
    }

    $summaryText = "Processed $(@($workflowFiles).Count) workflows, pinned $totalPinned actions, $totalSkipped require manual review"
    Write-SecurityOutput -OutputFormat $OutputFormat -Results $SecurityIssues -Summary $summaryText

    if ($WhatIfPreference) {
        Write-SecurityLog "" -Level 'Info'
        Write-SecurityLog "WhatIf mode: No files were modified. Run without -WhatIf to apply changes." -Level 'Info'
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-ActionSHAPinningUpdate -WorkflowPath $WorkflowPath -OutputReport:$OutputReport -OutputFormat $OutputFormat -UpdateStale:$UpdateStale
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Update-ActionSHAPinning failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}

#endregion Main Execution
