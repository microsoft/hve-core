# Validate-MarkdownFrontmatter.ps1
#
# Purpose: Validates frontmatter consistency and footer presence across markdown files
# Author: HVE Core Team
# Created: 2025-11-05
#
# This script validates:
# - Required frontmatter fields (title, description, author, ms.date)
# - Date format (ISO 8601: YYYY-MM-DD)
# - Standard Copilot attribution footer (excludes Microsoft template files)
# - Content structure by file type (GitHub configs, DevContainer docs, etc.)

#requires -Version 7.0

using namespace System.Collections.Generic
# Import FrontmatterValidation module with 'using' to make PowerShell class types
# (FileTypeInfo, ValidationIssue, etc.) available at parse time for [OutputType] attributes
using module .\Modules\FrontmatterValidation.psm1

param(
    [Parameter(Mandatory = $false)]
    [string[]]$Paths = @('.'),

    [Parameter(Mandatory = $false)]
    [string[]]$Files = @(),

    [Parameter(Mandatory = $false)]
    [string[]]$ExcludePaths = @(),

    [Parameter(Mandatory = $false)]
    [switch]$WarningsAsErrors,

    [Parameter(Mandatory = $false)]
    [switch]$ChangedFilesOnly,

    [Parameter(Mandatory = $false)]
    [string]$BaseBranch = "origin/main",

    [Parameter(Mandatory = $false)]
    [switch]$EnableSchemaValidation,

    [Parameter(Mandatory = $false)]
    [switch]$SkipFooterValidation
)

# Import helper modules
# Note: FrontmatterValidation.psm1 is imported via 'using module' at top of script for class type availability
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'Modules/LintingHelpers.psm1') -Force

#region Type Definitions

class SchemaValidationResult {
    [bool]$IsValid
    [string[]]$Errors
    [string[]]$Warnings
    [string]$SchemaUsed
    [string]$Note

    SchemaValidationResult([bool]$isValid, [string[]]$errors, [string[]]$warnings, [string]$schemaUsed, [string]$note) {
        $this.IsValid = $isValid
        $this.Errors = if ($null -eq $errors) { @() } else { $errors }
        $this.Warnings = if ($null -eq $warnings) { @() } else { $warnings }
        $this.SchemaUsed = $schemaUsed
        $this.Note = $note
    }
}

# ValidationResult replaced by ValidationSummary in FrontmatterValidation.psm1

# FileTypeInfo and ValidationIssue classes are defined in FrontmatterValidation.psm1

#endregion Type Definitions

function Initialize-JsonSchemaValidation {
    <#
    .SYNOPSIS
    Validates that PowerShell JSON processing capabilities are available.

    .DESCRIPTION
    Pure function that tests whether PowerShell can process JSON data,
    which is required for JSON Schema validation operations. Does not
    load external modules or modify state.

    .INPUTS
    None.

    .OUTPUTS
    [bool] $true if JSON processing is available; $false otherwise.

    .EXAMPLE
    if (Initialize-JsonSchemaValidation) {
        $schema = Get-Content 'schema.json' | ConvertFrom-Json
    }

    .NOTES
    PowerShell 7+ includes built-in JSON support via ConvertFrom-Json
    and ConvertTo-Json cmdlets. This function verifies that capability.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $testJson = '{"test": "value"}' | ConvertFrom-Json
        return ($null -ne $testJson)
    }
    catch {
        Write-Warning "Error initializing schema validation: $_"
        return $false
    }
}

