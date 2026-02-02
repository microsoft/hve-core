# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# LintingHelpers.psm1
#
# Purpose: Shared helper functions for linting scripts and workflows
# Author: HVE Core Team
# Created: 2025-11-05

Import-Module (Join-Path $PSScriptRoot "../../lib/Modules/CIHelpers.psm1") -Force

function Get-ChangedFilesFromGit {
    <#
    .SYNOPSIS
    Gets changed files from git with intelligent fallback strategies.

    .DESCRIPTION
    Attempts to detect changed files using merge-base, with fallbacks for different scenarios.

    .PARAMETER BaseBranch
    The base branch to compare against (default: origin/main).

    .PARAMETER FileExtensions
    Array of file extensions to filter (e.g., @('*.ps1', '*.md')).

    .OUTPUTS
    Array of changed file paths.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$BaseBranch = "origin/main",

        [Parameter(Mandatory = $false)]
        [string[]]$FileExtensions = @('*')
    )

    $changedFiles = @()

    try {
        # Try merge-base first (best for PRs)
        $mergeBase = git merge-base HEAD $BaseBranch 2>$null
        
        if ($LASTEXITCODE -eq 0 -and $mergeBase) {
            Write-Verbose "Using merge-base: $mergeBase"
            $changedFiles = git diff --name-only --diff-filter=ACMR $mergeBase HEAD 2>$null
        }
        elseif ((git rev-parse HEAD~1 2>$null)) {
            Write-Verbose "Merge base failed, using HEAD~1"
            $changedFiles = git diff --name-only --diff-filter=ACMR HEAD~1 HEAD 2>$null
        }
        else {
            Write-Verbose "HEAD~1 failed, using staged/unstaged files"
            $changedFiles = git diff --name-only HEAD 2>$null
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Unable to determine changed files from git"
            return @()
        }

        # Filter by extensions and verify files exist
        $filteredFiles = $changedFiles | Where-Object {
            if ([string]::IsNullOrEmpty($_)) { return $false }
            
            # Check if file matches any of the allowed extensions
            $currentFile = $_
            $matchesExtension = $false
            foreach ($pattern in $FileExtensions) {
                if ($currentFile -like $pattern) {
                    $matchesExtension = $true
                    break
                }
            }
            
            $matchesExtension -and (Test-Path $currentFile -PathType Leaf)
        }

        Write-Verbose "Found $($filteredFiles.Count) changed files matching extensions: $($FileExtensions -join ', ')"
        return $filteredFiles
    }
    catch {
        Write-Warning "Error getting changed files: $($_.Exception.Message)"
        return @()
    }
}

function Get-FilesRecursive {
    <#
    .SYNOPSIS
    Gets files recursively with gitignore filtering.

    .DESCRIPTION
    Recursively finds files by extension, respecting .gitignore patterns.

    .PARAMETER Path
    Root path to search from.

    .PARAMETER Include
    File patterns to include (e.g., @('*.ps1', '*.psm1')).

    .PARAMETER GitIgnorePath
    Path to .gitignore file for exclusion patterns.

    .OUTPUTS
    Array of FileInfo objects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string[]]$Include,

        [Parameter(Mandatory = $false)]
        [string]$GitIgnorePath
    )

    $files = Get-ChildItem -Path $Path -Recurse -Include $Include -File -ErrorAction SilentlyContinue

    # Apply gitignore filtering if provided
    if ($GitIgnorePath -and (Test-Path $GitIgnorePath)) {
        $gitignorePatterns = Get-GitIgnorePatterns -GitIgnorePath $GitIgnorePath
        
        $files = $files | Where-Object {
            $file = $_
            $excluded = $false
            
            foreach ($pattern in $gitignorePatterns) {
                if ($file.FullName -like $pattern) {
                    $excluded = $true
                    break
                }
            }
            
            -not $excluded
        }
    }

    return $files
}

