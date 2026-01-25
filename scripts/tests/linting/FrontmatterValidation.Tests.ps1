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
        # Create FileTypeInfo instances for different file types
        $script:ChatModeInfo = [FileTypeInfo]::new()
        $script:ChatModeInfo.IsChatMode = $true

        $script:InstructionInfo = [FileTypeInfo]::new()
        $script:InstructionInfo.IsInstruction = $true

        $script:PromptInfo = [FileTypeInfo]::new()
        $script:PromptInfo.IsPrompt = $true
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
