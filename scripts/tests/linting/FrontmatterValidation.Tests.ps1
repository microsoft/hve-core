<#
.SYNOPSIS
    Unit tests for FrontmatterValidation.psm1 module.
.DESCRIPTION
    Tests pure validation functions extracted for testability.
    Covers ValidationIssue class, shared helpers, and content-type validators.
#>

# Use 'using module' to access class types (must be before any other code)
using module ..\..\linting\Modules\FrontmatterValidation.psm1

BeforeAll {
    # Import the module under test
    $script:ModulePath = Join-Path $PSScriptRoot '..\..\linting\Modules\FrontmatterValidation.psm1'
    Import-Module $script:ModulePath -Force
    
    # Get module reference for class instantiation in module scope
    # This avoids parse-time caching issues with 'using module'
    $script:FVModule = Get-Module FrontmatterValidation
    
    # Helper functions for new classes (instantiate in module scope)
    function script:New-FileValidationResult {
        param([string]$FilePath)
        & $script:FVModule { param($fp) [FileValidationResult]::new($fp) } $FilePath
    }
    
    function script:New-ValidationSummary {
        & $script:FVModule { [ValidationSummary]::new() }
    }

    function script:New-ValidationIssue {
        param(
            [string]$Type = 'Warning',
            [string]$Field = '',
            [string]$Message = 'Test message',
            [string]$FilePath = 'test.md'
        )
        & $script:FVModule {
            param($t, $f, $m, $fp)
            [ValidationIssue]::new($t, $f, $m, $fp)
        } $Type $Field $Message $FilePath
    }

    function script:New-ValidationIssueEmpty {
        & $script:FVModule { [ValidationIssue]::new() }
    }
    
    function script:New-FileTypeInfo {
        param([hashtable]$Properties)
        & $script:FVModule {
            param($props)
            $info = [FileTypeInfo]::new()
            foreach ($key in $props.Keys) {
                $info.$key = $props[$key]
            }
            $info
        } $Properties
    }
}

AfterAll {
    Remove-Module FrontmatterValidation -ErrorAction SilentlyContinue
}

#region ValidationIssue Class Tests

Describe 'ValidationIssue Class' -Tag 'Unit' {
    Context 'Constructor with all parameters' {
        It 'Creates instance with Type, Field, Message, FilePath' {
            $issue = [ValidationIssue]::new('Error', 'title', 'Missing required field', 'docs/test.md')

            $issue.Type | Should -Be 'Error'
            $issue.Field | Should -Be 'title'
            $issue.Message | Should -Be 'Missing required field'
            $issue.FilePath | Should -Be 'docs/test.md'
        }

        It 'Accepts Warning type' {
            $issue = [ValidationIssue]::new('Warning', 'ms.date', 'Invalid format', 'README.md')

            $issue.Type | Should -Be 'Warning'
        }

        It 'Accepts Notice type' {
            $issue = [ValidationIssue]::new('Notice', 'author', 'Optional field missing', 'file.md')

            $issue.Type | Should -Be 'Notice'
        }
    }

    Context 'Constructor requires FilePath' {
        It 'FilePath is required - empty string allowed' {
            # ValidationIssue requires 4 parameters; FilePath can be empty
            $issue = [ValidationIssue]::new('Error', 'description', 'Cannot be empty', '')

            $issue.Type | Should -Be 'Error'
            $issue.Field | Should -Be 'description'
            $issue.Message | Should -Be 'Cannot be empty'
            $issue.FilePath | Should -Be ''
        }
    }

    Context 'Default constructor' {
        It 'Creates instance with defaults using parameterless constructor' {
            $issue = New-ValidationIssueEmpty

            $issue.Line | Should -Be 0
            $issue.Type | Should -Be 'Warning'
        }
    }
}

#endregion

#region FileValidationResult Class Tests

Describe 'FileValidationResult Class' -Tag 'Unit' {
    Context 'Initialization' {
        It 'Creates result with file path' {
            $result = New-FileValidationResult -FilePath 'test.md'

            $result.FilePath | Should -Be 'test.md'
            $result.Issues.Count | Should -Be 0
        }

        It 'Initializes with current timestamp' {
            $before = [datetime]::UtcNow
            $result = New-FileValidationResult -FilePath 'test.md'
            $after = [datetime]::UtcNow

            $result.ValidatedAt | Should -BeGreaterOrEqual $before
            $result.ValidatedAt | Should -BeLessOrEqual $after
        }

        It 'Initializes Issues as empty list' {
            $result = New-FileValidationResult -FilePath 'docs/test.md'

            $result.Issues | Should -HaveCount 0
        }
    }

    Context 'Issue tracking' {
        It 'Tracks errors separately from warnings' {
            $result = New-FileValidationResult -FilePath 'test.md'
            $result.AddError('Error 1', 'field1')
            $result.AddError('Error 2', 'field2')
            $result.AddWarning('Warning 1', 'field3')

            $result.ErrorCount() | Should -Be 2
            $result.WarningCount() | Should -Be 1
        }

        It 'Reports HasErrors correctly' {
            $result = New-FileValidationResult -FilePath 'test.md'
            $result.HasErrors() | Should -BeFalse

            $result.AddError('An error', 'testField')
            $result.HasErrors() | Should -BeTrue
        }

        It 'Reports HasWarnings correctly' {
            $result = New-FileValidationResult -FilePath 'test.md'
            $result.HasWarnings() | Should -BeFalse

            $result.AddWarning('A warning', 'testField')
            $result.HasWarnings() | Should -BeTrue
        }

        It 'Reports IsValid correctly' {
            $result = New-FileValidationResult -FilePath 'test.md'
            $result.IsValid() | Should -BeTrue

            $result.AddWarning('A warning', 'warnField')
            $result.IsValid() | Should -BeTrue

            $result.AddError('An error', 'errField')
            $result.IsValid() | Should -BeFalse
        }

        It 'Adds ValidationIssue directly' {
            $result = New-FileValidationResult -FilePath 'test.md'
            $issue = New-ValidationIssueEmpty
            $issue.Type = 'Error'
            $issue.Message = 'Direct issue'

            $result.AddIssue($issue)

            $result.Issues.Count | Should -Be 1
            $result.Issues[0].Message | Should -Be 'Direct issue'
        }

        It 'AddError creates issue with Error type' {
            $result = New-FileValidationResult -FilePath 'test.md'
            $result.AddError('Test error message', 'testField')

            $result.Issues[0].Type | Should -Be 'Error'
            $result.Issues[0].Message | Should -Be 'Test error message'
        }

        It 'AddWarning creates issue with Warning type' {
            $result = New-FileValidationResult -FilePath 'test.md'
            $result.AddWarning('Test warning message', 'testField')

            $result.Issues[0].Type | Should -Be 'Warning'
            $result.Issues[0].Message | Should -Be 'Test warning message'
        }
    }
}

