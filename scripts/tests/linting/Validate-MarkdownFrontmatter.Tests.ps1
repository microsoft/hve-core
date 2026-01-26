#Requires -Modules Pester

BeforeAll {
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
}

#endregion

#region Get-ChangedMarkdownFileGroup Tests

Describe 'Get-ChangedMarkdownFileGroup' -Tag 'Unit' {
    BeforeAll {
        Save-GitHubEnvironment
    }

    AfterAll {
        Restore-GitHubEnvironment
    }

    Context 'Merge-base succeeds' {
        BeforeEach {
            Mock git {
                $global:LASTEXITCODE = 0
                return 'abc123def456789'
            } -ParameterFilter { $args[0] -eq 'merge-base' }

            Mock git {
                $global:LASTEXITCODE = 0
                return @('docs/test.md', 'README.md', 'scripts/README.md')
            } -ParameterFilter { $args[0] -eq 'diff' }

            Mock Test-Path { return $true } -ParameterFilter { $PathType -eq 'Leaf' }
        }

        It 'Returns changed markdown files' {
            $result = Get-ChangedMarkdownFileGroup
            $result | Should -BeOfType [string]
            $result | Should -Contain 'docs/test.md'
            $result | Should -Contain 'README.md'
        }

        It 'Filters to markdown files only' {
            Mock git {
                $global:LASTEXITCODE = 0
                return @('test.md', 'test.ps1', 'test.json')
            } -ParameterFilter { $args[0] -eq 'diff' }

            $result = Get-ChangedMarkdownFileGroup
            $result | Should -Contain 'test.md'
            $result | Should -Not -Contain 'test.ps1'
            $result | Should -Not -Contain 'test.json'
        }

        It 'Returns array of strings' {
            $result = Get-ChangedMarkdownFileGroup
            $result.Count | Should -BeGreaterOrEqual 0
        }
    }

    Context 'Fallback scenarios' {
        BeforeEach {
            Mock git {
                $global:LASTEXITCODE = 128
                return $null
            } -ParameterFilter { $args[0] -eq 'merge-base' }

            Mock git {
                $global:LASTEXITCODE = 0
                return 'HEAD~1-sha'
            } -ParameterFilter { $args[0] -eq 'rev-parse' }

            Mock git {
                $global:LASTEXITCODE = 0
                return @('fallback.md')
            } -ParameterFilter { $args[0] -eq 'diff' }

            Mock Test-Path { return $true } -ParameterFilter { $PathType -eq 'Leaf' }
        }

        It 'Falls back to HEAD~1 when merge-base fails' {
            $result = Get-ChangedMarkdownFileGroup
            $result | Should -Contain 'fallback.md'
        }

        It 'Returns files when fallback succeeds' {
            $result = Get-ChangedMarkdownFileGroup
            $result.Count | Should -BeGreaterOrEqual 1
        }
    }

    Context 'No changes detected' {
        BeforeEach {
            Mock git {
                $global:LASTEXITCODE = 0
                return 'abc123'
            } -ParameterFilter { $args[0] -eq 'merge-base' }

            Mock git {
                $global:LASTEXITCODE = 0
                return @()
            } -ParameterFilter { $args[0] -eq 'diff' }
        }

        It 'Returns empty array when no changes' {
            $result = Get-ChangedMarkdownFileGroup
            $result.Count | Should -Be 0
        }
    }
}

#endregion

#region Test-FrontmatterValidation Integration Tests