function Get-SchemaForFile {
    <#
    .SYNOPSIS
    Determines the appropriate JSON Schema for a given file path.

    .DESCRIPTION
    Resolves the correct JSON Schema to use for validating a file's frontmatter
    based on the schema-mapping.json configuration. Matches file paths against
    glob patterns defined in the mapping rules.

    Pattern matching priority:
    1. Directory-based patterns (e.g., 'docs/**/*.md')
    2. Pipe-separated root file patterns (e.g., 'README.md|CONTRIBUTING.md')
    3. Simple file patterns
    4. Default schema fallback

    .PARAMETER FilePath
    Absolute or relative path to the file needing schema resolution.

    .PARAMETER RepoRoot
    Repository root directory for computing relative paths. If not specified,
    attempts to locate .git directory by walking up the directory tree.

    .PARAMETER SchemaDirectory
    Directory containing JSON Schema files. Defaults to 'schemas' subdirectory
    relative to this script.

    .INPUTS
    [string] File path to resolve schema for.

    .OUTPUTS
    [string] Absolute path to the appropriate JSON Schema file.
    Returns $null if no schema applies or configuration is missing.

    .EXAMPLE
    $schema = Get-SchemaForFile -FilePath 'docs/getting-started/README.md'
    # Returns path to docs-frontmatter.schema.json

    .EXAMPLE
    $schema = Get-SchemaForFile -FilePath '.github/instructions/shell.instructions.md' -RepoRoot '/repo'
    # Returns path to instruction-frontmatter.schema.json

    .NOTES
    Relies on schema-mapping.json in the SchemaDirectory for pattern definitions.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$SchemaDirectory
    )

    $schemaDir = if ($SchemaDirectory) { $SchemaDirectory } else { Join-Path -Path $PSScriptRoot -ChildPath 'schemas' }
    $mappingPath = Join-Path -Path $schemaDir -ChildPath 'schema-mapping.json'

    if (-not (Test-Path $mappingPath)) {
        return $null
    }

    try {
        $mapping = Get-Content $mappingPath | ConvertFrom-Json

        if (-not $RepoRoot) {
            $RepoRoot = $PSScriptRoot
            while ($RepoRoot -and -not (Test-Path (Join-Path $RepoRoot '.git'))) {
                $RepoRoot = Split-Path -Parent $RepoRoot
            }
            if (-not $RepoRoot) {
                Write-Warning "Could not find repository root"
                return $null
            }
        }

        $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $FilePath) -replace '\\', '/'
        $fileName = [System.IO.Path]::GetFileName($FilePath)

        foreach ($rule in $mapping.mappings) {
            # Handle recursive glob patterns (e.g., docs/**/*.md)
            if ($rule.pattern -like "*/**/*") {
                $regexPattern = $rule.pattern -replace '\.', '\.'
                $regexPattern = $regexPattern -replace '\*\*/', '(.*/)?'
                $regexPattern = $regexPattern -replace '\*', '[^/]*'
                $regexPattern = '^' + $regexPattern + '$'
                if ($relativePath -match $regexPattern) {
                    return Join-Path -Path $schemaDir -ChildPath $rule.schema
                }
            }
            # Handle pipe-separated filename alternatives (e.g., README.md|CONTRIBUTING.md)
            elseif ($rule.pattern -match '\|') {
                $patterns = $rule.pattern -split '\|'
                if ($relativePath -eq $fileName -and $fileName -in $patterns) {
                    return Join-Path -Path $schemaDir -ChildPath $rule.schema
                }
            }
            # Handle simple glob patterns with wildcard pre-filter
            elseif ($relativePath -like $rule.pattern -or $fileName -like $rule.pattern) {
                $regexPattern = $rule.pattern -replace '\.', '\.'
                $regexPattern = $regexPattern -replace '\*\*/', '(.*/)?'
                $regexPattern = $regexPattern -replace '\*', '[^/]*'
                $regexPattern = '^' + $regexPattern + '$'
                if ($relativePath -match $regexPattern) {
                    return Join-Path -Path $schemaDir -ChildPath $rule.schema
                }
            }
        }

        if ($mapping.defaultSchema) {
            return Join-Path -Path $schemaDir -ChildPath $mapping.defaultSchema
        }
    }
    catch {
        Write-Warning "Error reading schema mapping: $_"
    }

    return $null
}

