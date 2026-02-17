# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

#Requires -Modules Pester

BeforeAll {
    # Dot-source the main script
    $scriptPath = Join-Path $PSScriptRoot '../../linting/Validate-SkillStructure.ps1'
    . $scriptPath

    $mockPath = Join-Path $PSScriptRoot '../Mocks/GitMocks.psm1'
    Import-Module $mockPath -Force

    # Temp directory for test isolation
    $script:TempTestDir = Join-Path ([System.IO.Path]::GetTempPath()) "SkillStructureTests_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:TempTestDir -Force | Out-Null

    function New-TestSkillDirectory {
        param(
            [string]$SkillName,
            [string]$FrontmatterContent,
            [switch]$NoSkillMd,
            [switch]$WithScriptsDir,
            [switch]$WithEmptyScriptsDir,
            [switch]$WithUnrecognizedDir,
            [string[]]$OptionalDirs = @()
        )

        $skillDir = Join-Path $script:TempTestDir $SkillName
        New-Item -ItemType Directory -Path $skillDir -Force | Out-Null

        if (-not $NoSkillMd) {
            $skillMdPath = Join-Path $skillDir 'SKILL.md'
            if ($FrontmatterContent) {
                Set-Content -Path $skillMdPath -Value $FrontmatterContent
            }
            else {
                Set-Content -Path $skillMdPath -Value '# Test Skill'
            }
        }

        if ($WithScriptsDir) {
            $scriptsDir = Join-Path $skillDir 'scripts'
            New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
            Set-Content -Path (Join-Path $scriptsDir 'test.sh') -Value '#!/bin/bash'
        }

        if ($WithEmptyScriptsDir) {
            New-Item -ItemType Directory -Path (Join-Path $skillDir 'scripts') -Force | Out-Null
        }

        if ($WithUnrecognizedDir) {
            New-Item -ItemType Directory -Path (Join-Path $skillDir 'random-dir') -Force | Out-Null
        }

        foreach ($dir in $OptionalDirs) {
            New-Item -ItemType Directory -Path (Join-Path $skillDir $dir) -Force | Out-Null
        }

        return Get-Item $skillDir
    }
}