#endregion

#region ValidationSummary Class Tests

Describe 'ValidationSummary Class' -Tag 'Unit' {
    Context 'Aggregation' {
        It 'Aggregates results correctly' {
            $summary = New-ValidationSummary

            $result1 = New-FileValidationResult -FilePath 'file1.md'
            $result1.AddError('Error 1', 'field1')

            $result2 = New-FileValidationResult -FilePath 'file2.md'
            $result2.AddWarning('Warning 1', 'field2')

            $result3 = New-FileValidationResult -FilePath 'file3.md'

            $summary.AddResult($result1)
            $summary.AddResult($result2)
            $summary.AddResult($result3)
            $summary.Complete()

            $summary.TotalFiles | Should -Be 3
            $summary.FilesWithErrors | Should -Be 1
            $summary.FilesWithWarnings | Should -Be 1
            $summary.FilesValid | Should -Be 1
            $summary.TotalErrors | Should -Be 1
            $summary.TotalWarnings | Should -Be 1
        }

        It 'Tracks duration' {
            $summary = New-ValidationSummary
            Start-Sleep -Milliseconds 50
            $summary.Complete()

            $summary.Duration.TotalMilliseconds | Should -BeGreaterThan 40
        }

        It 'Stores results in Results collection' {
            $summary = New-ValidationSummary
            $result = New-FileValidationResult -FilePath 'test.md'
            $summary.AddResult($result)

            $summary.Results.Count | Should -Be 1
            $summary.Results[0].FilePath | Should -Be 'test.md'
        }
    }

    Context 'Exit code calculation' {
        It 'Returns 0 when no errors' {
            $summary = New-ValidationSummary
            $result = New-FileValidationResult -FilePath 'file.md'
            $summary.AddResult($result)

            $summary.GetExitCode($false) | Should -Be 0
        }

        It 'Returns 1 when errors exist' {
            $summary = New-ValidationSummary
            $result = New-FileValidationResult -FilePath 'file.md'
            $result.AddError('An error', 'testField')
            $summary.AddResult($result)

            $summary.GetExitCode($false) | Should -Be 1
        }

        It 'Treats warnings as errors when flag is set' {
            $summary = New-ValidationSummary
            $result = New-FileValidationResult -FilePath 'file.md'
            $result.AddWarning('A warning', 'testField')
            $summary.AddResult($result)

            $summary.GetExitCode($false) | Should -Be 0
            $summary.GetExitCode($true) | Should -Be 1
        }

        It 'Returns 2 for empty summary (no files validated)' {
            $summary = New-ValidationSummary

            # Exit code 2 = no files validated (distinct from validation errors)
            $summary.GetExitCode($false) | Should -Be 2
        }
    }

    Context 'Passed method' {
        It 'Returns true when no errors' {
            $summary = New-ValidationSummary
            $result = New-FileValidationResult -FilePath 'file.md'
            $summary.AddResult($result)

            $summary.Passed($false) | Should -BeTrue
        }

        It 'Returns false when errors exist' {
            $summary = New-ValidationSummary
            $result = New-FileValidationResult -FilePath 'file.md'
            $result.AddError('Error', 'testField')
            $summary.AddResult($result)

            $summary.Passed($false) | Should -BeFalse
        }

        It 'Considers warnings as failures when flag is set' {
            $summary = New-ValidationSummary
            $result = New-FileValidationResult -FilePath 'file.md'
            $result.AddWarning('Warning', 'testField')
            $summary.AddResult($result)

            $summary.Passed($false) | Should -BeTrue
            $summary.Passed($true) | Should -BeFalse
        }
    }

    Context 'Serialization' {
        It 'Converts to hashtable' {
            $summary = New-ValidationSummary
            $result = New-FileValidationResult -FilePath 'test.md'
            $result.AddError('Test error', 'testField')
            $summary.AddResult($result)
            $summary.Complete()

            $hash = $summary.ToHashtable()

            $hash.totalFiles | Should -Be 1
            $hash.totalErrors | Should -Be 1
            $hash.results.Count | Should -Be 1
            $hash.results[0].issues.Count | Should -Be 1
        }

        It 'Includes duration in hashtable' {
            $summary = New-ValidationSummary
            $summary.Complete()

            $hash = $summary.ToHashtable()

            $hash.ContainsKey('duration') | Should -BeTrue
        }
    }
}

#endregion

#region Test-RequiredField Tests

Describe 'Test-RequiredField' -Tag 'Unit' {
    Context 'Field exists and has value' {
        It 'Returns no issues when field is present with value' {
            $frontmatter = @{ title = 'My Title' }

            $issues = Test-RequiredField -Frontmatter $frontmatter -FieldName 'title' -RelativePath 'test.md'

            $issues.Count | Should -Be 0
        }
    }

    Context 'Field missing' {
        It 'Returns error when field is missing' {
            $frontmatter = @{ description = 'Has description' }

            $issues = Test-RequiredField -Frontmatter $frontmatter -FieldName 'title' -RelativePath 'test.md'

            $issues.Count | Should -Be 1
            $issues[0].Type | Should -Be 'Error'
            $issues[0].Field | Should -Be 'title'
            $issues[0].Message | Should -Match 'Missing required field'
        }
    }

    Context 'Field exists but empty' {
        It 'Returns error when field is empty string' {
            $frontmatter = @{ title = '' }

            $issues = Test-RequiredField -Frontmatter $frontmatter -FieldName 'title' -RelativePath 'test.md'

            $issues.Count | Should -Be 1
            $issues[0].Type | Should -Be 'Error'
        }

        It 'Returns error when field is whitespace only' {
            $frontmatter = @{ title = '   ' }

            $issues = Test-RequiredField -Frontmatter $frontmatter -FieldName 'title' -RelativePath 'test.md'

            $issues.Count | Should -Be 1
            $issues[0].Type | Should -Be 'Error'
        }

        It 'Returns error when field is null' {
            $frontmatter = @{ title = $null }

            $issues = Test-RequiredField -Frontmatter $frontmatter -FieldName 'title' -RelativePath 'test.md'

            $issues.Count | Should -Be 1
            $issues[0].Type | Should -Be 'Error'
        }
    }

    Context 'Custom severity' {
        It 'Uses Warning severity when specified' {
            $frontmatter = @{}

            $issues = Test-RequiredField -Frontmatter $frontmatter -FieldName 'author' -RelativePath 'test.md' -Severity 'Warning'

            $issues.Count | Should -Be 1
            $issues[0].Type | Should -Be 'Warning'
        }
    }
}

#endregion

#region Test-DateFormat Tests