function Test-JsonSchemaValidation {
    <#
    .SYNOPSIS
    Validates a frontmatter hashtable against a JSON Schema.

    .DESCRIPTION
    Performs validation of frontmatter data against a JSON Schema file using
    PowerShell native capabilities. Checks required fields, type constraints,
    pattern matching, enum values, and minimum length requirements.

    Validation coverage:
    - required: Field presence validation
    - type: string, array, boolean type checking
    - pattern: Regex pattern matching for strings
    - enum: Allowed value constraints
    - minLength: Minimum string length validation

    Limitations (intentional for soft validation):
    - $ref: Schema references not resolved
    - allOf/anyOf/oneOf: Composition keywords not supported
    - object: Nested object validation not implemented

    .PARAMETER Frontmatter
    Hashtable containing parsed frontmatter key-value pairs.

    .PARAMETER SchemaPath
    Absolute path to the JSON Schema file.

    .PARAMETER SchemaContent
    Pre-loaded schema object (PSCustomObject from ConvertFrom-Json).
    Alternative to SchemaPath for testing without file I/O.

    .INPUTS
    [hashtable] Frontmatter data to validate.

    .OUTPUTS
    [SchemaValidationResult] Object containing:
      - IsValid: Boolean indicating validation success
      - Errors: Array of error messages
      - Warnings: Array of warning messages
      - SchemaUsed: Path to schema file used
      - Note: Additional validation context

    .EXAMPLE
    $frontmatter = @{ title = 'My Doc'; description = 'A description' }
    $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaPath 'schemas/docs.schema.json'
    if (-not $result.IsValid) {
        $result.Errors | ForEach-Object { Write-Error $_ }
    }

    .EXAMPLE
    # Testing with in-memory schema
    $schema = @{
        required = @('title')
        properties = @{
            title = @{ type = 'string'; minLength = 1 }
        }
    } | ConvertTo-Json | ConvertFrom-Json
    $result = Test-JsonSchemaValidation -Frontmatter @{ title = '' } -SchemaContent $schema
    # Result.Errors contains "Field 'title' must have minimum length of 1"

    .NOTES
    This implements soft validation suitable for advisory feedback without
    blocking builds on schema violations.
    #>
    [CmdletBinding(DefaultParameterSetName = 'SchemaPath')]
    [OutputType([SchemaValidationResult])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [hashtable]$Frontmatter,

        [Parameter(Mandatory = $true, ParameterSetName = 'SchemaPath')]
        [ValidateNotNullOrEmpty()]
        [string]$SchemaPath,

        [Parameter(Mandatory = $true, ParameterSetName = 'SchemaContent')]
        [PSCustomObject]$SchemaContent
    )

    $errors = [List[string]]::new()
    $warnings = [List[string]]::new()
    $schemaUsed = $SchemaPath

    if ($PSCmdlet.ParameterSetName -eq 'SchemaPath') {
        if (-not (Test-Path $SchemaPath)) {
            return [SchemaValidationResult]::new(
                $false,
                @("Schema file not found: $SchemaPath"),
                @(),
                $SchemaPath,
                $null
            )
        }

        try {
            $SchemaContent = Get-Content $SchemaPath -Raw | ConvertFrom-Json
        }
        catch {
            return [SchemaValidationResult]::new(
                $false,
                @("Failed to parse schema: $_"),
                @(),
                $SchemaPath,
                $null
            )
        }
    }
    else {
        $schemaUsed = '<in-memory>'
    }

    try {
        if ($SchemaContent.required) {
            foreach ($requiredField in $SchemaContent.required) {
                if (-not $Frontmatter.ContainsKey($requiredField)) {
                    $errors.Add("Missing required field: $requiredField")
                }
            }
        }

        if ($SchemaContent.properties) {
            foreach ($prop in $SchemaContent.properties.PSObject.Properties) {
                $fieldName = $prop.Name
                $fieldSchema = $prop.Value

                if ($Frontmatter.ContainsKey($fieldName)) {
                    $value = $Frontmatter[$fieldName]

                    if ($fieldSchema.type) {
                        switch ($fieldSchema.type) {
                            'string' {
                                if ($value -isnot [string]) {
                                    $errors.Add("Field '$fieldName' must be a string")
                                }
                            }
                            'array' {
                                # Exclude strings from IEnumerable check - strings implement IEnumerable but aren't arrays
                                if ($value -is [string] -or ($value -isnot [array] -and $value -isnot [System.Collections.IEnumerable])) {
                                    $errors.Add("Field '$fieldName' must be an array")
                                }
                            }
                            'boolean' {
                                if ($value -isnot [bool] -and $value -notin @('true', 'false', 'True', 'False')) {
                                    $errors.Add("Field '$fieldName' must be a boolean")
                                }
                            }
                        }
                    }

                    if ($fieldSchema.pattern -and $value -is [string]) {
                        if ($value -notmatch $fieldSchema.pattern) {
                            $errors.Add("Field '$fieldName' does not match required pattern: $($fieldSchema.pattern)")
                        }
                    }

                    if ($fieldSchema.enum) {
                        if ($value -is [array]) {
                            foreach ($item in $value) {
                                if ($item -notin $fieldSchema.enum) {
                                    $errors.Add("Field '$fieldName' contains invalid value: $item. Allowed: $($fieldSchema.enum -join ', ')")
                                }
                            }
                        }
                        else {
                            if ($value -notin $fieldSchema.enum) {
                                $errors.Add("Field '$fieldName' must be one of: $($fieldSchema.enum -join ', '). Got: $value")
                            }
                        }
                    }

                    if ($fieldSchema.minLength -and $value -is [string]) {
                        if ($value.Length -lt $fieldSchema.minLength) {
                            $errors.Add("Field '$fieldName' must have minimum length of $($fieldSchema.minLength)")
                        }
                    }
                }
            }
        }

        return [SchemaValidationResult]::new(
            ($errors.Count -eq 0),
            $errors.ToArray(),
            $warnings.ToArray(),
            $schemaUsed,
            'Schema validation using PowerShell native capabilities'
        )
    }
    catch {
        return [SchemaValidationResult]::new(
            $false,
            @("Schema validation error: $_"),
            @(),
            $schemaUsed,
            $null
        )
    }
}

