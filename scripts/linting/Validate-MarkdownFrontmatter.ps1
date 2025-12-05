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

param(
    [Parameter(Mandatory = $false)]
    [string[]]$Paths = @('.'),

    [Parameter(Mandatory = $false)]
    [string[]]$Files = @(),

    [Parameter(Mandatory = $false)]
    [switch]$WarningsAsErrors,

    [Parameter(Mandatory = $false)]
    [switch]$ChangedFilesOnly,

    [Parameter(Mandatory = $false)]
    [string]$BaseBranch = "origin/main",

    [Parameter(Mandatory = $false)]
    [switch]$SkipFooterValidation,

    [Parameter(Mandatory = $false)]
    [switch]$EnableSchemaValidation
)

# Import LintingHelpers module
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'Modules/LintingHelpers.psm1') -Force

function Get-MarkdownFrontmatter {
    <#
    .SYNOPSIS
    Extracts YAML frontmatter from a markdown file.

    .DESCRIPTION
    Parses YAML frontmatter from the beginning of a markdown file and returns
    a structured object containing the frontmatter data and content.

    .PARAMETER FilePath
    Path to the markdown file to parse.

    .OUTPUTS
    Returns a hashtable with Frontmatter, FrontmatterEndIndex, and Content properties.
    #>

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        Write-Warning "File not found: $FilePath"
        return $null
    }

    try {
        $content = Get-Content -Path $FilePath -Raw -Encoding UTF8

        # Check if file starts with YAML frontmatter
        if (-not $content.StartsWith("---")) {
            return $null
        }

        # Find the end of frontmatter
        $lines = $content -split "`n"
        $endIndex = -1

        for ($i = 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i].Trim() -eq "---") {
                $endIndex = $i
                break
            }
        }

        if ($endIndex -eq -1) {
            Write-Warning "Malformed YAML frontmatter in: $FilePath"
            return $null
        }

        # Extract frontmatter lines
        $frontmatterLines = $lines[1..($endIndex - 1)]
        $frontmatter = @{}

        foreach ($line in $frontmatterLines) {
            $trimmedLine = $line.Trim()
            if ($trimmedLine -eq "" -or $trimmedLine.StartsWith("#")) {
                continue
            }

            if ($line -match "^([^:]+):\s*(.*)$") {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()

                # Handle array values (YAML arrays starting with -)
                if ($value.StartsWith("[") -and $value.EndsWith("]")) {
                    # Parse JSON-style array
                    try {
                        $frontmatter[$key] = $value | ConvertFrom-Json
                    }
                    catch {
                        $frontmatter[$key] = $value
                    }
                }
                else {
                    # Check if this is the start of a YAML array
                    if ($value.StartsWith("-") -or $value.Trim() -eq "") {
                        $arrayValues = @()
                        if ($value.StartsWith("-")) {
                            $arrayValues += $value.Substring(1).Trim()
                        }

                        # Look for additional array items
                        $j = $frontmatterLines.IndexOf($line) + 1
                        while ($j -lt $frontmatterLines.Count -and $frontmatterLines[$j].StartsWith("  -")) {
                            $arrayValues += $frontmatterLines[$j].Substring(3).Trim()
                            $j++
                        }

                        if ($arrayValues.Count -gt 0) {
                            $frontmatter[$key] = $arrayValues
                        }
                        else {
                            $frontmatter[$key] = $value
                        }
                    }
                    else {
                        # Remove quotes if present
                        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
                            ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                            $value = $value.Substring(1, $value.Length - 2)
                        }
                        $frontmatter[$key] = $value
                    }
                }
            }
        }

        return @{
            Frontmatter         = $frontmatter
            FrontmatterEndIndex = $endIndex + 1
            Content             = ($lines[($endIndex + 1)..($lines.Count - 1)] -join "`n")
        }
    }
    catch {
        Write-Warning "Error parsing frontmatter in ${FilePath}: [$($_.Exception.GetType().Name)] $($_.Exception.Message)"
        return $null
    }
}

function Test-MarkdownFooter {
    <#
    .SYNOPSIS
    Checks if a markdown file has the standard Copilot footer.

    .DESCRIPTION
    Validates that markdown files end with the standard Copilot attribution footer.
    Supports both plain text and markdownlint-wrapped variants.

    .PARAMETER Content
    The full content of the markdown file (from Get-MarkdownFrontmatter result).

    .OUTPUTS
    Returns $true if footer is present and valid, $false otherwise.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    # Normalize content (remove HTML comments and markdown formatting)
    # Use (?s) for multiline HTML comments and comprehensive markdown format removal
    $normalized = $Content -replace '(?s)<!--.*?-->', ''  # Remove HTML comments (multiline)
    $normalized = $normalized -replace '\*\*([^*]+)\*\*', '$1'  # Remove bold (**text**)
    $normalized = $normalized -replace '__([^_]+)__', '$1'  # Remove bold (__text__)
    $normalized = $normalized -replace '\*([^*]+)\*', '$1'  # Remove italic (*text*)
    $normalized = $normalized -replace '_([^_]+)_', '$1'  # Remove italic (_text_)
    $normalized = $normalized -replace '~~([^~]+)~~', '$1'  # Remove strikethrough
    $normalized = $normalized -replace '`([^`]+)`', '$1'  # Remove inline code
    $normalized = $normalized.TrimEnd()

    # Core footer pattern (flexible for line breaks and formatting variations)
    $pattern = '🤖\s*Crafted\s+with\s+precision\s+by\s+✨Copilot\s+following\s+brilliant\s+human\s+instruction[,\s]+(then\s+)?carefully\s+refined\s+by\s+our\s+team\s+of\s+discerning\s+human\s+reviewers\.?'
    
    return $normalized -match $pattern
}

