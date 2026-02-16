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
user-invokable: true
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
            $result['user-invokable'] | Should -BeExactly 'true'
            $result['argument-hint'] | Should -BeExactly 'provide a URL'
        }

        It 'Parses boolean values as strings (regex-based parser)' {
            $content = @"
---
name: bool-skill
description: Skill with booleans
user-invokable: false
---

# Bool Skill
"@
            $filePath = Join-Path $script:TempTestDir 'bool-values.md'
            Set-Content -Path $filePath -Value $content

            $result = Get-SkillFrontmatter -Path $filePath
            $result | Should -Not -BeNullOrEmpty
            $result['user-invokable'] | Should -BeOfType [string]
            $result['user-invokable'] | Should -BeExactly 'false'
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
            # Add a script file so scripts/ doesn't trigger the empty warning
            Set-Content -Path (Join-Path $dir.FullName 'scripts/run.sh') -Value '#!/bin/bash'

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
        It 'Warns when scripts/ directory is empty (no .ps1 or .sh files)' {
            $frontmatter = @"
---
name: empty-scripts
description: 'Skill with empty scripts dir'
---

# Empty Scripts
"@
            $dir = New-TestSkillDirectory -SkillName 'empty-scripts' -FrontmatterContent $frontmatter -WithEmptyScriptsDir

            $result = Test-SkillDirectory -Directory $dir -RepoRoot $script:SkillTestDir
            $result.IsValid | Should -BeTrue
            $result.Warnings | Should -HaveCount 1
            $result.Warnings[0] | Should -BeLike '*scripts*no .ps1 or .sh*'
        }

        It 'No warning when scripts/ contains a .sh file' {
            $frontmatter = @"
---
name: sh-scripts
description: 'Skill with sh script'
---

# SH Scripts
"@
            $dir = New-TestSkillDirectory -SkillName 'sh-scripts' -FrontmatterContent $frontmatter -WithScriptsDir

            $result = Test-SkillDirectory -Directory $dir -RepoRoot $script:SkillTestDir
            $result.IsValid | Should -BeTrue
            $result.Warnings | Should -HaveCount 0
        }

        It 'No warning when scripts/ contains a .ps1 file' {
            $frontmatter = @"
---
name: ps1-scripts
description: 'Skill with ps1 script'
---

# PS1 Scripts
"@
            $dir = New-TestSkillDirectory -SkillName 'ps1-scripts' -FrontmatterContent $frontmatter
            $scriptsDir = Join-Path $dir.FullName 'scripts'
            New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
            Set-Content -Path (Join-Path $scriptsDir 'run.ps1') -Value 'Write-Host "hello"'

            $result = Test-SkillDirectory -Directory $dir -RepoRoot $script:SkillTestDir
            $result.IsValid | Should -BeTrue
            $result.Warnings | Should -HaveCount 0
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
            # Add a script file so scripts/ doesn't trigger the empty warning
            Set-Content -Path (Join-Path $dir.FullName 'scripts/run.sh') -Value '#!/bin/bash'

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
            Mock git {
                $global:LASTEXITCODE = 0
                return 'abc123'
            } -ParameterFilter { $args[0] -eq 'merge-base' }

            Mock git {
                $global:LASTEXITCODE = 0
                return @('.github/skills/video-to-gif/SKILL.md')
            } -ParameterFilter { $args[0] -eq 'diff' -and ($args -contains '--name-only') }

            $result = Get-ChangedSkillDirectories -BaseBranch 'origin/main' -SkillsPath '.github/skills'
            $result | Should -Contain 'video-to-gif'
        }

        It 'Returns empty when changed files are outside skills directory' {
            Mock git {
                $global:LASTEXITCODE = 0
                return 'abc123'
            } -ParameterFilter { $args[0] -eq 'merge-base' }

            Mock git {
                $global:LASTEXITCODE = 0
                return @('scripts/linting/Test.ps1', 'docs/README.md')
            } -ParameterFilter { $args[0] -eq 'diff' -and ($args -contains '--name-only') }

            $result = Get-ChangedSkillDirectories -BaseBranch 'origin/main' -SkillsPath '.github/skills'
            $result | Should -HaveCount 0
        }

        It 'Returns unique skill name for multiple changed files in same skill' {
            Mock git {
                $global:LASTEXITCODE = 0
                return 'abc123'
            } -ParameterFilter { $args[0] -eq 'merge-base' }

            Mock git {
                $global:LASTEXITCODE = 0
                return @(
                    '.github/skills/my-skill/SKILL.md',
                    '.github/skills/my-skill/scripts/run.sh',
                    '.github/skills/my-skill/references/doc.md'
                )
            } -ParameterFilter { $args[0] -eq 'diff' -and ($args -contains '--name-only') }

            $result = Get-ChangedSkillDirectories -BaseBranch 'origin/main' -SkillsPath '.github/skills'
            $result | Should -HaveCount 1
            $result | Should -Contain 'my-skill'
        }

        It 'Returns empty when no files are changed' {
            Mock git {
                $global:LASTEXITCODE = 0
                return 'abc123'
            } -ParameterFilter { $args[0] -eq 'merge-base' }

            Mock git {
                $global:LASTEXITCODE = 0
                return @()
            } -ParameterFilter { $args[0] -eq 'diff' -and ($args -contains '--name-only') }

            $result = Get-ChangedSkillDirectories -BaseBranch 'origin/main' -SkillsPath '.github/skills'
            $result | Should -HaveCount 0
        }

        It 'Returns multiple skill names for changes across different skills' {
            Mock git {
                $global:LASTEXITCODE = 0
                return 'abc123'
            } -ParameterFilter { $args[0] -eq 'merge-base' }

            Mock git {
                $global:LASTEXITCODE = 0
                return @(
                    '.github/skills/skill-a/SKILL.md',
                    '.github/skills/skill-b/scripts/run.sh'
                )
            } -ParameterFilter { $args[0] -eq 'diff' -and ($args -contains '--name-only') }

            $result = Get-ChangedSkillDirectories -BaseBranch 'origin/main' -SkillsPath '.github/skills'
            $result | Should -HaveCount 2
            $result | Should -Contain 'skill-a'
            $result | Should -Contain 'skill-b'
        }
    }

    Context 'Git command failures' {
        It 'Returns empty with warning on merge-base failure' {
            Mock git {
                $global:LASTEXITCODE = 128
                return $null
            } -ParameterFilter { $args[0] -eq 'merge-base' }

            $result = Get-ChangedSkillDirectories -BaseBranch 'origin/main' -SkillsPath '.github/skills' 3>&1
            # Filter out the actual return value from the warning stream
            $warnings = $result | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
            $values = @($result | Where-Object { $_ -isnot [System.Management.Automation.WarningRecord] })

            $warnings | Should -Not -BeNullOrEmpty
            $values | Should -HaveCount 0
        }

        It 'Returns empty with warning on diff failure' {
            Mock git {
                $global:LASTEXITCODE = 0
                return 'abc123'
            } -ParameterFilter { $args[0] -eq 'merge-base' }

            Mock git {
                $global:LASTEXITCODE = 1
                return $null
            } -ParameterFilter { $args[0] -eq 'diff' -and ($args -contains '--name-only') }

            $result = Get-ChangedSkillDirectories -BaseBranch 'origin/main' -SkillsPath '.github/skills' 3>&1
            $warnings = $result | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
            $values = @($result | Where-Object { $_ -isnot [System.Management.Automation.WarningRecord] })

            $warnings | Should -Not -BeNullOrEmpty
            $values | Should -HaveCount 0
        }

        It 'Returns empty with warning when an exception is thrown' {
            Mock git {
                throw 'Simulated git failure'
            } -ParameterFilter { $args[0] -eq 'merge-base' }

            $result = Get-ChangedSkillDirectories -BaseBranch 'origin/main' -SkillsPath '.github/skills' 3>&1
            $warnings = $result | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
            $values = @($result | Where-Object { $_ -isnot [System.Management.Automation.WarningRecord] })

            $warnings | Should -Not -BeNullOrEmpty
            ($warnings | Select-Object -First 1).Message | Should -BeLike '*Error detecting changed skill directories*'
            $values | Should -HaveCount 0
        }
    }

    Context 'Path normalization' {
        It 'Handles backslash paths in changed files' {
            Mock git {
                $global:LASTEXITCODE = 0
                return 'abc123'
            } -ParameterFilter { $args[0] -eq 'merge-base' }

            Mock git {
                $global:LASTEXITCODE = 0
                return @('.github\skills\backslash-skill\SKILL.md')
            } -ParameterFilter { $args[0] -eq 'diff' -and ($args -contains '--name-only') }

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