# Get-FileTypeInfo is provided by FrontmatterValidation.psm1 via 'using module' directive

function Test-FrontmatterValidation {
    <#
    .SYNOPSIS
    Validates frontmatter consistency across markdown files.

    .DESCRIPTION
    Thin wrapper that delegates validation to FrontmatterValidation module functions.
    Supports directory scanning, explicit file lists, and git diff-based changed files.

    .PARAMETER Paths
    Directory paths to search recursively for markdown files.

    .PARAMETER Files
    Specific file paths to validate. Takes precedence over Paths.

    .PARAMETER ExcludePaths
    Glob patterns for paths to exclude from validation.

    .PARAMETER WarningsAsErrors
    Treat warnings as errors.

    .PARAMETER ChangedFilesOnly
    Only validate files changed since the base branch.

    .PARAMETER BaseBranch
    Git reference for comparison. Default: 'origin/main'.

    .PARAMETER EnableSchemaValidation
    Enable JSON Schema validation (advisory only).

    .OUTPUTS
    ValidationSummary from FrontmatterValidation module.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Paths = @(),
        [string[]]$Files = @(),
        [string[]]$ExcludePaths = @(),
        [switch]$WarningsAsErrors,
        [switch]$ChangedFilesOnly,
        [string]$BaseBranch = "origin/main",
        [switch]$EnableSchemaValidation,
        [switch]$SkipFooterValidation
    )

    # Resolve repository root
    $repoRoot = (Get-Location).Path
    if (-not (Test-Path ".git")) {
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($gitRoot) { $repoRoot = $gitRoot }
    }

    Write-Host "🔍 Validating frontmatter across markdown files..." -ForegroundColor Cyan

    # Handle ChangedFilesOnly mode
    if ($ChangedFilesOnly) {
        Write-Host "🔍 Detecting changed markdown files from git diff..." -ForegroundColor Cyan
        $Files = Get-ChangedMarkdownFileGroup -BaseBranch $BaseBranch
        if ($Files.Count -eq 0) {
            Write-Host "No changed markdown files found - validation complete" -ForegroundColor Green
            # Return empty summary with TotalFiles=0 to accurately represent no files validated
            # The caller handles this as success when ChangedFilesOnly mode is used
            $emptySummary = & (Get-Module FrontmatterValidation) { [ValidationSummary]::new() }
            $null = $emptySummary.Complete()
            return $emptySummary
        }
        Write-Host "Found $($Files.Count) changed markdown files to validate" -ForegroundColor Cyan
    }

    # Resolve files from paths if not provided directly
    [string[]]$resolvedFiles = @()
    if ($Files.Count -gt 0) {
        Write-Host "Validating specific files..." -ForegroundColor Cyan
        $resolvedFiles = $Files | Where-Object { -not [string]::IsNullOrEmpty($_) } |
            ForEach-Object { $_.Trim() } |
            Where-Object { (Test-Path $_ -PathType Leaf) -and ($_ -like "*.md") } |
            ForEach-Object { (Get-Item $_).FullName }
    }
    elseif ($Paths.Count -gt 0) {
        Write-Host "Searching for markdown files in specified paths..." -ForegroundColor Cyan
        $gitignorePatterns = Get-GitIgnorePatterns -GitIgnorePath (Join-Path $repoRoot ".gitignore")
        foreach ($path in ($Paths | Where-Object { -not [string]::IsNullOrEmpty($_) })) {
            if (Test-Path $path) {
                $rawFiles = Get-ChildItem -Path $path -Filter '*.md' -Recurse -File -ErrorAction SilentlyContinue
                foreach ($f in $rawFiles) {
                    if ($null -eq $f -or [string]::IsNullOrEmpty($f.FullName)) { continue }
                    $excluded = $false
                    foreach ($pattern in $gitignorePatterns) {
                        if ($f.FullName -like $pattern) { $excluded = $true; break }
                    }
                    if (-not $excluded) { $resolvedFiles += $f.FullName }
                }
            }
        }
    }

    # Apply exclude patterns
    if ($ExcludePaths.Count -gt 0 -and $resolvedFiles.Count -gt 0) {
        $resolvedFiles = $resolvedFiles | Where-Object {
            $relativePath = $_.Replace($repoRoot, '').TrimStart('\', '/').Replace('\', '/')
            $excluded = $false
            foreach ($excludePattern in $ExcludePaths) {
                if ($relativePath -like $excludePattern) { $excluded = $true; break }
            }
            -not $excluded
        }
    }

    if ($resolvedFiles.Count -eq 0) {
        Write-Warning "No valid files or paths provided for validation"
        return & (Get-Module FrontmatterValidation) { [ValidationSummary]::new() }
    }

    Write-Host "Found $($resolvedFiles.Count) total markdown files to validate" -ForegroundColor Cyan

    # Use module's orchestration function for core validation
    $summary = Invoke-FrontmatterValidation -Files $resolvedFiles -RepoRoot $repoRoot -SkipFooterValidation:$SkipFooterValidation

    # Optional schema validation overlay (advisory only)
    # Uses frontmatter already parsed by Invoke-FrontmatterValidation
    if ($EnableSchemaValidation -and (Initialize-JsonSchemaValidation)) {
        foreach ($fileResult in $summary.Results) {
            if ($fileResult.HasFrontmatter -and $fileResult.Frontmatter) {
                $schemaPath = Get-SchemaForFile -FilePath $fileResult.FilePath
                if ($schemaPath) {
                    $schemaResult = Test-JsonSchemaValidation -Frontmatter $fileResult.Frontmatter -SchemaPath $schemaPath
                    if ($schemaResult.Errors.Count -gt 0) {
                        Write-Warning "JSON Schema validation errors in $($fileResult.FilePath)"
                        $schemaResult.Errors | ForEach-Object { Write-Warning "  - $_" }
                    }
                }
            }
        }
    }

    # Output to console
    Write-ValidationConsoleOutput -Summary $summary -ShowDetails

    # GitHub Actions annotations
    if ($env:GITHUB_ACTIONS) {
        Write-GitHubAnnotations -Summary $summary
    }

    # Export results
    $logsDir = Join-Path -Path $repoRoot -ChildPath 'logs'
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }
    Export-ValidationResults -Summary $summary -OutputPath (Join-Path $logsDir 'frontmatter-validation-results.json')

    # GitHub step summary
    $hasIssues = $summary.GetExitCode($WarningsAsErrors) -ne 0
    if ($hasIssues) {
        $summaryContent = @"
## ❌ Frontmatter Validation Failed

**Files checked:** $($summary.TotalFiles)
**Files with errors:** $($summary.FilesWithErrors)
**Files with warnings:** $($summary.FilesWithWarnings)
**Total errors:** $($summary.TotalErrors)
**Total warnings:** $($summary.TotalWarnings)

See the uploaded artifact for complete details.
"@
        Write-GitHubStepSummary -Content $summaryContent
        Set-GitHubEnv -Name "FRONTMATTER_VALIDATION_FAILED" -Value "true"
    }
    else {
        $summaryContent = @"
## ✅ Frontmatter Validation Passed

**Files checked:** $($summary.TotalFiles)
**Errors:** 0
**Warnings:** 0

All frontmatter fields are valid and properly formatted. Great job! 🎉
"@
        Write-GitHubStepSummary -Content $summaryContent
        Write-Host "✅ Frontmatter validation completed successfully" -ForegroundColor Green
    }

    return $summary
}

