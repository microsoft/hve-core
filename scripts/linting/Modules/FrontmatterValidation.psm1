<#
.SYNOPSIS
    Frontmatter validation module with validation functions and I/O helpers.
.DESCRIPTION
    Contains content-type validators, shared helpers, and output functions
    for frontmatter validation. Returns ValidationIssue arrays for testability.
.NOTES
    Author: HVE Core Team
#>

#region Classes

class ValidationIssue {
    [ValidateSet('Error', 'Warning', 'Notice')]
    [string]$Type = 'Warning'
    [string]$Field
    [string]$Message
    [string]$FilePath
    [int]$Line

    ValidationIssue() {
        $this.Type = 'Warning'
        $this.Line = 0
    }

    ValidationIssue([string]$type, [string]$field, [string]$message, [string]$filePath) {
        $this.Type = $type
        $this.Field = $field
        $this.Message = $message
        $this.FilePath = $filePath
        $this.Line = 0
    }

    ValidationIssue([string]$type, [string]$field, [string]$message, [string]$filePath, [int]$line) {
        $this.Type = $type
        $this.Field = $field
        $this.Message = $message
        $this.FilePath = $filePath
        $this.Line = $line
    }
}

class FileTypeInfo {
    [bool]$IsGitHub
    [bool]$IsChatMode
    [bool]$IsPrompt
    [bool]$IsInstruction
    [bool]$IsAgent
    [bool]$IsRootCommunityFile
    [bool]$IsDevContainer
    [bool]$IsVSCodeReadme
    [bool]$IsDocsFile

    FileTypeInfo() {
        $this.IsGitHub = $false
        $this.IsChatMode = $false
        $this.IsPrompt = $false
        $this.IsInstruction = $false
        $this.IsAgent = $false
        $this.IsRootCommunityFile = $false
        $this.IsDevContainer = $false
        $this.IsVSCodeReadme = $false
        $this.IsDocsFile = $false
    }
}

class FileValidationResult {
    [ValidateNotNullOrEmpty()]
    [string]$FilePath

    [string]$RelativePath
    [bool]$HasFrontmatter
    [hashtable]$Frontmatter
    [FileTypeInfo]$FileType
    [System.Collections.Generic.List[ValidationIssue]]$Issues
    [datetime]$ValidatedAt

    FileValidationResult([string]$filePath) {
        $this.FilePath = $filePath
        $this.RelativePath = $filePath
        $this.Issues = [System.Collections.Generic.List[ValidationIssue]]::new()
        $this.ValidatedAt = [datetime]::UtcNow
    }

    [bool] HasErrors() {
        return ($this.Issues | Where-Object Type -eq 'Error').Count -gt 0
    }

    [bool] HasWarnings() {
        return ($this.Issues | Where-Object Type -eq 'Warning').Count -gt 0
    }

    [bool] IsValid() {
        return -not $this.HasErrors()
    }

    [int] ErrorCount() {
        return ($this.Issues | Where-Object Type -eq 'Error').Count
    }

    [int] WarningCount() {
        return ($this.Issues | Where-Object Type -eq 'Warning').Count
    }

    [void] AddIssue([ValidationIssue]$issue) {
        $this.Issues.Add($issue)
    }

    [void] AddError([string]$message, [string]$field) {
        $this.AddError($message, $field, 0)
    }

    [void] AddError([string]$message, [string]$field, [int]$line) {
        $issue = [ValidationIssue]::new()
        $issue.Type = 'Error'
        $issue.Message = $message
        $issue.Field = $field
        $issue.FilePath = $this.FilePath
        $issue.Line = $line
        $this.Issues.Add($issue)
    }

    [void] AddWarning([string]$message, [string]$field) {
        $this.AddWarning($message, $field, 0)
    }

    [void] AddWarning([string]$message, [string]$field, [int]$line) {
        $issue = [ValidationIssue]::new()
        $issue.Type = 'Warning'
        $issue.Message = $message
        $issue.Field = $field
        $issue.FilePath = $this.FilePath
        $issue.Line = $line
        $this.Issues.Add($issue)
    }
}

class ValidationSummary {
    [int]$TotalFiles
    [int]$FilesWithErrors
    [int]$FilesWithWarnings
    [int]$FilesValid
    [int]$TotalErrors
    [int]$TotalWarnings
    [System.Collections.ArrayList]$Results
    [datetime]$StartedAt
    [datetime]$CompletedAt
    [timespan]$Duration

    ValidationSummary() {
        $this.Results = [System.Collections.ArrayList]::new()
        $this.StartedAt = [datetime]::UtcNow
    }

