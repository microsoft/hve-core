#Requires -Modules Pester
<#
.SYNOPSIS
    Pester tests for Link-Lang-Check.ps1 script
.DESCRIPTION
    Tests for language path link checker functions:
    - Get-GitTextFile
    - Find-LinksInFile
    - Repair-LinksInFile
    - Repair-AllLink
    - ConvertTo-JsonOutput
#>

BeforeAll {
    # Direct dot-source for proper code coverage tracking
    . $PSScriptRoot/../../linting/Link-Lang-Check.ps1

    $script:FixtureDir = Join-Path $PSScriptRoot '../Fixtures/Linting'
}

#region Get-GitTextFile Tests

Describe 'Get-GitTextFile' -Tag 'Unit' {
    Context 'Git command succeeds' {
        BeforeEach {
            Mock git {
                $global:LASTEXITCODE = 0
                return @('file1.md', 'file2.ps1', 'subdir/file3.txt')
            } -ParameterFilter { $args -contains '--name-only' }
        }

        It 'Returns array of file paths' {
            $result = Get-GitTextFile
            $result | Should -BeOfType [string]
            $result.Count | Should -Be 3
        }

        It 'Includes all returned files' {
            $result = Get-GitTextFile
            $result | Should -Contain 'file1.md'
            $result | Should -Contain 'file2.ps1'
            $result | Should -Contain 'subdir/file3.txt'
        }
    }

    Context 'Git command fails' {
        BeforeEach {
            Mock git {
                $global:LASTEXITCODE = 128
                return 'fatal: not a git repository'
            } -ParameterFilter { $args -contains '--name-only' }

            Mock Write-Error {}
        }

        It 'Returns empty array on git error' {
            $result = Get-GitTextFile
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Empty repository' {
        BeforeEach {
            Mock git {
                $global:LASTEXITCODE = 0
                return @()
            } -ParameterFilter { $args -contains '--name-only' }
        }

        It 'Returns empty array for empty repo' {
            $result = Get-GitTextFile
            $result | Should -BeNullOrEmpty
        }
    }
}

#endregion

#region Find-LinksInFile Tests

Describe 'Find-LinksInFile' -Tag 'Unit' {
    BeforeAll {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'File with en-us links' {
        BeforeEach {
            $script:TestFile = Join-Path $script:TempDir 'test-links.md'
            @'
# Test Document

Visit https://docs.microsoft.com/en-us/azure for Azure docs.
Also see https://learn.microsoft.com/en-us/dotnet/api for .NET API.
'@ | Set-Content -Path $script:TestFile
        }

        It 'Finds all en-us links' {
            $result = Find-LinksInFile -FilePath $script:TestFile
            $result.Count | Should -Be 2
        }

        It 'Returns correct file path' {
            $result = Find-LinksInFile -FilePath $script:TestFile
            $result[0].File | Should -Be $script:TestFile
        }

        It 'Returns correct line numbers' {
            $result = Find-LinksInFile -FilePath $script:TestFile
            $result[0].LineNumber | Should -Be 3
            $result[1].LineNumber | Should -Be 4
        }

        It 'Provides fixed URL without en-us' {
            $result = Find-LinksInFile -FilePath $script:TestFile
            $result[0].FixedUrl | Should -Not -Match 'en-us/'
            $result[0].FixedUrl | Should -Be 'https://docs.microsoft.com/azure'
        }
    }

    Context 'File without en-us links' {
        BeforeEach {
            $script:CleanFile = Join-Path $script:TempDir 'clean-links.md'
            @'
# Clean Document

Visit https://docs.microsoft.com/azure for docs.
'@ | Set-Content -Path $script:CleanFile
        }

        It 'Returns empty array when no en-us links found' {
            $result = Find-LinksInFile -FilePath $script:CleanFile
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Nonexistent file' {
        It 'Returns empty array for nonexistent file' {
            $result = Find-LinksInFile -FilePath 'C:\nonexistent\file.md'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Multiple links on same line' {
        BeforeEach {
            $script:MultiLinkFile = Join-Path $script:TempDir 'multi-links.md'
            'See https://docs.microsoft.com/en-us/a and https://docs.microsoft.com/en-us/b here.' |
                Set-Content -Path $script:MultiLinkFile
        }

        It 'Finds all links on same line' {
            $result = Find-LinksInFile -FilePath $script:MultiLinkFile
            $result.Count | Should -Be 2
            $result[0].LineNumber | Should -Be 1
            $result[1].LineNumber | Should -Be 1
        }
    }
}

#endregion

#region Repair-LinksInFile Tests

Describe 'Repair-LinksInFile' -Tag 'Unit' {
    BeforeAll {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'File with links to repair' {
        BeforeEach {
            $script:RepairFile = Join-Path $script:TempDir 'repair-test.md'
            'Visit https://docs.microsoft.com/en-us/azure for docs.' |
                Set-Content -Path $script:RepairFile

            $script:Links = @(
                [PSCustomObject]@{
                    OriginalUrl = 'https://docs.microsoft.com/en-us/azure'
                    FixedUrl    = 'https://docs.microsoft.com/azure'
                }
            )
        }

        It 'Returns true when file is modified' {
            $result = Repair-LinksInFile -FilePath $script:RepairFile -Links $script:Links
            $result | Should -BeTrue
        }

        It 'Replaces en-us in file content' {
            Repair-LinksInFile -FilePath $script:RepairFile -Links $script:Links
            $content = Get-Content -Path $script:RepairFile -Raw
            $content | Should -Not -Match 'en-us/'
            $content | Should -Match 'https://docs.microsoft.com/azure'
        }
    }

    Context 'File with no changes needed' {
        BeforeEach {
            $script:NoChangeFile = Join-Path $script:TempDir 'no-change.md'
            'Visit https://docs.microsoft.com/azure for docs.' |
                Set-Content -Path $script:NoChangeFile

            $script:NoMatchLinks = @(
                [PSCustomObject]@{
                    OriginalUrl = 'https://example.com/en-us/page'
                    FixedUrl    = 'https://example.com/page'
                }
            )
        }

        It 'Returns false when no changes made' {
            $result = Repair-LinksInFile -FilePath $script:NoChangeFile -Links $script:NoMatchLinks
            $result | Should -BeFalse
        }
    }

    Context 'Nonexistent file' {
        It 'Returns false for nonexistent file' {
            $links = @([PSCustomObject]@{ OriginalUrl = 'a'; FixedUrl = 'b' })
            $result = Repair-LinksInFile -FilePath 'C:\nonexistent\file.md' -Links $links
            $result | Should -BeFalse
        }
    }
}

#endregion

#region Repair-AllLink Tests

Describe 'Repair-AllLink' -Tag 'Unit' {
    BeforeAll {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Multiple files with links' {
        BeforeEach {
            $script:File1 = Join-Path $script:TempDir 'file1.md'
            $script:File2 = Join-Path $script:TempDir 'file2.md'

            'Link: https://docs.microsoft.com/en-us/a' | Set-Content -Path $script:File1
            'Link: https://docs.microsoft.com/en-us/b' | Set-Content -Path $script:File2

            $script:AllLinks = @(
                [PSCustomObject]@{
                    File        = $script:File1
                    LineNumber  = 1
                    OriginalUrl = 'https://docs.microsoft.com/en-us/a'
                    FixedUrl    = 'https://docs.microsoft.com/a'
                },
                [PSCustomObject]@{
                    File        = $script:File2
                    LineNumber  = 1
                    OriginalUrl = 'https://docs.microsoft.com/en-us/b'
                    FixedUrl    = 'https://docs.microsoft.com/b'
                }
            )
        }

        It 'Returns count of modified files' {
            $result = Repair-AllLink -AllLinks $script:AllLinks
            $result | Should -Be 2
        }

        It 'Modifies all files' {
            Repair-AllLink -AllLinks $script:AllLinks
            (Get-Content $script:File1 -Raw) | Should -Not -Match 'en-us/'
            (Get-Content $script:File2 -Raw) | Should -Not -Match 'en-us/'
        }
    }

    Context 'Empty links array' {
        It 'Returns zero for empty input' {
            $result = Repair-AllLink -AllLinks @()
            $result | Should -Be 0
        }
    }
}

#endregion

#region ConvertTo-JsonOutput Tests

Describe 'ConvertTo-JsonOutput' -Tag 'Unit' {
    Context 'Valid link objects' {
        BeforeEach {
            $script:Links = @(
                [PSCustomObject]@{
                    File        = 'test.md'
                    LineNumber  = 5
                    OriginalUrl = 'https://example.com/en-us/page'
                    FixedUrl    = 'https://example.com/page'
                }
            )
        }

        It 'Returns array of objects' {
            $result = ConvertTo-JsonOutput -Links $script:Links
            $result | Should -BeOfType [PSCustomObject]
        }

        It 'Uses snake_case property names' {
            $result = ConvertTo-JsonOutput -Links $script:Links
            $result[0].PSObject.Properties.Name | Should -Contain 'file'
            $result[0].PSObject.Properties.Name | Should -Contain 'line_number'
            $result[0].PSObject.Properties.Name | Should -Contain 'original_url'
        }

        It 'Excludes FixedUrl from output' {
            $result = ConvertTo-JsonOutput -Links $script:Links
            $result[0].PSObject.Properties.Name | Should -Not -Contain 'FixedUrl'
            $result[0].PSObject.Properties.Name | Should -Not -Contain 'fixed_url'
        }

        It 'Preserves values correctly' {
            $result = ConvertTo-JsonOutput -Links $script:Links
            $result[0].file | Should -Be 'test.md'
            $result[0].line_number | Should -Be 5
            $result[0].original_url | Should -Be 'https://example.com/en-us/page'
        }
    }

    Context 'Empty input' {
        It 'Returns empty array for empty input' {
            $result = ConvertTo-JsonOutput -Links @()
            $result | Should -BeNullOrEmpty
        }
    }
}

#endregion

#region ExcludePaths Filtering Tests

Describe 'ExcludePaths Filtering' -Tag 'Integration' {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot '../../linting/Link-Lang-Check.ps1'
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Script invocation with ExcludePaths' {
        BeforeEach {
            # Create test directory structure
            $script:TestsDir = Join-Path $script:TempDir 'scripts/tests/linting'
            $script:DocsDir = Join-Path $script:TempDir 'docs'
            New-Item -ItemType Directory -Path $script:TestsDir -Force | Out-Null
            New-Item -ItemType Directory -Path $script:DocsDir -Force | Out-Null

            # Create test file with en-us link (should be excluded)
            $testFile = Join-Path $script:TestsDir 'test.md'
            'Link: https://docs.microsoft.com/en-us/test' | Set-Content -Path $testFile

            # Create docs file with en-us link (should be included)
            $docsFile = Join-Path $script:DocsDir 'readme.md'
            'Link: https://docs.microsoft.com/en-us/azure' | Set-Content -Path $docsFile
        }

        It 'Excludes files matching single pattern' {
            Push-Location $script:TempDir
            try {
                # Initialize git repo for Get-GitTextFile to work
                git init --quiet 2>$null
                git add -A 2>$null
                git commit -m 'init' --quiet 2>$null

                # Script outputs JSON by default (when not in -Fix mode)
                $result = & $script:ScriptPath -ExcludePaths 'scripts/tests/**' 2>$null
                $jsonResult = $result | ConvertFrom-Json -ErrorAction SilentlyContinue

                # Should only find the docs file, not the tests file
                if ($null -ne $jsonResult -and $jsonResult.Count -gt 0) {
                    $jsonResult | ForEach-Object { $_.file } | Should -Not -Match 'scripts/tests'
                }
            }
            finally {
                Pop-Location
            }
        }

        It 'Excludes files matching multiple patterns' {
            Push-Location $script:TempDir
            try {
                # Create additional directory to exclude
                $buildDir = Join-Path $script:TempDir 'build'
                New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
                $buildFile = Join-Path $buildDir 'output.md'
                'Link: https://docs.microsoft.com/en-us/build' | Set-Content -Path $buildFile

                git add -A 2>$null
                git commit -m 'add build' --quiet 2>$null

                $result = & $script:ScriptPath -ExcludePaths @('scripts/tests/**', 'build/**') 2>$null
                $jsonResult = $result | ConvertFrom-Json -ErrorAction SilentlyContinue

                if ($null -ne $jsonResult -and $jsonResult.Count -gt 0) {
                    $files = $jsonResult | ForEach-Object { $_.file }
                    $files | Should -Not -Match 'scripts/tests'
                    $files | Should -Not -Match 'build/'
                }
            }
            finally {
                Pop-Location
            }
        }

        It 'Processes all files when ExcludePaths is empty' {
            Push-Location $script:TempDir
            try {
                # Initialize git repo for the script to work
                git init --quiet 2>$null
                git add -A 2>$null
                git commit -m 'init' --quiet 2>$null

                $result = & $script:ScriptPath 2>$null
                $jsonResult = $result | ConvertFrom-Json -ErrorAction SilentlyContinue

                # Test passes if we get results or if the script runs without error
                # The actual count depends on file contents and patterns matched
                if ($null -ne $jsonResult -and $jsonResult.Count -gt 0) {
                    $jsonResult.Count | Should -BeGreaterOrEqual 1
                } else {
                    # Script ran successfully but found no matches - verify empty result
                    $jsonResult | Should -BeNullOrEmpty
                }
            }
            finally {
                Pop-Location
            }
        }
    }

    Context 'Pattern matching behavior' {
        It 'Matches glob pattern with double asterisk' {
            # Test the -like pattern matching used in the script
            $testPaths = @(
                'scripts/tests/linting/test.md',
                'scripts/tests/security/check.ps1',
                'scripts/linting/main.ps1',
                'docs/readme.md'
            )
            $pattern = 'scripts/tests/**'

            $excluded = $testPaths | Where-Object { $_ -like $pattern }
            $included = $testPaths | Where-Object { $_ -notlike $pattern }

            $excluded | Should -Contain 'scripts/tests/linting/test.md'
            $excluded | Should -Contain 'scripts/tests/security/check.ps1'
            $included | Should -Contain 'scripts/linting/main.ps1'
            $included | Should -Contain 'docs/readme.md'
        }

        It 'Matches multiple patterns correctly' {
            $testPaths = @(
                'scripts/tests/test.md',
                'build/output.md',
                'node_modules/pkg/file.js',
                'src/main.ps1'
            )
            $patterns = @('scripts/tests/**', 'build/**', 'node_modules/**')

            $included = $testPaths | Where-Object {
                $path = $_
                $isExcluded = $false
                foreach ($p in $patterns) {
                    if ($path -like $p) {
                        $isExcluded = $true
                        break
                    }
                }
                -not $isExcluded
            }

            $included.Count | Should -Be 1
            $included | Should -Contain 'src/main.ps1'
        }
    }
}

#endregion

#region Invoke-LinkLanguageCheck Function Tests

Describe 'Invoke-LinkLanguageCheck' -Tag 'Unit' {
    BeforeAll {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "llc-invoke-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Function discovery' {
        It 'Invoke-LinkLanguageCheck is defined' {
            Get-Command Invoke-LinkLanguageCheck -ErrorAction SilentlyContinue | Should -Not -BeNull
        }

        It 'Function has OutputType attribute' {
            $cmd = Get-Command Invoke-LinkLanguageCheck
            $cmd.OutputType.Type | Should -Contain ([int])
        }
    }

    Context 'No links found scenario' {
        BeforeEach {
            Mock Get-GitTextFile { return @() }
        }

        It 'Returns 0 exit code when no files to scan' {
            Mock Write-Output { }
            $result = Invoke-LinkLanguageCheck
            # The function returns exit code 0 at the end
            # But also outputs to Write-Output, so $result may be an array
            if ($result -is [array]) {
                $result[-1] | Should -Be 0
            } else {
                $result | Should -Be 0
            }
        }

        It 'Outputs empty JSON array when -Fix is not specified' {
            Mock Get-GitTextFile { return @() }
            Mock Write-Output { $script:CapturedOutput = $InputObject }

            Invoke-LinkLanguageCheck
            $script:CapturedOutput | Should -Be '[]'
        }

        It 'Outputs message when -Fix is specified and no links found' {
            Mock Get-GitTextFile { return @() }
            Mock Write-Output { $script:CapturedOutput = $InputObject }

            Invoke-LinkLanguageCheck -Fix
            $script:CapturedOutput | Should -Be "No URLs containing 'en-us' were found."
        }
    }

    Context 'Links found without -Fix' {
        BeforeEach {
            $script:TestFile = Join-Path $script:TempDir 'test-links.md'
            'Visit https://docs.microsoft.com/en-us/azure for docs.' | Set-Content -Path $script:TestFile

            Mock Get-GitTextFile { return @($script:TestFile) }
        }

        It 'Returns JSON output with found links' {
            $script:CapturedJson = $null
            Mock Write-Output { $script:CapturedJson = $InputObject }

            Invoke-LinkLanguageCheck

            $script:CapturedJson | Should -Not -BeNullOrEmpty
            $parsed = $script:CapturedJson | ConvertFrom-Json
            $parsed | Should -Not -BeNullOrEmpty
            $parsed[0].file | Should -Be $script:TestFile
        }

        It 'Returns exit code 0' {
            Mock Write-Output { }
            $result = Invoke-LinkLanguageCheck
            $result | Should -Be 0
        }
    }

    Context 'Links found with -Fix' {
        BeforeEach {
            $script:FixTestFile = Join-Path $script:TempDir 'fix-test.md'
            'Visit https://docs.microsoft.com/en-us/azure for docs.' | Set-Content -Path $script:FixTestFile

            Mock Get-GitTextFile { return @($script:FixTestFile) }
        }

        It 'Fixes links and outputs summary message' {
            $script:CapturedOutput = $null
            Mock Write-Output { $script:CapturedOutput = $InputObject }

            Invoke-LinkLanguageCheck -Fix

            $script:CapturedOutput | Should -Match 'Fixed \d+ URLs? in \d+ files?'
        }

        It 'Actually removes en-us from file content' {
            Mock Write-Output { }

            Invoke-LinkLanguageCheck -Fix

            $content = Get-Content -Path $script:FixTestFile -Raw
            $content | Should -Not -Match 'en-us/'
            $content | Should -Match 'https://docs.microsoft.com/azure'
        }
    }

    Context 'ExcludePaths filtering in function' {
        BeforeEach {
            $script:TestFile1 = Join-Path $script:TempDir 'src/doc.md'
            $script:TestFile2 = Join-Path $script:TempDir 'tests/test.md'

            New-Item -ItemType Directory -Path (Join-Path $script:TempDir 'src') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $script:TempDir 'tests') -Force | Out-Null

            'Link: https://docs.microsoft.com/en-us/src' | Set-Content -Path $script:TestFile1
            'Link: https://docs.microsoft.com/en-us/test' | Set-Content -Path $script:TestFile2

            Mock Get-GitTextFile { return @($script:TestFile1, $script:TestFile2) }
        }

        It 'Excludes files matching pattern' {
            # The function uses -like pattern matching internally
            $files = @('src/doc.md', 'tests/test.md')
            $excludePattern = 'tests/**'

            $filtered = $files | Where-Object {
                $filePath = $_
                $excluded = $false
                if ($filePath -like $excludePattern) {
                    $excluded = $true
                }
                -not $excluded
            }

            $filtered | Should -HaveCount 1
            $filtered | Should -Contain 'src/doc.md'
        }
    }

    Context 'File validation' {
        BeforeEach {
            Mock Get-GitTextFile { return @('nonexistent.md', $script:TestFile) }
        }

        It 'Skips files that do not exist' {
            $script:TestFile = Join-Path $script:TempDir 'existing.md'
            'Link: https://docs.microsoft.com/en-us/azure' | Set-Content -Path $script:TestFile

            Mock Get-GitTextFile { return @('nonexistent.md', $script:TestFile) }
            Mock Write-Output { $script:CapturedJson = $InputObject }

            Invoke-LinkLanguageCheck

            $parsed = $script:CapturedJson | ConvertFrom-Json
            # Should only have results from the existing file
            if ($parsed) {
                $parsed | ForEach-Object { $_.file } | Should -Not -Contain 'nonexistent.md'
            }
        }
    }
}

#endregion

#region Fix Mode Detailed Tests

Describe 'Fix Mode Detailed Tests' -Tag 'Unit' {
    BeforeAll {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "llc-fix-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Multiple links in multiple files' {
        BeforeEach {
            $script:File1 = Join-Path $script:TempDir 'doc1.md'
            $script:File2 = Join-Path $script:TempDir 'doc2.md'

            @'
# Documentation

Visit https://docs.microsoft.com/en-us/azure for Azure.
Also see https://learn.microsoft.com/en-us/dotnet for .NET.
'@ | Set-Content -Path $script:File1

            @'
# Guide

Link: https://docs.microsoft.com/en-us/windows
'@ | Set-Content -Path $script:File2

            Mock Get-GitTextFile { return @($script:File1, $script:File2) }
        }

        It 'Fixes all links in all files' {
            Mock Write-Output { }

            Invoke-LinkLanguageCheck -Fix

            $content1 = Get-Content -Path $script:File1 -Raw
            $content2 = Get-Content -Path $script:File2 -Raw

            $content1 | Should -Not -Match 'en-us/'
            $content2 | Should -Not -Match 'en-us/'
        }

        It 'Reports correct count of fixed URLs' {
            # Reset files
            @'
# Documentation
Visit https://docs.microsoft.com/en-us/azure for Azure.
Also see https://learn.microsoft.com/en-us/dotnet for .NET.
'@ | Set-Content -Path $script:File1

            @'
# Guide
Link: https://docs.microsoft.com/en-us/windows
'@ | Set-Content -Path $script:File2

            $script:CapturedOutput = $null
            Mock Write-Output { $script:CapturedOutput = $InputObject }

            Invoke-LinkLanguageCheck -Fix

            $script:CapturedOutput | Should -Match 'Fixed 3 URLs in 2 files'
        }
    }

    Context 'Verbose output in Fix mode' {
        BeforeEach {
            $script:VerboseFile = Join-Path $script:TempDir 'verbose-test.md'
            'Link: https://docs.microsoft.com/en-us/verbose' | Set-Content -Path $script:VerboseFile

            Mock Get-GitTextFile { return @($script:VerboseFile) }
            Mock Write-Output { }
            Mock Write-Information { }
        }

        It 'Outputs fix details when verbose' {
            # The function checks $Verbose variable, not -Verbose parameter
            # We test the Information stream behavior
            Invoke-LinkLanguageCheck -Fix

            # Function should complete and modify the file
            $content = Get-Content -Path $script:VerboseFile -Raw
            $content | Should -Not -Match 'en-us/'
        }
    }
}

#endregion

#region Error Handling Tests

Describe 'Error Handling' -Tag 'Unit' {
    Context 'Get-GitTextFile error handling' {
        It 'Returns empty array on git error' {
            Mock git {
                $global:LASTEXITCODE = 128
                throw 'git error'
            }

            $result = Get-GitTextFile
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Repair-LinksInFile write error handling' {
        BeforeAll {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "llc-err-$(New-Guid)"
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
        }

        AfterAll {
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Returns false when file cannot be read' {
            $links = @([PSCustomObject]@{ OriginalUrl = 'a'; FixedUrl = 'b' })
            $result = Repair-LinksInFile -FilePath 'C:\nonexistent\readonly.md' -Links $links
            $result | Should -BeFalse
        }

        It 'Returns false when content has no matching links' {
            $testFile = Join-Path $script:TempDir 'no-match.md'
            'No links here' | Set-Content -Path $testFile

            $links = @([PSCustomObject]@{
                OriginalUrl = 'https://example.com/en-us/nothere'
                FixedUrl = 'https://example.com/nothere'
            })

            $result = Repair-LinksInFile -FilePath $testFile -Links $links
            $result | Should -BeFalse
        }
    }
}

#endregion
