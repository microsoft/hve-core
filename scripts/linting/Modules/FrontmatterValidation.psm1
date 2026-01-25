<#
.SYNOPSIS
    Frontmatter validation module with pure validation functions.
.DESCRIPTION
    Contains content-type validators and shared helpers for frontmatter validation.
    All functions are pure (no I/O) and return ValidationIssue arrays for testability.
.NOTES
    Author: HVE Core Team
    Created: 2026-01-24
#>

#region Classes

class ValidationIssue {
    [ValidateSet('Error', 'Warning', 'Notice')]
    [string]$Type
    [string]$Field
    [string]$Message
    [string]$FilePath
    [int]$Line

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
    [bool]$IsRootCommunityFile
    [bool]$IsDevContainer
    [bool]$IsVSCodeReadme
    [bool]$IsDocsFile

    FileTypeInfo() {
        $this.IsGitHub = $false
        $this.IsChatMode = $false
        $this.IsPrompt = $false
        $this.IsInstruction = $false
        $this.IsRootCommunityFile = $false
        $this.IsDevContainer = $false
        $this.IsVSCodeReadme = $false
        $this.IsDocsFile = $false
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
        FileTypeInfo object with classification details.
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
        [FileTypeInfo]$FileTypeInfo
    )

    $issues = [System.Collections.Generic.List[ValidationIssue]]::new()

    if ($FileTypeInfo.IsChatMode) {
        if (-not $Frontmatter.ContainsKey('description')) {
            $issues.Add([ValidationIssue]::new('Warning', 'description', "Agent file missing 'description' field", $RelativePath))
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
    # Classification
    'Get-FileTypeInfo'
)

#endregion Exports