    # Type constraint removed for testability (PowerShell class identity conflicts)
    [void] AddResult($result) {
        $this.Results.Add($result)
        $this.TotalFiles++

        if ($result.HasErrors()) {
            $this.FilesWithErrors++
            $this.TotalErrors += $result.ErrorCount()
        }
        if ($result.HasWarnings()) {
            $this.FilesWithWarnings++
            $this.TotalWarnings += $result.WarningCount()
        }
        if ($result.IsValid() -and -not $result.HasWarnings()) {
            $this.FilesValid++
        }
    }

    [void] Complete() {
        $this.CompletedAt = [datetime]::UtcNow
        $this.Duration = $this.CompletedAt - $this.StartedAt
    }

    [bool] Passed([bool]$warningsAsErrors) {
        if ($this.TotalErrors -gt 0) { return $false }
        if ($warningsAsErrors -and $this.TotalWarnings -gt 0) { return $false }
        return $true
    }

    [int] GetExitCode([bool]$warningsAsErrors) {
        # Exit code 2 indicates no files were validated (distinct from validation errors)
        if ($this.TotalFiles -eq 0) { return 2 }
        if ($this.Passed($warningsAsErrors)) { return 0 } else { return 1 }
    }

    [hashtable] ToHashtable() {
        return @{
            totalFiles        = $this.TotalFiles
            filesWithErrors   = $this.FilesWithErrors
            filesWithWarnings = $this.FilesWithWarnings
            filesValid        = $this.FilesValid
            totalErrors       = $this.TotalErrors
            totalWarnings     = $this.TotalWarnings
            duration          = $this.Duration.TotalSeconds
            results           = [object[]]($this.Results | ForEach-Object {
                @{
                    filePath     = $_.RelativePath
                    isValid      = $_.IsValid()
                    errorCount   = $_.ErrorCount()
                    warningCount = $_.WarningCount()
                    issues       = [object[]]($_.Issues | ForEach-Object {
                        @{
                            type    = $_.Type
                            message = $_.Message
                            field   = $_.Field
                            line    = $_.Line
                        }
                    })
                }
            })
        }
    }
}

#endregion Classes

#region Shared Helpers

function Test-RequiredField {
    <#
    .SYNOPSIS
        Validates that a required field exists and is not empty.
    .DESCRIPTION
        Pure validation helper that checks for field presence and non-empty value.
        Returns a ValidationIssue if the field is missing or empty.
    .PARAMETER Frontmatter
        Hashtable containing parsed frontmatter fields.
    .PARAMETER FieldName
        Name of the required field to check.
    .PARAMETER RelativePath
        Relative path to the file being validated.
    .PARAMETER Severity
        Issue severity: 'Error' or 'Warning'. Default: 'Error'.
    .OUTPUTS
        ValidationIssue or $null if field is valid.
    #>
    [CmdletBinding()]
    [OutputType([ValidationIssue])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Frontmatter,

        [Parameter(Mandatory)]
        [string]$FieldName,

        [Parameter(Mandatory)]
        [string]$RelativePath,

        [Parameter()]
        [ValidateSet('Error', 'Warning')]
        [string]$Severity = 'Error'
    )

    if (-not $Frontmatter.ContainsKey($FieldName) -or [string]::IsNullOrWhiteSpace($Frontmatter[$FieldName])) {
        return [ValidationIssue]::new($Severity, $FieldName, "Missing required field: $FieldName", $RelativePath)
    }

    return $null
}