Describe 'Test-DateFormat' -Tag 'Unit' {
    Context 'Valid date formats' {
        It 'Returns no issues for ISO 8601 date (YYYY-MM-DD)' {
            $frontmatter = @{ 'ms.date' = '2025-01-16' }

            $issues = Test-DateFormat -Frontmatter $frontmatter -FieldName 'ms.date' -RelativePath 'test.md'

            $issues.Count | Should -Be 0
        }

        It 'Returns no issues for placeholder format (YYYY-MM-dd)' {
            $frontmatter = @{ 'ms.date' = '(YYYY-MM-dd)' }

            $issues = Test-DateFormat -Frontmatter $frontmatter -FieldName 'ms.date' -RelativePath 'test.md'

            $issues.Count | Should -Be 0
        }

        It 'Returns no issues when field is missing' {
            $frontmatter = @{ title = 'Test' }

            $issues = Test-DateFormat -Frontmatter $frontmatter -FieldName 'ms.date' -RelativePath 'test.md'

            $issues.Count | Should -Be 0
        }
    }

    Context 'Invalid date formats' {
        It 'Returns warning for slash-separated date' {
            $frontmatter = @{ 'ms.date' = '2025/01/16' }

            $issues = Test-DateFormat -Frontmatter $frontmatter -FieldName 'ms.date' -RelativePath 'test.md'

            $issues.Count | Should -Be 1
            $issues[0].Type | Should -Be 'Warning'
            $issues[0].Message | Should -Match 'Invalid date format'
        }

        It 'Returns warning for MM-DD-YYYY format' {
            $frontmatter = @{ 'ms.date' = '01-16-2025' }

            $issues = Test-DateFormat -Frontmatter $frontmatter -FieldName 'ms.date' -RelativePath 'test.md'

            $issues.Count | Should -Be 1
            $issues[0].Type | Should -Be 'Warning'
        }

        It 'Returns warning for text date' {
            $frontmatter = @{ 'ms.date' = 'January 16, 2025' }

            $issues = Test-DateFormat -Frontmatter $frontmatter -FieldName 'ms.date' -RelativePath 'test.md'

            $issues.Count | Should -Be 1
            $issues[0].Type | Should -Be 'Warning'
        }
    }
}

#endregion

#region Test-SuggestedFields Tests

Describe 'Test-SuggestedFields' -Tag 'Unit' {
    Context 'All suggested fields present' {
        It 'Returns no issues when all fields exist' {
            $frontmatter = @{
                author = 'test-author'
                'ms.date' = '2025-01-16'
            }
            $fieldNames = @('author', 'ms.date')

            $issues = Test-SuggestedFields -Frontmatter $frontmatter -FieldNames $fieldNames -RelativePath 'test.md'

            $issues.Count | Should -Be 0
        }
    }

    Context 'Missing suggested fields' {
        It 'Returns warning for each missing field' {
            $frontmatter = @{ title = 'Test' }
            $fieldNames = @('author', 'ms.date', 'ms.topic')

            $issues = Test-SuggestedFields -Frontmatter $frontmatter -FieldNames $fieldNames -RelativePath 'test.md'

            $issues.Count | Should -Be 3
            $issues | ForEach-Object { $_.Type | Should -Be 'Warning' }
        }

        It 'Returns warning with field name in message' {
            $frontmatter = @{}
            $fieldNames = @('author')

            $issues = Test-SuggestedFields -Frontmatter $frontmatter -FieldNames $fieldNames -RelativePath 'test.md'

            $issues[0].Field | Should -Be 'author'
            $issues[0].Message | Should -Match 'author'
        }
    }

    Context 'Partial fields present' {
        It 'Returns warnings only for missing fields' {
            $frontmatter = @{
                author = 'test'
                'ms.topic' = 'overview'
            }
            $fieldNames = @('author', 'ms.date', 'ms.topic')

            $issues = Test-SuggestedFields -Frontmatter $frontmatter -FieldNames $fieldNames -RelativePath 'test.md'

            $issues.Count | Should -Be 1
            $issues[0].Field | Should -Be 'ms.date'
        }
    }
}

#endregion

#region Test-RootCommunityFileFields Tests

Describe 'Test-RootCommunityFileFields' -Tag 'Unit' {
    Context 'Valid frontmatter' {
        It 'Returns only warnings for complete frontmatter with all fields' {
            $frontmatter = @{
                title = 'Contributing Guide'
                description = 'How to contribute to this project'
                author = 'maintainer'
                'ms.date' = '2025-01-16'
            }

            $issues = Test-RootCommunityFileFields -Frontmatter $frontmatter -RelativePath 'CONTRIBUTING.md'

            $errors = $issues | Where-Object { $_.Type -eq 'Error' }
            $errors.Count | Should -Be 0
        }
    }

    Context 'Missing required fields' {
        It 'Returns error for missing title' {
            $frontmatter = @{ description = 'Valid description' }

            $issues = Test-RootCommunityFileFields -Frontmatter $frontmatter -RelativePath 'README.md'

            $errors = $issues | Where-Object { $_.Type -eq 'Error' -and $_.Field -eq 'title' }
            $errors.Count | Should -Be 1
        }

        It 'Returns error for missing description' {
            $frontmatter = @{ title = 'Valid title' }

            $issues = Test-RootCommunityFileFields -Frontmatter $frontmatter -RelativePath 'README.md'

            $errors = $issues | Where-Object { $_.Type -eq 'Error' -and $_.Field -eq 'description' }
            $errors.Count | Should -Be 1
        }
    }

    Context 'Missing suggested fields' {
        It 'Returns warnings for missing author and ms.date' {
            $frontmatter = @{
                title = 'Test'
                description = 'Test desc'
            }

            $issues = Test-RootCommunityFileFields -Frontmatter $frontmatter -RelativePath 'SECURITY.md'

            $warnings = $issues | Where-Object { $_.Type -eq 'Warning' }
            $warnings.Count | Should -BeGreaterOrEqual 2
        }
    }

    Context 'Invalid date format' {
        It 'Returns warning for invalid ms.date format' {
            $frontmatter = @{
                title = 'Test'
                description = 'Test'
                author = 'test'
                'ms.date' = '2025/01/16'
            }

            $issues = Test-RootCommunityFileFields -Frontmatter $frontmatter -RelativePath 'CODE_OF_CONDUCT.md'

            $dateWarnings = $issues | Where-Object { $_.Field -eq 'ms.date' -and $_.Type -eq 'Warning' }
            $dateWarnings.Count | Should -Be 1
        }
    }
}

#endregion

#region Test-DevContainerFileFields Tests