function Get-GitIgnorePatterns {
    <#
    .SYNOPSIS
    Parses .gitignore into PowerShell wildcard patterns.

    .PARAMETER GitIgnorePath
    Path to .gitignore file.

    .OUTPUTS
    Array of wildcard patterns using platform-appropriate separators.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$GitIgnorePath
    )

    if (-not (Test-Path $GitIgnorePath)) {
        return @()
    }

    $sep = [System.IO.Path]::DirectorySeparatorChar

    $patterns = Get-Content $GitIgnorePath | Where-Object {
        $_ -and -not $_.StartsWith('#') -and $_.Trim() -ne ''
    } | ForEach-Object {
        $pattern = $_.Trim()
        
        # Normalize to platform separator
        $normalizedPattern = $pattern.Replace('/', $sep).Replace('\', $sep)
        
        if ($pattern.EndsWith('/')) {
            "*$sep$($normalizedPattern.TrimEnd($sep))$sep*"
        }
        elseif ($pattern.Contains('/') -or $pattern.Contains('\')) {
            "*$sep$normalizedPattern*"
        }
        else {
            "*$sep$normalizedPattern$sep*"
        }
    }

    return $patterns
}

function Write-GitHubAnnotation {
    <#
    .SYNOPSIS
    Writes GitHub Actions annotations for errors, warnings, or notices.

    .PARAMETER Type
    Annotation type: 'error', 'warning', or 'notice'.

    .PARAMETER Message
    The annotation message.

    .PARAMETER File
    Optional file path.

    .PARAMETER Line
    Optional line number.

    .PARAMETER Column
    Optional column number.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('error', 'warning', 'notice')]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$File,

        [Parameter(Mandatory = $false)]
        [int]$Line,

        [Parameter(Mandatory = $false)]
        [int]$Column
    )

    $escapedMessage = ConvertTo-GitHubActionsEscaped -Value $Message
    
    $annotation = "::${Type}"
    
    $properties = @()
    if ($File) {
        $escapedFile = ConvertTo-GitHubActionsEscaped -Value $File -ForProperty
        $properties += "file=$escapedFile"
    }
    if ($Line -gt 0) { $properties += "line=$Line" }
    if ($Column -gt 0) { $properties += "col=$Column" }
    
    if ($properties.Count -gt 0) {
        $annotation += " $($properties -join ',')"
    }
    
    $annotation += "::$escapedMessage"
    
    Write-Host $annotation
}

function Set-GitHubOutput {
    <#
    .SYNOPSIS
    Sets GitHub Actions output variable.

    .PARAMETER Name
    Output variable name.

    .PARAMETER Value
    Output value.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    if ($env:GITHUB_OUTPUT) {
        "$Name=$Value" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    }
    else {
        Write-Verbose "Not in GitHub Actions environment - output: $Name=$Value"
    }
}

function Set-GitHubEnv {
    <#
    .SYNOPSIS
    Sets GitHub Actions environment variable.

    .PARAMETER Name
    Environment variable name.

    .PARAMETER Value
    Environment value.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    if ($env:GITHUB_ENV) {
        "$Name=$Value" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
    }
    else {
        Write-Verbose "Not in GitHub Actions environment - env: $Name=$Value"
    }
}

function Write-GitHubStepSummary {
    <#
    .SYNOPSIS
    Appends content to GitHub Actions step summary.

    .PARAMETER Content
    Markdown content to append.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    if ($env:GITHUB_STEP_SUMMARY) {
        $Content | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
    }
    else {
        Write-Verbose "Not in GitHub Actions environment - summary content: $Content"
    }
}

function Test-LintingFilesExist {
    <#
    .SYNOPSIS
    Checks if files exist and handles early exit messaging for linting scripts.

    .DESCRIPTION
    Common boilerplate for linting scripts: checks if any files were found,
    writes appropriate console messages, and returns whether to continue.
    Caller is responsible for setting GitHub outputs if needed.

    .PARAMETER ToolName
    Display name of the linting tool.

    .PARAMETER Files
    Array of files to check.

    .OUTPUTS
    Hashtable with:
    - Continue: Boolean - whether to continue processing
    - FileCount: Int - number of files found

    .EXAMPLE
    $result = Test-LintingFilesExist -ToolName 'PSScriptAnalyzer' -Files $files
    if (-not $result.Continue) { 
        Set-GitHubOutput -Name "count" -Value "0"
        exit 0 
    }
    Set-GitHubOutput -Name "count" -Value $result.FileCount
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolName,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Files
    )

    $fileCount = @($Files).Count

    if ($fileCount -eq 0) {
        Write-Host "✅ No files to analyze for $ToolName" -ForegroundColor Green
        return @{ Continue = $false; FileCount = 0 }
    }

    Write-Host "Analyzing $fileCount file(s) for $ToolName..." -ForegroundColor Cyan
    return @{ Continue = $true; FileCount = $fileCount }
}