function Initialize-JsonSchemaValidation {
    <#
    .SYNOPSIS
    Initializes JSON Schema validation using PowerShell native capabilities.

    .DESCRIPTION
    Validates that schema files exist and PowerShell can process JSON.
    Uses PowerShell's built-in JSON and YAML processing capabilities.
    #>
    try {
        # Check if we can work with JSON (built into PowerShell)
        $testJson = '{"test": "value"}' | ConvertFrom-Json
        if ($null -eq $testJson) {
            Write-Warning "PowerShell JSON processing not available."
            return $false
        }
        
        # Schema validation is ready using PowerShell native capabilities
        return $true
    }
    catch {
        Write-Warning "Error initializing schema validation: $_"
        return $false
    }
}

function Get-SchemaForFile {
    <#
    .SYNOPSIS
    Determines the appropriate JSON Schema for a given file.

    .PARAMETER FilePath
    The path of the file to get schema for.

    .OUTPUTS
    Returns the schema file path or null if no specific schema applies.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $schemaDir = Join-Path -Path $PSScriptRoot -ChildPath 'schemas'
    $mappingPath = Join-Path -Path $schemaDir -ChildPath 'schema-mapping.json'
    
    if (-not (Test-Path $mappingPath)) {
        return $null
    }

    try {
        $mapping = Get-Content $mappingPath | ConvertFrom-Json
        
        # Find repository root by searching for .git directory
        $repoRoot = $PSScriptRoot
        while ($repoRoot -and -not (Test-Path (Join-Path $repoRoot '.git'))) {
            $repoRoot = Split-Path -Parent $repoRoot
        }
        if (-not $repoRoot) {
            Write-Warning "Could not find repository root"
            return $null
        }
        
        $relativePath = [System.IO.Path]::GetRelativePath($repoRoot, $FilePath) -replace '\\', '/'
        $fileName = [System.IO.Path]::GetFileName($FilePath)

        foreach ($rule in $mapping.mappings) {
            # Directory-based patterns (check these FIRST for proper specificity)
            if ($rule.pattern -like "*/**/*") {
                # Convert glob to regex: '**/' => '(.*/)?', '*' => '[^/]*', '.' => '\.'
                $regexPattern = $rule.pattern
                $regexPattern = $regexPattern -replace '\*\*/', '(.*/)?'
                $regexPattern = $regexPattern -replace '\*', '[^/]*'
                $regexPattern = $regexPattern -replace '\.', '\.'
                $regexPattern = '^' + $regexPattern + '$'
                if ($relativePath -match $regexPattern) {
                    return Join-Path -Path $schemaDir -ChildPath $rule.schema
                }
            }
            # Simple pattern matching for root file names only
            elseif ($rule.pattern -match '\|') {
                $patterns = $rule.pattern -split '\|'
                # Only match if file is in root (relativePath equals fileName)
                if ($relativePath -eq $fileName -and $fileName -in $patterns) {
                    return Join-Path -Path $schemaDir -ChildPath $rule.schema
                }
            }
            # Simple file patterns
            elseif ($relativePath -like $rule.pattern -or $fileName -like $rule.pattern) {
                # Convert glob to regex: '**/' => '(.*/)?', '*' => '[^/]*', '.' => '\.'
                $regexPattern = $rule.pattern
                $regexPattern = $regexPattern -replace '\*\*/', '(.*/)?'
                $regexPattern = $regexPattern -replace '\*', '[^/]*'
                $regexPattern = $regexPattern -replace '\.', '\.'
                $regexPattern = '^' + $regexPattern + '$'
                if ($relativePath -match $regexPattern) {
                    return Join-Path -Path $schemaDir -ChildPath $rule.schema
                }
            }
            # Simple file patterns
            elseif ($relativePath -like $rule.pattern -or $fileName -like $rule.pattern) {
                return Join-Path -Path $schemaDir -ChildPath $rule.schema
            }
        }

        # Return default schema if available
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
    Validates frontmatter against JSON Schema using PowerShell native capabilities.

    .PARAMETER Frontmatter
    The frontmatter hashtable to validate.

    .PARAMETER SchemaPath
    Path to the JSON Schema file.

    .OUTPUTS
    Returns validation result with errors and warnings.
    
    .NOTES
    Validation limitations (intentional for soft validation):
    - $ref references are not resolved (workaround: inline base schema properties)
    - allOf/anyOf/oneOf schema composition is not supported
    - object type validation is not implemented
    - enum and minLength validations are supported
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Frontmatter,

        [Parameter(Mandatory = $true)]
        [string]$SchemaPath
    )

    if (-not (Test-Path $SchemaPath)) {
        return @{
            IsValid = $false
            Errors = @("Schema file not found: $SchemaPath")
            Warnings = @()
        }
    }

    try {
        # Load the schema file
        $schemaContent = Get-Content $SchemaPath -Raw | ConvertFrom-Json
        $errors = @()
        $warnings = @()

        # Basic validation using PowerShell native capabilities
        # Check required fields
        if ($schemaContent.required) {
            foreach ($requiredField in $schemaContent.required) {
                if (-not $Frontmatter.ContainsKey($requiredField)) {
                    $errors += "Missing required field: $requiredField"
                }
            }
        }

        # Check field types if properties are defined
        if ($schemaContent.properties) {
            foreach ($prop in $schemaContent.properties.PSObject.Properties) {
                $fieldName = $prop.Name
                $fieldSchema = $prop.Value
                
                if ($Frontmatter.ContainsKey($fieldName)) {
                    $value = $Frontmatter[$fieldName]
                    
                    # Type validation
                    if ($fieldSchema.type) {
                        switch ($fieldSchema.type) {
                            'string' {
                                if ($value -isnot [string]) {
                                    $errors += "Field '$fieldName' must be a string"
                                }
                            }
                            'array' {
                                if ($value -isnot [array] -and $value -isnot [System.Collections.IEnumerable]) {
                                    $errors += "Field '$fieldName' must be an array"
                                }
                            }
                            'boolean' {
                                if ($value -isnot [bool] -and $value -notin @('true', 'false', 'True', 'False')) {
                                    $errors += "Field '$fieldName' must be a boolean"
                                }
                            }
                        }
                    }
                    
                    # Pattern validation for strings
                    if ($fieldSchema.pattern -and $value -is [string]) {
                        if ($value -notmatch $fieldSchema.pattern) {
                            $errors += "Field '$fieldName' does not match required pattern: $($fieldSchema.pattern)"
                        }
                    }
                    
                    # Enum validation
                    if ($fieldSchema.enum) {
                        if ($value -is [array]) {
                            foreach ($item in $value) {
                                if ($item -notin $fieldSchema.enum) {
                                    $errors += "Field '$fieldName' contains invalid value: $item. Allowed: $($fieldSchema.enum -join ', ')"
                                }
                            }
                        } else {
                            if ($value -notin $fieldSchema.enum) {
                                $errors += "Field '$fieldName' must be one of: $($fieldSchema.enum -join ', '). Got: $value"
                            }
                        }
                    }
                    
                    # MinLength validation for strings
                    if ($fieldSchema.minLength -and $value -is [string]) {
                        if ($value.Length -lt $fieldSchema.minLength) {
                            $errors += "Field '$fieldName' must have minimum length of $($fieldSchema.minLength)"
                        }
                    }
                }
            }
        }

        return @{
            IsValid = ($errors.Count -eq 0)
            Errors = $errors
            Warnings = $warnings
            SchemaUsed = $SchemaPath
            Note = "Schema validation using PowerShell native capabilities"
        }
    }
    catch {
        return @{
            IsValid = $false
            Errors = @("Schema validation error: $_")
            Warnings = @()
        }
    }
}