Describe 'Test-DevContainerFileFields' -Tag 'Unit' {
    Context 'Valid frontmatter' {
        It 'Returns no issues for complete frontmatter' {
            $frontmatter = @{
                title = 'Dev Container Setup'
                description = 'Development container configuration'
            }

            $issues = Test-DevContainerFileFields -Frontmatter $frontmatter -RelativePath '.devcontainer/README.md'

            $issues.Count | Should -Be 0
        }
    }

    Context 'Missing required fields' {
        It 'Returns error for missing title' {
            $frontmatter = @{ description = 'Valid' }

            $issues = Test-DevContainerFileFields -Frontmatter $frontmatter -RelativePath '.devcontainer/README.md'

            $issues.Count | Should -Be 1
            $issues[0].Field | Should -Be 'title'
            $issues[0].Type | Should -Be 'Error'
        }

        It 'Returns error for missing description' {
            $frontmatter = @{ title = 'Valid' }

            $issues = Test-DevContainerFileFields -Frontmatter $frontmatter -RelativePath '.devcontainer/README.md'

            $issues.Count | Should -Be 1
            $issues[0].Field | Should -Be 'description'
        }

        It 'Returns two errors when both fields missing' {
            $frontmatter = @{}

            $issues = Test-DevContainerFileFields -Frontmatter $frontmatter -RelativePath '.devcontainer/README.md'

            $issues.Count | Should -Be 2
        }
    }
}

#endregion

#region Test-VSCodeReadmeFileFields Tests

Describe 'Test-VSCodeReadmeFileFields' -Tag 'Unit' {
    Context 'Valid frontmatter' {
        It 'Returns no issues for complete frontmatter' {
            $frontmatter = @{
                title = 'Extension README'
                description = 'VS Code extension documentation'
            }

            $issues = Test-VSCodeReadmeFileFields -Frontmatter $frontmatter -RelativePath 'extension/README.md'

            $issues.Count | Should -Be 0
        }
    }

    Context 'Missing required fields' {
        It 'Returns error for missing title' {
            $frontmatter = @{ description = 'Valid' }

            $issues = Test-VSCodeReadmeFileFields -Frontmatter $frontmatter -RelativePath '.vscode/README.md'

            $errors = $issues | Where-Object { $_.Field -eq 'title' }
            $errors.Count | Should -Be 1
        }

        It 'Returns error for missing description' {
            $frontmatter = @{ title = 'Valid' }

            $issues = Test-VSCodeReadmeFileFields -Frontmatter $frontmatter -RelativePath '.vscode/README.md'

            $errors = $issues | Where-Object { $_.Field -eq 'description' }
            $errors.Count | Should -Be 1
        }

        It 'Returns two errors when both fields missing' {
            $frontmatter = @{}

            $issues = Test-VSCodeReadmeFileFields -Frontmatter $frontmatter -RelativePath '.vscode/README.md'

            $issues.Count | Should -Be 2
        }
    }
}

#endregion

#region Test-FooterPresence Tests

Describe 'Test-FooterPresence' -Tag 'Unit' {
    Context 'Footer present' {
        It 'Returns null when footer is present' {
            $issue = Test-FooterPresence -HasFooter $true -RelativePath '.vscode/README.md'

            $issue | Should -BeNullOrEmpty
        }
    }

    Context 'Footer missing' {
        It 'Returns error when footer is missing' {
            $issue = Test-FooterPresence -HasFooter $false -RelativePath '.vscode/README.md'

            $issue | Should -Not -BeNullOrEmpty
            $issue.Type | Should -Be 'Error'
            $issue.Field | Should -Be 'footer'
        }

        It 'Uses Warning severity when specified' {
            $issue = Test-FooterPresence -HasFooter $false -RelativePath 'test.md' -Severity 'Warning'

            $issue.Type | Should -Be 'Warning'
        }
    }
}

#endregion

#region Test-GitHubResourceFileFields Tests

Describe 'Test-GitHubResourceFileFields' -Tag 'Unit' {
    BeforeAll {
        # Create FileTypeInfo mock objects using module scope to avoid
        # class identity conflicts between using module and Import-Module
        $script:ChatModeInfo = New-FileTypeInfo -Properties @{ IsChatMode = $true; IsGitHub = $true }
        $script:InstructionInfo = New-FileTypeInfo -Properties @{ IsInstruction = $true; IsGitHub = $true }
        $script:PromptInfo = New-FileTypeInfo -Properties @{ IsPrompt = $true; IsGitHub = $true }
    }

    Context 'ChatMode/Agent files' {
        It 'Returns warning when description missing for agent file' {
            $frontmatter = @{ name = 'Test Agent' }

            $issues = Test-GitHubResourceFileFields -Frontmatter $frontmatter -RelativePath '.github/agents/test.agent.md' -FileTypeInfo $script:ChatModeInfo

            $issues.Count | Should -Be 1
            $issues[0].Type | Should -Be 'Warning'
            $issues[0].Field | Should -Be 'description'
        }

        It 'Returns no issues when description present for agent file' {
            $frontmatter = @{ description = 'Agent description' }

            $issues = Test-GitHubResourceFileFields -Frontmatter $frontmatter -RelativePath '.github/agents/test.chatmode.md' -FileTypeInfo $script:ChatModeInfo

            $issues.Count | Should -Be 0
        }
    }

    Context 'Instruction files' {
        It 'Returns error when description missing for instruction file' {
            $frontmatter = @{ title = 'Test' }

            $issues = Test-GitHubResourceFileFields -Frontmatter $frontmatter -RelativePath '.github/instructions/test.instructions.md' -FileTypeInfo $script:InstructionInfo

            $issues.Count | Should -Be 1
            $issues[0].Type | Should -Be 'Error'
            $issues[0].Field | Should -Be 'description'
        }

        It 'Returns no issues when description present for instruction file' {
            $frontmatter = @{ description = 'Instruction description' }

            $issues = Test-GitHubResourceFileFields -Frontmatter $frontmatter -RelativePath '.github/instructions/test.instructions.md' -FileTypeInfo $script:InstructionInfo

            $issues.Count | Should -Be 0
        }
    }

    Context 'Prompt files' {
        It 'Returns no issues for prompt files (freeform content)' {
            $frontmatter = @{}

            $issues = Test-GitHubResourceFileFields -Frontmatter $frontmatter -RelativePath '.github/prompts/test.prompt.md' -FileTypeInfo $script:PromptInfo

            $issues.Count | Should -Be 0
        }
    }
}

#endregion

#region Test-DocsFileFields Tests