function Get-ChangedMarkdownFileGroup {
    <#
    .SYNOPSIS
    Retrieves changed markdown files from git diff comparison.

    .DESCRIPTION
    Uses git diff to identify markdown files that have changed between the current
    HEAD and a base branch. Implements a fallback strategy when standard comparison
    methods fail:

    1. First attempts: git merge-base comparison with specified base branch
    2. Fallback 1: Comparison with HEAD~1 (previous commit)
    3. Fallback 2: Staged and unstaged files against HEAD

    .PARAMETER BaseBranch
    Git reference for the base branch to compare against. Defaults to 'origin/main'.
    Can be any valid git ref (branch name, tag, commit SHA).

    .PARAMETER FallbackStrategy
    Controls fallback behavior when primary comparison fails.
    - 'Auto' (default): Tries all fallback strategies automatically
    - 'HeadOnly': Only uses HEAD~1 fallback
    - 'None': No fallback, returns empty on failure

    .INPUTS
    None. Does not accept pipeline input.

    .OUTPUTS
    [string[]] Array of relative file paths for changed markdown files.
    Returns empty array if no changes detected or git operations fail.

    .EXAMPLE
    $changedFiles = Get-ChangedMarkdownFileGroup
    # Returns markdown files changed compared to origin/main

    .EXAMPLE
    $changedFiles = Get-ChangedMarkdownFileGroup -BaseBranch 'origin/develop'
    # Returns markdown files changed compared to develop branch

    .EXAMPLE
    $changedFiles = Get-ChangedMarkdownFileGroup -FallbackStrategy 'None'
    # Returns empty array if merge-base comparison fails

    .NOTES
    Requires git to be available in PATH. Files must exist on disk to be included
    in the result (deleted files are excluded).
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseBranch = "origin/main",

        [Parameter(Mandatory = $false)]
        [ValidateSet('Auto', 'HeadOnly', 'None')]
        [string]$FallbackStrategy = 'Auto'
    )

    try {
        $changedFiles = git diff --name-only $(git merge-base HEAD $BaseBranch) HEAD 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Verbose "Merge base comparison with '$BaseBranch' failed"

            if ($FallbackStrategy -eq 'None') {
                Write-Warning "Unable to determine changed files from git (no fallback enabled)"
                return @()
            }

            Write-Verbose "Attempting fallback: HEAD~1 comparison"
            $changedFiles = git diff --name-only HEAD~1 HEAD 2>$null

            if ($LASTEXITCODE -ne 0 -and $FallbackStrategy -eq 'Auto') {
                Write-Verbose "HEAD~1 comparison failed, attempting staged/unstaged files"
                $changedFiles = git diff --name-only HEAD 2>$null

                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Unable to determine changed files from git"
                    return @()
                }
            }
            elseif ($LASTEXITCODE -ne 0) {
                Write-Warning "Unable to determine changed files from git"
                return @()
            }
        }

        [string[]]$changedMarkdownFiles = $changedFiles | Where-Object {
            -not [string]::IsNullOrEmpty($_) -and
            $_ -match '\.md$' -and
            (Test-Path $_ -PathType Leaf)
        }

        Write-Verbose "Found $($changedMarkdownFiles.Count) changed markdown files from git diff"
        $changedMarkdownFiles | ForEach-Object { Write-Verbose "  Changed: $_" }

        return $changedMarkdownFiles
    }
    catch {
        Write-Warning "Error getting changed files from git: $($_.Exception.Message)"
        return @()
    }
}