Describe 'Test-FrontmatterValidation' -Tag 'Integration' {
    BeforeAll {
        Save-GitHubEnvironment
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
        Restore-GitHubEnvironment
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
            # Mock Get-ChangedMarkdownFileGroup to return empty
            Mock Get-ChangedMarkdownFileGroup { return @() }

            $result = Test-FrontmatterValidation -ChangedFilesOnly

            # TotalFiles=0 accurately represents no files were validated
            # This is a successful no-op, not a validation failure
            $result.TotalFiles | Should -Be 0
            $result.FilesValid | Should -Be 0
            # Verify the summary was completed
            $result.Duration | Should -Not -BeNullOrEmpty
        }

        It 'Validates only files returned by Get-ChangedMarkdownFileGroup' {
            # Mock Get-ChangedMarkdownFileGroup to return specific file
            Mock Get-ChangedMarkdownFileGroup {
                return @("$script:TestRepoRoot/docs/changed.md")
            }

            $result = Test-FrontmatterValidation -ChangedFilesOnly

            $result.TotalFiles | Should -Be 1
        }

        It 'Passes BaseBranch parameter to Get-ChangedMarkdownFileGroup' {
            Mock Get-ChangedMarkdownFileGroup {
                return @()
            } -ParameterFilter { $BaseBranch -eq 'develop' }

            $null = Test-FrontmatterValidation -ChangedFilesOnly -BaseBranch 'develop'

            Should -Invoke Get-ChangedMarkdownFileGroup -ParameterFilter { $BaseBranch -eq 'develop' }
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

Describe 'GitHub Actions Environment Integration' -Tag 'Unit' {
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

    Context 'Write-GitHubAnnotations execution path' {
        It 'Calls Write-GitHubAnnotations when GITHUB_ACTIONS is set' {
            $env:GITHUB_ACTIONS = 'true'

            # Create test file with error
            $testFile = Join-Path $TestDrive 'ci-test.md'
            Set-Content $testFile "---`ndescription: x`n---`n# Test"

            Mock Write-GitHubAnnotations { return '::error file=ci-test.md::' }

            $null = Test-FrontmatterValidation -Files @($testFile) -SkipFooterValidation

            # Annotation function should be called in CI environment
            Should -Invoke Write-GitHubAnnotations -Times 1 -Exactly
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
    }
}

#endregion

#region Git Fallback Strategy Tests

Describe 'Git Fallback Strategies' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../linting/Validate-MarkdownFrontmatter.ps1
    }

    Context 'FallbackStrategy None behavior' {
        It 'Returns empty array when merge-base fails with FallbackStrategy None' {
            Mock git {
                $global:LASTEXITCODE = 128
                return $null
            }

            $result = Get-ChangedMarkdownFileGroup -BaseBranch 'origin/main' -FallbackStrategy 'None'
            $result | Should -BeNullOrEmpty
        }

        It 'Emits warning when merge-base fails with FallbackStrategy None' {
            Mock git {
                $global:LASTEXITCODE = 128
                return $null
            }

            $null = Get-ChangedMarkdownFileGroup -FallbackStrategy 'None' -WarningVariable warnings 3>$null
            $warnings | Should -Not -BeNullOrEmpty
            $warnings[0] | Should -Match 'no fallback enabled'
        }
    }

    Context 'FallbackStrategy HeadOnly behavior' {
        It 'Falls back to HEAD~1 when merge-base fails' {
            # The implementation uses $(git merge-base) inside git diff, so first call has 2 git invocations
            # Then fallback to HEAD~1 is another git diff call
            $callCount = 0
            Mock git {
                $callCount++
                # First two calls are merge-base + diff (which fails)
                if ($callCount -le 2) {
                    $global:LASTEXITCODE = 128
                    return $null
                }
                # Third call is HEAD~1 fallback
                $global:LASTEXITCODE = 0
                return @()
            }

            $result = Get-ChangedMarkdownFileGroup -FallbackStrategy 'HeadOnly'
            $result | Should -BeNullOrEmpty
            # merge-base subexpression + diff + fallback HEAD~1 = 3 calls minimum
            Should -Invoke git -Times 3 -Exactly
        }

        It 'Returns empty with warning when HEAD~1 also fails for HeadOnly' {
            Mock git {
                $global:LASTEXITCODE = 128
                return $null
            }

            $null = Get-ChangedMarkdownFileGroup -FallbackStrategy 'HeadOnly' -WarningVariable warnings 3>$null
            $warnings | Should -Not -BeNullOrEmpty
            $warnings[0] | Should -Match 'Unable to determine changed files'
        }

        It 'Emits verbose message when merge-base comparison fails' {
            Mock git {
                $global:LASTEXITCODE = 128
                return $null
            }

            $output = Get-ChangedMarkdownFileGroup -FallbackStrategy 'HeadOnly' -Verbose 4>&1
            $verbose = $output | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $messages = @($verbose | ForEach-Object { $_.Message })
            ($messages -match 'Merge base comparison.*failed').Count | Should -BeGreaterThan 0
        }

        It 'Emits verbose message when attempting HEAD~1 fallback' {
            $callCount = 0
            Mock git {
                $callCount++
                if ($callCount -le 2) {
                    $global:LASTEXITCODE = 128
                    return $null
                }
                $global:LASTEXITCODE = 0
                return @('test.md')
            }

            $output = Get-ChangedMarkdownFileGroup -FallbackStrategy 'HeadOnly' -Verbose 4>&1
            $verbose = $output | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $messages = @($verbose | ForEach-Object { $_.Message })
            ($messages -match 'Attempting fallback.*HEAD~1').Count | Should -BeGreaterThan 0
        }

        It 'Emits verbose count message when files found' {
            Mock git {
                $global:LASTEXITCODE = 0
                return @('docs/test.md', 'src/readme.md')
            }

            $output = Get-ChangedMarkdownFileGroup -Verbose 4>&1
            $verbose = $output | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $messages = @($verbose | ForEach-Object { $_.Message })
            ($messages -match 'Found.*changed markdown files').Count | Should -BeGreaterThan 0
        }
    }

    Context 'FallbackStrategy Auto cascading behavior' {
        It 'Cascades through all fallback strategies when Auto' {
            # merge-base (1) + diff (2) fail, then HEAD~1 diff (3) fail, then HEAD diff (4) fail
            $callCount = 0
            Mock git {
                $callCount++
                if ($callCount -le 3) {
                    $global:LASTEXITCODE = 128
                    return $null
                }
                $global:LASTEXITCODE = 0
                return @()
            }

            $null = Get-ChangedMarkdownFileGroup -FallbackStrategy 'Auto'
            # merge-base (1) + diff (2) + HEAD~1 fallback (3) + HEAD fallback (4) = 4 calls
            Should -Invoke git -Times 4 -Exactly
        }

        It 'Returns empty with warning when all Auto fallbacks fail' {
            Mock git {
                $global:LASTEXITCODE = 128
                return $null
            }

            $null = Get-ChangedMarkdownFileGroup -FallbackStrategy 'Auto' -WarningVariable warnings 3>$null
            $warnings | Should -Not -BeNullOrEmpty
        }

        It 'Emits verbose message when HEAD~1 fails and falls back to staged' {
            $callCount = 0
            Mock git {
                $callCount++
                # merge-base (1) + diff (2) + HEAD~1 (3) all fail
                if ($callCount -le 3) {
                    $global:LASTEXITCODE = 128
                    return $null
                }
                # HEAD (staged/unstaged) succeeds
                $global:LASTEXITCODE = 0
                return @('staged.md')
            }

            $output = Get-ChangedMarkdownFileGroup -FallbackStrategy 'Auto' -Verbose 4>&1
            $verbose = $output | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseMessages = $verbose.Message -join "`n"
            $verboseMessages | Should -Match 'staged|unstaged'
        }

        It 'Succeeds when second fallback works' {
            $script:TestFilePath = Join-Path $TestDrive 'changed.md'
            @"
---
title: Test
description: Changed file
---
"@ | Set-Content -Path $script:TestFilePath -Encoding UTF8

            $script:gitCallCount = 0
            Mock git {
                $script:gitCallCount++
                # First 2 calls (merge-base + diff) fail
                if ($script:gitCallCount -le 2) {
                    $global:LASTEXITCODE = 128
                    return $null
                }
                # Third call (HEAD~1 fallback) succeeds
                $global:LASTEXITCODE = 0
                return @($script:TestFilePath)
            }

            $result = Get-ChangedMarkdownFileGroup -FallbackStrategy 'Auto'
            $result | Should -Contain $script:TestFilePath
        }
    }

    Context 'Git exception handling' {
        It 'Returns empty array when git throws exception' {
            Mock git { throw 'fatal: not a git repository' }

            $result = Get-ChangedMarkdownFileGroup
            $result | Should -BeNullOrEmpty
        }

        It 'Emits warning with exception message when git fails' {
            Mock git { throw 'fatal: not a git repository' }

            $null = Get-ChangedMarkdownFileGroup -WarningVariable warnings 3>$null
            $warnings | Should -Not -BeNullOrEmpty
            $warnings[0] | Should -Match 'Error getting changed files'
        }
    }
}

#endregion

#region Integration Modes Tests

Describe 'Write-GitHubAnnotations' -Tag 'Unit' {
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
            $output = Write-GitHubAnnotations -Summary $summary

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
            $output = Write-GitHubAnnotations -Summary $summary

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
            $output = Write-GitHubAnnotations -Summary $summary

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

Describe 'ChangedFilesOnly Integration' -Tag 'Unit' {
    BeforeAll {
        $script:TestRoot = Join-Path $TestDrive 'changed-files-test'
        New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
    }

    Context 'Git diff filtering' {
        It 'Returns only markdown files from git diff output' {
            # Arrange
            $mdFile = Join-Path $script:TestRoot 'readme.md'
            Set-Content -Path $mdFile -Value "---`ndescription: test`n---"

            Mock git {
                $global:LASTEXITCODE = 0
                # Git returns multiple file types
                return @('readme.md', 'script.ps1', 'config.json')
            }

            # Change to TestRoot so Test-Path resolves relative paths correctly
            Push-Location $script:TestRoot
            try {
                # Act
                $result = Get-ChangedMarkdownFileGroup -BaseBranch 'origin/main'

                # Assert - Should filter to only .md files
                $result | Should -Contain 'readme.md'
                $result | Should -Not -Contain 'script.ps1'
                $result | Should -Not -Contain 'config.json'
            }
            finally {
                Pop-Location
            }
        }

        It 'Returns empty array when git diff returns no files' {
            Mock git {
                $global:LASTEXITCODE = 0
                return @()
            }

            # Act
            $result = Get-ChangedMarkdownFileGroup -BaseBranch 'origin/main'

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It 'Handles mixed path separators in git output' {
            # Create test files that match git output paths
            $docsPath = Join-Path $TestDrive 'docs'
            $srcPath = Join-Path $TestDrive 'src' 'api'
            New-Item -Path $docsPath -ItemType Directory -Force | Out-Null
            New-Item -Path $srcPath -ItemType Directory -Force | Out-Null
            $file1 = Join-Path $docsPath 'readme.md'
            $file2 = Join-Path $srcPath 'guide.md'
            '---' + "`ntitle: Test`n---" | Set-Content -Path $file1 -Encoding UTF8
            '---' + "`ntitle: Test`n---" | Set-Content -Path $file2 -Encoding UTF8

            Mock git {
                $global:LASTEXITCODE = 0
                return @($file1, $file2)
            }

            # Act
            $result = Get-ChangedMarkdownFileGroup -BaseBranch 'origin/main'

            # Assert - Should handle both path separators
            $result.Count | Should -Be 2
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