Describe 'Test-DocsFileFields' -Tag 'Unit' {
    Context 'Valid frontmatter' {
        It 'Returns only warnings for complete frontmatter' {
            $frontmatter = @{
                title = 'Getting Started'
                description = 'How to get started with the project'
                author = 'docs-team'
                'ms.date' = '2025-01-16'
                'ms.topic' = 'overview'
            }

            $issues = Test-DocsFileFields -Frontmatter $frontmatter -RelativePath 'docs/getting-started.md'

            $errors = $issues | Where-Object { $_.Type -eq 'Error' }
            $errors.Count | Should -Be 0
        }
    }

    Context 'Missing required fields' {
        It 'Returns error for missing title' {
            $frontmatter = @{ description = 'Valid' }

            $issues = Test-DocsFileFields -Frontmatter $frontmatter -RelativePath 'docs/test.md'

            $errors = $issues | Where-Object { $_.Type -eq 'Error' -and $_.Field -eq 'title' }
            $errors.Count | Should -Be 1
        }

        It 'Returns error for missing description' {
            $frontmatter = @{ title = 'Valid' }

            $issues = Test-DocsFileFields -Frontmatter $frontmatter -RelativePath 'docs/test.md'

            $errors = $issues | Where-Object { $_.Type -eq 'Error' -and $_.Field -eq 'description' }
            $errors.Count | Should -Be 1
        }
    }

    Context 'Missing suggested fields' {
        It 'Returns warnings for missing author, ms.date, ms.topic' {
            $frontmatter = @{
                title = 'Test'
                description = 'Test'
            }

            $issues = Test-DocsFileFields -Frontmatter $frontmatter -RelativePath 'docs/test.md'

            $warnings = $issues | Where-Object { $_.Type -eq 'Warning' }
            $warnings.Count | Should -BeGreaterOrEqual 3
        }
    }

    Context 'Invalid ms.topic value' {
        It 'Returns warning for unknown topic type' {
            $frontmatter = @{
                title = 'Test'
                description = 'Test'
                'ms.topic' = 'invalid-topic'
            }

            $issues = Test-DocsFileFields -Frontmatter $frontmatter -RelativePath 'docs/test.md'

            $topicWarnings = $issues | Where-Object { $_.Field -eq 'ms.topic' }
            $topicWarnings.Count | Should -Be 1
            $topicWarnings[0].Message | Should -Match 'Unknown topic type'
        }

        It 'Returns no warning for valid topic types' {
            $validTopics = @('overview', 'concept', 'tutorial', 'reference', 'how-to', 'troubleshooting')

            foreach ($topic in $validTopics) {
                $frontmatter = @{
                    title = 'Test'
                    description = 'Test'
                    'ms.topic' = $topic
                }

                $issues = Test-DocsFileFields -Frontmatter $frontmatter -RelativePath 'docs/test.md'

                $topicWarnings = $issues | Where-Object { $_.Field -eq 'ms.topic' -and $_.Message -match 'Unknown' }
                $topicWarnings.Count | Should -Be 0 -Because "Topic '$topic' should be valid"
            }
        }
    }

    Context 'Invalid date format' {
        It 'Returns warning for invalid ms.date format' {
            $frontmatter = @{
                title = 'Test'
                description = 'Test'
                'ms.date' = 'Jan 16, 2025'
            }

            $issues = Test-DocsFileFields -Frontmatter $frontmatter -RelativePath 'docs/test.md'

            $dateWarnings = $issues | Where-Object { $_.Field -eq 'ms.date' -and $_.Message -match 'Invalid date' }
            $dateWarnings.Count | Should -Be 1
        }
    }
}

#endregion

#region Main Script Function Tests

# Tests for functions in Validate-MarkdownFrontmatter.ps1
Describe 'Main Script Functions' -Tag 'Unit' {
    BeforeAll {
        # Dot-source the main script to access its functions
        $script:MainScriptPath = Join-Path $PSScriptRoot '..\..\linting\Validate-MarkdownFrontmatter.ps1'
        # Source the script with minimal parameters to avoid executing main logic
        . $script:MainScriptPath -Paths @() -ErrorAction SilentlyContinue 2>$null
    }

    # Note: ConvertFrom-YamlFrontmatter and Get-MarkdownFrontmatter tests removed
    # Those functions were deleted as part of issue #266 refactoring - functionality
    # now provided by FrontmatterValidation.psm1

    Context 'Test-MarkdownFooter' {
        It 'Returns $true when standard Copilot footer present' {
            $content = @"
# Test

Content here.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, carefully refined by our team of discerning human reviewers.
"@
            $result = Test-MarkdownFooter -Content $content

            $result | Should -BeTrue
        }

        It 'Returns $true when footer is bold formatted' {
            $content = @"
# Test

Content.

**🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.**
"@
            $result = Test-MarkdownFooter -Content $content

            $result | Should -BeTrue
        }

        It 'Returns $false when no footer present' {
            $content = @"
# Test

Content without footer.
"@
            $result = Test-MarkdownFooter -Content $content

            $result | Should -BeFalse
        }

        It 'Returns $true when footer wrapped in HTML comment markers' {
            $content = @"
# Test

<!-- markdownlint-disable -->
🤖 Crafted with precision by ✨Copilot following brilliant human instruction, carefully refined by our team of discerning human reviewers.
<!-- markdownlint-enable -->
"@
            $result = Test-MarkdownFooter -Content $content

            $result | Should -BeTrue
        }
    }

    Context 'Initialize-JsonSchemaValidation' {
        It 'Returns $true when JSON processing available' {
            $result = Initialize-JsonSchemaValidation

            $result | Should -BeTrue
        }
    }

    Context 'Get-SchemaForFile' {
        BeforeAll {
            $script:SchemaDir = Join-Path $PSScriptRoot '..\..\linting\schemas'
        }

        It 'Returns docs schema for docs/ files' {
            $result = Get-SchemaForFile -FilePath 'docs/getting-started.md' -SchemaDirectory $script:SchemaDir

            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match 'docs-frontmatter'
        }

        It 'Returns instruction schema for .instructions.md files' {
            $result = Get-SchemaForFile -FilePath '.github/instructions/test.instructions.md' -SchemaDirectory $script:SchemaDir

            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match 'instruction'
        }

        It 'Returns default schema for unmapped files' {
            $result = Get-SchemaForFile -FilePath 'random/file.md' -SchemaDirectory $script:SchemaDir

            # Function returns defaultSchema from mapping, not null
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match 'base-frontmatter'
        }
    }
}

#endregion

#region Test-CommonFields Tests

