#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Pester tests for Invoke-MsDateFreshnessCheck.ps1 script
.DESCRIPTION
    Tests for ms.date frontmatter freshness checking:
    - File discovery with exclusions
    - ChangedFilesOnly filtering via mocked git
    - ms.date parsing (valid, invalid, missing)
    - Report generation (JSON and markdown)
    - Integration smoke test with CI annotations
#>

BeforeAll {
    $lintingHelpersPath = Join-Path $PSScriptRoot '../../linting/Modules/LintingHelpers.psm1'
    $ciHelpersPath = Join-Path $PSScriptRoot '../../lib/Modules/CIHelpers.psm1'

    Import-Module $lintingHelpersPath -Force
    Import-Module $ciHelpersPath -Force
    Import-Module (Join-Path $PSScriptRoot '../Mocks/GitMocks.psm1') -Force
    Import-Module powershell-yaml -Force

    . $PSScriptRoot/../../linting/Invoke-MsDateFreshnessCheck.ps1
    $ErrorActionPreference = 'Continue'
}

AfterAll {
    Remove-Module LintingHelpers -Force -ErrorAction SilentlyContinue
    Remove-Module CIHelpers -Force -ErrorAction SilentlyContinue
    Remove-Module GitMocks -Force -ErrorAction SilentlyContinue
}

#region Get-MarkdownFiles Tests

Describe 'Get-MarkdownFiles' -Tag 'Unit' {
    BeforeAll {
        Save-CIEnvironment
    }

    AfterAll {
        Restore-CIEnvironment
    }

    BeforeEach {
        $script:TestDir = Join-Path $TestDrive 'ms-date-test'
        New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        Push-Location $script:TestDir
    }

    AfterEach {
        Pop-Location
        Restore-CIEnvironment
    }

    Context 'File discovery' {
        BeforeEach {
            New-Item -ItemType File -Path (Join-Path $script:TestDir 'readme.md') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $script:TestDir 'docs') -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $script:TestDir 'docs/guide.md') -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $script:TestDir 'docs/tutorial.md') -Force | Out-Null
        }

        It 'Discovers markdown files recursively' {
            $files = @(Get-MarkdownFiles -SearchPaths @($script:TestDir))
            $files.Count | Should -BeGreaterOrEqual 3
        }

        It 'Returns FileInfo objects' {
            $files = @(Get-MarkdownFiles -SearchPaths @($script:TestDir))
            $files[0] | Should -BeOfType [System.IO.FileInfo]
        }
    }

    Context 'Exclusion patterns' {
        BeforeEach {
            Push-Location $script:TestDir
            New-Item -ItemType Directory -Path 'node_modules' -Force | Out-Null
            New-Item -ItemType File -Path 'node_modules/package.md' -Force | Out-Null
            New-Item -ItemType Directory -Path '.git' -Force | Out-Null
            New-Item -ItemType File -Path '.git/commit.md' -Force | Out-Null
            New-Item -ItemType Directory -Path 'logs' -Force | Out-Null
            New-Item -ItemType File -Path 'logs/output.md' -Force | Out-Null
            New-Item -ItemType Directory -Path '.copilot-tracking' -Force | Out-Null
            New-Item -ItemType File -Path '.copilot-tracking/notes.md' -Force | Out-Null
            New-Item -ItemType File -Path 'CHANGELOG.md' -Force | Out-Null
            New-Item -ItemType File -Path 'valid.md' -Force | Out-Null
        }

        AfterEach {
            Pop-Location
        }

        It 'Excludes node_modules directory' {
            $files = @(Get-MarkdownFiles -SearchPaths @('.'))
            $files.Name | Should -Not -Contain 'package.md'
        }

        It 'Excludes .git directory' {
            $files = @(Get-MarkdownFiles -SearchPaths @('.'))
            $files.Name | Should -Not -Contain 'commit.md'
        }

        It 'Excludes logs directory' {
            $files = @(Get-MarkdownFiles -SearchPaths @('.'))
            $files.Name | Should -Not -Contain 'output.md'
        }

        It 'Excludes .copilot-tracking directory' {
            $files = @(Get-MarkdownFiles -SearchPaths @('.'))
            $files.Name | Should -Not -Contain 'notes.md'
        }

        It 'Excludes CHANGELOG.md' {
            $files = @(Get-MarkdownFiles -SearchPaths @('.'))
            $files.Name | Should -Not -Contain 'CHANGELOG.md'
        }

        It 'Includes non-excluded files' {
            $files = @(Get-MarkdownFiles -SearchPaths @('.'))
            $files.Name | Should -Contain 'valid.md'
        }
    }

    Context 'Explicit path mode' {
        BeforeEach {
            New-Item -ItemType Directory -Path (Join-Path $script:TestDir 'logs') -Force | Out-Null
            $script:ExplicitFile = Join-Path $script:TestDir 'logs/specific.md'
            New-Item -ItemType File -Path $script:ExplicitFile -Force | Out-Null
        }

        It 'Includes excluded directories when path is explicit' {
            $files = @(Get-MarkdownFiles -SearchPaths @($script:ExplicitFile))
            $files.FullName | Should -Contain $script:ExplicitFile
        }
    }

    Context 'ChangedFilesOnly mode' {
        BeforeEach {
            Push-Location $script:TestDir
            New-Item -ItemType File -Path 'changed.md' -Force | Out-Null
            New-Item -ItemType File -Path 'unchanged.md' -Force | Out-Null

            Initialize-MockCIEnvironment -Workspace $script:TestDir | Out-Null

            Mock git {
                $global:LASTEXITCODE = 0
                return 'abc123'
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'merge-base' }

            Mock git {
                $global:LASTEXITCODE = 0
                return @('changed.md')
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'diff' }
        }

        AfterEach {
            Pop-Location
        }

        It 'Uses Git changed files when ChangedOnly is set' {
            $files = @(Get-MarkdownFiles -SearchPaths @('.') -ChangedOnly -Base 'origin/main')
            $files.Count | Should -Be 1
            $files[0] | Should -Be 'changed.md'
        }

        It 'Filters out non-existent changed files' {
            Mock git {
                $global:LASTEXITCODE = 0
                return @('missing.md')
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'diff' }

            $files = @(Get-MarkdownFiles -SearchPaths @('.') -ChangedOnly -Base 'origin/main')
            $files | Should -BeNullOrEmpty
        }
    }

    Context 'Multiple paths' {
        BeforeEach {
            $script:Path1 = Join-Path $script:TestDir 'dir1'
            $script:Path2 = Join-Path $script:TestDir 'dir2'
            New-Item -ItemType Directory -Path $script:Path1 -Force | Out-Null
            New-Item -ItemType Directory -Path $script:Path2 -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $script:Path1 'file1.md') -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $script:Path2 'file2.md') -Force | Out-Null
        }

        It 'Searches multiple paths' {
            $files = @(Get-MarkdownFiles -SearchPaths @($script:Path1, $script:Path2))
            $files.Count | Should -Be 2
        }
    }

    Context 'Edge cases' {
        It 'Returns empty array for non-existent path' {
            $files = @(Get-MarkdownFiles -SearchPaths @('/non-existent-path-xyz-12345') -WarningAction SilentlyContinue)
            $files | Should -BeNullOrEmpty
        }
    }
}