function Write-LintingHeader {
    <#
    .SYNOPSIS
    Writes standardized header for linting scripts.

    .PARAMETER ToolName
    Display name of the linting tool.

    .PARAMETER ChangedFilesOnly
    Whether scanning only changed files.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolName,

        [Parameter(Mandatory = $false)]
        [switch]$ChangedFilesOnly
    )

    Write-Host "🔍 Running $ToolName..." -ForegroundColor Cyan

    if ($ChangedFilesOnly) {
        Write-Host "Mode: Changed files only" -ForegroundColor Cyan
    }
    else {
        Write-Host "Mode: All files" -ForegroundColor Cyan
    }
}

function New-LintingContext {
    <#
    .SYNOPSIS
    Creates a linting context with file discovery and common setup.

    .DESCRIPTION
    Handles common boilerplate for linting scripts: file discovery with changes-only
    filtering, header output, and file existence checks. Returns a context object
    with the files to analyze and metadata.

    .PARAMETER ToolName
    Display name of the linting tool.

    .PARAMETER FileExtensions
    Array of file extensions to include (e.g., @('*.ps1', '*.psm1')).

    .PARAMETER ChangedFilesOnly
    Whether to scan only changed files.

    .PARAMETER BaseBranch
    Base branch for detecting changed files (default: origin/main).

    .PARAMETER SearchPath
    Root path to search for files (default: current directory).

    .PARAMETER PathFilter
    Optional filter to limit files to a specific path pattern.

    .OUTPUTS
    Hashtable with:
    - Files: Array of files to analyze
    - FileCount: Number of files found
    - Continue: Boolean - whether to continue processing
    - ChangedFilesOnly: Boolean - mode indicator

    .EXAMPLE
    $ctx = New-LintingContext -ToolName 'PSScriptAnalyzer' -FileExtensions @('*.ps1', '*.psm1') -ChangedFilesOnly:$ChangedFilesOnly
    if (-not $ctx.Continue) { exit 0 }
    foreach ($file in $ctx.Files) { ... }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolName,

        [Parameter(Mandatory = $true)]
        [string[]]$FileExtensions,

        [Parameter(Mandatory = $false)]
        [switch]$ChangedFilesOnly,

        [Parameter(Mandatory = $false)]
        [string]$BaseBranch = "origin/main",

        [Parameter(Mandatory = $false)]
        [string]$SearchPath = ".",

        [Parameter(Mandatory = $false)]
        [string]$PathFilter
    )

    # Write standardized header
    Write-LintingHeader -ToolName $ToolName -ChangedFilesOnly:$ChangedFilesOnly

    # Get files based on mode
    $filesToAnalyze = @()

    if ($ChangedFilesOnly) {
        Write-Host "Detecting changed files..." -ForegroundColor Cyan
        $filesToAnalyze = Get-ChangedFilesFromGit -BaseBranch $BaseBranch -FileExtensions $FileExtensions

        # Apply path filter if specified
        if ($PathFilter -and $filesToAnalyze.Count -gt 0) {
            $filesToAnalyze = $filesToAnalyze | Where-Object { $_ -like $PathFilter }
        }
    }
    else {
        Write-Host "Scanning all files..." -ForegroundColor Cyan
        $gitignorePath = Join-Path (git rev-parse --show-toplevel 2>$null) ".gitignore"

        # Convert extensions for Get-FilesRecursive format
        $includePatterns = $FileExtensions | ForEach-Object { $_.TrimStart('*') }
        $filesToAnalyze = Get-FilesRecursive -Path $SearchPath -Include $FileExtensions -GitIgnorePath $gitignorePath

        # Apply path filter if specified
        if ($PathFilter -and $filesToAnalyze.Count -gt 0) {
            $filesToAnalyze = $filesToAnalyze | Where-Object {
                $path = if ($_ -is [System.IO.FileInfo]) { $_.FullName } else { $_ }
                $path -like $PathFilter
            }
        }
    }

    # Check if files exist
    $lintCheck = Test-LintingFilesExist -ToolName $ToolName -Files $filesToAnalyze

    return @{
        Files            = $filesToAnalyze
        FileCount        = $lintCheck.FileCount
        Continue         = $lintCheck.Continue
        ChangedFilesOnly = $ChangedFilesOnly.IsPresent
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Get-ChangedFilesFromGit',
    'Get-FilesRecursive',
    'Get-GitIgnorePatterns',
    'Write-GitHubAnnotation',
    'Set-GitHubOutput',
    'Set-GitHubEnv',
    'Write-GitHubStepSummary',
    'Test-LintingFilesExist',
    'Write-LintingHeader',
    'New-LintingContext'
)