Describe 'Test-CommonFields' -Tag 'Unit' {
    Context 'Keywords validation' {
        It 'Returns no issues when keywords is an array' {
            $frontmatter = @{
                keywords = @('powershell', 'validation', 'frontmatter')
            }

            $issues = Test-CommonFields -Frontmatter $frontmatter -RelativePath 'test.md'

            $keywordIssues = $issues | Where-Object { $_.Field -eq 'keywords' }
            $keywordIssues.Count | Should -Be 0
        }

        It 'Returns no issues when keywords contains comma (treated as list)' {
            $frontmatter = @{
                keywords = 'powershell, validation, frontmatter'
            }

            $issues = Test-CommonFields -Frontmatter $frontmatter -RelativePath 'test.md'

            $keywordIssues = $issues | Where-Object { $_.Field -eq 'keywords' }
            $keywordIssues.Count | Should -Be 0
        }

        It 'Returns warning when keywords is single string without comma' {
            $frontmatter = @{
                keywords = 'single-keyword'
            }

            $issues = Test-CommonFields -Frontmatter $frontmatter -RelativePath 'test.md'

            $keywordIssues = $issues | Where-Object { $_.Field -eq 'keywords' }
            $keywordIssues.Count | Should -Be 1
            $keywordIssues[0].Type | Should -Be 'Warning'
        }
    }

    Context 'Estimated reading time validation' {
        It 'Returns no issues for valid integer reading time' {
            $frontmatter = @{
                estimated_reading_time = '5'
            }

            $issues = Test-CommonFields -Frontmatter $frontmatter -RelativePath 'test.md'

            $readingTimeIssues = $issues | Where-Object { $_.Field -eq 'estimated_reading_time' }
            $readingTimeIssues.Count | Should -Be 0
        }

        It 'Returns warning for non-integer reading time' {
            $frontmatter = @{
                estimated_reading_time = '5 minutes'
            }

            $issues = Test-CommonFields -Frontmatter $frontmatter -RelativePath 'test.md'

            $readingTimeIssues = $issues | Where-Object { $_.Field -eq 'estimated_reading_time' }
            $readingTimeIssues.Count | Should -Be 1
            $readingTimeIssues[0].Type | Should -Be 'Warning'
        }

        It 'Returns warning for decimal reading time' {
            $frontmatter = @{
                estimated_reading_time = '5.5'
            }

            $issues = Test-CommonFields -Frontmatter $frontmatter -RelativePath 'test.md'

            $readingTimeIssues = $issues | Where-Object { $_.Field -eq 'estimated_reading_time' }
            $readingTimeIssues.Count | Should -Be 1
        }
    }

    Context 'No optional fields' {
        It 'Returns no issues when optional fields are missing' {
            $frontmatter = @{
                title = 'Test'
                description = 'Test'
            }

            $issues = Test-CommonFields -Frontmatter $frontmatter -RelativePath 'test.md'

            $issues.Count | Should -Be 0
        }
    }
}

#endregion

#region Test-MarkdownFooter Tests

Describe 'Test-MarkdownFooter' -Tag 'Unit' {
    Context 'Valid footer detection' {
        It 'Returns true for standard footer' {
            $content = @"
# Content

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, carefully refined by our team of discerning human reviewers.
"@
            Test-MarkdownFooter -Content $content | Should -BeTrue
        }

        It 'Returns true for footer with then keyword' {
            $content = @"
# Content

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
"@
            Test-MarkdownFooter -Content $content | Should -BeTrue
        }

        It 'Returns true for bold formatted footer' {
            $content = @"
# Content

**🤖 Crafted with precision by ✨Copilot following brilliant human instruction, carefully refined by our team of discerning human reviewers.**
"@
            Test-MarkdownFooter -Content $content | Should -BeTrue
        }

        It 'Returns true for footer wrapped in HTML comments' {
            $content = @"
# Content

<!-- markdownlint-disable -->
🤖 Crafted with precision by ✨Copilot following brilliant human instruction, carefully refined by our team of discerning human reviewers.
<!-- markdownlint-enable -->
"@
            Test-MarkdownFooter -Content $content | Should -BeTrue
        }
    }

    Context 'Missing or invalid footer' {
        It 'Returns false for empty content' {
            Test-MarkdownFooter -Content '' | Should -BeFalse
        }

        It 'Returns false for content without footer' {
            $content = @"
# Content

Just some regular content here.
"@
            Test-MarkdownFooter -Content $content | Should -BeFalse
        }

        It 'Returns false for partial footer' {
            $content = @"
# Content

🤖 Crafted with precision by ✨Copilot
"@
            Test-MarkdownFooter -Content $content | Should -BeFalse
        }
    }
}

#endregion

#region Test-SingleFileFrontmatter Tests