function Test-FrontmatterValidation {
    <#
    .SYNOPSIS
    Validates frontmatter across all markdown files in specified paths.

    .DESCRIPTION
    Performs comprehensive frontmatter validation including required fields,
    date format validation, and content type-specific requirements.

    .PARAMETER Paths
    Array of paths to search for markdown files.

    .PARAMETER Files
    Array of specific file paths to validate (takes precedence over Paths).

    .PARAMETER WarningsAsErrors
    Treat warnings as errors (fail validation on warnings).

    .PARAMETER EnableSchemaValidation
    Enable JSON Schema validation against defined schemas.

    .OUTPUTS
    Returns validation results with errors and warnings.
    #>

    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$Paths = @(),

        [Parameter(Mandatory = $false)]
        [switch]$SkipFooterValidation,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$Files = @(),

        [Parameter(Mandatory = $false)]
        [switch]$WarningsAsErrors,

        [Parameter(Mandatory = $false)]
        [switch]$ChangedFilesOnly,

        [Parameter(Mandatory = $false)]
        [string]$BaseBranch = "origin/main",

        [Parameter(Mandatory = $false)]
        [switch]$EnableSchemaValidation
    )
    
    # Get repository root
    $repoRoot = (Get-Location).Path
    if (-not (Test-Path ".git")) {
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($gitRoot) {
            $repoRoot = $gitRoot
        }
    }
    
    # Parse .gitignore patterns
    $gitignorePatterns = @()
    $gitignorePath = Join-Path $repoRoot ".gitignore"
    if (Test-Path $gitignorePath) {
        $gitignorePatterns = Get-Content $gitignorePath | Where-Object {
            $_ -and 
            -not $_.StartsWith('#') -and 
            $_.Trim() -ne ''
        } | ForEach-Object {
            $pattern = $_.Trim()
            # Convert gitignore patterns to PowerShell wildcard patterns
            if ($pattern.EndsWith('/')) {
                # Directory pattern
                "*\$($pattern.TrimEnd('/'))\*"
            }
            elseif ($pattern.Contains('/')) {
                # Path pattern
                "*\$($pattern.Replace('/', '\'))*"
            }
            else {
                # Simple pattern
                "*\$pattern\*"
            }
        }
    }
    
    Write-Host "🔍 Validating frontmatter across markdown files..." -ForegroundColor Cyan
    
    # Input validation and sanitization
    $errors = @()
    $warnings = @()
    $filesWithErrors = [System.Collections.Generic.HashSet[string]]::new()
    $filesWithWarnings = [System.Collections.Generic.HashSet[string]]::new()

    # If ChangedFilesOnly is specified, get changed files from git
    if ($ChangedFilesOnly) {
        Write-Host "🔍 Detecting changed markdown files from git diff..." -ForegroundColor Cyan
        $gitChangedFiles = Get-ChangedMarkdownFileGroup -BaseBranch $BaseBranch
        if ($gitChangedFiles.Count -gt 0) {
            $Files = $gitChangedFiles
            Write-Host "Found $($Files.Count) changed markdown files to validate" -ForegroundColor Cyan
        }
        else {
            Write-Host "No changed markdown files found - validation complete" -ForegroundColor Green
            return @{
                Errors            = @()
                Warnings          = @()
                HasIssues         = $false
                TotalFilesChecked = 0
            }
        }
    }

    # Sanitize Files array - remove empty or null entries
    if ($Files.Count -gt 0) {
        $sanitizedFiles = @()
        foreach ($file in $Files) {
            if (-not [string]::IsNullOrEmpty($file)) {
                $sanitizedFiles += $file.Trim()
            }
            else {
                Write-Verbose "Filtering out empty file path from Files array"
            }
        }
        $Files = $sanitizedFiles
    }

    # Sanitize Paths array - remove empty or null entries
    if ($Paths.Count -gt 0) {
        $sanitizedPaths = @()
        foreach ($path in $Paths) {
            if (-not [string]::IsNullOrEmpty($path)) {
                $sanitizedPaths += $path.Trim()
            }
            else {
                Write-Verbose "Filtering out empty path from Paths array"
            }
        }
        $Paths = $sanitizedPaths
    }

    # Ensure we have at least one valid input source
    if ($Files.Count -eq 0 -and $Paths.Count -eq 0) {
        $warnings += "No valid files or paths provided for validation"
        return @{
            Errors            = @()
            Warnings          = $warnings
            HasIssues         = $true
            TotalFilesChecked = 0
        }
    }

    # Get markdown files either from specific files or from paths
    [System.Collections.ArrayList]$markdownFiles = @()

    if ($Files.Count -gt 0) {
        Write-Host "Validating specific files..." -ForegroundColor Cyan
        foreach ($file in $Files) {
            if (-not [string]::IsNullOrEmpty($file) -and (Test-Path $file -PathType Leaf)) {
                if ($file -like "*.md") {
                    $fileItem = Get-Item $file
                    if ($null -ne $fileItem -and -not [string]::IsNullOrEmpty($fileItem.FullName)) {
                        $markdownFiles += $fileItem
                        Write-Verbose "Added specific file: $file"
                    }
                }
                else {
                    Write-Verbose "Skipping non-markdown file: $file"
                }
            }
            else {
                Write-Warning "File not found or invalid: $file"
            }
        }
    }
    else {
        Write-Host "Searching for markdown files in specified paths..." -ForegroundColor Cyan
        foreach ($path in $Paths) {
            if (Test-Path $path) {
                # Get files and filter manually with strongly typed array
                $rawFiles = Get-ChildItem -Path $path -Filter '*.md' -Recurse -File -ErrorAction SilentlyContinue
                
                # Manual filtering with strongly typed array to prevent implicit string conversion
                [System.IO.FileInfo[]]$files = @()
                foreach ($f in $rawFiles) {
                    if ($null -eq $f -or
                        [string]::IsNullOrEmpty($f.FullName) -or
                        $f.PSIsContainer -eq $true) {
                        continue
                    }
                    
                    # Check against gitignore patterns
                    $excluded = $false
                    foreach ($pattern in $gitignorePatterns) {
                        if ($f.FullName -like $pattern) {
                            $excluded = $true
                            break
                        }
                    }
                    
                    if (-not $excluded) {
                        $files += $f
                    }
                }
                
                if ($files.Count -gt 0) {
                    [void]$markdownFiles.AddRange($files)
                    Write-Verbose "Found $($files.Count) markdown files in $path"
                }  
                else {
                    Write-Verbose "No markdown files found in $path"
                }
            }
            else {
                Write-Warning "Path not found: $path"
            }
        }
    }
    
    Write-Host "Found $($markdownFiles.Count) total markdown files to validate" -ForegroundColor Cyan

    # Initialize schema validation once before processing files
    $schemaValidationEnabled = $false
    if ($EnableSchemaValidation) {
        $schemaValidationEnabled = Initialize-JsonSchemaValidation
        if (-not $schemaValidationEnabled) {
            Write-Warning "Schema validation requested but not available - continuing without schema validation"
        }
    }

    foreach ($file in $markdownFiles) {
        # Skip null file objects or files with empty/null paths
        if ($null -eq $file) {
            Write-Verbose "Skipping null file object"
            continue
        }
        
        if ([string]::IsNullOrEmpty($file.FullName)) {
            Write-Verbose "Skipping file with empty path"
            continue
        }

        Write-Verbose "Validating: $($file.FullName)"

        try {
            $frontmatter = Get-MarkdownFrontmatter -FilePath $file.FullName

            if ($frontmatter) {
                # Soft validation mode: Schema validation reports issues via Write-Warning without failing builds.
                # This provides comprehensive advisory feedback while manual validation below enforces critical rules.
                if ($schemaValidationEnabled) {
                    $schemaPath = Get-SchemaForFile -FilePath $file.FullName
                    if ($schemaPath) {
                        $schemaResult = Test-JsonSchemaValidation -Frontmatter $frontmatter.Frontmatter -SchemaPath $schemaPath
                        if ($schemaResult.Errors.Count -gt 0) {
                            Write-Warning "JSON Schema validation errors in $($file.FullName):"
                            $schemaResult.Errors | ForEach-Object { Write-Warning "  - $_" }
                        }
                        if ($schemaResult.Warnings.Count -gt 0) {
                            Write-Verbose "JSON Schema validation warnings in $($file.FullName):"
                            $schemaResult.Warnings | ForEach-Object { Write-Verbose "  - $_" }
                        }
                    }
                }

                # Determine content type and required fields
                $isGitHub = $file.DirectoryName -like "*.github*"
                $isChatMode = $file.Name -like "*.chatmode.md"
                $isPrompt = $file.Name -like "*.prompt.md"
                $isInstruction = $file.Name -like "*.instructions.md"
                $isRootCommunityFile = ($file.DirectoryName -eq $repoRoot) -and 
                                       ($file.Name -in @('CODE_OF_CONDUCT.md', 'CONTRIBUTING.md', 
                                                        'SECURITY.md', 'SUPPORT.md', 'README.md'))
                $isDevContainer = $file.DirectoryName -like "*.devcontainer*" -and $file.Name -eq 'README.md'
                $isVSCodeReadme = $file.DirectoryName -like "*.vscode*" -and $file.Name -eq 'README.md'

                # Determine if file should have footer
                $shouldHaveFooter = $false
                $footerSeverity = 'Error'  # Default to error if footer is required

                # Set footer requirements for root community files
                if ($isRootCommunityFile) {
                    # All root community files require footers in hve-core
                    $shouldHaveFooter = $true
                    $footerSeverity = 'Error'
                }
                elseif ($isDevContainer) {
                    # DevContainer docs are custom
                    $shouldHaveFooter = $true
                    $footerSeverity = 'Error'
                }
                elseif ($isVSCodeReadme) {
                    # VS Code configuration docs require footers
                    $shouldHaveFooter = $true
                    $footerSeverity = 'Error'
                }
                elseif ($isGitHub) {
                    if ($file.Name -eq 'README.md') {
                        # GitHub subdirectory READMEs should have footers
                        $shouldHaveFooter = $true
                        $footerSeverity = 'Error'
                    }
                    # Chatmodes, instructions, and prompts are excluded from footer validation
                    # (they are internal configuration files, not public documentation)
                }

                # Validate required fields for root community files
                if ($isRootCommunityFile) {
                    $requiredFields = @('title', 'description')
                    $suggestedFields = @('author', 'ms.date')

                    foreach ($field in $requiredFields) {
                        if (-not $frontmatter.Frontmatter.ContainsKey($field)) {
                            $errorMsg = "Missing required field '$field' in: $($file.FullName)"
                            $errors += $errorMsg
                            Write-GitHubAnnotation -Type 'error' -Message "Missing required field '$field'" -File $file.FullName
                        }
                    }

                    foreach ($field in $suggestedFields) {
                        if (-not $frontmatter.Frontmatter.ContainsKey($field)) {
                            $warningMsg = "Suggested field '$field' missing in: $($file.FullName)"
                            $warnings += $warningMsg
                            [void]$filesWithWarnings.Add($file.FullName)
                            Write-GitHubAnnotation -Type 'warning' -Message "Suggested field '$field' missing" -File $file.FullName
                        }
                    }

                    # Validate date format (ISO 8601: YYYY-MM-DD)
                    if ($frontmatter.Frontmatter.ContainsKey('ms.date')) {
                        $date = $frontmatter.Frontmatter['ms.date']
                        if ($date -notmatch '^\d{4}-\d{2}-\d{2}$') {
                            $warningMsg = "Invalid date format in: $($file.FullName). Expected YYYY-MM-DD (ISO 8601), got: $date"
                            $warnings += $warningMsg
                            [void]$filesWithWarnings.Add($file.FullName)
                            Write-GitHubAnnotation -Type 'warning' -Message "Invalid date format: Expected YYYY-MM-DD (ISO 8601), got: $date" -File $file.FullName
                        }
                    }
                }
                # Validate .devcontainer documentation
                elseif ($isDevContainer) {
                    $requiredFields = @('title', 'description')

                    foreach ($field in $requiredFields) {
                        if (-not $frontmatter.Frontmatter.ContainsKey($field)) {
                            $errorMsg = "Missing required field '$field' in: $($file.FullName)"
                            $errors += $errorMsg
                            [void]$filesWithErrors.Add($file.FullName)
                            Write-GitHubAnnotation -Type 'error' -Message "Missing required field '$field'" -File $file.FullName
                        }
                    }
                }
                # Validate .vscode documentation
                elseif ($isVSCodeReadme) {
                    $requiredFields = @('title', 'description')

                    foreach ($field in $requiredFields) {
                        if (-not $frontmatter.Frontmatter.ContainsKey($field)) {
                            $errorMsg = "Missing required field '$field' in: $($file.FullName)"
                            $errors += $errorMsg
                            [void]$filesWithErrors.Add($file.FullName)
                            Write-GitHubAnnotation -Type 'error' -Message "Missing required field '$field'" -File $file.FullName
                        }
                    }
                }

                # GitHub resources have different requirements
                elseif ($isGitHub) {
                    # ChatMode files (.chatmode.md) have specific frontmatter structure
                    if ($isChatMode) {
                        # ChatMode files typically have description, tools, etc. but not standard doc fields
                        # Only warn if missing description as it's commonly used
                        if (-not $frontmatter.Frontmatter.ContainsKey('description')) {
                            $warnings += "ChatMode file missing 'description' field: $($file.FullName)"
                            [void]$filesWithWarnings.Add($file.FullName)
                        }
                    }
                    # Instruction files (.instructions.md) have specific patterns
                    elseif ($isInstruction) {
                        # Instruction files should have 'applyTo' field for context-specific instructions
                        # This is informational only - does not fail validation
                        if (-not $frontmatter.Frontmatter.ContainsKey('applyTo')) {
                            Write-Verbose "Instruction file missing optional 'applyTo' field: $($file.FullName)"
                        }
                        
                        # Validate required description field for instruction files
                        if (-not $frontmatter.Frontmatter.ContainsKey('description')) {
                            $errors += "Instruction file missing required 'description' field: $($file.FullName)"
                            [void]$filesWithErrors.Add($file.FullName)
                            Write-GitHubAnnotation -Type 'error' -Message "Missing required field 'description'" -File $file.FullName
                        }
                    }
                    # Prompt files (.prompt.md) are instructions/templates
                    elseif ($isPrompt) {
                        # Prompt files are typically instruction content, no specific frontmatter required
                        # These are generally freeform content
                    }
                    # Other GitHub files (exclude standard GitHub templates)
                    elseif ($file.Name -like "*template*" -and 
                           -not ($file.Name -in @('PULL_REQUEST_TEMPLATE.md', 'ISSUE_TEMPLATE.md')) -and 
                           -not $frontmatter.Frontmatter.ContainsKey('name')) {
                        $warnings += "GitHub template missing 'name' field: $($file.FullName)"
                        [void]$filesWithWarnings.Add($file.FullName)
                    }
                }

                # Validate keywords array (applies to all content types)
                if ($frontmatter.Frontmatter.ContainsKey('keywords')) {
                    $keywords = $frontmatter.Frontmatter['keywords']
                    if ($keywords -isnot [array] -and $keywords -notmatch ',') {
                        $warnings += "Keywords should be an array in: $($file.FullName)"
                        [void]$filesWithWarnings.Add($file.FullName)
                    }
                }
                # Validate estimated_reading_time if present
                if ($frontmatter.Frontmatter.ContainsKey('estimated_reading_time')) {
                    $readingTime = $frontmatter.Frontmatter['estimated_reading_time']
                    if ($readingTime -notmatch '^\d+$') {
                        $warnings += "Invalid estimated_reading_time format in: $($file.FullName). Should be a number."
                        [void]$filesWithWarnings.Add($file.FullName)
                    }
                }
                
                # Manual validation enforces critical rules (fails builds); schema validation above provides comprehensive advisory feedback (soft mode).
                $isDocsFile = $file.DirectoryName -like "*docs*" -and -not $isGitHubLocal
                if ($isDocsFile) {
                    # Documentation files should have comprehensive frontmatter
                    $requiredDocsFields = @('title', 'description')
                    $suggestedDocsFields = @('author', 'ms.date', 'ms.topic')
                    
                    foreach ($field in $requiredDocsFields) {
                        if (-not $frontmatter.Frontmatter.ContainsKey($field)) {
                            $errors += "Documentation file missing required field '$field' in: $($file.FullName)"
                            [void]$filesWithErrors.Add($file.FullName)
                            Write-GitHubAnnotation -Type 'error' -Message "Missing required field '$field'" -File $file.FullName
                        }
                    }
                    
                    foreach ($field in $suggestedDocsFields) {
                        if (-not $frontmatter.Frontmatter.ContainsKey($field)) {
                            $warnings += "Documentation file missing suggested field '$field' in: $($file.FullName)"
                            [void]$filesWithWarnings.Add($file.FullName)
                            Write-GitHubAnnotation -Type 'warning' -Message "Suggested field '$field' missing" -File $file.FullName
                        }
                    }
                    
                    # Validate date format for docs
                    if ($frontmatter.Frontmatter.ContainsKey('ms.date')) {
                        $date = $frontmatter.Frontmatter['ms.date']
                        if ($date -notmatch '^\d{4}-\d{2}-\d{2}$') {
                            $warnings += "Invalid date format in: $($file.FullName). Expected YYYY-MM-DD (ISO 8601), got: $date"
                            [void]$filesWithWarnings.Add($file.FullName)
                            Write-GitHubAnnotation -Type 'warning' -Message "Invalid date format: Expected YYYY-MM-DD (ISO 8601), got: $date" -File $file.FullName
                        }
                    }
                }

                # Validate footer presence
                if (-not $SkipFooterValidation -and $shouldHaveFooter -and $frontmatter.Content) {
                    $hasFooter = Test-MarkdownFooter -Content $frontmatter.Content
                    
                    if (-not $hasFooter) {
                        $footerMessage = "Missing standard Copilot footer in: $($file.FullName)"
                        
                        if ($footerSeverity -eq 'Error') {
                            $errors += $footerMessage
                            [void]$filesWithErrors.Add($file.FullName)
                            Write-GitHubAnnotation -Type 'error' -Message "Missing standard Copilot footer" -File $file.FullName
                        }
                        else {
                            $warnings += $footerMessage
                            [void]$filesWithWarnings.Add($file.FullName)
                            Write-GitHubAnnotation -Type 'warning' -Message "Missing standard Copilot footer" -File $file.FullName
                        }
                    }
                }
            }
            else {
                # Only warn for main docs, not for GitHub files, prompts, or chatmodes
                $isGitHubLocal = $file.DirectoryName -like "*.github*"
                $isMainDocLocal = ($file.DirectoryName -like "*docs*" -or
                    $file.DirectoryName -like "*scripts*") -and
                -not $isGitHubLocal

                if ($isMainDocLocal) {
                    $warnings += "No frontmatter found in: $($file.FullName)"
                    [void]$filesWithWarnings.Add($file.FullName)
                }
            }
        }
        catch {
            $errors += "Error processing file '$($file.FullName)': $($_.Exception.Message)"
            Write-Verbose "Error processing file '$($file.FullName)': $($_.Exception.Message)"
        }
    }

    # Get repository root for logs directory
    $repoRoot = (Get-Location).Path
    if (-not (Test-Path ".git")) {
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($gitRoot) {
            $repoRoot = $gitRoot
        }
    }

    # Create logs directory and export results
    $logsDir = Join-Path -Path $repoRoot -ChildPath 'logs'
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }

    $resultsJson = @{
        timestamp = (Get-Date).ToUniversalTime().ToString('o')
        script = 'frontmatter-validation'
        summary = @{
            total_files = $markdownFiles.Count
            files_with_errors = $filesWithErrors.Count
            files_with_warnings = $filesWithWarnings.Count
            total_errors = $errors.Count
            total_warnings = $warnings.Count
        }
        errors = $errors
        warnings = $warnings
    }

    $resultsPath = Join-Path -Path $logsDir -ChildPath 'frontmatter-validation-results.json'
    $resultsJson | ConvertTo-Json -Depth 10 | Set-Content -Path $resultsPath -Encoding UTF8

    # Output results
    $hasIssues = $false

    if ($warnings.Count -gt 0) {
        Write-Host "⚠️ Warnings found:" -ForegroundColor Yellow
        $warnings | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
        if ($WarningsAsErrors) {
            $hasIssues = $true
        }
    }

    if ($errors.Count -gt 0) {
        Write-Host "❌ Errors found:" -ForegroundColor Red
        $errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        $hasIssues = $true
    }

    # Generate GitHub step summary
    if ($hasIssues) {
        $summaryContent = @"
## ❌ Frontmatter Validation Failed

**Files checked:** $($markdownFiles.Count)
**Files with errors:** $($resultsJson.summary.files_with_errors)
**Files with warnings:** $($resultsJson.summary.files_with_warnings)
**Total errors:** $($errors.Count)
**Total warnings:** $($warnings.Count)

### Issues Found

"@
        
        if ($errors.Count -gt 0) {
            $summaryContent += "`n#### Errors`n`n"
            foreach ($errorItem in $errors | Select-Object -First 10) {
                $summaryContent += "- ❌ $errorItem`n"
            }
            if ($errors.Count -gt 10) {
                $summaryContent += "`n*... and $($errors.Count - 10) more errors*`n"
            }
        }
        
        if ($warnings.Count -gt 0) {
            $summaryContent += "`n#### Warnings`n`n"
            foreach ($warning in $warnings | Select-Object -First 10) {
                $summaryContent += "- ⚠️ $warning`n"
            }
            if ($warnings.Count -gt 10) {
                $summaryContent += "`n*... and $($warnings.Count - 10) more warnings*`n"
            }
        }
        
        $summaryContent += @"


### How to Fix

1. Review the errors and warnings listed above
2. Update frontmatter fields as required
3. Ensure date formats follow ISO 8601 (YYYY-MM-DD)
4. Add missing Copilot attribution footer where required
5. Re-run validation to verify fixes

See the uploaded artifact for complete details.
"@
        
        Write-GitHubStepSummary -Content $summaryContent
        Set-GitHubEnv -Name "FRONTMATTER_VALIDATION_FAILED" -Value "true"
    }
    else {
        $summaryContent = @"
## ✅ Frontmatter Validation Passed

**Files checked:** $($markdownFiles.Count)
**Errors:** 0
**Warnings:** 0

All frontmatter fields are valid and properly formatted. Great job! 🎉
"@
        
        Write-GitHubStepSummary -Content $summaryContent
        Write-Host "✅ Frontmatter validation completed successfully" -ForegroundColor Green
    }

    return @{
        Errors            = $errors
        Warnings          = $warnings
        HasIssues         = $hasIssues
        TotalFilesChecked = $markdownFiles.Count
    }
}

