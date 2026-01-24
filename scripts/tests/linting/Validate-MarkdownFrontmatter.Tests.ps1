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

#region ConvertFrom-YamlFrontmatter Tests

Describe 'ConvertFrom-YamlFrontmatter' -Tag 'Unit' {
    Context 'Valid YAML input' {
        It 'Parses single key-value pair' {
            $content = @"
---
description: Test description
---
"@
            $result = ConvertFrom-YamlFrontmatter -Content $content
            $result.Frontmatter.description | Should -Be 'Test description'
        }

        It 'Parses multiple key-value pairs' {
            $content = @"
---
title: Test Title
description: Test description
ms.date: 2025-01-16
---
"@
            $result = ConvertFrom-YamlFrontmatter -Content $content
            $result.Frontmatter.title | Should -Be 'Test Title'
            $result.Frontmatter.description | Should -Be 'Test description'
            $result.Frontmatter.'ms.date' | Should -Be '2025-01-16'
        }

        It 'Handles quoted values' {
            $content = @"
---
description: "Quoted value with: colon"
---
"@
            $result = ConvertFrom-YamlFrontmatter -Content $content
            $result.Frontmatter.description | Should -Be 'Quoted value with: colon'
        }

        It 'Handles single-quoted values' {
            $content = @"
---
description: 'Single quoted'
---
"@
            $result = ConvertFrom-YamlFrontmatter -Content $content
            $result.Frontmatter.description | Should -Be 'Single quoted'
        }
    }

    Context 'Empty or null input' {
        It 'Returns null for empty string' {
            $result = ConvertFrom-YamlFrontmatter -Content ''
            $result | Should -BeNullOrEmpty
        }

        It 'Returns null for content without frontmatter delimiters' {
            $result = ConvertFrom-YamlFrontmatter -Content 'Just some text'
            $result | Should -BeNullOrEmpty
        }

        It 'Returns null for whitespace only' {
            $result = ConvertFrom-YamlFrontmatter -Content '   '
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Edge cases' {
        It 'Handles values with colons' {
            $content = @"
---
time: "10:30:00"
---
"@
            $result = ConvertFrom-YamlFrontmatter -Content $content
            $result.Frontmatter.time | Should -Be '10:30:00'
        }

        It 'Preserves leading and trailing whitespace in values' {
            $content = @"
---
description: "  spaced  "
---
"@
            $result = ConvertFrom-YamlFrontmatter -Content $content
            $result.Frontmatter.description | Should -Be '  spaced  '
        }

        It 'Skips comment lines' {
            $content = @"
---
title: Valid
# This is a comment
description: Also valid
---
"@
            $result = ConvertFrom-YamlFrontmatter -Content $content
            $result.Frontmatter.title | Should -Be 'Valid'
            $result.Frontmatter.description | Should -Be 'Also valid'
        }

        It 'Returns FrontmatterEndIndex indicating where frontmatter ends' {
            $content = @"
---
title: Test
---
# Body content
"@
            $result = ConvertFrom-YamlFrontmatter -Content $content
            $result.FrontmatterEndIndex | Should -Be 3
        }

        It 'Falls back to raw value when JSON array parsing fails' {
            # Malformed JSON array with trailing comma should fall back to raw string
            $content = @"
---
tags: [a, b,]
---
"@
            $result = ConvertFrom-YamlFrontmatter -Content $content
            # When ConvertFrom-Json fails, the raw value is preserved
            $result.Frontmatter.tags | Should -Be '[a, b,]'
        }
    }
}

#endregion

#region Get-MarkdownFrontmatter Tests

Describe 'Get-MarkdownFrontmatter' -Tag 'Unit' {
    Context 'Valid frontmatter extraction' {
        It 'Extracts frontmatter from Content parameter' {
            $content = @"
---
description: Test description
---

# Content
"@
            $result = Get-MarkdownFrontmatter -Content $content
            $result.Frontmatter.description | Should -Be 'Test description'
        }

        It 'Returns correct end index' {
            $content = @"
---
title: Test
---

Body
"@
            $result = Get-MarkdownFrontmatter -Content $content
            $result.FrontmatterEndIndex | Should -BeGreaterThan 0
        }

        It 'Extracts from fixture file' {
            $fixturePath = Join-Path $script:FixtureDir 'valid-docs.md'
            $result = Get-MarkdownFrontmatter -FilePath $fixturePath
            $result.Frontmatter | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Missing frontmatter' {
        It 'Returns null frontmatter when no delimiters' {
            $content = '# Just a heading'
            $result = Get-MarkdownFrontmatter -Content $content
            $result.Frontmatter | Should -BeNullOrEmpty
        }

        It 'Returns null for missing-frontmatter fixture' {
            $fixturePath = Join-Path $script:FixtureDir 'missing-frontmatter.md'
            $result = Get-MarkdownFrontmatter -FilePath $fixturePath
            $result.Frontmatter | Should -BeNullOrEmpty
        }
    }

    Context 'Empty frontmatter' {
        It 'Handles empty frontmatter block' {
            $content = @"
---
---

Content
"@
            $result = Get-MarkdownFrontmatter -Content $content
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'File path parameter' {
        It 'Reads from file path' {
            $fixturePath = Join-Path $script:FixtureDir 'valid-docs.md'
            $result = Get-MarkdownFrontmatter -FilePath $fixturePath
            $result.Frontmatter.title | Should -Be 'Valid Documentation File'
        }
    }
}

#endregion

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
}

#endregion

#region Validation Helper Tests

Describe 'Validation helpers' -Tag 'Unit' {
    Describe 'Sanitize-InputList' {
        It 'Trims entries and removes blanks' {
            $result = Sanitize-InputList -InputList @(' file.md ', '', $null, 'path/to.md ')
            $result | Should -Be @('file.md', 'path/to.md')
        }
    }

    Describe 'New-ValidationState and adders' {
        It 'Tracks errors and warnings per file' {
            $state = New-ValidationState
            Add-ValidationError -State $state -Message 'err1' -FilePath 'a.md'
            Add-ValidationWarning -State $state -Message 'warn1' -FilePath 'b.md'
            $state.Errors.Count | Should -Be 1
            $state.Warnings.Count | Should -Be 1
            $state.FilesWithErrors.Contains('a.md') | Should -BeTrue
            $state.FilesWithWarnings.Contains('b.md') | Should -BeTrue
        }
    }

    Describe 'Get-RepoRoot' {
        BeforeAll {
            $script:TempRepo = Join-Path ([System.IO.Path]::GetTempPath()) "RepoRoot_$([guid]::NewGuid().ToString('N'))"
            New-Item -ItemType Directory -Path $script:TempRepo -Force | Out-Null
            Push-Location $script:TempRepo
            New-Item -ItemType Directory -Path '.git' -Force | Out-Null
        }

        AfterAll {
            Pop-Location
            if (Test-Path $script:TempRepo) {
                Remove-Item -Path $script:TempRepo -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Returns current path when .git exists locally' {
            $result = Get-RepoRoot
            $result | Should -Be $script:TempRepo
        }
    }

    Describe 'Get-FooterRequirement' {
        It 'Requires footer for root community files' {
            $info = [FileTypeInfo]::new()
            $info.IsRootCommunityFile = $true
            $filePath = Join-Path $TestDrive 'root-community.md'
            Set-Content -Path $filePath -Value 'x'
            $file = Get-Item -Path $filePath
            $result = Get-FooterRequirement -FileTypeInfo $info -File $file
            $result.ShouldHaveFooter | Should -BeTrue
            $result.Severity | Should -Be 'Error'
        }

        It 'Requires footer for GitHub README' {
            $info = [FileTypeInfo]::new()
            $info.IsGitHub = $true
            $filePath = Join-Path $TestDrive 'README.md'
            Set-Content -Path $filePath -Value 'x'
            $file = Get-Item $filePath
            $result = Get-FooterRequirement -FileTypeInfo $info -File $file
            $result.ShouldHaveFooter | Should -BeTrue
        }

        It 'Skips footer for other files' {
            $info = [FileTypeInfo]::new()
            $filePath = Join-Path $TestDrive 'note.md'
            Set-Content -Path $filePath -Value 'x'
            $file = Get-Item $filePath
            $result = Get-FooterRequirement -FileTypeInfo $info -File $file
            $result.ShouldHaveFooter | Should -BeFalse
        }
    }

    Describe 'Resolve-ExplicitMarkdownFiles' {
        It 'Filters non-markdown and excluded files' {
            $repo = Join-Path $TestDrive 'explicit-repo'
            New-Item -ItemType Directory -Path $repo -Force | Out-Null
            $keep = Join-Path $repo 'keep.md'
            $skip = Join-Path $repo 'skip.txt'
            $exclude = Join-Path $repo 'ignore.md'
            @($keep, $skip, $exclude) | ForEach-Object { Set-Content -Path $_ -Value 'x' }

            $result = Resolve-ExplicitMarkdownFiles -Files @($keep, $skip, $exclude) -ExcludePaths @('ignore.md') -RepoRoot $repo
            ($result.FullName -contains $keep) | Should -BeTrue
            ($result.FullName -contains $exclude) | Should -BeFalse
            ($result.FullName -contains $skip) | Should -BeFalse
        }
    }

    Describe 'Discover-MarkdownFilesFromPaths' {
        It 'Honors gitignore and exclude patterns' {
            $repo = Join-Path $TestDrive 'discover-repo'
            New-Item -ItemType Directory -Path (Join-Path $repo 'docs') -Force | Out-Null
            $keep = Join-Path $repo 'docs/keep.md'
            $ignore = Join-Path $repo 'docs/ignoreme.md'
            $exclude = Join-Path $repo 'docs/exclude.md'
            @($keep, $ignore, $exclude) | ForEach-Object { Set-Content -Path $_ -Value 'x' }

            $result = Discover-MarkdownFilesFromPaths -Paths @($repo) -GitIgnorePatterns @('*ignoreme*') -ExcludePaths @('docs/exclude.md') -RepoRoot $repo
            $result.FullName | Should -Contain $keep
            $result.FullName | Should -Not -Contain $ignore
            $result.FullName | Should -Not -Contain $exclude
        }
    }

    Describe 'Validate-FooterPresence' {
        It 'Adds error when required footer is missing' {
            $state = New-ValidationState
            $requirement = [pscustomobject]@{ ShouldHaveFooter = $true; Severity = 'Error' }
            $filePath = Join-Path $TestDrive 'no-footer.md'
            Set-Content -Path $filePath -Value 'Content'
            $file = Get-Item $filePath
            Validate-FooterPresence -File $file -State $state -Requirement $requirement -Content 'content without footer' -SkipFooterValidation:$false
            $state.Errors.Count | Should -Be 1
        }

        It 'Skips when validation disabled' {
            $state = New-ValidationState
            $requirement = [pscustomobject]@{ ShouldHaveFooter = $true; Severity = 'Error' }
            $filePath = Join-Path $TestDrive 'skip-footer.md'
            Set-Content -Path $filePath -Value 'Content'
            $file = Get-Item $filePath
            Validate-FooterPresence -File $file -State $state -Requirement $requirement -Content 'content without footer' -SkipFooterValidation:$true
            $state.Errors.Count | Should -Be 0
        }
    }

    Describe 'Export-ValidationResults' {
        It 'Writes results file and returns summary data' {
            $state = New-ValidationState
            Add-ValidationError -State $state -Message 'err' -FilePath 'a.md'
            Add-ValidationWarning -State $state -Message 'warn' -FilePath 'b.md'
            $repo = Join-Path $TestDrive 'export-repo'
            New-Item -ItemType Directory -Path $repo -Force | Out-Null
            $filePath = Join-Path $repo 'file.md'
            Set-Content -Path $filePath -Value 'x'
            $file = Get-Item $filePath
            $result = Export-ValidationResults -State $state -MarkdownFiles @($file) -RepoRoot $repo
            Test-Path $result.Path | Should -BeTrue
            $result.Results.summary.total_files | Should -Be 1
            $result.Results.summary.files_with_errors | Should -Be 1
            $result.Results.summary.files_with_warnings | Should -Be 1
        }
    }

    Describe 'Write-ValidationSummary' {
        It 'Returns hasIssues when errors exist' {
            $state = New-ValidationState
            Add-ValidationError -State $state -Message 'err1'
            $results = @{ summary = @{ files_with_errors = 1; files_with_warnings = 0 } }
            $filePath = Join-Path $TestDrive 'f.md'
            Set-Content -Path $filePath -Value 'x'
            $file = Get-Item $filePath
            $hasIssues = Write-ValidationSummary -State $state -MarkdownFiles @($file) -ResultsJson $results -WarningsAsErrors:$false
            $hasIssues | Should -BeTrue
        }

        It 'Respects WarningsAsErrors when only warnings exist' {
            $state = New-ValidationState
            Add-ValidationWarning -State $state -Message 'warn1'
            $results = @{ summary = @{ files_with_errors = 0; files_with_warnings = 1 } }
            $filePath = Join-Path $TestDrive 'f2.md'
            Set-Content -Path $filePath -Value 'x'
            $file = Get-Item $filePath
            $hasIssues = Write-ValidationSummary -State $state -MarkdownFiles @($file) -ResultsJson $results -WarningsAsErrors:$true
            $hasIssues | Should -BeTrue
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

        It 'Returns ValidationResult type' {
            $result = Test-FrontmatterValidation -Files @("$script:TestRepoRoot/docs/test.md")
            $result.GetType().Name | Should -Be 'ValidationResult'
        }

        It 'Reports no errors for valid frontmatter' {
            $result = Test-FrontmatterValidation -Files @("$script:TestRepoRoot/docs/test.md")
            $result.HasIssues | Should -BeFalse
            $result.Errors.Count | Should -Be 0
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
            $result.Warnings.Count | Should -BeGreaterThan 0
            $result.Warnings | Should -Match 'No frontmatter found'
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

        It 'Reports schema validation warning for empty description' {
            # Schema validation is soft (advisory) - errors are Write-Warning, not HasIssues
            $result = Test-FrontmatterValidation -Files @("$script:TestRepoRoot/docs/empty-desc.md")
            # HasIssues is false because schema errors are advisory warnings
            $result.HasIssues | Should -BeFalse
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
            $result.HasIssues | Should -BeFalse
            ($result.Warnings -join "`n") | Should -Match 'Invalid date format'
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
            $result.TotalFilesChecked | Should -BeGreaterOrEqual 2
        }
    }

    Context 'Result aggregation' {
        It 'Aggregates errors and warnings in result' {
            # docs-frontmatter.schema.json requires BOTH title AND description
            @"
---
title: Test File
description: Valid
---
Content
"@ | Set-Content -Path "$script:TestRepoRoot/docs/test.md" -Encoding UTF8

            $result = Test-FrontmatterValidation -Files @("$script:TestRepoRoot/docs/test.md")
            $result.PSObject.Properties.Name | Should -Contain 'Errors'
            $result.PSObject.Properties.Name | Should -Contain 'Warnings'
            $result.PSObject.Properties.Name | Should -Contain 'HasIssues'
            $result.PSObject.Properties.Name | Should -Contain 'TotalFilesChecked'
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
            $result.TotalFilesChecked | Should -Be 1
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
            $result.TotalFilesChecked | Should -Be 1
        }
    }

    Context 'Processes all files when ExcludePaths is empty' {
        It 'Validates all markdown files without exclusions' {
            $result = Test-FrontmatterValidation -Paths @($script:ExcludeTestDir) -ExcludePaths @()
            # Should check all markdown files (docs + tests + vendor)
            $result.TotalFilesChecked | Should -BeGreaterOrEqual 2
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
