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

function Write-ScriptLog {
    <#
    .SYNOPSIS
    Writes formatted log messages with CI/CD platform support.

    .DESCRIPTION
    Consolidated logging function that supports GitHub Actions, Azure DevOps,
    and console output formats. Provides consistent logging across all security
    and linting scripts.

    .PARAMETER Message
    The log message to write.

    .PARAMETER Level
    Log level: Info, Warning, Error, Debug, or Success.

    .PARAMETER OutputFormat
    Output format: github, azdo, or console.

    .PARAMETER LogPath
    Optional file path for persistent logging.

    .EXAMPLE
    Write-ScriptLog -Message "Starting scan..." -Level Info

    .EXAMPLE
    Write-ScriptLog -Message "Found issue" -Level Warning -OutputFormat github

    .EXAMPLE
    Write-ScriptLog -Message "Check complete" -Level Success -LogPath "./logs/scan.log"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Success')]
        [string]$Level = 'Info',

        [Parameter(Mandatory = $false)]
        [ValidateSet('github', 'azdo', 'console')]
        [string]$OutputFormat = 'console',

        [Parameter(Mandatory = $false)]
        [string]$LogPath
    )

    # Handle empty or whitespace messages
    if ([string]::IsNullOrWhiteSpace($Message)) {
        $Message = "(empty message)"
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    switch ($OutputFormat) {
        'github' {
            # GitHub Actions annotation format
            switch ($Level) {
                'Error'   { Write-Output "::error::$Message" }
                'Warning' { Write-Output "::warning::$Message" }
                'Debug'   { Write-Output "::debug::$Message" }
                'Success' { Write-Output "::notice::$Message" }
                default   { Write-Output $logEntry }
            }
        }

        'azdo' {
            # Azure DevOps logging commands
            switch ($Level) {
                'Error'   { Write-Output "##vso[task.logissue type=error]$Message" }
                'Warning' { Write-Output "##vso[task.logissue type=warning]$Message" }
                'Debug'   { Write-Output "##[debug]$Message" }
                'Success' { Write-Output "##[section]$Message" }
                default   { Write-Output $logEntry }
            }
        }

        'console' {
            # Colored console output
            switch ($Level) {
                'Info'    { Write-Host $logEntry -ForegroundColor Cyan }
                'Warning' { Write-Host $logEntry -ForegroundColor Yellow }
                'Error'   { Write-Host $logEntry -ForegroundColor Red }
                'Debug'   { Write-Host $logEntry -ForegroundColor Gray }
                'Success' { Write-Host $logEntry -ForegroundColor Green }
                default   { Write-Host $logEntry }
            }
        }

        default {
            # Fallback to plain output
            Write-Output $logEntry
        }
    }

    # File logging if path provided
    if ($LogPath) {
        try {
            # Ensure parent directory exists
            $logDir = Split-Path -Parent $LogPath
            if ($logDir -and -not (Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }
            Add-Content -Path $LogPath -Value $logEntry -ErrorAction SilentlyContinue
        }
        catch {
            # Silently fail file logging to avoid disrupting script execution
            Write-Verbose "Failed to write to log file: $($_.Exception.Message)"
        }
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
    'Write-ScriptLog'
)