function Get-ChangedMarkdownFileGroup {
    <#
    .SYNOPSIS
    Gets list of changed markdown files from git diff.

    .DESCRIPTION
    Uses git diff to identify changed markdown files, with fallback strategies for different scenarios.

    .PARAMETER BaseBranch
    The base branch to compare against (default: origin/main).

    .OUTPUTS
    Returns array of file paths for changed markdown files.
    #>
    param(
        [Parameter(Mandatory = $false)]
        [string]$BaseBranch = "origin/main"
    )

    $changedMarkdownFiles = @()

    try {
        # Try to get changed files from the merge base
        $changedFiles = git diff --name-only $(git merge-base HEAD $BaseBranch) HEAD 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Verbose "Merge base failed, trying HEAD~1"
            # Fallback to comparing with HEAD~1 if merge-base fails
            $changedFiles = git diff --name-only HEAD~1 HEAD 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Verbose "HEAD~1 failed, trying staged/unstaged files"
                # Last fallback - get staged and unstaged files
                $changedFiles = git diff --name-only HEAD 2>$null
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Unable to determine changed files from git"
                    return @()
                }
            }
        }

        # Filter for markdown files that exist and are not empty
        $changedMarkdownFiles = $changedFiles | Where-Object {
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

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    if ($ChangedFilesOnly) {
        $result = Test-FrontmatterValidation -ChangedFilesOnly -BaseBranch $BaseBranch -WarningsAsErrors:$WarningsAsErrors -SkipFooterValidation:$SkipFooterValidation -EnableSchemaValidation:$EnableSchemaValidation
    }
    elseif ($Files.Count -gt 0) {
        $result = Test-FrontmatterValidation -Files $Files -WarningsAsErrors:$WarningsAsErrors -SkipFooterValidation:$SkipFooterValidation -EnableSchemaValidation:$EnableSchemaValidation
    }
    else {
        $result = Test-FrontmatterValidation -Paths $Paths -WarningsAsErrors:$WarningsAsErrors -SkipFooterValidation:$SkipFooterValidation -EnableSchemaValidation:$EnableSchemaValidation
    }

    if ($result.HasIssues) {
        exit 1
    }
    else {
        Write-Host "✅ All frontmatter validation checks passed!" -ForegroundColor Green
        exit 0
    }
}