Describe 'Test-SingleFileFrontmatter' -Tag 'Unit' {
    BeforeAll {
        # Use TestDrive for cross-platform compatibility (Linux CI runners)
        $script:TestRepoRoot = Join-Path $TestDrive 'test-repo'
        New-Item -ItemType Directory -Path $script:TestRepoRoot -Force | Out-Null
    }

    Context 'Valid docs file' {
        It 'Returns result with no errors for valid frontmatter' {
            $mockContent = @"
---
title: Test Document
description: A test file description
ms.date: 01/15/2025
author: testuser
ms.topic: concept
---

# Content

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, carefully refined by our team of discerning human reviewers.
"@
            $testFile = Join-Path $script:TestRepoRoot 'docs' 'test.md'
            $result = Test-SingleFileFrontmatter `
                -FilePath $testFile `
                -RepoRoot $script:TestRepoRoot `
                -FileReader { $mockContent }.GetNewClosure()

            $result | Should -Not -BeNull
            $result.HasFrontmatter | Should -BeTrue
            $result.Frontmatter.title | Should -Be 'Test Document'
            $result.IsValid() | Should -BeTrue
        }
    }

    Context 'Missing frontmatter' {
        It 'Returns warning for file without frontmatter' {
            $testFile = Join-Path $script:TestRepoRoot 'docs' 'test.md'
            $result = Test-SingleFileFrontmatter `
                -FilePath $testFile `
                -RepoRoot $script:TestRepoRoot `
                -FileReader { '# Just a heading' }

            $result.HasFrontmatter | Should -BeFalse
            $result.HasWarnings() | Should -BeTrue
            $result.Issues[0].Message | Should -BeLike '*No frontmatter*'
        }
    }

    Context 'Invalid YAML' {
        It 'Returns error for malformed YAML' {
            $mockContent = @"
---
title: Test
bad yaml: [unclosed
---
# Content
"@
            $testFile = Join-Path $script:TestRepoRoot 'docs' 'test.md'
            $result = Test-SingleFileFrontmatter `
                -FilePath $testFile `
                -RepoRoot $script:TestRepoRoot `
                -FileReader { $mockContent }.GetNewClosure()

            $result.HasErrors() | Should -BeTrue
            $result.Issues[0].Message | Should -BeLike '*YAML*'
        }
    }

    Context 'File read error' {
        It 'Returns error when file cannot be read' {
            $testFile = Join-Path $script:TestRepoRoot 'docs' 'missing.md'
            $result = Test-SingleFileFrontmatter `
                -FilePath $testFile `
                -RepoRoot $script:TestRepoRoot `
                -FileReader { throw 'File not found' }

            $result.HasErrors() | Should -BeTrue
            $result.Issues[0].Message | Should -BeLike '*Failed to read*'
        }
    }

    Context 'File type detection' {
        It 'Detects docs file correctly' {
            $mockContent = @"
---
title: Test
description: Test desc
---
# Content
"@
            $testFile = Join-Path $script:TestRepoRoot 'docs' 'guide.md'
            $result = Test-SingleFileFrontmatter `
                -FilePath $testFile `
                -RepoRoot $script:TestRepoRoot `
                -FileReader { $mockContent }.GetNewClosure()

            $result.FileType | Should -Not -BeNull
            $result.FileType.IsDocsFile | Should -BeTrue
        }

        It 'Detects instructions file correctly' {
            $mockContent = @"
---
description: Test instruction
---
# Content
"@
            $testFile = Join-Path $script:TestRepoRoot '.github' 'instructions' 'test.instructions.md'
            $result = Test-SingleFileFrontmatter `
                -FilePath $testFile `
                -RepoRoot $script:TestRepoRoot `
                -FileReader { $mockContent }.GetNewClosure()

            $result.FileType | Should -Not -BeNull
            $result.FileType.IsInstruction | Should -BeTrue
        }
    }

    Context 'Relative path computation' {
        It 'Computes correct relative path' {
            $mockContent = @"
---
title: Test
description: Test
---
"@
            $testFile = Join-Path $script:TestRepoRoot 'docs' 'subdir' 'file.md'
            $result = Test-SingleFileFrontmatter `
                -FilePath $testFile `
                -RepoRoot $script:TestRepoRoot `
                -FileReader { $mockContent }.GetNewClosure()

            # Use platform-specific path separator for assertion
            $expectedPath = 'docs' + [IO.Path]::DirectorySeparatorChar + 'subdir' + [IO.Path]::DirectorySeparatorChar + 'file.md'
            $result.RelativePath | Should -Be $expectedPath
        }
    }
}

Describe 'Invoke-FrontmatterValidation' -Tag 'Unit' {
    BeforeAll {
        # Use TestDrive for cross-platform compatibility (Linux CI runners)
        $script:TestRepoRoot = Join-Path $TestDrive 'TestRepo'
        New-Item -ItemType Directory -Path $script:TestRepoRoot -Force | Out-Null
        # Get module reference for mock object creation
        $script:MockModule = Get-Module FrontmatterValidation
    }

    Context 'Multi-file orchestration' {
        It 'Returns ValidationSummary object' {
            Mock Test-SingleFileFrontmatter -ModuleName FrontmatterValidation {
                & (Get-Module FrontmatterValidation) {
                    param($path)
                    $r = [FileValidationResult]::new($path)
                    $r.HasFrontmatter = $true
                    return $r
                } $FilePath
            }

            $summary = Invoke-FrontmatterValidation `
                -Files @("$script:TestRepoRoot\file1.md", "$script:TestRepoRoot\file2.md") `
                -RepoRoot $script:TestRepoRoot

            $summary | Should -Not -BeNull
            $summary.TotalFiles | Should -Be 2
        }

        It 'Aggregates results from multiple files' {
            Mock Test-SingleFileFrontmatter -ModuleName FrontmatterValidation {
                & (Get-Module FrontmatterValidation) {
                    param($path)
                    $r = [FileValidationResult]::new($path)
                    $r.HasFrontmatter = $true
                    return $r
                } $FilePath
            }

            $files = @(
                "$script:TestRepoRoot\docs\file1.md",
                "$script:TestRepoRoot\docs\file2.md",
                "$script:TestRepoRoot\docs\file3.md"
            )

            $summary = Invoke-FrontmatterValidation -Files $files -RepoRoot $script:TestRepoRoot

            $summary.TotalFiles | Should -Be 3
            $summary.FilesValid | Should -Be 3
        }

        It 'Tracks files with warnings' {
            Mock Test-SingleFileFrontmatter -ModuleName FrontmatterValidation {
                & (Get-Module FrontmatterValidation) {
                    param($path)
                    $r = [FileValidationResult]::new($path)
                    $r.HasFrontmatter = $false
                    $r.AddWarning('No frontmatter found', 'frontmatter')
                    return $r
                } $FilePath
            }

            $summary = Invoke-FrontmatterValidation `
                -Files @("$script:TestRepoRoot\plain.md") `
                -RepoRoot $script:TestRepoRoot

            $summary.FilesValid | Should -Be 0
            $summary.FilesWithWarnings | Should -Be 1
            $summary.TotalFiles | Should -Be 1
        }

        It 'Tracks errors across files' {
            Mock Test-SingleFileFrontmatter -ModuleName FrontmatterValidation {
                & (Get-Module FrontmatterValidation) {
                    param($path)
                    $r = [FileValidationResult]::new($path)
                    $r.AddError('Parse error', 'yaml')
                    return $r
                } $FilePath
            }

            $summary = Invoke-FrontmatterValidation `
                -Files @("$script:TestRepoRoot\bad1.md", "$script:TestRepoRoot\bad2.md") `
                -RepoRoot $script:TestRepoRoot

            $summary.TotalErrors | Should -Be 2
            $summary.FilesWithErrors | Should -Be 2
        }

        It 'Completes summary after processing' {
            Mock Test-SingleFileFrontmatter -ModuleName FrontmatterValidation {
                & (Get-Module FrontmatterValidation) {
                    param($path)
                    $r = [FileValidationResult]::new($path)
                    $r.HasFrontmatter = $true
                    return $r
                } $FilePath
            }

            $summary = Invoke-FrontmatterValidation `
                -Files @("$script:TestRepoRoot\file.md") `
                -RepoRoot $script:TestRepoRoot

            $summary.CompletedAt | Should -Not -Be ([datetime]::MinValue)
            $summary.Duration | Should -Not -BeNull
        }
    }

    Context 'Single file handling' {
        It 'Handles single file' {
            Mock Test-SingleFileFrontmatter -ModuleName FrontmatterValidation {
                & (Get-Module FrontmatterValidation) {
                    param($path)
                    $r = [FileValidationResult]::new($path)
                    $r.HasFrontmatter = $true
                    return $r
                } $FilePath
            }

            $summary = Invoke-FrontmatterValidation `
                -Files @("$script:TestRepoRoot\single.md") `
                -RepoRoot $script:TestRepoRoot

            $summary.TotalFiles | Should -Be 1
        }
    }
}

#endregion

#region Output Functions

Describe 'Write-ValidationConsoleOutput' -Tag 'Unit' {
    It 'Writes summary without error' {
        $summary = script:New-ValidationSummary
        $result = script:New-FileValidationResult -FilePath 'test.md'
        $summary.AddResult($result)
        $summary.Complete()

        { Write-ValidationConsoleOutput -Summary $summary } | Should -Not -Throw
    }

    It 'Handles ShowDetails switch' {
        $summary = script:New-ValidationSummary
        $result = script:New-FileValidationResult -FilePath 'test.md'
        $result.AddWarning('Test warning', 'field')
        $summary.AddResult($result)
        $summary.Complete()

        { Write-ValidationConsoleOutput -Summary $summary -ShowDetails } | Should -Not -Throw
    }

    It 'Displays valid file icon in details mode' {
        $summary = script:New-ValidationSummary
        $result = script:New-FileValidationResult -FilePath 'valid.md'
        $result.HasFrontmatter = $true
        $summary.AddResult($result)
        $summary.Complete()

        # Verify no error thrown with valid file
        { Write-ValidationConsoleOutput -Summary $summary -ShowDetails } | Should -Not -Throw
    }
}

Describe 'Write-GitHubAnnotations' -Tag 'Unit' {
    It 'Outputs correct error annotation format' {
        $summary = script:New-ValidationSummary
        $result = script:New-FileValidationResult -FilePath 'test.md'
        $result.AddError('Test error', 'field')
        $summary.AddResult($result)

        $output = Write-GitHubAnnotations -Summary $summary
        $output | Should -BeLike '::error file=test.md*::Test error'
    }

    It 'Outputs warnings correctly' {
        $summary = script:New-ValidationSummary
        $result = script:New-FileValidationResult -FilePath 'test.md'
        $result.AddWarning('Test warning', 'field')
        $summary.AddResult($result)

        $output = Write-GitHubAnnotations -Summary $summary
        $output | Should -BeLike '::warning file=test.md*::Test warning'
    }

    It 'Includes line number when available' {
        $summary = script:New-ValidationSummary
        $result = script:New-FileValidationResult -FilePath 'test.md'
        # Use AddError overload with line number
        $result.AddError('Error at line', 'field', 42)
        $summary.AddResult($result)

        $output = Write-GitHubAnnotations -Summary $summary
        $output | Should -BeLike '::error file=test.md,line=42::Error at line'
    }

    It 'Returns nothing when no issues' {
        $summary = script:New-ValidationSummary
        $result = script:New-FileValidationResult -FilePath 'test.md'
        $result.HasFrontmatter = $true
        $summary.AddResult($result)

        $output = Write-GitHubAnnotations -Summary $summary
        $output | Should -BeNullOrEmpty
    }

    It 'Escapes percent character in message' {
        $summary = script:New-ValidationSummary
        $result = script:New-FileValidationResult -FilePath 'test.md'
        $result.AddError('50% complete', 'field')
        $summary.AddResult($result)

        $output = Write-GitHubAnnotations -Summary $summary
        $output | Should -Match '50%25 complete'
    }

    It 'Escapes carriage return in message' {
        $summary = script:New-ValidationSummary
        $result = script:New-FileValidationResult -FilePath 'test.md'
        $result.AddError("line1`rline2", 'field')
        $summary.AddResult($result)

        $output = Write-GitHubAnnotations -Summary $summary
        $output | Should -Match 'line1%0Dline2'
    }

    It 'Escapes newline in message' {
        $summary = script:New-ValidationSummary
        $result = script:New-FileValidationResult -FilePath 'test.md'
        $result.AddError("line1`nline2", 'field')
        $summary.AddResult($result)

        $output = Write-GitHubAnnotations -Summary $summary
        $output | Should -Match 'line1%0Aline2'
    }

    It 'Escapes double colon in message' {
        $summary = script:New-ValidationSummary
        $result = script:New-FileValidationResult -FilePath 'test.md'
        $result.AddError('scope::value', 'field')
        $summary.AddResult($result)

        $output = Write-GitHubAnnotations -Summary $summary
        $output | Should -Match 'scope%3A%3Avalue'
    }

    It 'Escapes colon in file path' {
        $summary = script:New-ValidationSummary
        $result = script:New-FileValidationResult -FilePath 'path:file.md'
        $result.AddError('Test error', 'field')
        $summary.AddResult($result)

        $output = Write-GitHubAnnotations -Summary $summary
        $output | Should -Match 'file=path%3Afile\.md'
    }

    It 'Escapes comma in file path' {
        $summary = script:New-ValidationSummary
        $result = script:New-FileValidationResult -FilePath 'file,backup.md'
        $result.AddError('Test error', 'field')
        $summary.AddResult($result)

        $output = Write-GitHubAnnotations -Summary $summary
        $output | Should -Match 'file=file%2Cbackup\.md'
    }

    It 'Escapes percent in file path' {
        $summary = script:New-ValidationSummary
        $result = script:New-FileValidationResult -FilePath 'file%20name.md'
        $result.AddError('Test error', 'field')
        $summary.AddResult($result)

        $output = Write-GitHubAnnotations -Summary $summary
        $output | Should -Match 'file=file%2520name\.md'
    }

    It 'Handles null message gracefully' {
        $summary = script:New-ValidationSummary
        $result = script:New-FileValidationResult -FilePath 'test.md'
        # Create issue with null message via direct class instantiation
        $issue = & (Get-Module FrontmatterValidation) {
            param($fp)
            $i = [ValidationIssue]::new()
            $i.Type = 'Error'
            $i.Message = $null
            $i.FilePath = $fp
            $i
        } 'test.md'
        $result.Issues.Add($issue)
        $summary.AddResult($result)

        { Write-GitHubAnnotations -Summary $summary } | Should -Not -Throw
    }
}

Describe 'Export-ValidationResults' -Tag 'Unit' {
    It 'Exports valid JSON' {
        $summary = script:New-ValidationSummary
        $result = script:New-FileValidationResult -FilePath 'test.md'
        $summary.AddResult($result)
        $summary.Complete()

        $outputPath = Join-Path $TestDrive 'test-output.json'
        Export-ValidationResults -Summary $summary -OutputPath $outputPath

        Test-Path $outputPath | Should -BeTrue
        $json = Get-Content $outputPath -Raw | ConvertFrom-Json
        $json.totalFiles | Should -Be 1
    }

    It 'Creates output directory if needed' {
        $summary = script:New-ValidationSummary
        $summary.Complete()

        $outputPath = Join-Path $TestDrive 'subdir/test-output.json'
        Export-ValidationResults -Summary $summary -OutputPath $outputPath

        Test-Path $outputPath | Should -BeTrue
    }

    It 'Includes all summary fields in JSON' {
        $summary = script:New-ValidationSummary
        $result = script:New-FileValidationResult -FilePath 'test.md'
        $result.AddError('Test error', 'field')
        $result.AddWarning('Test warning', 'field')
        $summary.AddResult($result)
        $summary.Complete()

        $outputPath = Join-Path $TestDrive 'full-output.json'
        Export-ValidationResults -Summary $summary -OutputPath $outputPath

        $json = Get-Content $outputPath -Raw | ConvertFrom-Json
        $json.totalFiles | Should -Be 1
        $json.totalErrors | Should -Be 1
        $json.totalWarnings | Should -Be 1
        $json.filesWithErrors | Should -Be 1
        $json.filesWithWarnings | Should -Be 1
    }
}

#endregion
#endregion