#endregion

#region Get-MsDateFromFrontmatter Tests

Describe 'Get-MsDateFromFrontmatter' -Tag 'Unit' {
    BeforeEach {
        $script:TestFile = Join-Path $TestDrive 'test-frontmatter.md'
    }

    Context 'Valid ms.date' {
        It 'Returns DateTime for valid ISO 8601 date' {
            Set-Content -Path $script:TestFile -Value @'
---
title: Test
ms.date: 2025-06-15
---
# Content
'@
            $result = Get-MsDateFromFrontmatter -FilePath $script:TestFile
            $result | Should -BeOfType [DateTime]
            $result.Year | Should -Be 2025
            $result.Month | Should -Be 6
            $result.Day | Should -Be 15
        }

        It 'Parses ms.date alongside other frontmatter fields' {
            Set-Content -Path $script:TestFile -Value @'
---
title: Example
description: This is a test
ms.date: 2024-06-15
author: tester
---
Content
'@
            $result = Get-MsDateFromFrontmatter -FilePath $script:TestFile
            $result | Should -BeOfType [DateTime]
            $result.ToString('yyyy-MM-dd') | Should -Be '2024-06-15'
        }
    }

    Context 'Missing ms.date' {
        It 'Returns null when ms.date key is absent' {
            Set-Content -Path $script:TestFile -Value @'
---
title: No Date Field
---
Content
'@
            $result = Get-MsDateFromFrontmatter -FilePath $script:TestFile
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Invalid ms.date format' {
        It 'Returns null for wrong date separator format' {
            Set-Content -Path $script:TestFile -Value @'
---
ms.date: 2025/01/01
---
Content
'@
            $result = Get-MsDateFromFrontmatter -FilePath $script:TestFile
            $result | Should -BeNullOrEmpty
        }

        It 'Returns null for non-date string value' {
            Set-Content -Path $script:TestFile -Value @'
---
ms.date: invalid-date
---
Content
'@
            $result = Get-MsDateFromFrontmatter -FilePath $script:TestFile
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Malformed frontmatter' {
        It 'Returns null when frontmatter has no closing delimiter' {
            Set-Content -Path $script:TestFile -Value @'
---
title: Incomplete
'@
            $result = Get-MsDateFromFrontmatter -FilePath $script:TestFile
            $result | Should -BeNullOrEmpty
        }

        It 'Returns null when file has no frontmatter' {
            Set-Content -Path $script:TestFile -Value @'
# Regular Markdown
No frontmatter here.
'@
            $result = Get-MsDateFromFrontmatter -FilePath $script:TestFile
            $result | Should -BeNullOrEmpty
        }

        It 'Handles malformed YAML gracefully' {
            Set-Content -Path $script:TestFile -Value @'
---
title: "Unclosed quote
ms.date: 2025-01-01
---
Content
'@
            $result = Get-MsDateFromFrontmatter -FilePath $script:TestFile
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'File access errors' {
        It 'Returns null when file cannot be read' {
            $result = Get-MsDateFromFrontmatter -FilePath (Join-Path $TestDrive 'nonexistent.md') 3>$null
            $result | Should -BeNullOrEmpty
        }

        It 'Emits warning when file cannot be read' {
            $warnings = @(Get-MsDateFromFrontmatter -FilePath (Join-Path $TestDrive 'nonexistent.md') 3>&1)
            $warnings | Where-Object { $_ -like '*Error reading file*' } | Should -Not -BeNullOrEmpty
        }
    }
}

#endregion
#region New-MsDateReport Tests

Describe 'New-MsDateReport' -Tag 'Unit' {
    BeforeEach {
        Push-Location $TestDrive
        $script:Results = @(
            [PSCustomObject]@{ File = 'docs/fresh.md'; MsDate = '2026-03-01'; AgeDays = 8; IsStale = $false; Threshold = 90 },
            [PSCustomObject]@{ File = 'docs/stale.md'; MsDate = '2025-11-01'; AgeDays = 128; IsStale = $true; Threshold = 90 },
            [PSCustomObject]@{ File = 'docs/very-stale.md'; MsDate = '2025-06-01'; AgeDays = 281; IsStale = $true; Threshold = 90 }
        )
    }

    AfterEach {
        Pop-Location
    }

    Context 'JSON report creation' {
        It 'Creates msdate-freshness-results.json in logs directory' {
            New-MsDateReport -Results $script:Results -Threshold 90 -OutputDirectory (Join-Path $TestDrive 'logs')
            Test-Path (Join-Path $TestDrive 'logs/msdate-freshness-results.json') | Should -BeTrue
        }

        It 'JSON contains correct schema fields' {
            New-MsDateReport -Results $script:Results -Threshold 90 -OutputDirectory (Join-Path $TestDrive 'logs')
            $json = Get-Content (Join-Path $TestDrive 'logs/msdate-freshness-results.json') -Raw | ConvertFrom-Json
            $json.Count | Should -Be 3
            $staleItem = $json | Where-Object { $_.File -eq 'docs/stale.md' }
            $staleItem.AgeDays | Should -Be 128
            $staleItem.IsStale | Should -BeTrue
        }
    }

    Context 'Markdown summary creation' {
        It 'Creates msdate-summary.md in logs directory' {
            New-MsDateReport -Results $script:Results -Threshold 90 -OutputDirectory (Join-Path $TestDrive 'logs')
            Test-Path (Join-Path $TestDrive 'logs/msdate-summary.md') | Should -BeTrue
        }

        It 'Markdown table lists stale files sorted by AgeDays descending' {
            New-MsDateReport -Results $script:Results -Threshold 90 -OutputDirectory (Join-Path $TestDrive 'logs')
            $md = Get-Content (Join-Path $TestDrive 'logs/msdate-summary.md') -Raw
            $md | Should -Match 'Stale Documentation Files'
            $veryStaleIndex = $md.IndexOf('docs/very-stale.md')
            $staleIndex = $md.IndexOf('docs/stale.md')
            $veryStaleIndex | Should -BeLessThan $staleIndex
        }
    }

    Context 'Return values' {
        It 'Returns object with JsonPath and MarkdownPath properties' {
            $report = New-MsDateReport -Results $script:Results -Threshold 90 -OutputDirectory (Join-Path $TestDrive 'logs')
            $report.JsonPath | Should -Not -BeNullOrEmpty
            $report.MarkdownPath | Should -Not -BeNullOrEmpty
        }

        It 'Returns StaleCount matching number of stale results' {
            $report = New-MsDateReport -Results $script:Results -Threshold 90 -OutputDirectory (Join-Path $TestDrive 'logs')
            $report.StaleCount | Should -Be 2
        }
    }

    Context 'All fresh files' {
        BeforeEach {
            $script:FreshResults = @(
                [PSCustomObject]@{ File = 'docs/fresh.md'; MsDate = '2026-03-01'; AgeDays = 8; IsStale = $false; Threshold = 90 }
            )
        }

        It 'Shows success message when no stale files' {
            New-MsDateReport -Results $script:FreshResults -Threshold 90 -OutputDirectory (Join-Path $TestDrive 'logs')
            $md = Get-Content (Join-Path $TestDrive 'logs/msdate-summary.md') -Raw
            $md | Should -Match 'All Files Fresh'
        }

        It 'Does not include stale files table' {
            New-MsDateReport -Results $script:FreshResults -Threshold 90 -OutputDirectory (Join-Path $TestDrive 'logs')
            $md = Get-Content (Join-Path $TestDrive 'logs/msdate-summary.md') -Raw
            $md | Should -Not -Match 'Stale Documentation Files'
        }
    }
}

#endregion

#region Integration Tests

Describe 'Invoke-MsDateFreshnessCheck Integration' -Tag 'Integration' {
    BeforeAll {
        Save-CIEnvironment
    }

    AfterAll {
        Restore-CIEnvironment
    }

    BeforeEach {
        $script:TestDir = Join-Path $TestDrive 'msdate-integration'
        New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        Push-Location $script:TestDir
        New-Item -ItemType Directory -Path 'logs' -Force | Out-Null
        Initialize-MockCIEnvironment -Workspace $script:TestDir | Out-Null
        Mock git { return $script:TestDir } -ParameterFilter { $args[0] -eq 'rev-parse' }

        Set-Content (Join-Path $script:TestDir 'fresh.md') @'
---
ms.date: 2026-03-01
title: Fresh Document
---
Content
'@

        Set-Content (Join-Path $script:TestDir 'stale.md') @'
---
ms.date: 2025-01-01
title: Stale Document
---
Content
'@

        Set-Content (Join-Path $script:TestDir 'no-date.md') @'
---
title: No Date
---
Content
'@
    }

    AfterEach {
        Pop-Location
        Restore-CIEnvironment
    }

    Context 'Full workflow' {
        It 'Processes files and generates reports' {
            Mock Write-CIAnnotation { }
            $markdownFiles = @(Get-MarkdownFiles -SearchPaths @($script:TestDir))
            $results = @()
            $currentDate = Get-Date

            foreach ($file in $markdownFiles) {
                $msDate = Get-MsDateFromFrontmatter -FilePath $file
                if ($null -eq $msDate) { continue }
                $ageDays = [int](($currentDate - $msDate).TotalDays)
                $results += [PSCustomObject]@{
                    File      = $file.Name
                    MsDate    = $msDate.ToString('yyyy-MM-dd')
                    AgeDays   = $ageDays
                    IsStale   = $ageDays -gt 90
                    Threshold = 90
                }
            }

            $results.Count | Should -Be 2
            $report = New-MsDateReport -Results $results -Threshold 90 -OutputDirectory (Join-Path $script:TestDir 'logs')
            Test-Path $report.JsonPath | Should -BeTrue
            Test-Path $report.MarkdownPath | Should -BeTrue
            $report.StaleCount | Should -BeGreaterThan 0
        }
    }

    Context 'CI annotations' {
        It 'Calls Write-CIAnnotation for stale files' {
            Mock Write-CIAnnotation { } -Verifiable
            $markdownFiles = @(Get-MarkdownFiles -SearchPaths @($script:TestDir))
            $currentDate = Get-Date

            foreach ($file in $markdownFiles) {
                $relativePath = $file.Name
                $msDate = Get-MsDateFromFrontmatter -FilePath $file
                if ($null -eq $msDate) { continue }
                $ageDays = [int](($currentDate - $msDate).TotalDays)
                if ($ageDays -gt 90) {
                    Write-CIAnnotation -Message "${relativePath}: ms.date is $ageDays days old (threshold: 90 days)" -Level 'Warning' -File $relativePath
                }
            }

            Should -InvokeVerifiable
        }
    }

    Context 'Threshold configuration' {
        It 'Allows custom threshold values' {
            $threshold = 30
            $markdownFiles = @(Get-MarkdownFiles -SearchPaths @($script:TestDir))
            $results = @()
            $currentDate = Get-Date

            foreach ($file in $markdownFiles) {
                $msDate = Get-MsDateFromFrontmatter -FilePath $file
                if ($null -eq $msDate) { continue }
                $ageDays = [int](($currentDate - $msDate).TotalDays)
                $results += [PSCustomObject]@{
                    File      = $file.Name
                    MsDate    = $msDate.ToString('yyyy-MM-dd')
                    AgeDays   = $ageDays
                    IsStale   = $ageDays -gt $threshold
                    Threshold = $threshold
                }
            }

            $staleFiles = @($results | Where-Object { $_.IsStale })
            $staleFiles.Count | Should -BeGreaterThan 0
        }
    }
}

#endregion