function Test-DateFormat {
    <#
    .SYNOPSIS
        Validates date format is ISO 8601 (YYYY-MM-DD) or placeholder.
    .DESCRIPTION
        Pure validation helper that checks date format compliance.
        Accepts ISO 8601 format or placeholder syntax (YYYY-MM-dd).
    .PARAMETER Frontmatter
        Hashtable containing parsed frontmatter fields.
    .PARAMETER FieldName
        Name of the date field to check. Default: 'ms.date'.
    .PARAMETER RelativePath
        Relative path to the file being validated.
    .OUTPUTS
        ValidationIssue or $null if format is valid or field not present.
    #>
    [CmdletBinding()]
    [OutputType([ValidationIssue])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Frontmatter,

        [Parameter()]
        [string]$FieldName = 'ms.date',

        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    if (-not $Frontmatter.ContainsKey($FieldName)) {
        return $null
    }

    $date = $Frontmatter[$FieldName]
    if ($date -notmatch '^(\d{4}-\d{2}-\d{2}|\(YYYY-MM-dd\))$') {
        return [ValidationIssue]::new('Warning', $FieldName, "Invalid date format: Expected YYYY-MM-DD, got: $date", $RelativePath)
    }

    return $null
}

function Test-SuggestedFields {
    <#
    .SYNOPSIS
        Validates presence of suggested (optional but recommended) fields.
    .DESCRIPTION
        Pure validation helper that checks for suggested field presence.
        Returns warnings for missing suggested fields.
    .PARAMETER Frontmatter
        Hashtable containing parsed frontmatter fields.
    .PARAMETER FieldNames
        Array of suggested field names to check.
    .PARAMETER RelativePath
        Relative path to the file being validated.
    .OUTPUTS
        ValidationIssue[] Array of warnings for missing fields.
    #>
    [CmdletBinding()]
    [OutputType([ValidationIssue[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Frontmatter,

        [Parameter(Mandatory)]
        [string[]]$FieldNames,

        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    $issues = [System.Collections.Generic.List[ValidationIssue]]::new()

    foreach ($field in $FieldNames) {
        if (-not $Frontmatter.ContainsKey($field)) {
            $issues.Add([ValidationIssue]::new('Warning', $field, "Suggested field '$field' missing", $RelativePath))
        }
    }

    return , $issues.ToArray()
}

function Test-TopicValue {
    <#
    .SYNOPSIS
        Validates ms.topic field value against allowed values.
    .DESCRIPTION
        Pure validation helper that checks topic value is one of the allowed types.
    .PARAMETER Frontmatter
        Hashtable containing parsed frontmatter fields.
    .PARAMETER RelativePath
        Relative path to the file being validated.
    .OUTPUTS
        ValidationIssue or $null if valid or not present.
    #>
    [CmdletBinding()]
    [OutputType([ValidationIssue])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Frontmatter,

        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    if (-not $Frontmatter.ContainsKey('ms.topic')) {
        return $null
    }

    $validTopics = @('overview', 'concept', 'tutorial', 'reference', 'how-to', 'troubleshooting')
    $topicValue = $Frontmatter['ms.topic']

    if ($topicValue -notin $validTopics) {
        return [ValidationIssue]::new('Warning', 'ms.topic', "Unknown topic type: '$topicValue'. Expected one of: $($validTopics -join ', ')", $RelativePath)
    }

    return $null
}

#endregion Shared Helpers

#region Content-Type Validators

function Test-RootCommunityFileFields {
    <#
    .SYNOPSIS
        Validates frontmatter fields for root community files.
    .DESCRIPTION
        Pure validation for README.md, CONTRIBUTING.md, CODE_OF_CONDUCT.md,
        SECURITY.md, SUPPORT.md in repository root.
    .PARAMETER Frontmatter
        Hashtable containing parsed frontmatter fields.
    .PARAMETER RelativePath
        Relative path to the file being validated.
    .OUTPUTS
        ValidationIssue[] Array of validation issues found.
    #>
    [CmdletBinding()]
    [OutputType([ValidationIssue[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Frontmatter,

        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    $issues = [System.Collections.Generic.List[ValidationIssue]]::new()

    # Required fields
    $titleIssue = Test-RequiredField -Frontmatter $Frontmatter -FieldName 'title' -RelativePath $RelativePath
    if ($titleIssue) { $issues.Add($titleIssue) }

    $descIssue = Test-RequiredField -Frontmatter $Frontmatter -FieldName 'description' -RelativePath $RelativePath
    if ($descIssue) { $issues.Add($descIssue) }

    # Suggested fields
    $suggestedIssues = Test-SuggestedFields -Frontmatter $Frontmatter -FieldNames @('author', 'ms.date') -RelativePath $RelativePath
    $issues.AddRange($suggestedIssues)

    # Date format
    $dateIssue = Test-DateFormat -Frontmatter $Frontmatter -RelativePath $RelativePath
    if ($dateIssue) { $issues.Add($dateIssue) }

    return , $issues.ToArray()
}

function Test-DevContainerFileFields {
    <#
    .SYNOPSIS
        Validates frontmatter fields for devcontainer documentation.
    .DESCRIPTION
        Pure validation for .devcontainer/ markdown files.
    .PARAMETER Frontmatter
        Hashtable containing parsed frontmatter fields.
    .PARAMETER RelativePath
        Relative path to the file being validated.
    .OUTPUTS
        ValidationIssue[] Array of validation issues found.
    #>
    [CmdletBinding()]
    [OutputType([ValidationIssue[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Frontmatter,

        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    $issues = [System.Collections.Generic.List[ValidationIssue]]::new()

    $titleIssue = Test-RequiredField -Frontmatter $Frontmatter -FieldName 'title' -RelativePath $RelativePath
    if ($titleIssue) { $issues.Add($titleIssue) }

    $descIssue = Test-RequiredField -Frontmatter $Frontmatter -FieldName 'description' -RelativePath $RelativePath
    if ($descIssue) { $issues.Add($descIssue) }

    return , $issues.ToArray()
}

function Test-VSCodeReadmeFileFields {
    <#
    .SYNOPSIS
        Validates frontmatter fields for VS Code extension README files.
    .DESCRIPTION
        Pure validation for extension/ README.md files.
    .PARAMETER Frontmatter
        Hashtable containing parsed frontmatter fields.
    .PARAMETER RelativePath
        Relative path to the file being validated.
    .OUTPUTS
        ValidationIssue[] Array of validation issues found.
    #>
    [CmdletBinding()]
    [OutputType([ValidationIssue[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Frontmatter,

        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    $issues = [System.Collections.Generic.List[ValidationIssue]]::new()

    $titleIssue = Test-RequiredField -Frontmatter $Frontmatter -FieldName 'title' -RelativePath $RelativePath
    if ($titleIssue) { $issues.Add($titleIssue) }

    $descIssue = Test-RequiredField -Frontmatter $Frontmatter -FieldName 'description' -RelativePath $RelativePath
    if ($descIssue) { $issues.Add($descIssue) }

    return , $issues.ToArray()
}

function Test-GitHubResourceFileFields {
    <#
    .SYNOPSIS
        Validates frontmatter fields for .github/ resource files.
    .DESCRIPTION
        Pure validation for instructions, prompts, agents, and skills.
    .PARAMETER Frontmatter
        Hashtable containing parsed frontmatter fields.
    .PARAMETER RelativePath
        Relative path to the file being validated.
    .PARAMETER FileTypeInfo
        FileTypeInfo object with classification details. Type constraint removed
        to avoid PowerShell class identity conflicts in tests.
    .OUTPUTS
        ValidationIssue[] Array of validation issues found.
    #>
    [CmdletBinding()]
    [OutputType([ValidationIssue[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Frontmatter,

        [Parameter(Mandatory)]
        [string]$RelativePath,

        [Parameter(Mandatory)]
        $FileTypeInfo
    )

    $issues = [System.Collections.Generic.List[ValidationIssue]]::new()

    if ($FileTypeInfo.IsAgent -or $FileTypeInfo.IsChatMode) {
        if (-not $Frontmatter.ContainsKey('description')) {
            $issues.Add([ValidationIssue]::new('Warning', 'description', "Chat or agent file missing 'description' field", $RelativePath))
        }
    }
    elseif ($FileTypeInfo.IsInstruction) {
        $descIssue = Test-RequiredField -Frontmatter $Frontmatter -FieldName 'description' -RelativePath $RelativePath
        if ($descIssue) {
            $descIssue.Message = "Instruction file missing required 'description' field"
            $issues.Add($descIssue)
        }
    }
    # Prompt files have no specific requirements

    return , $issues.ToArray()
}

function Test-DocsFileFields {
    <#
    .SYNOPSIS
        Validates frontmatter fields for docs/ directory files.
    .DESCRIPTION
        Pure validation for documentation files with comprehensive requirements.
    .PARAMETER Frontmatter
        Hashtable containing parsed frontmatter fields.
    .PARAMETER RelativePath
        Relative path to the file being validated.
    .OUTPUTS
        ValidationIssue[] Array of validation issues found.
    #>
    [CmdletBinding()]
    [OutputType([ValidationIssue[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Frontmatter,

        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    $issues = [System.Collections.Generic.List[ValidationIssue]]::new()

    # Required fields
    $titleIssue = Test-RequiredField -Frontmatter $Frontmatter -FieldName 'title' -RelativePath $RelativePath
    if ($titleIssue) { $issues.Add($titleIssue) }

    $descIssue = Test-RequiredField -Frontmatter $Frontmatter -FieldName 'description' -RelativePath $RelativePath
    if ($descIssue) { $issues.Add($descIssue) }

    # Suggested fields
    $suggestedIssues = Test-SuggestedFields -Frontmatter $Frontmatter -FieldNames @('author', 'ms.date', 'ms.topic') -RelativePath $RelativePath
    $issues.AddRange($suggestedIssues)

    # Date format
    $dateIssue = Test-DateFormat -Frontmatter $Frontmatter -RelativePath $RelativePath
    if ($dateIssue) { $issues.Add($dateIssue) }

    # Topic value
    $topicIssue = Test-TopicValue -Frontmatter $Frontmatter -RelativePath $RelativePath
    if ($topicIssue) { $issues.Add($topicIssue) }

    return , $issues.ToArray()
}

function Test-CommonFields {
    <#
    .SYNOPSIS
        Validates common frontmatter fields for all content types.
    .DESCRIPTION
        Pure validation for fields like keywords and estimated_reading_time.
    .PARAMETER Frontmatter
        Hashtable containing parsed frontmatter fields.
    .PARAMETER RelativePath
        Relative path to the file being validated.
    .OUTPUTS
        ValidationIssue[] Array of validation issues found.
    #>
    [CmdletBinding()]
    [OutputType([ValidationIssue[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Frontmatter,

        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    $issues = [System.Collections.Generic.List[ValidationIssue]]::new()

    # Validate keywords array
    if ($Frontmatter.ContainsKey('keywords')) {
        $keywords = $Frontmatter['keywords']
        if ($keywords -isnot [array] -and $keywords -notmatch ',') {
            $issues.Add([ValidationIssue]::new('Warning', 'keywords', 'Keywords should be an array', $RelativePath))
        }
    }

    # Validate estimated_reading_time
    if ($Frontmatter.ContainsKey('estimated_reading_time')) {
        $readingTime = $Frontmatter['estimated_reading_time']
        if ($readingTime -notmatch '^\d+$') {
            $issues.Add([ValidationIssue]::new('Warning', 'estimated_reading_time', 'Should be a positive integer', $RelativePath))
        }
    }

    return , $issues.ToArray()
}

function Test-FooterPresence {
    <#
    .SYNOPSIS
        Validates Copilot attribution footer presence.
    .DESCRIPTION
        Pure validation wrapper for footer check.
    .PARAMETER HasFooter
        Boolean result from Test-MarkdownFooter.
    .PARAMETER RelativePath
        Relative path to the file being validated.
    .PARAMETER Severity
        Issue severity: 'Error' or 'Warning'. Default: 'Error'.
    .OUTPUTS
        ValidationIssue or $null if footer is present.
    #>
    [CmdletBinding()]
    [OutputType([ValidationIssue])]
    param(
        [Parameter(Mandatory)]
        [bool]$HasFooter,

        [Parameter(Mandatory)]
        [string]$RelativePath,

        [Parameter()]
        [ValidateSet('Error', 'Warning')]
        [string]$Severity = 'Error'
    )

    if (-not $HasFooter) {
        return [ValidationIssue]::new($Severity, 'footer', 'Missing standard Copilot footer', $RelativePath)
    }

    return $null
}

function Test-MarkdownFooter {
    <#
    .SYNOPSIS
        Checks if markdown content contains the standard Copilot attribution footer.
    .DESCRIPTION
        Pure function that validates markdown content ends with the standard Copilot
        attribution footer. Normalizes content by removing HTML comments and markdown
        formatting before pattern matching.
    .PARAMETER Content
        The markdown content string to validate.
    .OUTPUTS
        [bool] $true if valid footer present; $false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Content
    )

    process {
        if ([string]::IsNullOrEmpty($Content)) {
            return $false
        }

        $normalized = $Content -replace '(?s)<!--.*?-->', ''
        $normalized = $normalized -replace '\*\*([^*]+)\*\*', '$1'
        $normalized = $normalized -replace '__([^_]+)__', '$1'
        $normalized = $normalized -replace '\*([^*]+)\*', '$1'
        $normalized = $normalized -replace '_([^_]+)_', '$1'
        $normalized = $normalized -replace '~~([^~]+)~~', '$1'
        $normalized = $normalized -replace '`([^`]+)`', '$1'
        $normalized = $normalized.TrimEnd()

        $pattern = '🤖\s*Crafted\s+with\s+precision\s+by\s+✨Copilot\s+following\s+brilliant\s+human\s+instruction[,\s]+(then\s+)?carefully\s+refined\s+by\s+our\s+team\s+of\s+discerning\s+human\s+reviewers\.?'

        return $normalized -match $pattern
    }
}

#endregion Content-Type Validators

#region File Classification

function Get-FileTypeInfo {
    <#
    .SYNOPSIS
        Classifies a file based on its path and name.
    .DESCRIPTION
        Pure function that determines file type for validation routing.
    .PARAMETER File
        FileInfo object to classify.
    .PARAMETER RepoRoot
        Repository root path for relative path computation.
    .OUTPUTS
        FileTypeInfo object with classification flags.
    #>
    [CmdletBinding()]
    [OutputType([FileTypeInfo])]
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    $info = [FileTypeInfo]::new()
    $info.IsGitHub = $File.DirectoryName -like "*.github*"
    $info.IsChatMode = $File.Name -like "*.chatmode.md"
    $info.IsPrompt = $File.Name -like "*.prompt.md"
    $info.IsInstruction = $File.Name -like "*.instructions.md"
    $info.IsAgent = $File.Name -like "*.agent.md"
    $info.IsRootCommunityFile = ($File.DirectoryName -eq $RepoRoot) -and
        ($File.Name -in @('CODE_OF_CONDUCT.md', 'CONTRIBUTING.md', 'SECURITY.md', 'SUPPORT.md', 'README.md'))
    $info.IsDevContainer = $File.DirectoryName -like "*.devcontainer*" -and $File.Name -eq 'README.md'
    $info.IsVSCodeReadme = $File.DirectoryName -like "*.vscode*" -and $File.Name -eq 'README.md'
    # Exclude .copilot-tracking and templates from docs validation
    $isCopilotTracking = $File.DirectoryName -like "*.copilot-tracking*"
    $isTemplate = $File.Name -like "*TEMPLATE*"
    $info.IsDocsFile = $File.DirectoryName -like "*docs*" -and -not $info.IsGitHub -and -not $isCopilotTracking -and -not $isTemplate

    return $info
}

#endregion File Classification

#region Orchestration

function Test-SingleFileFrontmatter {
    <#
    .SYNOPSIS
        Validates frontmatter for a single markdown file.
    .DESCRIPTION
        Performs complete frontmatter validation including presence check,
        YAML parsing, file type detection, field validation, and footer check.
    .PARAMETER FilePath
        Absolute path to the markdown file.
    .PARAMETER RepoRoot
        Repository root path for relative path computation and file classification.
    .PARAMETER FileReader
        Optional scriptblock for reading file content. Enables testing.
    .OUTPUTS
        FileValidationResult
    #>
    [CmdletBinding()]
    [OutputType([FileValidationResult])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [scriptblock]$FileReader = { param($p) Get-Content -Path $p -Raw -ErrorAction Stop },

        [switch]$SkipFooterValidation
    )

    $relativePath = $FilePath
    if ($FilePath.StartsWith($RepoRoot)) {
        $relativePath = $FilePath.Substring($RepoRoot.Length).TrimStart('\', '/')
    }

    $result = [FileValidationResult]::new($FilePath)
    $result.RelativePath = $relativePath

    # Detect file type early - needed for frontmatter requirement decisions
    $fileInfo = [System.IO.FileInfo]::new($FilePath)
    $result.FileType = Get-FileTypeInfo -File $fileInfo -RepoRoot $RepoRoot
    $fileTypeInfo = $result.FileType

    # AI artifacts (prompts, instructions, agents, chatmodes) don't require frontmatter
    $isAiArtifact = $fileTypeInfo.IsPrompt -or $fileTypeInfo.IsInstruction -or $fileTypeInfo.IsAgent -or $fileTypeInfo.IsChatMode

    # Read file content
    try {
        $content = & $FileReader $FilePath
    }
    catch {
        $result.AddError("Failed to read file: $($_.Exception.Message)", 'file')
        return $result
    }

    # Parse frontmatter
    $frontmatter = $null
    $hasFrontmatterBlock = $content -match '(?s)^---\r?\n(.*?)\r?\n---'
    if ($hasFrontmatterBlock) {
        $yamlBlock = $Matches[1]

        # Verify ConvertFrom-Yaml is available (requires powershell-yaml module)
        if (-not (Get-Command -Name 'ConvertFrom-Yaml' -ErrorAction SilentlyContinue)) {
            $result.AddError("ConvertFrom-Yaml cmdlet not found. Install powershell-yaml module: Install-Module -Name PowerShell-Yaml -Force -Scope CurrentUser", 'dependency')
            return $result
        }

        try {
            $frontmatter = $yamlBlock | ConvertFrom-Yaml -ErrorAction Stop
        }
        catch {
            $result.AddError("Invalid YAML syntax: $($_.Exception.Message)", 'yaml')
            return $result
        }
    }

    $result.HasFrontmatter = $null -ne $frontmatter
    $result.Frontmatter = $frontmatter

    # Only warn about missing frontmatter for content types that require it
    # AI artifacts (.github prompts, instructions, agents, chatmodes) are exempt
    if (-not $result.HasFrontmatter -and -not $isAiArtifact) {
        $result.AddWarning('No frontmatter found', 'frontmatter')
        # Continue to footer validation even without frontmatter
    }

    # Validate fields based on file type (only if frontmatter was successfully parsed)
    $issues = @()

    if ($null -ne $frontmatter) {
        if ($fileTypeInfo.IsDocsFile) {
            $issues = Test-DocsFileFields -Frontmatter $frontmatter -RelativePath $relativePath
        }
        elseif ($fileTypeInfo.IsInstruction -or $fileTypeInfo.IsPrompt -or $fileTypeInfo.IsChatMode -or $fileTypeInfo.IsAgent) {
            $issues = Test-GitHubResourceFileFields -Frontmatter $frontmatter -FileTypeInfo $fileTypeInfo -RelativePath $relativePath
        }
        elseif ($fileTypeInfo.IsDevContainer) {
            $issues = Test-DevContainerFileFields -Frontmatter $frontmatter -RelativePath $relativePath
        }
        elseif ($fileTypeInfo.IsVSCodeReadme) {
            $issues = Test-VSCodeReadmeFileFields -Frontmatter $frontmatter -RelativePath $relativePath
        }
        elseif ($fileTypeInfo.IsRootCommunityFile) {
            $issues = Test-RootCommunityFileFields -Frontmatter $frontmatter -RelativePath $relativePath
        }

        foreach ($issue in $issues) {
            $result.AddIssue($issue)
        }
    }

    # Common field validation for all content types with frontmatter
    if ($null -ne $frontmatter) {
        $commonIssues = Test-CommonFields -Frontmatter $frontmatter -RelativePath $relativePath
        foreach ($commonIssue in $commonIssues) {
            $result.AddIssue($commonIssue)
        }
    }

    # Footer validation for all markdown EXCEPT AI artifacts (prompts, instructions, agents, chatmodes)
    if (-not $isAiArtifact -and -not $SkipFooterValidation) {
        # Determine severity based on file type
        $footerSeverity = 'Warning'
        if ($fileTypeInfo.IsRootCommunityFile -or $fileTypeInfo.IsDevContainer -or $fileTypeInfo.IsVSCodeReadme) {
            $footerSeverity = 'Error'
        }

        $hasFooter = Test-MarkdownFooter -Content $content
        $footerIssue = Test-FooterPresence -HasFooter $hasFooter -RelativePath $relativePath -Severity $footerSeverity
        if ($footerIssue) {
            $result.AddIssue($footerIssue)
        }
    }

    return $result
}

function Invoke-FrontmatterValidation {
    <#
    .SYNOPSIS
        Validates frontmatter across multiple markdown files.

    .DESCRIPTION
        Orchestrates validation of multiple files and aggregates results
        into a ValidationSummary object.

    .PARAMETER Files
        Array of file paths to validate.

    .PARAMETER RepoRoot
        Repository root path for relative path computation and file classification.

    .OUTPUTS
        ValidationSummary
    #>
    [CmdletBinding()]
    [OutputType([ValidationSummary])]
    param(
        [Parameter(Mandatory)]
        [string[]]$Files,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [switch]$SkipFooterValidation
    )

    $summary = [ValidationSummary]::new()

    foreach ($file in $Files) {
        $result = Test-SingleFileFrontmatter -FilePath $file -RepoRoot $RepoRoot -SkipFooterValidation:$SkipFooterValidation
        $summary.AddResult($result)
    }

    $summary.Complete()
    return $summary
}

#endregion Orchestration

#region Output

function Write-ValidationConsoleOutput {
    <#
    .SYNOPSIS
        Writes validation results to console.

    .PARAMETER Summary
        ValidationSummary object to display.

    .PARAMETER ShowDetails
        When true, shows per-file details.
    #>
    [CmdletBinding()]
    param(
        # Type constraint removed for testability (PowerShell class identity conflicts)
        [Parameter(Mandatory)]
        $Summary,

        [switch]$ShowDetails
    )

    Write-Host "`n🔍 Frontmatter Validation Results" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────" -ForegroundColor DarkGray

    if ($ShowDetails) {
        foreach ($result in $Summary.Results) {
            $hasError = $result.Issues | Where-Object { $_.Type -eq 'Error' } | Select-Object -First 1
            $hasWarning = $result.Issues | Where-Object { $_.Type -eq 'Warning' } | Select-Object -First 1
            $icon = if ($hasError) { '❌' } elseif ($hasWarning) { '⚠️' } else { '✅' }
            Write-Host "$icon $($result.RelativePath)"

            foreach ($issue in $result.Issues) {
                $color = if ($issue.Type -eq 'Error') { 'Red' } else { 'Yellow' }
                $prefix = if ($issue.Type -eq 'Error') { '  ❌' } else { '  ⚠️' }
                Write-Host "$prefix $($issue.Message)" -ForegroundColor $color
            }
        }
        Write-Host ""
    }

    # Summary
    Write-Host "📊 Summary:" -ForegroundColor Cyan
    $errorColor = if ($Summary.FilesWithErrors -gt 0) { 'Red' } else { 'Green' }
    $warnColor = if ($Summary.FilesWithWarnings -gt 0) { 'Yellow' } else { 'Green' }

    Write-Host "   Files validated: $($Summary.TotalFiles)"
    Write-Host "   Files with errors: $($Summary.FilesWithErrors)" -ForegroundColor $errorColor
    Write-Host "   Files with warnings: $($Summary.FilesWithWarnings)" -ForegroundColor $warnColor
    Write-Host "   Duration: $($Summary.Duration.TotalSeconds.ToString('F2'))s"
}

function Write-GitHubAnnotations {
    <#
    .SYNOPSIS
        Outputs GitHub Actions annotations for validation issues.

    .PARAMETER Summary
        ValidationSummary object containing results.
    #>
    [CmdletBinding()]
    param(
        # Type constraint removed for testability (PowerShell class identity conflicts)
        [Parameter(Mandatory)]
        $Summary
    )

    # Convert message text to GitHub workflow command safe format (%, CR, LF, ::)
    function ConvertTo-GitHubCommandMessage {
        param([string]$Text)
        if ($null -eq $Text) { return '' }
        $escaped = $Text -replace '%', '%25'
        $escaped = $escaped -replace "`r", '%0D'
        $escaped = $escaped -replace "`n", '%0A'
        $escaped = $escaped -replace '::', '%3A%3A'
        return $escaped
    }

    # Convert property text to GitHub workflow command safe format (%, CR, LF, :, ,)
    function ConvertTo-GitHubCommandProperty {
        param([string]$Text)
        if ($null -eq $Text) { return '' }
        $escaped = $Text -replace '%', '%25'
        $escaped = $escaped -replace "`r", '%0D'
        $escaped = $escaped -replace "`n", '%0A'
        $escaped = $escaped -replace ':', '%3A'
        $escaped = $escaped -replace ',', '%2C'
        return $escaped
    }

    foreach ($result in $Summary.Results) {
        foreach ($issue in $result.Issues) {
            $type = if ($issue.Type -eq 'Error') { 'error' } else { 'warning' }
            $line = if ($issue.Line) { $issue.Line } else { 1 }

            $escapedFile = ConvertTo-GitHubCommandProperty -Text ([string]$result.RelativePath)
            $escapedLine = ConvertTo-GitHubCommandProperty -Text ([string]$line)
            $escapedMessage = ConvertTo-GitHubCommandMessage -Text ([string]$issue.Message)

            Write-Output "::$type file=$escapedFile,line=$escapedLine::$escapedMessage"
        }
    }
}

function Export-ValidationResults {
    <#
    .SYNOPSIS
        Exports validation results to JSON file.

    .PARAMETER Summary
        ValidationSummary object to export.

    .PARAMETER OutputPath
        Path to output JSON file.
    #>
    [CmdletBinding()]
    param(
        # Type constraint removed for testability (PowerShell class identity conflicts)
        [Parameter(Mandatory)]
        $Summary,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $outputDir = Split-Path -Path $OutputPath -Parent
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    $Summary.ToHashtable() | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding utf8
}

#endregion Output

#region Exports

Export-ModuleMember -Function @(
    # Shared helpers
    'Test-RequiredField'
    'Test-DateFormat'
    'Test-SuggestedFields'
    'Test-TopicValue'
    # Content-type validators
    'Test-RootCommunityFileFields'
    'Test-DevContainerFileFields'
    'Test-VSCodeReadmeFileFields'
    'Test-GitHubResourceFileFields'
    'Test-DocsFileFields'
    'Test-CommonFields'
    'Test-FooterPresence'
    'Test-MarkdownFooter'
    # Classification
    'Get-FileTypeInfo'
    # Orchestration
    'Test-SingleFileFrontmatter'
    'Invoke-FrontmatterValidation'
    # Output
    'Write-ValidationConsoleOutput'
    'Write-GitHubAnnotations'
    'Export-ValidationResults'
)

#endregion Exports