AfterAll {
    if ($script:TempTestDir -and (Test-Path $script:TempTestDir)) {
        Remove-Item -Path $script:TempTestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    Remove-Module CIHelpers -Force -ErrorAction SilentlyContinue
    Remove-Module GitMocks -Force -ErrorAction SilentlyContinue
    Remove-Module LintingHelpers -Force -ErrorAction SilentlyContinue
}

#region Get-SkillFrontmatter Tests

Describe 'Get-SkillFrontmatter' -Tag 'Unit' {
    Context 'Valid frontmatter' {
        It 'Returns hashtable for valid frontmatter with name and description' {
            $content = @"
---
name: test-skill
description: A test skill for validation
---

# Test Skill
"@
            $filePath = Join-Path $script:TempTestDir 'valid-fm.md'
            Set-Content -Path $filePath -Value $content

            $result = Get-SkillFrontmatter -Path $filePath
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [hashtable]
            $result['name'] | Should -BeExactly 'test-skill'
            $result['description'] | Should -BeExactly 'A test skill for validation'
        }

        It 'Strips single-quoted values correctly' {
            $content = @"
---
name: 'my-skill'
description: 'A skill with single quotes - Brought to you by microsoft/hve-core'
---

# Skill
"@
            $filePath = Join-Path $script:TempTestDir 'single-quoted.md'
            Set-Content -Path $filePath -Value $content

            $result = Get-SkillFrontmatter -Path $filePath
            $result | Should -Not -BeNullOrEmpty
            $result['name'] | Should -BeExactly 'my-skill'
            $result['description'] | Should -BeExactly 'A skill with single quotes - Brought to you by microsoft/hve-core'
        }

        It 'Strips double-quoted values correctly' {
            $content = @"
---
name: "double-skill"
description: "A skill with double quotes"
---

# Skill
"@
            $filePath = Join-Path $script:TempTestDir 'double-quoted.md'
            Set-Content -Path $filePath -Value $content

            $result = Get-SkillFrontmatter -Path $filePath
            $result | Should -Not -BeNullOrEmpty
            $result['name'] | Should -BeExactly 'double-skill'
            $result['description'] | Should -BeExactly 'A skill with double quotes'
        }

        It 'Returns all fields including optional ones' {
            $content = @"
---
name: advanced-skill
description: An advanced skill
user-invocable: true
argument-hint: provide a URL
---

# Advanced Skill
"@
            $filePath = Join-Path $script:TempTestDir 'optional-fields.md'
            Set-Content -Path $filePath -Value $content

            $result = Get-SkillFrontmatter -Path $filePath
            $result | Should -Not -BeNullOrEmpty
            $result['name'] | Should -BeExactly 'advanced-skill'
            $result['description'] | Should -BeExactly 'An advanced skill'
            $result['user-invocable'] | Should -BeExactly 'true'
            $result['argument-hint'] | Should -BeExactly 'provide a URL'
        }

        It 'Parses boolean values as strings (regex-based parser)' {
            $content = @"
---
name: bool-skill
description: Skill with booleans
user-invocable: false
---

# Bool Skill
"@
            $filePath = Join-Path $script:TempTestDir 'bool-values.md'
            Set-Content -Path $filePath -Value $content

            $result = Get-SkillFrontmatter -Path $filePath
            $result | Should -Not -BeNullOrEmpty
            $result['user-invocable'] | Should -BeOfType [string]
            $result['user-invocable'] | Should -BeExactly 'false'
        }

    }

    Context 'Invalid or missing frontmatter' {
        It 'Returns null for plain markdown without frontmatter' {
            $content = @"
# Just a Heading

Some content without frontmatter.
"@
            $filePath = Join-Path $script:TempTestDir 'no-frontmatter.md'
            Set-Content -Path $filePath -Value $content

            $result = Get-SkillFrontmatter -Path $filePath
            $result | Should -BeNullOrEmpty
        }

        It 'Returns null for malformed frontmatter (missing closing ---)' {
            $content = @"
---
name: broken-skill
description: Missing closing delimiter

# Some content
"@
            $filePath = Join-Path $script:TempTestDir 'malformed-fm.md'
            Set-Content -Path $filePath -Value $content

            $result = Get-SkillFrontmatter -Path $filePath
            $result | Should -BeNullOrEmpty
        }

        It 'Returns null for empty file' {
            $filePath = Join-Path $script:TempTestDir 'empty.md'
            Set-Content -Path $filePath -Value ''

            $result = Get-SkillFrontmatter -Path $filePath
            $result | Should -BeNullOrEmpty
        }

        It 'Returns null when file does not exist' {
            $filePath = Join-Path $script:TempTestDir 'nonexistent-file.md'

            $result = Get-SkillFrontmatter -Path $filePath
            $result | Should -BeNullOrEmpty
        }

        It 'Returns null for frontmatter block with no valid key-value pairs' {
            $content = @"
---
   just some random text
   no key value pairs here
---

# Content
"@
            $filePath = Join-Path $script:TempTestDir 'no-kv-pairs.md'
            Set-Content -Path $filePath -Value $content

            $result = Get-SkillFrontmatter -Path $filePath
            $result | Should -BeNullOrEmpty
        }
    }
}

#endregion

#region Test-SkillDirectory Tests

Describe 'Test-SkillDirectory' -Tag 'Unit' {
    BeforeAll {
        $script:SkillTestDir = Join-Path $script:TempTestDir 'skill-dir-tests'
        New-Item -ItemType Directory -Path $script:SkillTestDir -Force | Out-Null

        # Override TempTestDir for fixture helper within this Describe
        $script:TempTestDir = $script:SkillTestDir
    }

    AfterAll {
        $script:TempTestDir = (Split-Path $script:SkillTestDir -Parent)
    }

    Context 'Valid skill directory' {
        It 'Passes validation with proper SKILL.md and matching name' {
            $frontmatter = @"
---
name: test-skill
description: 'A test skill for validation - Brought to you by microsoft/hve-core'
---

# Test Skill
"@
            $dir = New-TestSkillDirectory -SkillName 'test-skill' -FrontmatterContent $frontmatter

            $result = Test-SkillDirectory -Directory $dir -RepoRoot $script:SkillTestDir
            $result.IsValid | Should -BeTrue
            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
            $result.SkillName | Should -BeExactly 'test-skill'
        }

        It 'Passes with valid optional directories and no warnings' {
            $frontmatter = @"
---
name: dirs-skill
description: 'Skill with optional dirs'
---

# Dirs Skill
"@
            $dir = New-TestSkillDirectory -SkillName 'dirs-skill' -FrontmatterContent $frontmatter -OptionalDirs @('scripts', 'references', 'assets', 'examples')
            # Add both script types so scripts/ passes validation
            Set-Content -Path (Join-Path $dir.FullName 'scripts/run.sh') -Value '#!/bin/bash'
            Set-Content -Path (Join-Path $dir.FullName 'scripts/run.ps1') -Value 'Write-Host "hello"'

            $result = Test-SkillDirectory -Directory $dir -RepoRoot $script:SkillTestDir
            $result.IsValid | Should -BeTrue
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'Missing SKILL.md' {
        It 'Reports error when SKILL.md is missing' {
            $dir = New-TestSkillDirectory -SkillName 'no-skillmd' -NoSkillMd

            $result = Test-SkillDirectory -Directory $dir -RepoRoot $script:SkillTestDir
            $result.IsValid | Should -BeFalse
            $result.Errors | Should -HaveCount 1
            $result.Errors[0] | Should -BeLike '*SKILL.md is missing*'
        }
    }

    Context 'Frontmatter issues' {
        It 'Reports error when SKILL.md has no frontmatter' {
            $dir = New-TestSkillDirectory -SkillName 'no-fm-skill'
            # Default content is just "# Test Skill" without frontmatter

            $result = Test-SkillDirectory -Directory $dir -RepoRoot $script:SkillTestDir
            $result.IsValid | Should -BeFalse
            $result.Errors | Should -HaveCount 1
            $result.Errors[0] | Should -BeLike '*missing or malformed frontmatter*'
        }

        It 'Reports error when frontmatter is missing name field' {
            $frontmatter = @"
---
description: 'A skill without a name'
---

# No Name
"@
            $dir = New-TestSkillDirectory -SkillName 'missing-name' -FrontmatterContent $frontmatter

            $result = Test-SkillDirectory -Directory $dir -RepoRoot $script:SkillTestDir
            $result.IsValid | Should -BeFalse
            $result.Errors | Should -Contain ($result.Errors | Where-Object { $_ -like "*missing required 'name'*" })
        }

        It 'Reports error when frontmatter is missing description field' {
            $frontmatter = @"
---
name: missing-desc
---

# Missing Desc
"@
            $dir = New-TestSkillDirectory -SkillName 'missing-desc' -FrontmatterContent $frontmatter

            $result = Test-SkillDirectory -Directory $dir -RepoRoot $script:SkillTestDir
            $result.IsValid | Should -BeFalse
            $result.Errors | Should -Contain ($result.Errors | Where-Object { $_ -like "*missing required 'description'*" })
        }

        It 'Reports error when name does not match directory name' {
            $frontmatter = @"
---
name: wrong-name
description: 'Mismatched name skill'
---

# Wrong Name
"@
            $dir = New-TestSkillDirectory -SkillName 'actual-name' -FrontmatterContent $frontmatter

            $result = Test-SkillDirectory -Directory $dir -RepoRoot $script:SkillTestDir
            $result.IsValid | Should -BeFalse
            $result.Errors | Should -Contain ($result.Errors | Where-Object { $_ -like "*does not match directory name*" })
        }

        It 'Reports both errors when name and description are missing' {
            $frontmatter = @"
---
some-other-key: value
---

# Both Missing
"@
            $dir = New-TestSkillDirectory -SkillName 'both-missing' -FrontmatterContent $frontmatter

            $result = Test-SkillDirectory -Directory $dir -RepoRoot $script:SkillTestDir
            $result.IsValid | Should -BeFalse
            $result.Errors.Count | Should -BeGreaterOrEqual 2
            $result.Errors | Where-Object { $_ -like "*missing required 'name'*" } | Should -Not -BeNullOrEmpty
            $result.Errors | Where-Object { $_ -like "*missing required 'description'*" } | Should -Not -BeNullOrEmpty
        }

        It 'Reports error when name is empty string' {
            $frontmatter = @"
---
name: ''
description: 'Has empty name'
---

# Empty Name
"@
            $dir = New-TestSkillDirectory -SkillName 'empty-name' -FrontmatterContent $frontmatter

            $result = Test-SkillDirectory -Directory $dir -RepoRoot $script:SkillTestDir
            $result.IsValid | Should -BeFalse
            $result.Errors | Where-Object { $_ -like "*missing required 'name'*" } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Scripts subdirectory checks' {
        It 'Reports error when scripts/ directory is empty (no .ps1 or .sh files)' {
            $frontmatter = @"
---
name: empty-scripts
description: 'Skill with empty scripts dir'
---

# Empty Scripts
"@
            $dir = New-TestSkillDirectory -SkillName 'empty-scripts' -FrontmatterContent $frontmatter -WithEmptyScriptsDir

            $result = Test-SkillDirectory -Directory $dir -RepoRoot $script:SkillTestDir
            $result.IsValid | Should -BeFalse
            $result.Errors | Should -HaveCount 1
            $result.Errors[0] | Should -BeLike '*scripts*no .ps1 or .sh*'
        }

        It 'Reports error when scripts/ contains only .sh file (missing .ps1)' {
            $frontmatter = @"
---
name: sh-only-scripts
description: 'Skill with sh script only'
---

# SH Only Scripts
"@
            $dir = New-TestSkillDirectory -SkillName 'sh-only-scripts' -FrontmatterContent $frontmatter -WithScriptsDir

            $result = Test-SkillDirectory -Directory $dir -RepoRoot $script:SkillTestDir
            $result.IsValid | Should -BeFalse
            $result.Errors | Should -HaveCount 1
            $result.Errors[0] | Should -BeLike '*scripts*missing a required .ps1*'
        }

        It 'Reports error when scripts/ contains only .ps1 file (missing .sh)' {
            $frontmatter = @"
---
name: ps1-only-scripts
description: 'Skill with ps1 script only'
---

# PS1 Only Scripts
"@
            $dir = New-TestSkillDirectory -SkillName 'ps1-only-scripts' -FrontmatterContent $frontmatter
            $scriptsDir = Join-Path $dir.FullName 'scripts'
            New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
            Set-Content -Path (Join-Path $scriptsDir 'run.ps1') -Value 'Write-Host "hello"'

            $result = Test-SkillDirectory -Directory $dir -RepoRoot $script:SkillTestDir
            $result.IsValid | Should -BeFalse
            $result.Errors | Should -HaveCount 1
            $result.Errors[0] | Should -BeLike '*scripts*missing a required .sh*'
        }

        It 'Passes when scripts/ contains both .ps1 and .sh files' {
            $frontmatter = @"
---
name: both-scripts
description: 'Skill with both script types'
---

# Both Scripts
"@
            $dir = New-TestSkillDirectory -SkillName 'both-scripts' -FrontmatterContent $frontmatter
            $scriptsDir = Join-Path $dir.FullName 'scripts'
            New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
            Set-Content -Path (Join-Path $scriptsDir 'run.ps1') -Value 'Write-Host "hello"'
            Set-Content -Path (Join-Path $scriptsDir 'run.sh') -Value '#!/bin/bash'

            $result = Test-SkillDirectory -Directory $dir -RepoRoot $script:SkillTestDir
            $result.IsValid | Should -BeTrue
            $result.Errors | Should -HaveCount 0
        }

        It 'Passes when no scripts/ directory exists (scripts are optional)' {
            $frontmatter = @"
---
name: no-scripts-dir
description: 'Skill without scripts directory'
---

# No Scripts Dir
"@
            $dir = New-TestSkillDirectory -SkillName 'no-scripts-dir' -FrontmatterContent $frontmatter

            $result = Test-SkillDirectory -Directory $dir -RepoRoot $script:SkillTestDir
            $result.IsValid | Should -BeTrue
            $result.Errors | Should -HaveCount 0
        }
    }

    Context 'Unrecognized subdirectories' {
        It 'Warns about unrecognized subdirectory' {
            $frontmatter = @"
---
name: unrecognized-dir
description: 'Skill with unknown dir'
---

# Unrecognized Dir
"@
            $dir = New-TestSkillDirectory -SkillName 'unrecognized-dir' -FrontmatterContent $frontmatter -WithUnrecognizedDir

            $result = Test-SkillDirectory -Directory $dir -RepoRoot $script:SkillTestDir
            $result.IsValid | Should -BeTrue
            $result.Warnings | Should -HaveCount 1
            $result.Warnings[0] | Should -BeLike "*Unrecognized subdirectory 'random-dir'*"
        }

        It 'Does not warn about recognized optional directories' {
            $frontmatter = @"
---
name: recognized-dirs
description: 'Skill with recognized dirs'
---

# Recognized Dirs
"@
            $dir = New-TestSkillDirectory -SkillName 'recognized-dirs' -FrontmatterContent $frontmatter -OptionalDirs @('scripts', 'references', 'assets', 'examples')
            # Add both script types so scripts/ passes validation
            Set-Content -Path (Join-Path $dir.FullName 'scripts/run.sh') -Value '#!/bin/bash'
            Set-Content -Path (Join-Path $dir.FullName 'scripts/run.ps1') -Value 'Write-Host "hello"'

            $result = Test-SkillDirectory -Directory $dir -RepoRoot $script:SkillTestDir
            $result.IsValid | Should -BeTrue
            $result.Warnings | Should -HaveCount 0
        }
    }

    Context 'Result object structure' {
        It 'Returns correct SkillPath as relative path' {
            $frontmatter = @"
---
name: path-check
description: 'Path check skill'
---

# Path Check
"@
            $dir = New-TestSkillDirectory -SkillName 'path-check' -FrontmatterContent $frontmatter

            $result = Test-SkillDirectory -Directory $dir -RepoRoot $script:SkillTestDir
            $result.SkillPath | Should -BeExactly 'path-check'
        }
    }
}

#endregion

#region Get-ChangedSkillDirectories Tests

Describe 'Get-ChangedSkillDirectories' -Tag 'Unit' {
    Context 'Changed files in skill directories' {
        It 'Returns skill name for changed file in skill directory' {
            Mock Get-ChangedFilesFromGit {
                return @('.github/skills/video-to-gif/SKILL.md')
            }

            $result = Get-ChangedSkillDirectories -BaseBranch 'origin/main' -SkillsPath '.github/skills'
            $result | Should -Contain 'video-to-gif'
        }

        It 'Returns empty when changed files are outside skills directory' {
            Mock Get-ChangedFilesFromGit {
                return @('scripts/linting/Test.ps1', 'docs/README.md')
            }

            $result = Get-ChangedSkillDirectories -BaseBranch 'origin/main' -SkillsPath '.github/skills'
            @($result).Count | Should -Be 0
        }

        It 'Returns unique skill name for multiple changed files in same skill' {
            Mock Get-ChangedFilesFromGit {
                return @(
                    '.github/skills/my-skill/SKILL.md',
                    '.github/skills/my-skill/scripts/run.sh',
                    '.github/skills/my-skill/references/doc.md'
                )
            }

            $result = Get-ChangedSkillDirectories -BaseBranch 'origin/main' -SkillsPath '.github/skills'
            $result | Should -HaveCount 1
            $result | Should -Contain 'my-skill'
        }

        It 'Returns empty when no files are changed' {
            Mock Get-ChangedFilesFromGit { return @() }

            $result = Get-ChangedSkillDirectories -BaseBranch 'origin/main' -SkillsPath '.github/skills'
            @($result).Count | Should -Be 0
        }

        It 'Returns multiple skill names for changes across different skills' {
            Mock Get-ChangedFilesFromGit {
                return @(
                    '.github/skills/skill-a/SKILL.md',
                    '.github/skills/skill-b/scripts/run.sh'
                )
            }

            $result = Get-ChangedSkillDirectories -BaseBranch 'origin/main' -SkillsPath '.github/skills'
            $result | Should -HaveCount 2
            $result | Should -Contain 'skill-a'
            $result | Should -Contain 'skill-b'
        }
    }

    Context 'Delegation to Get-ChangedFilesFromGit' {
        It 'Passes BaseBranch to Get-ChangedFilesFromGit' {
            Mock Get-ChangedFilesFromGit { return @() }

            Get-ChangedSkillDirectories -BaseBranch 'develop' -SkillsPath '.github/skills'
            Should -Invoke Get-ChangedFilesFromGit -Times 1 -ParameterFilter {
                $BaseBranch -eq 'develop'
            }
        }
    }

    Context 'Path normalization' {
        It 'Handles backslash paths in changed files' {
            Mock Get-ChangedFilesFromGit {
                return @('.github\skills\backslash-skill\SKILL.md')
            }

            $result = Get-ChangedSkillDirectories -BaseBranch 'origin/main' -SkillsPath '.github/skills'
            $result | Should -Contain 'backslash-skill'
        }
    }
}

#endregion

#region Write-SkillValidationResults Tests

Describe 'Write-SkillValidationResults' -Tag 'Unit' {
    BeforeAll {
        $script:ResultsTestDir = Join-Path $script:TempTestDir 'results-tests'
        New-Item -ItemType Directory -Path $script:ResultsTestDir -Force | Out-Null

        # Clear CI env so Test-CIEnvironment returns false
        Clear-MockCIEnvironment
    }

    Context 'JSON output' {
        It 'Creates JSON file in logs directory for passing results' {
            $repoRoot = Join-Path $script:ResultsTestDir 'pass-repo'
            New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

            $results = @(
                [PSCustomObject]@{
                    SkillName = 'passing-skill'
                    SkillPath = '.github/skills/passing-skill'
                    IsValid   = $true
                    Errors    = [string[]]@()
                    Warnings  = [string[]]@()
                }
            )

            Write-SkillValidationResults -Results $results -RepoRoot $repoRoot

            $jsonPath = Join-Path $repoRoot 'logs/skill-validation-results.json'
            Test-Path $jsonPath | Should -BeTrue

            $json = Get-Content $jsonPath -Raw | ConvertFrom-Json
            $json.totalSkills | Should -Be 1
            $json.skillErrors | Should -Be 0
            $json.skillWarnings | Should -Be 0
            $json.results[0].skillName | Should -BeExactly 'passing-skill'
            $json.results[0].isValid | Should -BeTrue
        }

        It 'Creates JSON file with error details for failing results' {
            $repoRoot = Join-Path $script:ResultsTestDir 'fail-repo'
            New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

            $results = @(
                [PSCustomObject]@{
                    SkillName = 'failing-skill'
                    SkillPath = '.github/skills/failing-skill'
                    IsValid   = $false
                    Errors    = [string[]]@('SKILL.md is missing')
                    Warnings  = [string[]]@()
                },
                [PSCustomObject]@{
                    SkillName = 'warning-skill'
                    SkillPath = '.github/skills/warning-skill'
                    IsValid   = $true
                    Errors    = [string[]]@()
                    Warnings  = [string[]]@('Unrecognized subdirectory')
                }
            )

            Write-SkillValidationResults -Results $results -RepoRoot $repoRoot

            $jsonPath = Join-Path $repoRoot 'logs/skill-validation-results.json'
            Test-Path $jsonPath | Should -BeTrue

            $json = Get-Content $jsonPath -Raw | ConvertFrom-Json
            $json.totalSkills | Should -Be 2
            $json.skillErrors | Should -Be 1
            $json.skillWarnings | Should -Be 1
            $json.results[0].isValid | Should -BeFalse
            $json.results[0].errors | Should -HaveCount 1
        }

        It 'Creates logs directory if it does not exist' {
            $repoRoot = Join-Path $script:ResultsTestDir 'new-logs-repo'
            New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null
            # Ensure logs dir does not exist
            $logsDir = Join-Path $repoRoot 'logs'
            if (Test-Path $logsDir) {
                Remove-Item $logsDir -Recurse -Force
            }

            $results = @(
                [PSCustomObject]@{
                    SkillName = 'create-logs'
                    SkillPath = '.github/skills/create-logs'
                    IsValid   = $true
                    Errors    = [string[]]@()
                    Warnings  = [string[]]@()
                }
            )

            Write-SkillValidationResults -Results $results -RepoRoot $repoRoot

            Test-Path $logsDir | Should -BeTrue
            Test-Path (Join-Path $logsDir 'skill-validation-results.json') | Should -BeTrue
        }

        It 'Includes timestamp in JSON output' {
            $repoRoot = Join-Path $script:ResultsTestDir 'timestamp-repo'
            New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

            $results = @(
                [PSCustomObject]@{
                    SkillName = 'ts-skill'
                    SkillPath = '.github/skills/ts-skill'
                    IsValid   = $true
                    Errors    = [string[]]@()
                    Warnings  = [string[]]@()
                }
            )

            Write-SkillValidationResults -Results $results -RepoRoot $repoRoot

            $jsonPath = Join-Path $repoRoot 'logs/skill-validation-results.json'
            $json = Get-Content $jsonPath -Raw | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }
    }

    Context 'CI annotations' {
        It 'Emits CI annotations when in CI environment' {
            $repoRoot = Join-Path $script:ResultsTestDir 'ci-repo'
            New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null
            $mockFiles = Initialize-MockCIEnvironment

            try {
                $results = @(
                    [PSCustomObject]@{
                        SkillName = 'ci-fail'
                        SkillPath = '.github/skills/ci-fail'
                        IsValid   = $false
                        Errors    = [string[]]@('Missing SKILL.md')
                        Warnings  = [string[]]@('Empty scripts dir')
                    }
                )

                # Capture all output; CI annotations go to stdout via Write-Output
                $null = Write-SkillValidationResults -Results $results -RepoRoot $repoRoot 6>&1

                $jsonPath = Join-Path $repoRoot 'logs/skill-validation-results.json'
                Test-Path $jsonPath | Should -BeTrue
            }
            finally {
                Clear-MockCIEnvironment
                Remove-MockCIFiles -MockFiles $mockFiles
            }
        }
    }
}

#endregion

#region Console output verification

Describe 'Write-SkillValidationResults console output' -Tag 'Unit' {
    BeforeAll {
        Clear-MockCIEnvironment
    }

    Context 'Status indicators' {
        It 'Shows green check for fully passing skill' {
            $repoRoot = Join-Path $script:TempTestDir 'console-pass'
            New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

            $results = @(
                [PSCustomObject]@{
                    SkillName = 'good-skill'
                    SkillPath = '.github/skills/good-skill'
                    IsValid   = $true
                    Errors    = [string[]]@()
                    Warnings  = [string[]]@()
                }
            )

            # Should not throw
            { Write-SkillValidationResults -Results $results -RepoRoot $repoRoot } | Should -Not -Throw
        }

        It 'Shows warning indicator for skill with warnings only' {
            $repoRoot = Join-Path $script:TempTestDir 'console-warn'
            New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

            $results = @(
                [PSCustomObject]@{
                    SkillName = 'warn-skill'
                    SkillPath = '.github/skills/warn-skill'
                    IsValid   = $true
                    Errors    = [string[]]@()
                    Warnings  = [string[]]@('Some warning')
                }
            )

            { Write-SkillValidationResults -Results $results -RepoRoot $repoRoot } | Should -Not -Throw
        }

        It 'Shows error indicator for failing skill' {
            $repoRoot = Join-Path $script:TempTestDir 'console-fail'
            New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

            $results = @(
                [PSCustomObject]@{
                    SkillName = 'bad-skill'
                    SkillPath = '.github/skills/bad-skill'
                    IsValid   = $false
                    Errors    = [string[]]@('Something broke')
                    Warnings  = [string[]]@()
                }
            )

            { Write-SkillValidationResults -Results $results -RepoRoot $repoRoot } | Should -Not -Throw
        }
    }
}

#endregion

#region Invoke-SkillStructureValidation Tests

Describe 'Invoke-SkillStructureValidation' -Tag 'Unit' {
    BeforeAll {
        $script:ValidationDir = Join-Path ([System.IO.Path]::GetTempPath()) "SkillValidation_$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:ValidationDir -Force | Out-Null

        # Clear CI env to avoid annotation output interference
        Clear-MockCIEnvironment
    }

    AfterAll {
        if ($script:ValidationDir -and (Test-Path $script:ValidationDir)) {
            Remove-Item -Path $script:ValidationDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Skills directory does not exist' {
        It 'Returns 0 when skills path does not exist' {
            Mock git {
                $global:LASTEXITCODE = 0
                return $script:ValidationDir
            } -ParameterFilter { $args[0] -eq 'rev-parse' }

            $exitCode = Invoke-SkillStructureValidation -SkillsPath 'nonexistent-skills'
            $exitCode | Should -Be 0
        }
    }

    Context 'Empty skills directory' {
        It 'Returns 0 when skills directory has no subdirectories' {
            $emptyDir = Join-Path $script:ValidationDir 'empty-skills'
            New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null

            Mock git {
                $global:LASTEXITCODE = 0
                return $script:ValidationDir
            } -ParameterFilter { $args[0] -eq 'rev-parse' }

            $exitCode = Invoke-SkillStructureValidation -SkillsPath 'empty-skills'
            $exitCode | Should -Be 0
        }
    }

    Context 'Valid skill directories' {
        It 'Returns 0 for a valid skill with proper SKILL.md' {
            $skillsDir = Join-Path $script:ValidationDir 'valid-skills'
            $skillDir = Join-Path $skillsDir 'good-skill'
            New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
            $content = @"
---
name: good-skill
description: 'A valid skill for integration testing'
---

# Good Skill
"@
            Set-Content -Path (Join-Path $skillDir 'SKILL.md') -Value $content

            Mock git {
                $global:LASTEXITCODE = 0
                return $script:ValidationDir
            } -ParameterFilter { $args[0] -eq 'rev-parse' }

            $exitCode = Invoke-SkillStructureValidation -SkillsPath 'valid-skills'
            $exitCode | Should -Be 0
        }
    }

    Context 'Invalid skill directories' {
        It 'Returns 1 when a skill is missing SKILL.md' {
            $skillsDir = Join-Path $script:ValidationDir 'invalid-missing'
            $skillDir = Join-Path $skillsDir 'broken-skill'
            New-Item -ItemType Directory -Path $skillDir -Force | Out-Null

            Mock git {
                $global:LASTEXITCODE = 0
                return $script:ValidationDir
            } -ParameterFilter { $args[0] -eq 'rev-parse' }

            $exitCode = Invoke-SkillStructureValidation -SkillsPath 'invalid-missing'
            $exitCode | Should -Be 1
        }

        It 'Returns 1 when SKILL.md has no frontmatter' {
            $skillsDir = Join-Path $script:ValidationDir 'invalid-nofm'
            $skillDir = Join-Path $skillsDir 'no-fm-skill'
            New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
            Set-Content -Path (Join-Path $skillDir 'SKILL.md') -Value '# Just a heading'

            Mock git {
                $global:LASTEXITCODE = 0
                return $script:ValidationDir
            } -ParameterFilter { $args[0] -eq 'rev-parse' }

            $exitCode = Invoke-SkillStructureValidation -SkillsPath 'invalid-nofm'
            $exitCode | Should -Be 1
        }

        It 'Returns 1 when frontmatter name does not match directory' {
            $skillsDir = Join-Path $script:ValidationDir 'invalid-mismatch'
            $skillDir = Join-Path $skillsDir 'real-name'
            New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
            $content = @"
---
name: wrong-name
description: 'Mismatched name'
---

# Wrong Name
"@
            Set-Content -Path (Join-Path $skillDir 'SKILL.md') -Value $content

            Mock git {
                $global:LASTEXITCODE = 0
                return $script:ValidationDir
            } -ParameterFilter { $args[0] -eq 'rev-parse' }

            $exitCode = Invoke-SkillStructureValidation -SkillsPath 'invalid-mismatch'
            $exitCode | Should -Be 1
        }
    }

    Context 'WarningsAsErrors flag' {
        It 'Returns 1 when WarningsAsErrors and skill has warnings' {
            $skillsDir = Join-Path $script:ValidationDir 'warn-as-error'
            $skillDir = Join-Path $skillsDir 'warn-skill'
            New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
            $content = @"
---
name: warn-skill
description: 'Skill with unrecognized dir'
---

# Warn Skill
"@
            Set-Content -Path (Join-Path $skillDir 'SKILL.md') -Value $content
            New-Item -ItemType Directory -Path (Join-Path $skillDir 'custom-dir') -Force | Out-Null

            Mock git {
                $global:LASTEXITCODE = 0
                return $script:ValidationDir
            } -ParameterFilter { $args[0] -eq 'rev-parse' }

            $exitCode = Invoke-SkillStructureValidation -SkillsPath 'warn-as-error' -WarningsAsErrors
            $exitCode | Should -Be 1
        }

        It 'Returns 0 when WarningsAsErrors but no warnings' {
            $skillsDir = Join-Path $script:ValidationDir 'nowarn'
            $skillDir = Join-Path $skillsDir 'clean-skill'
            New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
            $content = @"
---
name: clean-skill
description: 'Clean skill with no warnings'
---

# Clean Skill
"@
            Set-Content -Path (Join-Path $skillDir 'SKILL.md') -Value $content

            Mock git {
                $global:LASTEXITCODE = 0
                return $script:ValidationDir
            } -ParameterFilter { $args[0] -eq 'rev-parse' }

            $exitCode = Invoke-SkillStructureValidation -SkillsPath 'nowarn' -WarningsAsErrors
            $exitCode | Should -Be 0
        }
    }

    Context 'ChangedFilesOnly mode' {
        It 'Returns 0 when no skill files changed' {
            Mock git {
                $global:LASTEXITCODE = 0
                return $script:ValidationDir
            } -ParameterFilter { $args[0] -eq 'rev-parse' }

            Mock Get-ChangedSkillDirectories {
                return @()
            }

            $exitCode = Invoke-SkillStructureValidation -SkillsPath 'skills' -ChangedFilesOnly
            $exitCode | Should -Be 0
        }

        It 'Returns 0 for valid changed skill' {
            $skillsDir = Join-Path $script:ValidationDir 'changed-valid'
            $skillDir = Join-Path $skillsDir 'my-skill'
            New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
            $content = @"
---
name: my-skill
description: 'Valid changed skill'
---

# My Skill
"@
            Set-Content -Path (Join-Path $skillDir 'SKILL.md') -Value $content

            Mock git {
                $global:LASTEXITCODE = 0
                return $script:ValidationDir
            } -ParameterFilter { $args[0] -eq 'rev-parse' }

            Mock Get-ChangedSkillDirectories {
                return [string[]]@('my-skill')
            }

            $exitCode = Invoke-SkillStructureValidation -SkillsPath 'changed-valid' -ChangedFilesOnly
            $exitCode | Should -Be 0
        }

        It 'Returns 1 when changed skill has errors' {
            $skillsDir = Join-Path $script:ValidationDir 'changed-invalid'
            $skillDir = Join-Path $skillsDir 'bad-skill'
            New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
            $content = @"
---
name: bad-skill
---

# Bad Skill
"@
            Set-Content -Path (Join-Path $skillDir 'SKILL.md') -Value $content

            Mock git {
                $global:LASTEXITCODE = 0
                return $script:ValidationDir
            } -ParameterFilter { $args[0] -eq 'rev-parse' }

            Mock Get-ChangedSkillDirectories {
                return [string[]]@('bad-skill')
            }

            $exitCode = Invoke-SkillStructureValidation -SkillsPath 'changed-invalid' -ChangedFilesOnly
            $exitCode | Should -Be 1
        }

        It 'Returns 0 and skips validation when changed skill was deleted' {
            $skillsDir = Join-Path $script:ValidationDir 'changed-deleted'
            New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null

            Mock git {
                $global:LASTEXITCODE = 0
                return $script:ValidationDir
            } -ParameterFilter { $args[0] -eq 'rev-parse' }

            Mock Get-ChangedSkillDirectories {
                return [string[]]@('deleted-skill')
            }

            $exitCode = Invoke-SkillStructureValidation -SkillsPath 'changed-deleted' -ChangedFilesOnly
            $exitCode | Should -Be 0
        }
    }

    Context 'Multiple skills with mixed results' {
        It 'Returns 1 when at least one skill has errors among valid ones' {
            $skillsDir = Join-Path $script:ValidationDir 'mixed'
            New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null

            # Valid skill
            $validDir = Join-Path $skillsDir 'alpha-skill'
            New-Item -ItemType Directory -Path $validDir -Force | Out-Null
            $validContent = @"
---
name: alpha-skill
description: 'Valid skill'
---

# Alpha Skill
"@
            Set-Content -Path (Join-Path $validDir 'SKILL.md') -Value $validContent

            # Invalid skill (missing SKILL.md)
            $invalidDir = Join-Path $skillsDir 'beta-skill'
            New-Item -ItemType Directory -Path $invalidDir -Force | Out-Null

            Mock git {
                $global:LASTEXITCODE = 0
                return $script:ValidationDir
            } -ParameterFilter { $args[0] -eq 'rev-parse' }

            $exitCode = Invoke-SkillStructureValidation -SkillsPath 'mixed'
            $exitCode | Should -Be 1
        }
    }

    Context 'Repo root resolution' {
        It 'Uses git rev-parse when available' {
            $repoRoot = Join-Path $script:ValidationDir 'git-repo'
            $skillsDir = Join-Path $repoRoot '.github/skills'
            $skillDir = Join-Path $skillsDir 'repo-skill'
            New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
            $content = @"
---
name: repo-skill
description: 'Skill in git repo'
---

# Repo Skill
"@
            Set-Content -Path (Join-Path $skillDir 'SKILL.md') -Value $content

            Mock git {
                $global:LASTEXITCODE = 0
                return $repoRoot
            } -ParameterFilter { $args[0] -eq 'rev-parse' }

            $exitCode = Invoke-SkillStructureValidation -SkillsPath '.github/skills'
            $exitCode | Should -Be 0
        }

        It 'Falls back to current directory when git rev-parse fails' {
            $repoRoot = Join-Path $script:ValidationDir 'fallback-repo'
            $skillsDir = Join-Path $repoRoot 'my-skills'
            $skillDir = Join-Path $skillsDir 'fb-skill'
            New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
            $content = @"
---
name: fb-skill
description: 'Fallback skill'
---

# Fallback Skill
"@
            Set-Content -Path (Join-Path $skillDir 'SKILL.md') -Value $content

            Mock git {
                $global:LASTEXITCODE = 128
                return $null
            } -ParameterFilter { $args[0] -eq 'rev-parse' }

            Push-Location $repoRoot
            try {
                $exitCode = Invoke-SkillStructureValidation -SkillsPath 'my-skills'
                $exitCode | Should -Be 0
            }
            finally {
                Pop-Location
            }
        }
    }

    Context 'Error handling' {
        It 'Returns 1 when an unexpected error occurs' {
            Mock git {
                $global:LASTEXITCODE = 0
                return $script:ValidationDir
            } -ParameterFilter { $args[0] -eq 'rev-parse' }

            # Create the skills directory so the first Test-Path passes
            $errSkillsDir = Join-Path $script:ValidationDir 'error-skills'
            New-Item -ItemType Directory -Path $errSkillsDir -Force | Out-Null

            # Mock Get-ChildItem to throw to trigger catch block
            Mock Get-ChildItem {
                throw 'Simulated filesystem error'
            }

            $exitCode = Invoke-SkillStructureValidation -SkillsPath 'error-skills' 2>&1 |
                Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
            $exitCode | Should -Contain 1
        }
    }
}

#endregion
