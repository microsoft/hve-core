#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
# Import module with 'using' to make PowerShell class types (FileTypeInfo, ValidationSummary, etc.) available at parse time
using module ..\..\linting\Modules\FrontmatterValidation.psm1

BeforeAll {
    # Dot-source the main script
    $scriptPath = Join-Path $PSScriptRoot '../../linting/Validate-MarkdownFrontmatter.ps1'
    . $scriptPath

    $mockPath = Join-Path $PSScriptRoot '../Mocks/GitMocks.psm1'
    Import-Module $mockPath -Force
    $script:SchemaDir = Join-Path $PSScriptRoot '../../linting/schemas'
    $script:FixtureDir = Join-Path $PSScriptRoot '../Fixtures/Frontmatter'
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
}

#region Get-FileTypeInfo Tests

Describe 'Get-FileTypeInfo' -Tag 'Unit' {
    BeforeAll {
        # Create temporary test files for FileInfo objects
        $script:TempTestDir = Join-Path ([System.IO.Path]::GetTempPath()) "FrontmatterTests_$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:TempTestDir -Force | Out-Null

        # Create subdirectories to simulate repo structure
        @(
            'docs/guide',
            '.github/instructions',
            '.github/prompts',
            '.github/chatmodes',
            '.devcontainer',
            '.vscode',
            'random/path'
        ) | ForEach-Object {
            New-Item -ItemType Directory -Path (Join-Path $script:TempTestDir $_) -Force | Out-Null
        }
    }

    AfterAll {
        if (Test-Path $script:TempTestDir) {
            Remove-Item -Path $script:TempTestDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Root community files' {
        It 'Identifies README.md as root community' {
            $filePath = Join-Path $script:TempTestDir 'README.md'
            Set-Content -Path $filePath -Value 'test'
            $file = Get-Item $filePath
            $result = Get-FileTypeInfo -File $file -RepoRoot $script:TempTestDir
            $result.GetType().Name | Should -Be 'FileTypeInfo'
            $result.IsRootCommunityFile | Should -BeTrue
        }

        It 'Identifies CONTRIBUTING.md as root community' {
            $filePath = Join-Path $script:TempTestDir 'CONTRIBUTING.md'
            Set-Content -Path $filePath -Value 'test'
            $file = Get-Item $filePath
            $result = Get-FileTypeInfo -File $file -RepoRoot $script:TempTestDir
            $result.IsRootCommunityFile | Should -BeTrue
        }

        It 'Identifies CODE_OF_CONDUCT.md as root community' {
            $filePath = Join-Path $script:TempTestDir 'CODE_OF_CONDUCT.md'
            Set-Content -Path $filePath -Value 'test'
            $file = Get-Item $filePath
            $result = Get-FileTypeInfo -File $file -RepoRoot $script:TempTestDir
            $result.IsRootCommunityFile | Should -BeTrue
        }

        It 'Identifies SECURITY.md as root community' {
            $filePath = Join-Path $script:TempTestDir 'SECURITY.md'
            Set-Content -Path $filePath -Value 'test'
            $file = Get-Item $filePath
            $result = Get-FileTypeInfo -File $file -RepoRoot $script:TempTestDir
            $result.IsRootCommunityFile | Should -BeTrue
        }

        It 'Identifies SUPPORT.md as root community' {
            $filePath = Join-Path $script:TempTestDir 'SUPPORT.md'
            Set-Content -Path $filePath -Value 'test'
            $file = Get-Item $filePath
            $result = Get-FileTypeInfo -File $file -RepoRoot $script:TempTestDir
            $result.IsRootCommunityFile | Should -BeTrue
        }
    }

    Context 'Documentation files' {
        It 'Identifies docs/**/*.md as docs file' {
            $filePath = Join-Path $script:TempTestDir 'docs/guide/readme.md'
            Set-Content -Path $filePath -Value 'test'
            $file = Get-Item $filePath
            $result = Get-FileTypeInfo -File $file -RepoRoot $script:TempTestDir
            $result.IsDocsFile | Should -BeTrue
        }

        It 'Does not mark root README as docs file' {
            $filePath = Join-Path $script:TempTestDir 'README.md'
            Set-Content -Path $filePath -Value 'test'
            $file = Get-Item $filePath
            $result = Get-FileTypeInfo -File $file -RepoRoot $script:TempTestDir
            $result.IsDocsFile | Should -BeFalse
        }
    }

    Context 'Instruction files' {
        It 'Identifies *.instructions.md as instruction file' {
            $filePath = Join-Path $script:TempTestDir '.github/instructions/test.instructions.md'
            Set-Content -Path $filePath -Value 'test'
            $file = Get-Item $filePath
            $result = Get-FileTypeInfo -File $file -RepoRoot $script:TempTestDir
            $result.IsInstruction | Should -BeTrue
        }
    }

    Context 'Prompt files' {
        It 'Identifies *.prompt.md as prompt file' {
            $filePath = Join-Path $script:TempTestDir '.github/prompts/build.prompt.md'
            Set-Content -Path $filePath -Value 'test'
            $file = Get-Item $filePath
            $result = Get-FileTypeInfo -File $file -RepoRoot $script:TempTestDir
            $result.IsPrompt | Should -BeTrue
        }
    }

    Context 'Chatmode files' {
        It 'Identifies *.chatmode.md as chatmode file' {
            $filePath = Join-Path $script:TempTestDir '.github/chatmodes/helper.chatmode.md'
            Set-Content -Path $filePath -Value 'test'
            $file = Get-Item $filePath
            $result = Get-FileTypeInfo -File $file -RepoRoot $script:TempTestDir
            $result.IsChatMode | Should -BeTrue
        }
    }

    Context 'Special locations' {
        It 'Identifies .devcontainer README' {
            $filePath = Join-Path $script:TempTestDir '.devcontainer/README.md'
            Set-Content -Path $filePath -Value 'test'
            $file = Get-Item $filePath
            $result = Get-FileTypeInfo -File $file -RepoRoot $script:TempTestDir
            $result.IsDevContainer | Should -BeTrue
        }

        It 'Identifies .vscode README' {
            $filePath = Join-Path $script:TempTestDir '.vscode/README.md'
            Set-Content -Path $filePath -Value 'test'
            $file = Get-Item $filePath
            $result = Get-FileTypeInfo -File $file -RepoRoot $script:TempTestDir
            $result.IsVSCodeReadme | Should -BeTrue
        }
    }

    Context 'Unknown file types' {
        It 'Returns all false for random markdown file' {
            $filePath = Join-Path $script:TempTestDir 'random/path/file.md'
            Set-Content -Path $filePath -Value 'test'
            $file = Get-Item $filePath
            $result = Get-FileTypeInfo -File $file -RepoRoot $script:TempTestDir
            $result.IsRootCommunityFile | Should -BeFalse
            $result.IsDocsFile | Should -BeFalse
            $result.IsInstruction | Should -BeFalse
            $result.IsPrompt | Should -BeFalse
            $result.IsChatMode | Should -BeFalse
        }
    }
}

#endregion

#region Test-MarkdownFooter Tests

Describe 'Test-MarkdownFooter' -Tag 'Unit' {
    BeforeAll {
        # Standard Copilot attribution footer
        $script:ValidFooter = '🤖 Crafted with precision by ✨Copilot following brilliant human instruction, carefully refined by our team of discerning human reviewers.'
        $script:ValidFooterAlternate = '🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.'
    }

    Context 'Valid footer patterns' {
        It 'Returns true for standard Copilot attribution footer' {
            $content = "# Document`n`nSome content here.`n`n$script:ValidFooter"
            Test-MarkdownFooter -Content $content | Should -BeTrue
        }

        It 'Returns true for alternate footer with "then" phrasing' {
            $content = "# Document`n`nContent.`n`n$script:ValidFooterAlternate"
            Test-MarkdownFooter -Content $content | Should -BeTrue
        }

        It 'Returns true when footer has trailing period' {
            $content = "Content`n`n🤖 Crafted with precision by ✨Copilot following brilliant human instruction, carefully refined by our team of discerning human reviewers."
            Test-MarkdownFooter -Content $content | Should -BeTrue
        }

        It 'Returns true when footer has no trailing period' {
            $content = "Content`n`n🤖 Crafted with precision by ✨Copilot following brilliant human instruction, carefully refined by our team of discerning human reviewers"
            Test-MarkdownFooter -Content $content | Should -BeTrue
        }
    }

    Context 'Missing footer' {
        It 'Returns false for content without Copilot attribution' {
            $content = 'Content without the attribution footer'
            Test-MarkdownFooter -Content $content | Should -BeFalse
        }

        It 'Returns false for empty content' {
            Test-MarkdownFooter -Content '' | Should -BeFalse
        }

        It 'Returns false for partial attribution text' {
            $content = "Content`n`n🤖 Crafted with precision"
            Test-MarkdownFooter -Content $content | Should -BeFalse
        }
    }

    Context 'Footer variations and normalization' {
        It 'Handles footer with extra whitespace between words' {
            $content = "Content`n`n🤖  Crafted  with  precision  by  ✨Copilot  following  brilliant  human  instruction,  carefully  refined  by  our  team  of  discerning  human  reviewers."
            Test-MarkdownFooter -Content $content | Should -BeTrue
        }

        It 'Handles footer after multiple blank lines' {
            $content = "Content`n`n`n`n$script:ValidFooter"
            Test-MarkdownFooter -Content $content | Should -BeTrue
        }
    }
}

#endregion

#region Initialize-JsonSchemaValidation Tests

Describe 'Initialize-JsonSchemaValidation' -Tag 'Unit' {
    Context 'Normal operation' {
        It 'Returns true when JSON processing is available' {
            $result = Initialize-JsonSchemaValidation
            $result | Should -BeTrue
        }

        It 'Validates JSON can be parsed' {
            # Function internally tests JSON parsing
            $result = Initialize-JsonSchemaValidation
            $result | Should -BeOfType [bool]
        }
    }

    Context 'Error handling' {
        It 'Returns false and warns when JSON parsing fails' {
            # Arrange - Mock ConvertFrom-Json to throw an error
            Mock ConvertFrom-Json { throw "Simulated JSON parse error" }

            # Act
            $result = Initialize-JsonSchemaValidation -WarningVariable warnings -WarningAction SilentlyContinue

            # Assert
            $result | Should -BeFalse
        }

        It 'Warning message contains error details on exception' {
            # Arrange - Mock ConvertFrom-Json to throw specific error
            Mock ConvertFrom-Json { throw "Detailed parse failure" }

            # Act
            $null = Initialize-JsonSchemaValidation -WarningVariable warnings 3>$null

            # Assert - Warning should contain the error context
            $warnings | Should -Not -BeNullOrEmpty
            $warnings[0] | Should -Match 'Error initializing schema validation'
        }

        It 'Handles null result from ConvertFrom-Json' {
            # Arrange - Mock ConvertFrom-Json to return null
            Mock ConvertFrom-Json { return $null }

            # Act
            $result = Initialize-JsonSchemaValidation

            # Assert
            $result | Should -BeFalse
        }
    }
}

#endregion

#region Get-SchemaForFile Tests

Describe 'Get-SchemaForFile' -Tag 'Unit' {
    Context 'Schema mapping' {
        It 'Returns docs schema for docs files' {
            $result = Get-SchemaForFile -FilePath 'docs/guide/readme.md' -SchemaDirectory $script:SchemaDir -RepoRoot $script:RepoRoot
            $result | Should -Match 'docs-frontmatter\.schema\.json'
        }

        It 'Returns instruction schema for instruction files' {
            $result = Get-SchemaForFile -FilePath '.github/instructions/test.instructions.md' -SchemaDirectory $script:SchemaDir -RepoRoot $script:RepoRoot
            $result | Should -Match 'instruction-frontmatter\.schema\.json'
        }

        It 'Returns prompt schema for prompt files' {
            $result = Get-SchemaForFile -FilePath '.github/prompts/build.prompt.md' -SchemaDirectory $script:SchemaDir -RepoRoot $script:RepoRoot
            $result | Should -Match 'prompt-frontmatter\.schema\.json'
        }

        It 'Returns chatmode schema for chatmode files' {
            $result = Get-SchemaForFile -FilePath '.github/chatmodes/helper.chatmode.md' -SchemaDirectory $script:SchemaDir -RepoRoot $script:RepoRoot
            $result | Should -Match 'chatmode-frontmatter\.schema\.json'
        }

        It 'Returns agent schema for agent files' {
            $result = Get-SchemaForFile -FilePath '.github/agents/worker.agent.md' -SchemaDirectory $script:SchemaDir -RepoRoot $script:RepoRoot
            $result | Should -Match 'agent-frontmatter\.schema\.json'
        }

        It 'Returns root-community schema for root community files' {
            $result = Get-SchemaForFile -FilePath 'README.md' -SchemaDirectory $script:SchemaDir -RepoRoot $script:RepoRoot
            $result | Should -Match 'root-community-frontmatter\.schema\.json'
        }

        It 'Returns base schema for unknown file types' {
            $result = Get-SchemaForFile -FilePath 'random/file.md' -SchemaDirectory $script:SchemaDir -RepoRoot $script:RepoRoot
            $result | Should -Match 'base-frontmatter\.schema\.json'
        }
    }

    Context 'Pipe-separated pattern matching' {
        It 'Matches root file from pipe-separated pattern' {
            # Test CONTRIBUTING.md which should match the pipe-separated pattern in schema-mapping.json
            $result = Get-SchemaForFile -FilePath 'CONTRIBUTING.md' -SchemaDirectory $script:SchemaDir -RepoRoot $script:RepoRoot
            $result | Should -Match 'root-community-frontmatter\.schema\.json'
        }

        It 'Matches CODE_OF_CONDUCT.md from pipe-separated pattern' {
            $result = Get-SchemaForFile -FilePath 'CODE_OF_CONDUCT.md' -SchemaDirectory $script:SchemaDir -RepoRoot $script:RepoRoot
            $result | Should -Match 'root-community-frontmatter\.schema\.json'
        }

        It 'Matches SECURITY.md from pipe-separated pattern' {
            $result = Get-SchemaForFile -FilePath 'SECURITY.md' -SchemaDirectory $script:SchemaDir -RepoRoot $script:RepoRoot
            $result | Should -Match 'root-community-frontmatter\.schema\.json'
        }

        It 'Falls back to base schema for unlisted root files' {
            # LICENSE is not in the pipe-separated pattern, so should fall back to base
            $result = Get-SchemaForFile -FilePath 'LICENSE' -SchemaDirectory $script:SchemaDir -RepoRoot $script:RepoRoot
            $result | Should -Match 'base-frontmatter\.schema\.json'
        }
    }

    Context 'Simple glob pattern matching' {
        It 'Matches skill file using simple glob pattern' {
            $result = Get-SchemaForFile -FilePath '.github/skills/test-skill/SKILL.md' -SchemaDirectory $script:SchemaDir -RepoRoot $script:RepoRoot
            $result | Should -Match 'skill-frontmatter\.schema\.json'
        }

        It 'Falls back to base schema for paths not matching any pattern' {
            # A path that doesn't match any defined patterns
            $result = Get-SchemaForFile -FilePath 'misc/random/file.md' -SchemaDirectory $script:SchemaDir -RepoRoot $script:RepoRoot
            $result | Should -Match 'base-frontmatter\.schema\.json'
        }
    }

    Context 'Auto RepoRoot resolution' {
        It 'Auto-detects repo root when RepoRoot is not specified' {
            $result = Get-SchemaForFile -FilePath 'docs/guide/readme.md' -SchemaDirectory $script:SchemaDir
            $result | Should -Match 'docs-frontmatter\.schema\.json'
        }

        It 'Returns null when no .git directory is found' {
            $isolatedDir = Join-Path $TestDrive 'isolated-schemas'
            New-Item -ItemType Directory -Path $isolatedDir -Force | Out-Null
            '{"mappings": [], "defaultSchema": "base.schema.json"}' | Set-Content -Path (Join-Path $isolatedDir 'schema-mapping.json')

            Mock Test-Path { return $false } -ParameterFilter { $Path -like '*\.git' -or $Path -like '*/.git' }

            $result = Get-SchemaForFile -FilePath 'test.md' -SchemaDirectory $isolatedDir 3>$null
            $result | Should -BeNullOrEmpty
        }
    }
}

#endregion

#region Test-JsonSchemaValidation Tests

Describe 'Test-JsonSchemaValidation' -Tag 'Unit' {
    BeforeAll {
        $script:DocsSchemaPath = Join-Path $script:SchemaDir 'docs-frontmatter.schema.json'
        $script:DocsSchema = Get-Content -Path $script:DocsSchemaPath -Raw | ConvertFrom-Json
        $script:BaseSchemaPath = Join-Path $script:SchemaDir 'base-frontmatter.schema.json'
        $script:BaseSchema = Get-Content -Path $script:BaseSchemaPath -Raw | ConvertFrom-Json
    }

    Context 'Required fields validation' {
        It 'Fails when required field is missing' {
            $frontmatter = @{ title = 'Test' }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:DocsSchema
            $result.GetType().Name | Should -Be 'SchemaValidationResult'
            $result.IsValid | Should -BeFalse
        }

        It 'Passes with all required fields' {
            $frontmatter = @{
                title       = 'Test'
                description = 'Valid description'
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:DocsSchema
            $result.IsValid | Should -BeTrue
        }
    }

    Context 'Pattern validation' {
        BeforeAll {
            # Create inline schema since $ref is not resolved by Test-JsonSchemaValidation
            $script:PatternTestSchema = @{
                required   = @('title', 'description')
                properties = @{
                    title       = @{ type = 'string'; minLength = 1 }
                    description = @{ type = 'string'; minLength = 1 }
                    'ms.date'   = @{ type = 'string'; pattern = '^\d{4}-\d{2}-\d{2}$' }
                }
            } | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        }

        It 'Fails for invalid date format' {
            $frontmatter = @{
                title       = 'Test'
                description = 'Valid'
                'ms.date'   = '2025/01/16'
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:PatternTestSchema
            $result.IsValid | Should -BeFalse
        }

        It 'Passes for valid date format' {
            $frontmatter = @{
                title       = 'Test'
                description = 'Valid'
                'ms.date'   = '2025-01-16'
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:PatternTestSchema
            $result.IsValid | Should -BeTrue
        }
    }

    Context 'Enum validation' {
        It 'Fails for invalid ms.topic value' {
            $frontmatter = @{
                title       = 'Test'
                description = 'Valid'
                'ms.topic'  = 'invalid-topic-type'
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:DocsSchema
            $result.IsValid | Should -BeFalse
        }

        It 'Passes for valid ms.topic value' {
            $frontmatter = @{
                title       = 'Test'
                description = 'Valid'
                'ms.topic'  = 'overview'
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:DocsSchema
            $result.IsValid | Should -BeTrue
        }
    }

    Context 'Return type structure' {
        It 'Returns SchemaValidationResult with expected properties' {
            $frontmatter = @{ description = 'Test' }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:BaseSchema
            $result.PSObject.Properties.Name | Should -Contain 'IsValid'
            $result.PSObject.Properties.Name | Should -Contain 'Errors'
            $result.PSObject.Properties.Name | Should -Contain 'Warnings'
            $result.PSObject.Properties.Name | Should -Contain 'SchemaUsed'
        }
    }

    Context 'Array type validation' {
        BeforeAll {
            $script:ArrayTestSchema = @{
                required   = @('description')
                properties = @{
                    description = @{ type = 'string'; minLength = 1 }
                    applyTo     = @{ type = 'array'; items = @{ type = 'string' } }
                }
            } | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        }

        It 'Validates array field with empty array' {
            $frontmatter = @{
                description = 'test'
                applyTo     = @()
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:ArrayTestSchema
            $result.Errors | Where-Object { $_ -like '*applyTo*' } | Should -BeNullOrEmpty
        }

        It 'Validates array field with valid string items' {
            $frontmatter = @{
                description = 'test'
                applyTo     = @('*.md', '*.txt')
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:ArrayTestSchema
            $result.Errors | Where-Object { $_ -like '*applyTo*' } | Should -BeNullOrEmpty
        }

        It 'Reports error when string value used for array field' {
            # Strings implement IEnumerable but should not pass array validation
            $frontmatter = @{
                description = 'test'
                applyTo     = 'single-value'
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:ArrayTestSchema
            $result.IsValid | Should -BeFalse
            $result.Errors | Should -Contain "Field 'applyTo' must be an array"
        }

        It 'Reports error when array field has numeric value' {
            $frontmatter = @{
                description = 'test'
                applyTo     = 123
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:ArrayTestSchema
            $result.IsValid | Should -BeFalse
            $result.Errors | Should -Contain "Field 'applyTo' must be an array"
        }

        It 'Reports error when hashtable provided for array field' {
            # Hashtables/dictionaries are IEnumerable, but semantically objects, not arrays.
            $frontmatter = @{
                description = 'test'
                applyTo     = @{ pattern = '*.md' }
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:ArrayTestSchema
            $result.IsValid | Should -BeFalse
            $result.Errors | Should -Contain "Field 'applyTo' must be an array"
        }
    }

    Context 'Boolean type validation' {
        BeforeAll {
            $script:BoolTestSchema = @{
                required   = @('description')
                properties = @{
                    description = @{ type = 'string'; minLength = 1 }
                    deprecated  = @{ type = 'boolean' }
                }
            } | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        }

        It 'Accepts valid boolean true value' {
            $frontmatter = @{
                description = 'test'
                deprecated  = $true
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:BoolTestSchema
            $result.Errors | Where-Object { $_ -like '*deprecated*' } | Should -BeNullOrEmpty
        }

        It 'Accepts valid boolean false value' {
            $frontmatter = @{
                description = 'test'
                deprecated  = $false
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:BoolTestSchema
            $result.Errors | Where-Object { $_ -like '*deprecated*' } | Should -BeNullOrEmpty
        }

        It 'Accepts string true/false as boolean' {
            $frontmatter = @{
                description = 'test'
                deprecated  = 'true'
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:BoolTestSchema
            $result.Errors | Where-Object { $_ -like '*deprecated*' } | Should -BeNullOrEmpty
        }

        It 'Reports error when boolean field has invalid string value' {
            $frontmatter = @{
                description = 'test'
                deprecated  = 'yes'
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:BoolTestSchema
            $result.IsValid | Should -BeFalse
            $result.Errors | Should -Contain "Field 'deprecated' must be a boolean"
        }

        It 'Reports error when boolean field has numeric value' {
            $frontmatter = @{
                description = 'test'
                deprecated  = 1
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:BoolTestSchema
            $result.IsValid | Should -BeFalse
            $result.Errors | Should -Contain "Field 'deprecated' must be a boolean"
        }
    }

    Context 'Enum validation with arrays' {
        BeforeAll {
            $script:EnumArraySchema = @{
                required   = @('description')
                properties = @{
                    description = @{ type = 'string'; minLength = 1 }
                    tags        = @{ 
                        type  = 'array'
                        items = @{ type = 'string' }
                        enum  = @('stable', 'preview', 'deprecated')
                    }
                }
            } | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        }

        It 'Passes when array contains only valid enum values' {
            $frontmatter = @{
                description = 'test'
                tags        = @('stable', 'preview')
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:EnumArraySchema
            $result.Errors | Where-Object { $_ -like '*tags*' } | Should -BeNullOrEmpty
        }

        It 'Reports error when array contains invalid enum value' {
            $frontmatter = @{
                description = 'test'
                tags        = @('stable', 'invalid-value')
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:EnumArraySchema
            $result.IsValid | Should -BeFalse
            $result.Errors | Where-Object { $_ -like '*invalid-value*' } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'MinLength validation' {
        BeforeAll {
            $script:MinLengthSchema = @{
                required   = @('description')
                properties = @{
                    description = @{ type = 'string'; minLength = 10 }
                    title       = @{ type = 'string'; minLength = 5 }
                }
            } | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        }

        It 'Passes when string meets minimum length requirement' {
            $frontmatter = @{
                description = 'This is a sufficiently long description'
                title       = 'Valid Title'
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:MinLengthSchema
            $result.IsValid | Should -BeTrue
        }

        It 'Reports error when string is shorter than minLength' {
            $frontmatter = @{
                description = 'Short'
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:MinLengthSchema
            $result.IsValid | Should -BeFalse
            $result.Errors | Should -Contain "Field 'description' must have minimum length of 10"
        }

        It 'Reports error for empty string when minLength is set' {
            $frontmatter = @{
                description = ''
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:MinLengthSchema
            $result.IsValid | Should -BeFalse
            $result.Errors | Where-Object { $_ -like '*description*' -and $_ -like '*length*' } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'oneOf validation' {
        BeforeAll {
            $script:OneOfSchema = @{
                required   = @('description')
                properties = @{
                    description = @{ type = 'string'; minLength = 1 }
                    model       = @{
                        oneOf = @(
                            @{ type = 'string' },
                            @{ type = 'array'; items = @{ type = 'string' } }
                        )
                    }
                }
            } | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        }

        It 'Accepts string for oneOf string|array field' {
            $frontmatter = @{
                description = 'test'
                model       = 'gpt-5'
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:OneOfSchema
            $result.IsValid | Should -BeTrue
        }

        It 'Accepts array for oneOf string|array field' {
            $frontmatter = @{
                description = 'test'
                model       = @('gpt-5', 'claude-sonnet')
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:OneOfSchema
            $result.IsValid | Should -BeTrue
        }

        It 'Rejects invalid type for oneOf string|array field' {
            $frontmatter = @{
                description = 'test'
                model       = 123
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:OneOfSchema
            $result.IsValid | Should -BeFalse
        }

        It 'Rejects when value matches multiple oneOf subschemas' {
            $schema = @{
                required   = @('description')
                properties = @{
                    description = @{ type = 'string'; minLength = 1 }
                    model       = @{
                        oneOf = @(
                            @{ type = 'string' },
                            @{ type = 'string'; minLength = 1 }
                        )
                    }
                }
            } | ConvertTo-Json -Depth 10 | ConvertFrom-Json

            $frontmatter = @{
                description = 'test'
                model       = 'x'
            }

            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $schema
            $result.IsValid | Should -BeFalse
            $result.Errors | Where-Object { $_ -like "*exactly one*" } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Nested object and array validation' {
        BeforeAll {
            $script:NestedSchema = @{
                required   = @('description')
                properties = @{
                    description = @{ type = 'string'; minLength = 1 }
                    agents      = @{
                        oneOf = @(
                            @{ type = 'array'; items = @{ type = 'string' } },
                            @{ type = 'string'; enum = @('*') }
                        )
                    }
                    handoffs    = @{
                        type  = 'array'
                        items = @{
                            type       = 'object'
                            required   = @('label', 'agent')
                            properties = @{
                                label  = @{ type = 'string'; minLength = 1 }
                                agent  = @{ type = 'string'; minLength = 1 }
                                prompt = @{ type = 'string' }
                                model  = @{ type = 'string' }
                                send   = @{ type = 'boolean' }
                            }
                        }
                    }
                }
            } | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        }

        It 'Accepts agents as * string' {
            $frontmatter = @{
                description = 'test'
                agents      = '*'
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:NestedSchema
            $result.IsValid | Should -BeTrue
        }

        It 'Accepts agents as array of strings' {
            $frontmatter = @{
                description = 'test'
                agents      = @('task-researcher', 'task-planner')
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:NestedSchema
            $result.IsValid | Should -BeTrue
        }

        It 'Rejects agents as non-wildcard string' {
            $frontmatter = @{
                description = 'test'
                agents      = 'all'
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:NestedSchema
            $result.IsValid | Should -BeFalse
            $result.Errors | Where-Object { $_ -match 'must match one of the allowed schemas' } | Should -Not -BeNullOrEmpty
        }

        It 'Accepts handoff without prompt (prompt is optional)' {
            $frontmatter = @{
                description = 'test'
                handoffs    = @(
                    @{ label = 'Next'; agent = 'task-planner' }
                )
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:NestedSchema
            $result.IsValid | Should -BeTrue
        }

        It 'Accepts nested object values provided as PSCustomObject' {
            $frontmatter = @{
                description = 'test'
                handoffs    = @(
                    [pscustomobject]@{ label = 'Next'; agent = 'task-planner' }
                )
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:NestedSchema
            $result.IsValid | Should -BeTrue
        }

        It 'Rejects handoff item when item is not an object' {
            $frontmatter = @{
                description = 'test'
                handoffs    = @('not-an-object')
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:NestedSchema
            $result.IsValid | Should -BeFalse
            $result.Errors | Where-Object { $_ -match 'handoffs\[0\].*object' } | Should -Not -BeNullOrEmpty
        }

        It 'Rejects handoff with empty label due to nested minLength' {
            $frontmatter = @{
                description = 'test'
                handoffs    = @(
                    @{ label = ''; agent = 'task-planner' }
                )
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:NestedSchema
            $result.IsValid | Should -BeFalse
            $result.Errors | Where-Object { $_ -match 'handoffs\[0\]\.label.*minimum length' } | Should -Not -BeNullOrEmpty
        }

        It 'Accepts complex object values provided as hashtable (covers conversion of arrays and nested objects)' {
            $schema = @{
                required   = @('description', 'meta')
                properties = @{
                    description = @{ type = 'string'; minLength = 1 }
                    meta        = @{
                        type       = 'object'
                        required   = @('tags', 'items', 'child')
                        properties = @{
                            tags  = @{ type = 'array'; items = @{ type = 'string' } }
                            items = @{
                                type  = 'array'
                                items = @{
                                    type       = 'object'
                                    required   = @('name')
                                    properties = @{
                                        name = @{ type = 'string'; minLength = 1 }
                                    }
                                }
                            }
                            child = @{
                                type       = 'object'
                                required   = @('id')
                                properties = @{
                                    id = @{ type = 'string'; minLength = 1 }
                                }
                            }
                        }
                    }
                }
            } | ConvertTo-Json -Depth 20 | ConvertFrom-Json

            $frontmatter = @{
                description = 'test'
                meta        = @{
                    tags  = @('a', 'b')
                    items = @(
                        [pscustomobject]@{ name = 'x' }
                        @{ name = 'y' }
                    )
                    child = [pscustomobject]@{ id = 'c1' }
                }
            }

            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $schema
            $result.IsValid | Should -BeTrue
        }

        It 'Accepts complex object values provided as PSCustomObject (covers conversion of arrays and nested objects)' {
            $schema = @{
                required   = @('description', 'meta')
                properties = @{
                    description = @{ type = 'string'; minLength = 1 }
                    meta        = @{
                        type       = 'object'
                        required   = @('tags', 'items', 'child')
                        properties = @{
                            tags  = @{ type = 'array'; items = @{ type = 'string' } }
                            items = @{
                                type  = 'array'
                                items = @{
                                    type       = 'object'
                                    required   = @('name')
                                    properties = @{
                                        name = @{ type = 'string'; minLength = 1 }
                                    }
                                }
                            }
                            child = @{
                                type       = 'object'
                                required   = @('id')
                                properties = @{
                                    id = @{ type = 'string'; minLength = 1 }
                                }
                            }
                        }
                    }
                }
            } | ConvertTo-Json -Depth 20 | ConvertFrom-Json

            $frontmatter = @{
                description = 'test'
                meta        = [pscustomobject]@{
                    tags  = @('a')
                    items = @(
                        [pscustomobject]@{ name = 'x' }
                    )
                    child = @{ id = 'c1' }
                }
            }

            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $schema
            $result.IsValid | Should -BeTrue
        }

        It 'Rejects handoff missing required label' {
            $frontmatter = @{
                description = 'test'
                handoffs    = @(
                    @{ agent = 'task-planner'; prompt = '/task-plan' }
                )
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:NestedSchema
            $result.IsValid | Should -BeFalse
        }

        It 'Rejects handoff with invalid send type' {
            $frontmatter = @{
                description = 'test'
                handoffs    = @(
                    @{ label = 'Next'; agent = 'task-planner'; send = 'yes' }
                )
            }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaContent $script:NestedSchema
            $result.IsValid | Should -BeFalse
        }
    }
}

#endregion


#region Test-FrontmatterValidation Integration Tests

Describe 'Test-FrontmatterValidation' -Tag 'Integration' {
    BeforeAll {
        Save-CIEnvironment
        $script:TestRepoRoot = Join-Path $TestDrive 'test-repo'
    }

    BeforeEach {
        New-Item -Path "$script:TestRepoRoot/docs" -ItemType Directory -Force | Out-Null
        New-Item -Path "$script:TestRepoRoot/.github/instructions" -ItemType Directory -Force | Out-Null
        New-Item -Path "$script:TestRepoRoot/scripts/linting/schemas" -ItemType Directory -Force | Out-Null

        Copy-Item -Path "$script:SchemaDir/*" -Destination "$script:TestRepoRoot/scripts/linting/schemas/" -Force

        $schemaMappingSource = Join-Path $script:SchemaDir 'schema-mapping.json'
        if (Test-Path $schemaMappingSource) {
            Copy-Item -Path $schemaMappingSource -Destination "$script:TestRepoRoot/scripts/linting/schemas/schema-mapping.json" -Force
        }

        # Change to test repo root so function detects it as repo root
        Push-Location $script:TestRepoRoot
        # Initialize minimal git repo for function's repo root detection
        git init --quiet
    }

    AfterEach {
        Pop-Location
    }

    AfterAll {
        Restore-CIEnvironment
    }

    Context 'Valid files pass validation' {
        BeforeEach {
            @"
---
title: Test Documentation
description: Valid documentation file
ms.date: 2025-01-16
ms.topic: overview
---

# Test

Content here.
"@ | Set-Content -Path "$script:TestRepoRoot/docs/test.md" -Encoding UTF8
        }

        It 'Returns ValidationSummary type' {
            $result = Test-FrontmatterValidation -Files @("$script:TestRepoRoot/docs/test.md")
            $result.GetType().Name | Should -Be 'ValidationSummary'
        }

        It 'Reports no errors for valid frontmatter' {
            $result = Test-FrontmatterValidation -Files @("$script:TestRepoRoot/docs/test.md")
            $result.GetExitCode($false) | Should -Be 0
            $result.TotalErrors | Should -Be 0
        }
    }

    Context 'Missing frontmatter fails' {
        BeforeEach {
            @"
# No Frontmatter

Just content without any YAML.
"@ | Set-Content -Path "$script:TestRepoRoot/docs/no-frontmatter.md" -Encoding UTF8
        }

        It 'Reports warning for missing frontmatter' {
            $result = Test-FrontmatterValidation -Files @("$script:TestRepoRoot/docs/no-frontmatter.md")
            # Missing frontmatter in docs is a warning, not an error
            $result.TotalWarnings | Should -BeGreaterThan 0
            $warningMessages = $result.Results | ForEach-Object { $_.Issues | Where-Object Type -eq 'Warning' } | ForEach-Object { $_.Message }
            $warningMessages | Where-Object { $_ -match 'No frontmatter found' } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Empty description fails' {
        BeforeEach {
            @"
---
title: Has Title
description: ""
---

Content
"@ | Set-Content -Path "$script:TestRepoRoot/docs/empty-desc.md" -Encoding UTF8
        }

        It 'Reports error for empty description' {
            # Missing required description field is a validation error
            $result = Test-FrontmatterValidation -Files @("$script:TestRepoRoot/docs/empty-desc.md")
            # Empty required field causes validation error
            $result.TotalErrors | Should -BeGreaterThan 0
        }
    }

    Context 'Invalid date format fails' {
        BeforeEach {
            # docs-frontmatter.schema.json requires BOTH title AND description
            @"
---
title: Bad Date File
description: Valid description
ms.date: 2025/01/16
---

Content
"@ | Set-Content -Path "$script:TestRepoRoot/docs/bad-date.md" -Encoding UTF8
        }

        It 'Reports warning for invalid date format' {
            # Invalid date format is a warning, not an error
            $result = Test-FrontmatterValidation -Files @("$script:TestRepoRoot/docs/bad-date.md")
            $result.GetExitCode($false) | Should -Be 0
            $warningMessages = $result.Results | ForEach-Object { $_.Issues | Where-Object Type -eq 'Warning' } | ForEach-Object { $_.Message }
            ($warningMessages -join "`n") | Should -Match 'Invalid date format'
        }
    }

    Context 'Multiple file validation' {
        BeforeEach {
            # docs-frontmatter.schema.json requires BOTH title AND description
            @"
---
title: Valid File 1
description: Valid file 1
---
Content
"@ | Set-Content -Path "$script:TestRepoRoot/docs/valid1.md" -Encoding UTF8

            @"
---
title: Valid File 2
description: Valid file 2
---
Content
"@ | Set-Content -Path "$script:TestRepoRoot/docs/valid2.md" -Encoding UTF8
        }

        It 'Validates multiple files in directory' {
            $result = Test-FrontmatterValidation -Paths @("$script:TestRepoRoot/docs")
            $result.TotalFiles | Should -BeGreaterOrEqual 2
        }

        It 'Uses Paths parameter when Files is not provided' {
            # Test the else branch in main execution that uses Paths
            $result = Test-FrontmatterValidation -Paths @("$script:TestRepoRoot/docs")
            $result | Should -Not -BeNullOrEmpty
            $result.TotalFiles | Should -BeGreaterThan 0
        }
    }

    Context 'Result aggregation' {
        It 'Aggregates results in ValidationSummary' {
            # docs-frontmatter.schema.json requires BOTH title AND description
            @"
---
title: Test File
description: Valid
---
Content
"@ | Set-Content -Path "$script:TestRepoRoot/docs/test.md" -Encoding UTF8

            $result = Test-FrontmatterValidation -Files @("$script:TestRepoRoot/docs/test.md")
            $result.PSObject.Properties.Name | Should -Contain 'Results'
            $result.PSObject.Properties.Name | Should -Contain 'TotalFiles'
            $result.PSObject.Properties.Name | Should -Contain 'FilesWithErrors'
            $result.PSObject.Properties.Name | Should -Contain 'FilesWithWarnings'
        }
    }

    Context 'ChangedFilesOnly mode' {
        BeforeEach {
            # Create valid test file
            @"
---
title: Changed File
description: A file detected as changed by git
---
Content
"@ | Set-Content -Path "$script:TestRepoRoot/docs/changed.md" -Encoding UTF8
        }

        It 'Returns success ValidationSummary when no changed files found' {
            # Mock Get-ChangedFilesFromGit to return empty
            Mock Get-ChangedFilesFromGit { return @() } -ParameterFilter { $FileExtensions -contains '*.md' }

            $result = Test-FrontmatterValidation -ChangedFilesOnly

            # TotalFiles=0 accurately represents no files were validated
            # This is a successful no-op, not a validation failure
            $result.TotalFiles | Should -Be 0
            $result.FilesValid | Should -Be 0
            # Verify the summary was completed
            $result.Duration | Should -Not -BeNullOrEmpty
        }

        It 'Validates only files returned by Get-ChangedFilesFromGit' {
            # Mock Get-ChangedFilesFromGit to return specific file
            Mock Get-ChangedFilesFromGit {
                return @("$script:TestRepoRoot/docs/changed.md")
            } -ParameterFilter { $FileExtensions -contains '*.md' }

            $result = Test-FrontmatterValidation -ChangedFilesOnly

            $result.TotalFiles | Should -Be 1
        }

        It 'Passes BaseBranch parameter to Get-ChangedFilesFromGit' {
            Mock Get-ChangedFilesFromGit {
                return @()
            } -ParameterFilter { $BaseBranch -eq 'develop' -and $FileExtensions -contains '*.md' }

            $null = Test-FrontmatterValidation -ChangedFilesOnly -BaseBranch 'develop'

            Should -Invoke Get-ChangedFilesFromGit -ParameterFilter { $BaseBranch -eq 'develop' -and $FileExtensions -contains '*.md' }
        }
    }

    Context 'EnableSchemaValidation mode' {
        BeforeEach {
            @"
---
title: Schema Test Doc
description: Valid test document for schema overlay
---

# Test Content
"@ | Set-Content -Path "$script:TestRepoRoot/docs/schema-test.md" -Encoding UTF8
        }

        It 'Invokes schema validation on files with frontmatter' {
            Mock Initialize-JsonSchemaValidation { return $true }
            Mock Get-SchemaForFile { return (Join-Path $script:SchemaDir 'docs-frontmatter.schema.json') }
            Mock Test-JsonSchemaValidation {
                return [PSCustomObject]@{ IsValid = $true; Errors = @(); Warnings = @() }
            }

            $null = Test-FrontmatterValidation -Files @("$script:TestRepoRoot/docs/schema-test.md") -EnableSchemaValidation -SkipFooterValidation

            Should -Invoke Get-SchemaForFile -Times 1
            Should -Invoke Test-JsonSchemaValidation -Times 1
        }

        It 'Writes warnings when schema validation reports errors' {
            Mock Initialize-JsonSchemaValidation { return $true }
            Mock Get-SchemaForFile { return (Join-Path $script:SchemaDir 'docs-frontmatter.schema.json') }
            Mock Test-JsonSchemaValidation {
                return [PSCustomObject]@{ IsValid = $false; Errors = @('Missing required field: ms.date'); Warnings = @() }
            }

            $null = Test-FrontmatterValidation -Files @("$script:TestRepoRoot/docs/schema-test.md") -EnableSchemaValidation -SkipFooterValidation -WarningVariable warnings 3>$null

            $schemaWarnings = $warnings | Where-Object { $_ -match 'JSON Schema validation errors' -or $_ -match 'ms\.date' }
            $schemaWarnings | Should -Not -BeNullOrEmpty
        }

        It 'Skips schema check when file has no frontmatter' {
            @"
# No Frontmatter

Just content without YAML.
"@ | Set-Content -Path "$script:TestRepoRoot/docs/no-fm-schema.md" -Encoding UTF8

            Mock Initialize-JsonSchemaValidation { return $true }
            Mock Get-SchemaForFile {}
            Mock Test-JsonSchemaValidation {}

            $null = Test-FrontmatterValidation -Files @("$script:TestRepoRoot/docs/no-fm-schema.md") -EnableSchemaValidation -SkipFooterValidation

            Should -Invoke Get-SchemaForFile -Times 0
        }

        It 'Skips Test-JsonSchemaValidation when no schema matches file' {
            Mock Initialize-JsonSchemaValidation { return $true }
            Mock Get-SchemaForFile { return $null }
            Mock Test-JsonSchemaValidation {}

            $null = Test-FrontmatterValidation -Files @("$script:TestRepoRoot/docs/schema-test.md") -EnableSchemaValidation -SkipFooterValidation

            Should -Invoke Get-SchemaForFile -Times 1
            Should -Invoke Test-JsonSchemaValidation -Times 0
        }

        It 'Skips overlay entirely when Initialize-JsonSchemaValidation returns false' {
            Mock Initialize-JsonSchemaValidation { return $false }
            Mock Get-SchemaForFile {}

            $null = Test-FrontmatterValidation -Files @("$script:TestRepoRoot/docs/schema-test.md") -EnableSchemaValidation -SkipFooterValidation

            Should -Invoke Get-SchemaForFile -Times 0
        }
    }
}

#endregion

#region ExcludePaths Filtering Tests

Describe 'ExcludePaths Filtering' -Tag 'Unit' {
    BeforeAll {
        # Create test directory structure with files to include and exclude
        $script:ExcludeTestDir = Join-Path $TestDrive 'exclude-test'
        New-Item -ItemType Directory -Path "$script:ExcludeTestDir/docs" -Force | Out-Null
        New-Item -ItemType Directory -Path "$script:ExcludeTestDir/tests/fixtures" -Force | Out-Null

        # Valid file that should be included
        @"
---
title: Include This
description: File that should be validated
---
Content
"@ | Set-Content -Path "$script:ExcludeTestDir/docs/include.md" -Encoding UTF8

        # File in tests directory that should be excluded
        @"
---
title: Exclude This
description: File in tests folder
---
Content
"@ | Set-Content -Path "$script:ExcludeTestDir/tests/fixtures/exclude.md" -Encoding UTF8
    }

    Context 'Excludes files matching single pattern' {
        It 'Excludes files matching pattern with wildcard prefix' {
            # Use wildcard prefix since ExcludePaths computes relative path from repo root
            # For files outside repo, the full path is used, so we match with *tests*
            $result = Test-FrontmatterValidation -Paths @($script:ExcludeTestDir) -ExcludePaths @('*tests*')
            # Should only check docs/include.md, not tests/fixtures/exclude.md
            $result.TotalFiles | Should -Be 1
        }
    }

    Context 'Excludes files matching multiple patterns' {
        BeforeAll {
            # Add another directory to exclude
            New-Item -ItemType Directory -Path "$script:ExcludeTestDir/vendor" -Force | Out-Null
            @"
---
title: Vendor File
description: Third party content
---
Content
"@ | Set-Content -Path "$script:ExcludeTestDir/vendor/third-party.md" -Encoding UTF8
        }

        It 'Excludes files matching multiple patterns' {
            $result = Test-FrontmatterValidation -Paths @($script:ExcludeTestDir) -ExcludePaths @('*tests*', '*vendor*')
            # Should only check docs/include.md
            $result.TotalFiles | Should -Be 1
        }
    }

    Context 'Processes all files when ExcludePaths is empty' {
        It 'Validates all markdown files without exclusions' {
            $result = Test-FrontmatterValidation -Paths @($script:ExcludeTestDir) -ExcludePaths @()
            # Should check all markdown files (docs + tests + vendor)
            $result.TotalFiles | Should -BeGreaterOrEqual 2
        }
    }

    Context 'Pattern matching behavior' {
        It 'Matches glob pattern with double asterisk for relative paths' {
            $relativePath = 'tests/fixtures/exclude.md'
            $pattern = 'tests/**'
            $relativePath -like $pattern | Should -BeTrue
        }

        It 'Does not match non-matching patterns' {
            $relativePath = 'docs/include.md'
            $pattern = 'tests/**'
            $relativePath -like $pattern | Should -BeFalse
        }

        It 'Matches pattern with single asterisk for file names' {
            $relativePath = 'docs/README.md'
            $pattern = 'docs/*.md'
            $relativePath -like $pattern | Should -BeTrue
        }
    }

    Context 'FooterExcludePaths integration' {
        It 'Passes FooterExcludePaths to Invoke-FrontmatterValidation' {
            $testFile = Join-Path $TestDrive 'CHANGELOG.md'
            Set-Content $testFile "---`ndescription: Release history`n---`n# Changelog`n`nNo footer here"

            # File should not have footer error when excluded (use wildcard to match filename in any path)
            $result = Test-FrontmatterValidation -Files @($testFile) -FooterExcludePaths @('*CHANGELOG.md')
            $footerErrors = $result.Results | ForEach-Object { $_.Issues } | Where-Object { $_.Field -eq 'footer' }
            $footerErrors | Should -BeNullOrEmpty
        }

        It 'Applies footer validation to non-excluded files' {
            $testFile = Join-Path $TestDrive 'docs' 'guide.md'
            New-Item -ItemType Directory -Path (Join-Path $TestDrive 'docs') -Force | Out-Null
            Set-Content $testFile "---`ndescription: Test guide`n---`n# Guide`n`nNo footer here"

            # Non-excluded file should have footer error
            $result = Test-FrontmatterValidation -Files @($testFile) -FooterExcludePaths @('*CHANGELOG.md')
            $footerErrors = $result.Results | ForEach-Object { $_.Issues } | Where-Object { $_.Field -eq 'footer' }
            $footerErrors | Should -Not -BeNullOrEmpty
        }
    }
}

#endregion

#region Error Handling Path Tests

Describe 'Error handling paths' -Tag 'Unit' {
    Context 'Schema file error handling' {
        It 'Test-JsonSchemaValidation returns error for missing schema file' {
            $frontmatter = @{ title = 'Test'; description = 'Valid' }
            $missingSchemaPath = Join-Path $TestDrive 'does-not-exist.json'
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaPath $missingSchemaPath
            $result.IsValid | Should -BeFalse
            $result.Errors | Should -Contain "Schema file not found: $missingSchemaPath"
        }

        It 'Returns proper SchemaValidationResult on schema not found' {
            $frontmatter = @{ title = 'Test' }
            $missingSchemaPath = Join-Path $TestDrive 'missing-schema.json'
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaPath $missingSchemaPath
            $result.GetType().Name | Should -Be 'SchemaValidationResult'
            $result.SchemaUsed | Should -Be $missingSchemaPath
        }

        It 'Returns error for malformed JSON schema' {
            $badSchemaPath = Join-Path $TestDrive 'bad-schema.json'
            '{ invalid json }' | Set-Content -Path $badSchemaPath -Encoding UTF8

            $frontmatter = @{ title = 'Test' }
            $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaPath $badSchemaPath
            $result.IsValid | Should -BeFalse
            $result.Errors[0] | Should -Match 'Failed to parse schema'
        }

        It 'Get-SchemaForFile returns null when mapping file is missing' {
            # Use platform-agnostic path for cross-platform compatibility
            $nonexistentPath = Join-Path $TestDrive 'nonexistent-schemas-dir'
            $result = Get-SchemaForFile -FilePath 'test.md' -SchemaDirectory $nonexistentPath
            $result | Should -BeNullOrEmpty
        }

        It 'Get-SchemaForFile handles schema-mapping.json read errors gracefully' {
            $badMappingDir = Join-Path $TestDrive 'bad-mapping-dir'
            New-Item -ItemType Directory -Path $badMappingDir -Force | Out-Null
            '{ invalid json content }' | Set-Content -Path (Join-Path $badMappingDir 'schema-mapping.json') -Encoding UTF8

            $null = Get-SchemaForFile -FilePath 'test.md' -SchemaDirectory $badMappingDir -WarningVariable warnings 3>$null
            $warnings | Should -Not -BeNullOrEmpty
            $warnings[0] | Should -Match 'Error reading schema mapping'
        }
    }
}

Describe 'CI Environment Integration' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../linting/Validate-MarkdownFrontmatter.ps1
        Import-Module $PSScriptRoot/../../linting/Modules/FrontmatterValidation.psm1 -Force

        # Save original environment
        $script:OriginalGHA = $env:GITHUB_ACTIONS
        $script:OriginalStepSummary = $env:GITHUB_STEP_SUMMARY
    }

    AfterAll {
        # Restore original environment
        $env:GITHUB_ACTIONS = $script:OriginalGHA
        $env:GITHUB_STEP_SUMMARY = $script:OriginalStepSummary
    }

    Context 'Write-CIAnnotations execution path' {
        It 'Calls Write-CIAnnotations when CI is set' {
            $env:GITHUB_ACTIONS = 'true'

            # Create test file with error
            $testFile = Join-Path $TestDrive 'ci-test.md'
            Set-Content $testFile "---`ndescription: x`n---`n# Test"

            Mock Write-CIAnnotations { return '::error file=ci-test.md::' }

            $null = Test-FrontmatterValidation -Files @($testFile) -SkipFooterValidation

            # Annotation function should be called in CI environment
            Should -Invoke Write-CIAnnotations -Times 1 -Exactly
        }
    }

    Context 'Step summary generation' {
        It 'Writes to step summary file when GITHUB_STEP_SUMMARY is set' {
            $env:GITHUB_ACTIONS = 'true'
            $stepSummaryPath = Join-Path $TestDrive 'step-summary.md'
            $env:GITHUB_STEP_SUMMARY = $stepSummaryPath

            # Create valid test file
            $testFile = Join-Path $TestDrive 'valid-ci.md'
            Set-Content $testFile "---`ndescription: Valid test file`n---`n# Test"

            $null = Test-FrontmatterValidation -Files @($testFile) -SkipFooterValidation

            # Step summary should be written
            Test-Path $stepSummaryPath | Should -BeTrue
        }

        It 'Writes fail step summary and sets FRONTMATTER_VALIDATION_FAILED env var' {
            Mock Set-CIEnv { }

            $env:GITHUB_ACTIONS = 'true'
            $stepSummaryPath = Join-Path $TestDrive 'step-summary-fail.md'
            $env:GITHUB_STEP_SUMMARY = $stepSummaryPath

            # File without frontmatter generates warning; -WarningsAsErrors makes GetExitCode non-zero
            $testFile = Join-Path $TestDrive 'fail-ci.md'
            Set-Content $testFile "# No Frontmatter`n`nContent without YAML front matter."

            $null = Test-FrontmatterValidation -Files @($testFile) -WarningsAsErrors -SkipFooterValidation

            Test-Path $stepSummaryPath | Should -BeTrue
            $content = Get-Content $stepSummaryPath -Raw
            $content | Should -Match 'Failed'

            # Set-CIEnv writes to GITHUB_ENV file, not in-process env vars
            Should -Invoke Set-CIEnv -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'FRONTMATTER_VALIDATION_FAILED' -and $Value -eq 'true'
            }
        }
    }

    Context 'Main execution error handling with GitHub Actions' {
        It 'Outputs GitHub error annotation when validation throws exception in CI' {
            $env:GITHUB_ACTIONS = 'true'
            
            # Create a file that will cause validation to fail
            $errorFile = Join-Path $TestDrive 'error-test.md'
            # Create malformed content
            Set-Content $errorFile "Malformed content"
            
            # Mock a critical function to throw
            Mock Test-SingleFileFrontmatter { throw 'Validation critical error' }
            
            # Act
            $output = Test-FrontmatterValidation -Files @($errorFile) 2>&1 3>&1
            
            # Assert - Should attempt to output GitHub annotation on error
            # The error annotation is in the catch block
            $hasErrorOutput = $output | Where-Object { $_ -match 'error' }
            $hasErrorOutput | Should -Not -BeNullOrEmpty
        }
    }
}

#endregion


#region Integration Modes Tests

Describe 'Write-CIAnnotations' -Tag 'Unit' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '../../linting/Modules/FrontmatterValidation.psm1') -Force
    }

    Context 'GitHub Actions annotation output' {
        BeforeEach {
            $script:OriginalGHActions = $env:GITHUB_ACTIONS
            $env:GITHUB_ACTIONS = 'true'
        }

        AfterEach {
            if ($null -eq $script:OriginalGHActions) {
                Remove-Item Env:GITHUB_ACTIONS -ErrorAction SilentlyContinue
            }
            else {
                $env:GITHUB_ACTIONS = $script:OriginalGHActions
            }
        }

        It 'Outputs error annotation format for file errors' {
            # Arrange - Create summary with errors
            $summary = & (Get-Module FrontmatterValidation) { [ValidationSummary]::new() }
            $fileResult = & (Get-Module FrontmatterValidation) {
                $result = [FileValidationResult]::new('test/error.md')
                $result.AddError('Missing required field: description', 'description')
                $result
            }
            $summary.AddResult($fileResult)

            # Act - Capture Write-Output
            $output = Write-CIAnnotations -Summary $summary

            # Assert - Should output ::error:: annotation
            $output | Where-Object { $_ -like '::error*' } | Should -Not -BeNullOrEmpty
        }

        It 'Outputs warning annotation format for file warnings' {
            # Arrange - Create summary with warnings only
            $summary = & (Get-Module FrontmatterValidation) { [ValidationSummary]::new() }
            $fileResult = & (Get-Module FrontmatterValidation) {
                $result = [FileValidationResult]::new('test/warning.md')
                $result.AddWarning('Suggested field missing: author', 'author')
                $result
            }
            $summary.AddResult($fileResult)

            # Act - Capture Write-Output
            $output = Write-CIAnnotations -Summary $summary

            # Assert - Should output ::warning:: annotation
            $output | Where-Object { $_ -like '::warning*' } | Should -Not -BeNullOrEmpty
        }

        It 'Includes file path in annotations' {
            # Arrange
            $summary = & (Get-Module FrontmatterValidation) { [ValidationSummary]::new() }
            $fileResult = & (Get-Module FrontmatterValidation) {
                $result = [FileValidationResult]::new('docs/specific-file.md')
                $result.AddError('Test error', 'test')
                $result
            }
            $summary.AddResult($fileResult)

            # Act - Capture Write-Output
            $output = Write-CIAnnotations -Summary $summary

            # Assert - Annotation should include file path
            $output | Where-Object { $_ -like '*file=*specific-file*' } | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Empty Input Handling' -Tag 'Unit' {
    Context 'No files to validate' {
        It 'Warns when path contains no markdown files' {
            # Arrange
            $emptyDir = Join-Path $TestDrive 'empty-dir'
            New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null

            # Act & Assert - Test-FrontmatterValidation should handle empty gracefully
            $result = Test-FrontmatterValidation -Paths @($emptyDir) -WarningVariable warnings 3>$null
            $result.TotalFiles | Should -Be 0
        }

        It 'Returns empty summary when all files are excluded' {
            # Arrange
            $excludeDir = Join-Path $TestDrive 'exclude-all'
            $nodeModules = Join-Path $excludeDir 'node_modules'
            New-Item -ItemType Directory -Path $nodeModules -Force | Out-Null
            Set-Content -Path (Join-Path $nodeModules 'readme.md') -Value "---`ndescription: excluded`n---"

            # Act
            $result = Test-FrontmatterValidation -Paths @($excludeDir) -ExcludePaths @('**/node_modules/**')
            
            # Assert
            $result.TotalFiles | Should -Be 0
        }
    }
}


#region Schema Pattern Matching Tests

Describe 'Schema Pattern Matching' -Tag 'Unit' {
    BeforeAll {
        $script:MainScript = Join-Path $PSScriptRoot '../../linting/Validate-MarkdownFrontmatter.ps1'
    }

    Context 'Pipe-separated and Array patterns' {
        It 'Validates pipe-separated patterns in applyTo' {
            # Arrange
            $testFile = Join-Path $TestDrive 'pipe-patterns.md'
            Set-Content -Path $testFile -Value @"
---
description: test
applyTo: "**/*.ts | **/*.tsx | **/*.js"
---
"@

            # Act
            $result = Test-SingleFileFrontmatter -FilePath $testFile -RepoRoot $TestDrive

            # Assert - Should accept pipe-separated patterns
            $result.Issues | Where-Object { $_.Field -eq 'applyTo' -and $_.Type -eq 'Error' } | Should -BeNullOrEmpty
        }

        It 'Validates comma-separated patterns in applyTo array' {
            # Arrange
            $testFile = Join-Path $TestDrive 'array-patterns.md'
            Set-Content -Path $testFile -Value @"
---
description: test
applyTo:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/components/**"
---
"@

            # Act
            $result = Test-SingleFileFrontmatter -FilePath $testFile -RepoRoot $TestDrive

            # Assert - Array format should be valid
            $result.Issues | Where-Object { $_.Field -eq 'applyTo' -and $_.Type -eq 'Error' } | Should -BeNullOrEmpty
        }
    }

    Context 'Glob pattern validation' {
        It 'Validates double-star glob patterns' {
            # Arrange
            $testFile = Join-Path $TestDrive 'glob-doublestar.md'
            Set-Content -Path $testFile -Value @"
---
description: test
applyTo: "**/src/**/*.ts"
---
"@

            # Act
            $result = Test-SingleFileFrontmatter -FilePath $testFile -RepoRoot $TestDrive

            # Assert
            $result.Issues | Where-Object { $_.Field -eq 'applyTo' -and $_.Type -eq 'Error' } | Should -BeNullOrEmpty
        }

        It 'Validates single-star glob patterns' {
            # Arrange
            $testFile = Join-Path $TestDrive 'glob-singlestar.md'
            Set-Content -Path $testFile -Value @"
---
description: test
applyTo: "src/*.ts"
---
"@

            # Act
            $result = Test-SingleFileFrontmatter -FilePath $testFile -RepoRoot $TestDrive

            # Assert
            $result.Issues | Where-Object { $_.Field -eq 'applyTo' -and $_.Type -eq 'Error' } | Should -BeNullOrEmpty
        }

        It 'Validates question mark wildcard patterns' {
            # Arrange
            $testFile = Join-Path $TestDrive 'glob-question.md'
            Set-Content -Path $testFile -Value @"
---
description: test
applyTo: "src/file?.ts"
---
"@

            # Act
            $result = Test-SingleFileFrontmatter -FilePath $testFile -RepoRoot $TestDrive

            # Assert
            $result.Issues | Where-Object { $_.Field -eq 'applyTo' -and $_.Type -eq 'Error' } | Should -BeNullOrEmpty
        }

        It 'Validates brace expansion patterns' {
            # Arrange
            $testFile = Join-Path $TestDrive 'glob-braces.md'
            Set-Content -Path $testFile -Value @"
---
description: test
applyTo: "**/*.{ts,tsx,js,jsx}"
---
"@

            # Act
            $result = Test-SingleFileFrontmatter -FilePath $testFile -RepoRoot $TestDrive

            # Assert
            $result.Issues | Where-Object { $_.Field -eq 'applyTo' -and $_.Type -eq 'Error' } | Should -BeNullOrEmpty
        }
    }
}

#endregion

#endregion