#region Main Execution
try {
    if ($MyInvocation.InvocationName -ne '.') {
        if ($ChangedFilesOnly) {
            $result = Test-FrontmatterValidation -ChangedFilesOnly -BaseBranch $BaseBranch -ExcludePaths $ExcludePaths -WarningsAsErrors:$WarningsAsErrors -EnableSchemaValidation:$EnableSchemaValidation -SkipFooterValidation:$SkipFooterValidation
        }
        elseif ($Files.Count -gt 0) {
            $result = Test-FrontmatterValidation -Files $Files -ExcludePaths $ExcludePaths -WarningsAsErrors:$WarningsAsErrors -EnableSchemaValidation:$EnableSchemaValidation -SkipFooterValidation:$SkipFooterValidation
        }
        else {
            $result = Test-FrontmatterValidation -Paths $Paths -ExcludePaths $ExcludePaths -WarningsAsErrors:$WarningsAsErrors -EnableSchemaValidation:$EnableSchemaValidation -SkipFooterValidation:$SkipFooterValidation
        }

        # Normalize result: if pipeline output produced an array, extract the ValidationSummary object
        # PowerShell functions can inadvertently output multiple objects; take the last (the return value)
        if ($result -is [System.Array]) {
            $result = $result | Where-Object { $null -ne $_ -and $_.GetType().GetMethod('GetExitCode') } | Select-Object -Last 1
        }

        # In ChangedFilesOnly mode with no changed files, TotalFiles=0 is a successful no-op
        if ($ChangedFilesOnly -and $null -ne $result -and $result.TotalFiles -eq 0) {
            Write-Host "✅ No changed markdown files to validate - success!" -ForegroundColor Green
            exit 0
        }

        # Validate result object before calling GetExitCode to prevent method invocation errors
        # PowerShell class methods are compiled to .NET type metadata, not stored in PSObject.Methods (ETS only)
        if ($null -eq $result -or $null -eq $result.GetType().GetMethod('GetExitCode')) {
            $resultTypeName = if ($null -eq $result) { '<null>' } else { $result.GetType().FullName }
            Write-Host "Validation did not produce a usable result object (type: $resultTypeName). Exiting with code 1."
            exit 1
        }

        $exitCode = $result.GetExitCode($WarningsAsErrors)
        if ($exitCode -ne 0) {
            exit $exitCode
        }
        else {
            Write-Host "✅ All frontmatter validation checks passed!" -ForegroundColor Green
            exit 0
        }
    }
}
catch {
    Write-Error "Validate Markdown Frontmatter failed: $($_.Exception.Message)"
    if ($env:GITHUB_ACTIONS -eq 'true') {
        Write-Output "::error::$($_.Exception.Message)"
    }
    exit 1
}
#endregion