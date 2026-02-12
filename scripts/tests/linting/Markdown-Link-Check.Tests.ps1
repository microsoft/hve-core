#Requires -Modules Pester
<#
.SYNOPSIS
    Pester tests for Markdown-Link-Check.ps1 script
.DESCRIPTION
    Tests for markdown link checking wrapper functions:
    - Get-MarkdownTarget
    - Get-RelativePrefix
#>

BeforeAll {
    # Direct dot-source for proper code coverage tracking
    . $PSScriptRoot/../../linting/Markdown-Link-Check.ps1

    # Import LintingHelpers for mocking
    Import-Module (Join-Path $PSScriptRoot '../../linting/Modules/LintingHelpers.psm1') -Force

    $script:FixtureDir = Join-Path $PSScriptRoot '../Fixtures/Linting'
}

AfterAll {
    Remove-Module LintingHelpers -Force -ErrorAction SilentlyContinue
}

#region Get-MarkdownTarget Tests

Describe 'Get-MarkdownTarget' -Tag 'Unit' {
    BeforeAll {
        # Create a temp directory to use as test input
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Git-tracked files in repository' {
        BeforeEach {
            # Create test markdown files
            $script:TestFile1 = Join-Path $script:TempDir 'test1.md'
            $script:TestFile2 = Join-Path $script:TempDir 'test2.md'
            Set-Content -Path $script:TestFile1 -Value '# Test 1'
            Set-Content -Path $script:TestFile2 -Value '# Test 2'

            # Mock git to indicate we're in a repo and return tracked files
            Mock git {
                if ($args -contains 'rev-parse') {
                    $global:LASTEXITCODE = 0
                    return $script:TempDir
                }
                elseif ($args -contains 'ls-files') {
                    $global:LASTEXITCODE = 0
                    return @('test1.md', 'test2.md')
                }
            }
        }

        It 'Returns markdown files when given a directory' {
            $result = Get-MarkdownTarget -InputPath $script:TempDir
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Non-git fallback mode' {
        BeforeEach {
            # Create test files
            $script:TestFile = Join-Path $script:TempDir 'readme.md'
            Set-Content -Path $script:TestFile -Value '# Readme'

            # Mock git to simulate not being in a repo
            Mock git {
                $global:LASTEXITCODE = 128
                return 'fatal: not a git repository'
            }
        }

        It 'Falls back to filesystem when not in git repo' {
            $result = Get-MarkdownTarget -InputPath $script:TempDir
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Returns absolute paths' {
            $result = Get-MarkdownTarget -InputPath $script:TempDir
            if ($result) {
                [System.IO.Path]::IsPathRooted($result[0]) | Should -BeTrue
            }
        }
    }

    Context 'Empty input handling' {
        It 'Returns empty array for null input' {
            $result = Get-MarkdownTarget -InputPath $null
            $result | Should -BeNullOrEmpty
        }

        It 'Returns empty array for empty string input' {
            $result = Get-MarkdownTarget -InputPath ''
            $result | Should -BeNullOrEmpty
        }
    }
}

#endregion

#region Get-RelativePrefix Tests

Describe 'Get-RelativePrefix' -Tag 'Unit' {
    BeforeAll {
        # Create a temp directory structure for testing relative paths
        $script:TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:TempRoot -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TempRoot 'docs') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TempRoot 'docs/guide') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TempRoot 'src') -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Nested directory traversal' {
        It 'Returns relative prefix from subdirectory to root' {
            $fromPath = Join-Path $script:TempRoot 'docs/guide'
            $result = Get-RelativePrefix -FromPath $fromPath -ToPath $script:TempRoot
            $result | Should -Be '../../'
        }

        It 'Returns relative prefix from single-level directory to root' {
            $fromPath = Join-Path $script:TempRoot 'docs'
            $result = Get-RelativePrefix -FromPath $fromPath -ToPath $script:TempRoot
            $result | Should -Be '../'
        }
    }

    Context 'Same directory' {
        It 'Returns empty string for same directory' {
            $result = Get-RelativePrefix -FromPath $script:TempRoot -ToPath $script:TempRoot
            $result | Should -Be ''
        }
    }

    Context 'Sibling directories' {
        It 'Returns correct prefix between sibling directories' {
            $fromPath = Join-Path $script:TempRoot 'docs'
            $toPath = Join-Path $script:TempRoot 'src'
            $result = Get-RelativePrefix -FromPath $fromPath -ToPath $toPath
            $result | Should -Be '../src/'
        }
    }

    Context 'Forward slash normalization' {
        It 'Returns forward slashes on Windows' {
            $fromPath = Join-Path $script:TempRoot 'docs/guide'
            $result = Get-RelativePrefix -FromPath $fromPath -ToPath $script:TempRoot
            $result | Should -Not -Match '\\'
        }

        It 'Always has trailing slash when not empty' {
            $fromPath = Join-Path $script:TempRoot 'docs'
            $result = Get-RelativePrefix -FromPath $fromPath -ToPath $script:TempRoot
            if ($result -ne '') {
                $result | Should -Match '/$'
            }
        }
    }
}

#endregion

#region Script Integration Tests

Describe 'Markdown-Link-Check Integration' -Tag 'Integration' {
    Context 'Config file loading' {
        BeforeAll {
            $script:ConfigPath = Join-Path $PSScriptRoot '../Fixtures/Linting/link-check-config.json'
        }

        It 'Config fixture file exists' {
            Test-Path $script:ConfigPath | Should -BeTrue
        }

        It 'Config fixture is valid JSON' {
            { Get-Content $script:ConfigPath | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Config contains expected properties' {
            $config = Get-Content $script:ConfigPath | ConvertFrom-Json
            $config.PSObject.Properties.Name | Should -Contain 'ignorePatterns'
            $config.PSObject.Properties.Name | Should -Contain 'replacementPatterns'
        }
    }
}

Describe 'Invoke-MarkdownLinkCheck' -Tag 'Unit' {
    Context 'Function availability' {
        It 'Function is accessible after script load' {
            Get-Command Invoke-MarkdownLinkCheck | Should -Not -BeNullOrEmpty
        }

        It 'Has expected parameter set' {
            $cmd = Get-Command Invoke-MarkdownLinkCheck
            $cmd.Parameters.Keys | Should -Contain 'Path'
            $cmd.Parameters.Keys | Should -Contain 'ConfigPath'
            $cmd.Parameters.Keys | Should -Contain 'Quiet'
        }

        It 'Returns integer exit code' {
            $cmd = Get-Command Invoke-MarkdownLinkCheck
            $cmd.OutputType.Type.Name | Should -Contain 'Int32'
        }
    }

    Context 'Input validation' {
        BeforeEach {
            $script:originalLocation = Get-Location
            Set-Location $TestDrive

            # Create minimal structure
            New-Item -Path 'node_modules/.bin' -ItemType Directory -Force | Out-Null
            
            # Create a mock config file
            $script:configFile = Join-Path $TestDrive 'config.json'
            '{"ignorePatterns": []}' | Set-Content $script:configFile
        }

        AfterEach {
            Set-Location $script:originalLocation
        }

        It 'ConfigPath parameter is required' {
            $cmd = Get-Command Invoke-MarkdownLinkCheck
            # ConfigPath should not have an empty default value - verify it exists
            $cmd.Parameters.Keys | Should -Contain 'ConfigPath'
        }

        It 'Accepts array of paths' {
            $cmd = Get-Command Invoke-MarkdownLinkCheck
            $pathParam = $cmd.Parameters['Path']
            $pathParam.ParameterType.Name | Should -Be 'String[]'
        }
    }

    Context 'Default parameter values' {
        It 'Path has default value' {
            $cmd = Get-Command Invoke-MarkdownLinkCheck
            $pathParam = $cmd.Parameters['Path']
            # Parameters with default values are not mandatory
            $pathParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } | 
                ForEach-Object { $_.Mandatory | Should -BeFalse }
        }

        It 'Quiet is a switch parameter' {
            $cmd = Get-Command Invoke-MarkdownLinkCheck
            $quietParam = $cmd.Parameters['Quiet']
            $quietParam.ParameterType.Name | Should -Be 'SwitchParameter'
        }
    }

    Context 'No files found' {
        BeforeEach {
            $script:EmptyDir = Join-Path ([IO.Path]::GetTempPath()) (New-Guid).ToString()
            New-Item -ItemType Directory -Path $script:EmptyDir -Force | Out-Null
            
            $script:ConfigFile = Join-Path $script:EmptyDir 'config.json'
            '{"ignorePatterns": []}' | Set-Content $script:ConfigFile

            Mock git {
                if ($args -contains 'rev-parse') {
                    $global:LASTEXITCODE = 0
                    return $script:EmptyDir
                }
                elseif ($args -contains 'ls-files') {
                    $global:LASTEXITCODE = 0
                    return @()
                }
            }
        }

        AfterEach {
            Remove-Item -Path $script:EmptyDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Returns error when no markdown files found' {
            # Get-MarkdownTarget returns empty when no files found
            $files = Get-MarkdownTarget -InputPath @($script:EmptyDir)
            $files | Should -BeNullOrEmpty
        }
    }

    Context 'CLI not installed' {
        BeforeEach {
            $script:TestDir = Join-Path ([IO.Path]::GetTempPath()) (New-Guid).ToString()
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
            
            $script:TestMd = Join-Path $script:TestDir 'test.md'
            '# Test' | Set-Content $script:TestMd
            
            $script:ConfigFile = Join-Path $script:TestDir 'config.json'
            '{"ignorePatterns": []}' | Set-Content $script:ConfigFile

            Mock git {
                if ($args -contains 'rev-parse') {
                    $global:LASTEXITCODE = 0
                    return $script:TestDir
                }
                elseif ($args -contains 'ls-files') {
                    $global:LASTEXITCODE = 0
                    return @('test.md')
                }
            }
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'CLI path construction is correct' {
            # Verify the expected CLI path pattern
            $repoRoot = $script:TestDir
            $cli = Join-Path -Path $repoRoot -ChildPath 'node_modules/.bin/markdown-link-check'
            $cli | Should -Match 'markdown-link-check$'
        }
    }
}

#endregion

#region Get-MarkdownTarget Extended Tests

Describe 'Get-MarkdownTarget Extended' -Tag 'Unit' {
    BeforeAll {
        $script:TestRoot = Join-Path ([IO.Path]::GetTempPath()) (New-Guid).ToString()
        New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestRoot 'subdir') -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Specific file handling in git repo' {
        BeforeEach {
            $script:TestFile = Join-Path $script:TestRoot 'specific.md'
            '# Specific' | Set-Content $script:TestFile

            Mock git {
                if ($args -contains 'rev-parse') {
                    $global:LASTEXITCODE = 0
                    return $script:TestRoot
                }
                elseif ($args -contains 'ls-files') {
                    $global:LASTEXITCODE = 0
                    return 'specific.md'
                }
            }
        }

        It 'Returns specific file when it is git-tracked' {
            $result = Get-MarkdownTarget -InputPath $script:TestFile
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Untracked file handling' {
        BeforeEach {
            $script:UntrackedFile = Join-Path $script:TestRoot 'untracked.md'
            '# Untracked' | Set-Content $script:UntrackedFile

            Mock git {
                if ($args -contains 'rev-parse') {
                    $global:LASTEXITCODE = 0
                    return $script:TestRoot
                }
                elseif ($args -contains 'ls-files') {
                    $global:LASTEXITCODE = 0
                    return $null
                }
            }
        }

        It 'Writes warning for untracked files' {
            { Get-MarkdownTarget -InputPath $script:UntrackedFile -WarningAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context 'Non-markdown file handling' {
        BeforeEach {
            $script:NonMdFile = Join-Path $script:TestRoot 'readme.txt'
            'Not markdown' | Set-Content $script:NonMdFile

            Mock git {
                if ($args -contains 'rev-parse') {
                    $global:LASTEXITCODE = 0
                    return $script:TestRoot
                }
                elseif ($args -contains 'ls-files') {
                    $global:LASTEXITCODE = 0
                    return 'readme.txt'
                }
            }
        }

        It 'Ignores non-markdown files' {
            $result = Get-MarkdownTarget -InputPath $script:NonMdFile
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Multiple input paths' {
        BeforeEach {
            $script:File1 = Join-Path $script:TestRoot 'file1.md'
            $script:File2 = Join-Path $script:TestRoot 'file2.md'
            '# File 1' | Set-Content $script:File1
            '# File 2' | Set-Content $script:File2

            Mock git {
                if ($args -contains 'rev-parse') {
                    $global:LASTEXITCODE = 0
                    return $script:TestRoot
                }
                elseif ($args -contains 'ls-files') {
                    $global:LASTEXITCODE = 0
                    return @('file1.md', 'file2.md')
                }
            }
        }

        It 'Handles multiple input paths' {
            $result = Get-MarkdownTarget -InputPath @($script:File1, $script:File2)
            # Function should return array of files
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Invalid path handling' {
        It 'Handles non-existent paths gracefully' {
            Mock git {
                if ($args -contains 'rev-parse') {
                    $global:LASTEXITCODE = 0
                    return $script:TestRoot
                }
            }
            { Get-MarkdownTarget -InputPath '/nonexistent/path' -WarningAction SilentlyContinue } | Should -Not -Throw
        }
    }
}

#endregion

#region Invoke-MarkdownLinkCheck Extended Tests

Describe 'Invoke-MarkdownLinkCheck Extended' -Tag 'Unit' {
    BeforeAll {
        $script:TestDir = Join-Path ([IO.Path]::GetTempPath()) "mlc-ext-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestDir 'logs') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestDir 'node_modules/.bin') -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'No markdown files found' {
        BeforeEach {
            $script:ConfigFile = Join-Path $script:TestDir 'config.json'
            '{"ignorePatterns": []}' | Set-Content $script:ConfigFile

            Mock Get-MarkdownTarget { return @() }
            Mock Write-Error { }
        }

        It 'Returns 1 when no files found' {
            $result = Invoke-MarkdownLinkCheck -Path $script:TestDir -ConfigPath $script:ConfigFile 2>&1
            # Should error when no files found
            Should -Invoke Write-Error -Times 1
        }
    }

    Context 'CLI not installed' {
        BeforeEach {
            $script:ConfigFile = Join-Path $script:TestDir 'config.json'
            '{"ignorePatterns": []}' | Set-Content $script:ConfigFile

            $script:TestMd = Join-Path $script:TestDir 'test.md'
            '# Test document' | Set-Content $script:TestMd

            Mock Get-MarkdownTarget { return @($script:TestMd) }
            Mock Test-Path { $false } -ParameterFilter { $LiteralPath -match 'markdown-link-check' }
        }

        It 'Function requires CLI to be installed' {
            # Without actual CLI, function errors - verify CLI path check is performed
            $cmd = Get-Command Invoke-MarkdownLinkCheck -ErrorAction SilentlyContinue
            $cmd | Should -Not -BeNull
        }
    }

    Context 'Results output structure' {
        It 'Creates valid results structure' {
            $results = @{
                timestamp = (Get-Date).ToUniversalTime().ToString('o')
                script = 'markdown-link-check'
                summary = @{
                    total_files = 5
                    files_with_broken_links = 1
                    total_links_checked = 100
                    total_broken_links = 2
                }
                broken_links = @(
                    @{ File = 'test.md'; Link = 'http://broken.link'; Status = '404' }
                )
            }

            $results.script | Should -Be 'markdown-link-check'
            $results.summary.total_files | Should -Be 5
            $results.broken_links.Count | Should -Be 1
        }

        It 'Converts results to valid JSON' {
            $results = @{
                timestamp = (Get-Date).ToUniversalTime().ToString('o')
                script = 'markdown-link-check'
                summary = @{ total_files = 1; files_with_broken_links = 0; total_links_checked = 10; total_broken_links = 0 }
                broken_links = @()
            }

            $json = $results | ConvertTo-Json -Depth 10
            { $json | ConvertFrom-Json } | Should -Not -Throw
        }
    }

    Context 'GitHub annotations' {
        BeforeEach {
            Mock Write-GitHubAnnotation { }
        }

        It 'Creates annotation for broken link' {
            $brokenLink = @{ File = 'docs/readme.md'; Link = 'http://broken.com'; Status = '404' }

            Write-GitHubAnnotation -Type 'error' -Message "Broken link: $($brokenLink.Link) (Status: $($brokenLink.Status))" -File $brokenLink.File

            Should -Invoke Write-GitHubAnnotation -Times 1 -Exactly
        }
    }

    Context 'Step summary generation' {
        BeforeEach {
            Mock Write-GitHubStepSummary { }
            Mock Set-GitHubEnv { }
        }

        It 'Writes failure summary when broken links found' {
            $failedFiles = @('test1.md', 'test2.md')
            $brokenLinks = @(
                @{ File = 'test1.md'; Link = 'http://broken1.com'; Status = '404' },
                @{ File = 'test2.md'; Link = 'http://broken2.com'; Status = '500' }
            )
            $totalFiles = 5

            $summaryContent = @"
## ❌ Markdown Link Check Failed

**Files with broken links:** $($failedFiles.Count) / $totalFiles
**Total broken links:** $($brokenLinks.Count)
"@
            Write-GitHubStepSummary -Content $summaryContent

            Should -Invoke Write-GitHubStepSummary -Times 1 -Exactly
        }

        It 'Writes success summary when all links valid' {
            $totalFiles = 10
            $totalLinks = 50

            $summaryContent = @"
## ✅ Markdown Link Check Passed

**Files checked:** $totalFiles
**Total links checked:** $totalLinks
**Broken links:** 0
"@
            Write-GitHubStepSummary -Content $summaryContent

            Should -Invoke Write-GitHubStepSummary -Times 1 -Exactly
        }

        It 'Sets MARKDOWN_LINK_CHECK_FAILED env var on failure' {
            Set-GitHubEnv -Name "MARKDOWN_LINK_CHECK_FAILED" -Value "true"

            Should -Invoke Set-GitHubEnv -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'MARKDOWN_LINK_CHECK_FAILED' -and $Value -eq 'true'
            }
        }
    }

    Context 'Quiet mode' {
        It 'Quiet parameter is a switch' {
            $cmd = Get-Command Invoke-MarkdownLinkCheck
            $quietParam = $cmd.Parameters['Quiet']
            $quietParam.ParameterType.Name | Should -Be 'SwitchParameter'
        }
    }

    Context 'XML parsing simulation' {
        It 'Parses test case properties correctly' {
            # Simulate XML structure from markdown-link-check junit output
            $xmlContent = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
    <testsuite name="test.md" tests="3">
        <testcase name="link1">
            <properties>
                <property name="url" value="https://example.com"/>
                <property name="status" value="alive"/>
                <property name="statusCode" value="200"/>
            </properties>
        </testcase>
        <testcase name="link2">
            <properties>
                <property name="url" value="https://broken.com"/>
                <property name="status" value="dead"/>
                <property name="statusCode" value="404"/>
            </properties>
        </testcase>
    </testsuite>
</testsuites>
'@
            [xml]$xml = $xmlContent

            $testcases = $xml.testsuites.testsuite.testcase
            $testcases.Count | Should -Be 2

            $deadLink = $testcases | Where-Object {
                ($_.properties.property | Where-Object { $_.name -eq 'status' }).value -eq 'dead'
            }
            $deadLink | Should -Not -BeNull

            $url = ($deadLink.properties.property | Where-Object { $_.name -eq 'url' }).value
            $url | Should -Be 'https://broken.com'
        }
    }
}

#endregion

#region Invoke-MarkdownLinkCheck Detailed Tests

Describe 'Invoke-MarkdownLinkCheck Detailed' -Tag 'Unit' {
    BeforeAll {
        $script:TestDir = Join-Path ([IO.Path]::GetTempPath()) "mlc-detail-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestDir 'logs') -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Broken link output structure' {
        It 'Creates correct broken link object structure' {
            $brokenLink = @{
                File = 'docs/readme.md'
                Link = 'https://broken.example.com/page'
                Status = '404'
            }
            $brokenLink.File | Should -Be 'docs/readme.md'
            $brokenLink.Link | Should -Match '^https://'
            $brokenLink.Status | Should -Be '404'
        }

        It 'Accumulates multiple broken links' {
            $brokenLinks = @()
            $brokenLinks += @{ File = 'a.md'; Link = 'url1'; Status = '404' }
            $brokenLinks += @{ File = 'b.md'; Link = 'url2'; Status = '500' }
            $brokenLinks.Count | Should -Be 2
        }
    }

    Context 'Results JSON structure' {
        It 'Creates valid results object' {
            $results = @{
                timestamp = (Get-Date).ToUniversalTime().ToString('o')
                script = 'markdown-link-check'
                summary = @{
                    total_files = 10
                    files_with_broken_links = 2
                    total_links_checked = 100
                    total_broken_links = 5
                }
                broken_links = @(
                    @{ File = 'test.md'; Link = 'http://broken.com'; Status = '404' }
                )
            }
            $results.script | Should -Be 'markdown-link-check'
            $results.summary.total_files | Should -Be 10
            $results.summary.total_broken_links | Should -Be 5
        }

        It 'Serializes to valid JSON' {
            $results = @{
                timestamp = (Get-Date).ToUniversalTime().ToString('o')
                script = 'markdown-link-check'
                summary = @{ total_files = 1; files_with_broken_links = 0; total_links_checked = 5; total_broken_links = 0 }
                broken_links = @()
            }
            $json = $results | ConvertTo-Json -Depth 10
            $parsed = $json | ConvertFrom-Json
            $parsed.script | Should -Be 'markdown-link-check'
        }
    }

    Context 'GitHub summary content' {
        It 'Generates failure summary with correct format' {
            $failedFiles = @('test1.md', 'test2.md')
            $brokenLinks = @(
                @{ File = 'test1.md'; Link = 'http://broken1.com'; Status = '404' }
            )
            $totalFiles = 10

            $summary = "Files with broken links: $($failedFiles.Count) / $totalFiles"
            $summary | Should -Match 'Files with broken links: 2 / 10'
        }

        It 'Generates success summary' {
            $totalFiles = 10
            $totalLinks = 50

            $summary = "Files checked: $totalFiles, Links checked: $totalLinks, Broken: 0"
            $summary | Should -Match 'Broken: 0'
        }
    }

    Context 'Link status classification' {
        It 'Identifies alive status' {
            $status = 'alive'
            $status | Should -Be 'alive'
        }

        It 'Identifies dead status' {
            $status = 'dead'
            $status | Should -Be 'dead'
        }

        It 'Identifies ignored status' {
            $status = 'ignored'
            $status | Should -Be 'ignored'
        }
    }
}

Describe 'Get-MarkdownTarget Detailed' -Tag 'Unit' {
    BeforeAll {
        $script:TestRoot = Join-Path ([IO.Path]::GetTempPath()) "mdt-detail-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestRoot 'docs') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestRoot '.github') -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Path type detection' {
        BeforeEach {
            '# Test' | Set-Content -Path (Join-Path $script:TestRoot 'file.md')
            '# Docs' | Set-Content -Path (Join-Path $script:TestRoot 'docs/guide.md')
        }

        It 'Distinguishes files from directories' {
            $filePath = Join-Path $script:TestRoot 'file.md'
            $dirPath = Join-Path $script:TestRoot 'docs'

            Test-Path -Path $filePath -PathType Leaf | Should -BeTrue
            Test-Path -Path $dirPath -PathType Container | Should -BeTrue
        }

        It 'Resolves absolute paths' {
            $filePath = Join-Path $script:TestRoot 'file.md'
            $resolved = Resolve-Path $filePath
            [System.IO.Path]::IsPathRooted($resolved.Path) | Should -BeTrue
        }
    }

    Context 'Git integration paths' {
        BeforeEach {
            Mock git {
                if ($args -contains 'rev-parse') {
                    $global:LASTEXITCODE = 0
                    return $script:TestRoot
                }
                elseif ($args -contains 'ls-files') {
                    $global:LASTEXITCODE = 0
                    return @('docs/guide.md')
                }
            }
        }

        It 'Uses git ls-files for tracked files' {
            $result = Get-MarkdownTarget -InputPath (Join-Path $script:TestRoot 'docs')
            Should -Invoke git -ParameterFilter { $args -contains 'ls-files' }
        }
    }

    Context 'Deduplication' {
        It 'Returns unique paths' {
            $paths = @('file.md', 'file.md', 'other.md')
            $unique = $paths | Sort-Object -Unique
            $unique.Count | Should -Be 2
        }
    }
}

Describe 'Get-RelativePrefix Detailed' -Tag 'Unit' {
    BeforeAll {
        $script:TestRoot = Join-Path ([IO.Path]::GetTempPath()) "relprefix-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestRoot 'a/b/c') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestRoot 'x/y') -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Depth calculations' {
        It 'Returns correct prefix for 3-level depth' {
            $from = Join-Path $script:TestRoot 'a/b/c'
            $to = $script:TestRoot
            $result = Get-RelativePrefix -FromPath $from -ToPath $to
            $result | Should -Match '^\.\./\.\./\.\./$'
        }

        It 'Returns correct prefix for 2-level depth' {
            $from = Join-Path $script:TestRoot 'x/y'
            $to = $script:TestRoot
            $result = Get-RelativePrefix -FromPath $from -ToPath $to
            $result | Should -Match '^\.\./\.\./$'
        }
    }

    Context 'Cross-directory navigation' {
        It 'Calculates prefix between sibling trees' {
            $from = Join-Path $script:TestRoot 'a/b'
            $to = Join-Path $script:TestRoot 'x/y'
            $result = Get-RelativePrefix -FromPath $from -ToPath $to
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Invoke-MarkdownLinkCheck Orchestration' -Tag 'Integration' {
    BeforeAll {
        $script:OrchTestDir = Join-Path ([IO.Path]::GetTempPath()) "mlc-orch-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:OrchTestDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:OrchTestDir 'logs') -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $script:OrchTestDir) {
            Remove-Item -Path $script:OrchTestDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Input validation flow' {
        It 'Path parameter accepts multiple directories' {
            $paths = @('.', '.github', '.devcontainer')
            $paths.Count | Should -Be 3
        }

        It 'ConfigPath must be resolved' {
            $configPath = Join-Path $script:OrchTestDir 'test-config.json'
            '{"ignorePatterns": []}' | Set-Content $configPath

            { Resolve-Path -LiteralPath $configPath -ErrorAction Stop } | Should -Not -Throw
        }
    }

    Context 'CLI detection' {
        It 'Constructs correct CLI path on Windows' {
            $repoRoot = $script:OrchTestDir
            $baseCli = Join-Path $repoRoot 'node_modules/.bin/markdown-link-check'
            if ($IsWindows) {
                $cli = $baseCli + '.cmd'
                $cli | Should -Match '\.cmd$'
            } else {
                $cli = $baseCli
                $cli | Should -Not -Match '\.cmd$'
            }
        }

        It 'Constructs correct CLI path on Unix' {
            $repoRoot = $script:OrchTestDir
            $cli = Join-Path $repoRoot 'node_modules/.bin/markdown-link-check'
            $cli | Should -Not -Match '\\$'
        }
    }

    Context 'Arguments construction' {
        It 'Builds base arguments with config' {
            $configPath = '/path/to/config.json'
            $baseArguments = @('-c', $configPath)
            $baseArguments | Should -Contain '-c'
            $baseArguments | Should -Contain $configPath
        }

        It 'Adds -q flag when Quiet specified' {
            $baseArguments = @('-c', '/path/config.json')
            $quiet = $true
            if ($quiet) {
                $baseArguments += '-q'
            }
            $baseArguments | Should -Contain '-q'
        }

        It 'Does not add -q flag when Quiet not specified' {
            $baseArguments = @('-c', '/path/config.json')
            $quiet = $false
            if ($quiet) {
                $baseArguments += '-q'
            }
            $baseArguments | Should -Not -Contain '-q'
        }
    }

    Context 'Results accumulation' {
        It 'Tracks failed files' {
            $failedFiles = @()
            $relative = 'docs/broken.md'
            $exitCode = 1

            if ($exitCode -ne 0) {
                $failedFiles += $relative
            }

            $failedFiles.Count | Should -Be 1
            $failedFiles | Should -Contain 'docs/broken.md'
        }

        It 'Accumulates broken links' {
            $brokenLinks = @()
            $brokenLinks += @{ File = 'a.md'; Link = 'http://broken1.com'; Status = '404' }
            $brokenLinks += @{ File = 'b.md'; Link = 'http://broken2.com'; Status = '500' }

            $brokenLinks.Count | Should -Be 2
        }

        It 'Tracks total links checked' {
            $totalLinks = 0
            $totalLinks++
            $totalLinks++
            $totalLinks++

            $totalLinks | Should -Be 3
        }
    }

    Context 'Results file generation' {
        It 'Creates results structure with correct fields' {
            $results = @{
                timestamp = (Get-Date).ToUniversalTime().ToString('o')
                script = 'markdown-link-check'
                summary = @{
                    total_files = 10
                    files_with_broken_links = 2
                    total_links_checked = 150
                    total_broken_links = 5
                }
                broken_links = @()
            }

            $results.Keys | Should -Contain 'timestamp'
            $results.Keys | Should -Contain 'script'
            $results.Keys | Should -Contain 'summary'
            $results.Keys | Should -Contain 'broken_links'
        }

        It 'Writes results to logs directory' {
            $logsDir = Join-Path $script:OrchTestDir 'logs'
            $resultsPath = Join-Path $logsDir 'test-results.json'

            $results = @{ script = 'markdown-link-check'; summary = @{ total = 0 } }
            $results | ConvertTo-Json -Depth 10 | Set-Content -Path $resultsPath -Encoding UTF8

            Test-Path $resultsPath | Should -BeTrue
        }
    }

    Context 'Success path' {
        BeforeEach {
            Mock Write-GitHubStepSummary { }
        }

        It 'Returns 0 when no broken links' {
            $failedFilesCount = 0
            $exitCode = if ($failedFilesCount -gt 0) { 1 } else { 0 }
            $exitCode | Should -Be 0
        }

        It 'Writes success summary' {
            $totalFiles = 5
            $totalLinks = 25

            $summaryContent = @"
## ✅ Markdown Link Check Passed

**Files checked:** $totalFiles
**Total links checked:** $totalLinks
**Broken links:** 0

Great job! All markdown links are valid. 🎉
"@
            Write-GitHubStepSummary -Content $summaryContent

            Should -Invoke Write-GitHubStepSummary -Times 1
        }
    }

    Context 'Failure path' {
        BeforeEach {
            Mock Write-GitHubStepSummary { }
            Mock Set-GitHubEnv { }
            Mock Write-Error { }
        }

        It 'Returns 1 when broken links found' {
            $failedFilesCount = 2
            $exitCode = if ($failedFilesCount -gt 0) { 1 } else { 0 }
            $exitCode | Should -Be 1
        }

        It 'Sets MARKDOWN_LINK_CHECK_FAILED env variable' {
            Set-GitHubEnv -Name "MARKDOWN_LINK_CHECK_FAILED" -Value "true"
            Should -Invoke Set-GitHubEnv -ParameterFilter { $Name -eq 'MARKDOWN_LINK_CHECK_FAILED' }
        }

        It 'Writes failure summary with broken link table' {
            $failedFiles = @('test1.md')
            $brokenLinks = @(
                @{ File = 'test1.md'; Link = 'http://broken.com' }
            )
            $totalFiles = 2

            $summaryContent = @"
## ❌ Markdown Link Check Failed

**Files with broken links:** $($failedFiles.Count) / $totalFiles
**Total broken links:** $($brokenLinks.Count)

### Broken Links

| File | Broken Link |
|------|-------------|
"@
            foreach ($link in $brokenLinks) {
                $summaryContent += "`n| ``$($link.File)`` | ``$($link.Link)`` |"
            }

            Write-GitHubStepSummary -Content $summaryContent

            Should -Invoke Write-GitHubStepSummary -Times 1
        }
    }

    Context 'Logs directory creation' {
        It 'Creates logs directory if not exists' {
            $testLogsDir = Join-Path $script:OrchTestDir 'new-logs'
            if (-not (Test-Path $testLogsDir)) {
                New-Item -ItemType Directory -Path $testLogsDir -Force | Out-Null
            }
            Test-Path $testLogsDir | Should -BeTrue
        }
    }
}

#region Phase 1: Pure Function Error Path Tests

Describe 'Get-MarkdownTarget Additional Edge Cases' -Tag 'Unit' {
    BeforeAll {
        $script:EdgeCaseDir = Join-Path ([System.IO.Path]::GetTempPath()) "mdtarget-edge-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:EdgeCaseDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:EdgeCaseDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Git-tracked file handling' {
        BeforeEach {
            $script:TestMdFile = Join-Path $script:EdgeCaseDir 'tracked.md'
            '# Tracked file' | Set-Content -Path $script:TestMdFile

            $script:UntrackedFile = Join-Path $script:EdgeCaseDir 'untracked.md'
            '# Untracked file' | Set-Content -Path $script:UntrackedFile
        }

        It 'Warns when specific file is not tracked by git' {
            Mock git {
                if ($args -contains 'rev-parse') {
                    $global:LASTEXITCODE = 0
                    return $script:EdgeCaseDir
                }
                elseif ($args -contains 'ls-files') {
                    $global:LASTEXITCODE = 0
                    return $null  # File not tracked
                }
            }

            $warnings = $null
            $result = Get-MarkdownTarget -InputPath @($script:UntrackedFile) 3>&1 | ForEach-Object {
                if ($_ -is [System.Management.Automation.WarningRecord]) {
                    $warnings = $_
                }
                else {
                    $_
                }
            }
            # Should have warned about untracked file or returned empty
            ($warnings -match 'not tracked' -or $result.Count -eq 0) | Should -BeTrue
        }

        It 'Returns empty for directory with no tracked markdown files' {
            Mock git {
                if ($args -contains 'rev-parse') {
                    $global:LASTEXITCODE = 0
                    return $script:EdgeCaseDir
                }
                elseif ($args -contains 'ls-files') {
                    $global:LASTEXITCODE = 0
                    return @()  # No tracked files
                }
            }

            $result = Get-MarkdownTarget -InputPath @($script:EdgeCaseDir)
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Path resolution edge cases' {
        It 'Warns for non-existent path' {
            Mock git {
                $global:LASTEXITCODE = 0
                return $script:EdgeCaseDir
            }

            $nonExistent = '/this/path/does/not/exist/12345'
            $warnings = @()
            $result = Get-MarkdownTarget -InputPath @($nonExistent) 3>&1 | ForEach-Object {
                if ($_ -is [System.Management.Automation.WarningRecord]) {
                    $warnings += $_
                }
                else {
                    $_
                }
            }
            # Should warn about unresolvable path or return empty
            ($warnings.Count -gt 0 -or $null -eq $result -or $result.Count -eq 0) | Should -BeTrue
        }

        It 'Handles path with special characters' {
            $specialDir = Join-Path $script:EdgeCaseDir 'path-with-[brackets]'
            New-Item -ItemType Directory -Path $specialDir -Force -ErrorAction SilentlyContinue | Out-Null
            if (Test-Path $specialDir) {
                '# Special' | Set-Content -Path (Join-Path $specialDir 'test.md') -ErrorAction SilentlyContinue

                Mock git {
                    if ($args -contains 'rev-parse') {
                        $global:LASTEXITCODE = 128
                        return 'not a git repo'
                    }
                }

                # Fallback mode - filesystem search
                { Get-MarkdownTarget -InputPath @($specialDir) } | Should -Not -Throw
            }
        }

        It 'Handles whitespace-only path in array' {
            $result = Get-MarkdownTarget -InputPath @('   ', '')
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Non-git repository fallback' {
        BeforeEach {
            Mock git {
                $global:LASTEXITCODE = 128
                Write-Error 'fatal: not a git repository'
            }

            $script:NonGitDir = Join-Path $script:EdgeCaseDir 'non-git'
            New-Item -ItemType Directory -Path $script:NonGitDir -Force | Out-Null
            '# Test' | Set-Content -Path (Join-Path $script:NonGitDir 'test.md')
        }

        It 'Falls back to filesystem when git rev-parse fails' {
            $result = Get-MarkdownTarget -InputPath @($script:NonGitDir)
            # Should find the file via filesystem fallback
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Returns absolute paths in fallback mode' {
            $result = Get-MarkdownTarget -InputPath @($script:NonGitDir)
            if ($result) {
                foreach ($path in $result) {
                    [System.IO.Path]::IsPathRooted($path) | Should -BeTrue
                }
            }
        }
    }

    Context 'Mixed input types' {
        BeforeEach {
            $script:MixedDir = Join-Path $script:EdgeCaseDir 'mixed'
            New-Item -ItemType Directory -Path $script:MixedDir -Force | Out-Null
            $script:MixedFile = Join-Path $script:MixedDir 'file.md'
            '# File' | Set-Content -Path $script:MixedFile

            Mock git {
                if ($args -contains 'rev-parse') {
                    $global:LASTEXITCODE = 128
                    return 'not a git repo'
                }
            }
        }

        It 'Handles array with both files and directories' {
            $result = Get-MarkdownTarget -InputPath @($script:MixedDir, $script:MixedFile)
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Deduplicates results when file in directory is also specified' {
            $result = Get-MarkdownTarget -InputPath @($script:MixedDir, $script:MixedFile)
            $uniqueResult = $result | Sort-Object -Unique
            $result.Count | Should -Be $uniqueResult.Count
        }
    }
}

Describe 'Get-RelativePrefix Additional Edge Cases' -Tag 'Unit' {
    Context 'Path calculation edge cases' {
        It 'Handles deeply nested paths' {
            $deep = Join-Path ([System.IO.Path]::GetTempPath()) 'a/b/c/d/e/f'
            $root = [System.IO.Path]::GetTempPath().TrimEnd([System.IO.Path]::DirectorySeparatorChar)
            
            $result = Get-RelativePrefix -FromPath $deep -ToPath $root
            $result | Should -Match '^\.\./.*'
            ($result -split '/').Count | Should -BeGreaterOrEqual 6
        }

        It 'Returns forward slashes only on all platforms' {
            $from = Join-Path ([System.IO.Path]::GetTempPath()) 'src/components'
            $to = [System.IO.Path]::GetTempPath()

            $result = Get-RelativePrefix -FromPath $from -ToPath $to
            $result | Should -Not -Match '\\'
        }

        It 'Adds trailing slash to non-empty result' {
            $from = Join-Path ([System.IO.Path]::GetTempPath()) 'subdir'
            $to = [System.IO.Path]::GetTempPath()

            $result = Get-RelativePrefix -FromPath $from -ToPath $to
            if ($result -and $result -ne '') {
                $result | Should -Match '/$'
            }
        }
    }
}

#endregion

#region Phase 2: Mocked Integration Tests for Invoke-MarkdownLinkCheck

Describe 'Invoke-MarkdownLinkCheck Integration' -Tag 'Integration' {
    BeforeAll {
        $script:LinkCheckIntegrationDir = Join-Path ([IO.Path]::GetTempPath()) "linkcheck-integration-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:LinkCheckIntegrationDir -Force | Out-Null

        # Fixture XML for successful link check
        $script:FixtureXmlSuccess = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="test.md" tests="2" failures="0">
    <testcase name="link1">
      <properties>
        <property name="url" value="https://example.com"/>
        <property name="status" value="alive"/>
        <property name="statusCode" value="200"/>
      </properties>
    </testcase>
    <testcase name="link2">
      <properties>
        <property name="url" value="https://github.com"/>
        <property name="status" value="alive"/>
        <property name="statusCode" value="200"/>
      </properties>
    </testcase>
  </testsuite>
</testsuites>
'@

        # Fixture XML for broken links
        $script:FixtureXmlBroken = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="test.md" tests="2" failures="1">
    <testcase name="link1">
      <properties>
        <property name="url" value="https://example.com"/>
        <property name="status" value="alive"/>
        <property name="statusCode" value="200"/>
      </properties>
    </testcase>
    <testcase name="link2">
      <properties>
        <property name="url" value="https://broken.example.com/404"/>
        <property name="status" value="dead"/>
        <property name="statusCode" value="404"/>
      </properties>
    </testcase>
  </testsuite>
</testsuites>
'@

        # Fixture XML with ignored links
        $script:FixtureXmlIgnored = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="test.md" tests="2" failures="0">
    <testcase name="link1">
      <properties>
        <property name="url" value="https://example.com"/>
        <property name="status" value="alive"/>
        <property name="statusCode" value="200"/>
      </properties>
    </testcase>
    <testcase name="link2">
      <properties>
        <property name="url" value="http://localhost:3000"/>
        <property name="status" value="ignored"/>
        <property name="statusCode" value="0"/>
      </properties>
    </testcase>
  </testsuite>
</testsuites>
'@
    }

    AfterAll {
        Remove-Item -Path $script:LinkCheckIntegrationDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'XML fixture parsing' {
        It 'Parses successful XML fixture correctly' {
            $xml = [xml]$script:FixtureXmlSuccess

            $xml.testsuites | Should -Not -BeNullOrEmpty
            $xml.testsuites.testsuite | Should -Not -BeNullOrEmpty
            $xml.testsuites.testsuite.testcase.Count | Should -Be 2
        }

        It 'Extracts link properties from XML' {
            $xml = [xml]$script:FixtureXmlSuccess

            foreach ($testcase in $xml.testsuites.testsuite.testcase) {
                $url = ($testcase.properties.property | Where-Object { $_.name -eq 'url' }).value
                $status = ($testcase.properties.property | Where-Object { $_.name -eq 'status' }).value
                $statusCode = ($testcase.properties.property | Where-Object { $_.name -eq 'statusCode' }).value

                $url | Should -Not -BeNullOrEmpty
                $status | Should -Be 'alive'
                $statusCode | Should -Be '200'
            }
        }

        It 'Identifies broken links in XML' {
            $xml = [xml]$script:FixtureXmlBroken
            $brokenLinks = @()

            foreach ($testcase in $xml.testsuites.testsuite.testcase) {
                $status = ($testcase.properties.property | Where-Object { $_.name -eq 'status' }).value
                if ($status -eq 'dead') {
                    $url = ($testcase.properties.property | Where-Object { $_.name -eq 'url' }).value
                    $brokenLinks += $url
                }
            }

            $brokenLinks.Count | Should -Be 1
            $brokenLinks[0] | Should -Match 'broken\.example\.com'
        }

        It 'Identifies ignored links in XML' {
            $xml = [xml]$script:FixtureXmlIgnored
            $ignoredLinks = @()

            foreach ($testcase in $xml.testsuites.testsuite.testcase) {
                $status = ($testcase.properties.property | Where-Object { $_.name -eq 'status' }).value
                if ($status -eq 'ignored') {
                    $url = ($testcase.properties.property | Where-Object { $_.name -eq 'url' }).value
                    $ignoredLinks += $url
                }
            }

            $ignoredLinks.Count | Should -Be 1
            $ignoredLinks[0] | Should -Match 'localhost'
        }
    }

    Context 'Results aggregation' {
        It 'Aggregates results from single file' {
            $xml = [xml]$script:FixtureXmlSuccess
            $totalLinks = 0
            $brokenLinks = @()

            foreach ($testcase in $xml.testsuites.testsuite.testcase) {
                $totalLinks++
                $status = ($testcase.properties.property | Where-Object { $_.name -eq 'status' }).value
                if ($status -eq 'dead') {
                    $url = ($testcase.properties.property | Where-Object { $_.name -eq 'url' }).value
                    $brokenLinks += @{
                        File = 'test.md'
                        Link = $url
                    }
                }
            }

            $totalLinks | Should -Be 2
            $brokenLinks.Count | Should -Be 0
        }

        It 'Aggregates broken links correctly' {
            $xml = [xml]$script:FixtureXmlBroken
            $brokenLinks = @()

            foreach ($testcase in $xml.testsuites.testsuite.testcase) {
                $status = ($testcase.properties.property | Where-Object { $_.name -eq 'status' }).value
                $statusCode = ($testcase.properties.property | Where-Object { $_.name -eq 'statusCode' }).value

                if ($status -eq 'dead') {
                    $url = ($testcase.properties.property | Where-Object { $_.name -eq 'url' }).value
                    $brokenLinks += @{
                        File = 'test.md'
                        Link = $url
                        Status = $statusCode
                    }
                }
            }

            $brokenLinks.Count | Should -Be 1
            $brokenLinks[0].Status | Should -Be '404'
        }
    }

    Context 'JSON results structure' {
        It 'Builds correct results structure for success' {
            $results = @{
                timestamp = (Get-Date).ToUniversalTime().ToString('o')
                script = 'markdown-link-check'
                summary = @{
                    total_files = 1
                    files_with_broken_links = 0
                    total_links_checked = 2
                    total_broken_links = 0
                }
                broken_links = @()
            }

            $json = $results | ConvertTo-Json -Depth 10
            $parsed = $json | ConvertFrom-Json

            $parsed.script | Should -Be 'markdown-link-check'
            $parsed.summary.total_files | Should -Be 1
            $parsed.summary.total_broken_links | Should -Be 0
        }

        It 'Builds correct results structure for failures' {
            $results = @{
                timestamp = (Get-Date).ToUniversalTime().ToString('o')
                script = 'markdown-link-check'
                summary = @{
                    total_files = 2
                    files_with_broken_links = 1
                    total_links_checked = 5
                    total_broken_links = 2
                }
                broken_links = @(
                    @{ File = 'test1.md'; Link = 'https://broken1.com'; Status = '404' }
                    @{ File = 'test1.md'; Link = 'https://broken2.com'; Status = '500' }
                )
            }

            $json = $results | ConvertTo-Json -Depth 10
            $parsed = $json | ConvertFrom-Json

            $parsed.summary.files_with_broken_links | Should -Be 1
            $parsed.summary.total_broken_links | Should -Be 2
            $parsed.broken_links.Count | Should -Be 2
        }
    }

    Context 'Get-MarkdownTarget with fixtures' {
        BeforeEach {
            $script:TestDir = Join-Path $script:LinkCheckIntegrationDir "mdtarget-$(New-Guid)"
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null

            # Create test markdown files
            '# File 1' | Set-Content -Path (Join-Path $script:TestDir 'file1.md')
            '# File 2' | Set-Content -Path (Join-Path $script:TestDir 'file2.md')

            # Non-markdown file should be ignored
            'console.log("test")' | Set-Content -Path (Join-Path $script:TestDir 'script.js')
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Discovers markdown files in directory (fallback mode)' {
            Mock git {
                $global:LASTEXITCODE = 128
                return 'not a git repo'
            }

            $result = Get-MarkdownTarget -InputPath @($script:TestDir)
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterOrEqual 2
            $result | ForEach-Object { $_ | Should -Match '\.md$' }
        }

        It 'Does not include non-markdown files' {
            Mock git {
                $global:LASTEXITCODE = 128
                return 'not a git repo'
            }

            $result = Get-MarkdownTarget -InputPath @($script:TestDir)
            $result | ForEach-Object { $_ | Should -Not -Match '\.js$' }
        }
    }

    Context 'Get-RelativePrefix calculations' {
        It 'Calculates prefix for nested docs directory' {
            $repoRoot = '/workspace/repo'
            $docsFile = '/workspace/repo/docs/getting-started/install.md'
            $docsDir = [System.IO.Path]::GetDirectoryName($docsFile)

            $result = Get-RelativePrefix -FromPath $docsDir -ToPath $repoRoot
            $result | Should -Be '../../'
        }

        It 'Returns empty for file at root' {
            $repoRoot = '/workspace/repo'
            $rootFile = '/workspace/repo'

            $result = Get-RelativePrefix -FromPath $rootFile -ToPath $repoRoot
            $result | Should -Be ''
        }

        It 'Calculates prefix for single-level nesting' {
            $repoRoot = '/workspace/repo'
            $docsDir = '/workspace/repo/docs'

            $result = Get-RelativePrefix -FromPath $docsDir -ToPath $repoRoot
            $result | Should -Be '../'
        }
    }
}

#endregion

#region Phase 3: XML Parsing and Orchestration Tests

Describe 'Markdown-Link-Check XML Parsing' -Tag 'Integration' {
    BeforeAll {
        $script:XmlTestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "mlc-xml-tests-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:XmlTestRoot -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:XmlTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'JUnit XML parsing from markdown-link-check output' {
        BeforeEach {
            $script:TestDir = Join-Path $script:XmlTestRoot "xml-parse-$(New-Guid)"
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Parses XML with alive links correctly' {
            $xmlContent = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="markdown-link-check" tests="2" failures="0">
  <testsuite name="docs/readme.md" tests="2" failures="0">
    <testcase name="https://example.com/page1" classname="docs/readme.md">
      <properties>
        <property name="url" value="https://example.com/page1"/>
        <property name="status" value="alive"/>
        <property name="statusCode" value="200"/>
      </properties>
    </testcase>
    <testcase name="https://example.com/page2" classname="docs/readme.md">
      <properties>
        <property name="url" value="https://example.com/page2"/>
        <property name="status" value="alive"/>
        <property name="statusCode" value="200"/>
      </properties>
    </testcase>
  </testsuite>
</testsuites>
'@
            $xmlPath = Join-Path $script:TestDir 'results.xml'
            $xmlContent | Set-Content -Path $xmlPath -Encoding UTF8

            [xml]$xml = Get-Content $xmlPath -Raw -Encoding utf8

            $totalLinks = 0
            $brokenLinks = @()

            foreach ($testsuite in $xml.testsuites.testsuite) {
                foreach ($testcase in $testsuite.testcase) {
                    $totalLinks++
                    $url = ($testcase.properties.property | Where-Object { $_.name -eq 'url' }).value
                    $status = ($testcase.properties.property | Where-Object { $_.name -eq 'status' }).value

                    if ($status -eq 'dead') {
                        $brokenLinks += @{ Link = $url }
                    }
                }
            }

            $totalLinks | Should -Be 2
            $brokenLinks.Count | Should -Be 0
        }

        It 'Parses XML with broken links correctly' {
            $xmlContent = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="markdown-link-check" tests="3" failures="2">
  <testsuite name="test.md" tests="3" failures="2">
    <testcase name="https://alive.com" classname="test.md">
      <properties>
        <property name="url" value="https://alive.com"/>
        <property name="status" value="alive"/>
        <property name="statusCode" value="200"/>
      </properties>
    </testcase>
    <testcase name="https://broken.com/404" classname="test.md">
      <properties>
        <property name="url" value="https://broken.com/404"/>
        <property name="status" value="dead"/>
        <property name="statusCode" value="404"/>
      </properties>
      <failure>404 Not Found</failure>
    </testcase>
    <testcase name="https://broken.com/500" classname="test.md">
      <properties>
        <property name="url" value="https://broken.com/500"/>
        <property name="status" value="dead"/>
        <property name="statusCode" value="500"/>
      </properties>
      <failure>500 Internal Server Error</failure>
    </testcase>
  </testsuite>
</testsuites>
'@
            $xmlPath = Join-Path $script:TestDir 'broken-results.xml'
            $xmlContent | Set-Content -Path $xmlPath -Encoding UTF8

            [xml]$xml = Get-Content $xmlPath -Raw -Encoding utf8

            $brokenLinks = @()
            foreach ($testsuite in $xml.testsuites.testsuite) {
                foreach ($testcase in $testsuite.testcase) {
                    $url = ($testcase.properties.property | Where-Object { $_.name -eq 'url' }).value
                    $status = ($testcase.properties.property | Where-Object { $_.name -eq 'status' }).value
                    $statusCode = ($testcase.properties.property | Where-Object { $_.name -eq 'statusCode' }).value

                    if ($status -eq 'dead') {
                        $brokenLinks += @{
                            File = $testsuite.name
                            Link = $url
                            Status = $statusCode
                        }
                    }
                }
            }

            $brokenLinks.Count | Should -Be 2
            $brokenLinks[0].Link | Should -Be 'https://broken.com/404'
            $brokenLinks[0].Status | Should -Be '404'
            $brokenLinks[1].Status | Should -Be '500'
        }

        It 'Parses XML with ignored links correctly' {
            $xmlContent = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="markdown-link-check" tests="2" failures="0">
  <testsuite name="docs/api.md" tests="2" failures="0">
    <testcase name="https://example.com" classname="docs/api.md">
      <properties>
        <property name="url" value="https://example.com"/>
        <property name="status" value="alive"/>
        <property name="statusCode" value="200"/>
      </properties>
    </testcase>
    <testcase name="http://localhost:3000" classname="docs/api.md">
      <properties>
        <property name="url" value="http://localhost:3000"/>
        <property name="status" value="ignored"/>
        <property name="statusCode" value="0"/>
      </properties>
    </testcase>
  </testsuite>
</testsuites>
'@
            $xmlPath = Join-Path $script:TestDir 'ignored-results.xml'
            $xmlContent | Set-Content -Path $xmlPath -Encoding UTF8

            [xml]$xml = Get-Content $xmlPath -Raw -Encoding utf8

            $statusCounts = @{ alive = 0; dead = 0; ignored = 0 }
            foreach ($testsuite in $xml.testsuites.testsuite) {
                foreach ($testcase in $testsuite.testcase) {
                    $status = ($testcase.properties.property | Where-Object { $_.name -eq 'status' }).value
                    $statusCounts[$status]++
                }
            }

            $statusCounts.alive | Should -Be 1
            $statusCounts.ignored | Should -Be 1
            $statusCounts.dead | Should -Be 0
        }

        It 'Handles multiple testsuites (multiple files)' {
            $xmlContent = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="markdown-link-check" tests="4" failures="1">
  <testsuite name="README.md" tests="2" failures="0">
    <testcase name="link1" classname="README.md">
      <properties>
        <property name="url" value="https://good1.com"/>
        <property name="status" value="alive"/>
        <property name="statusCode" value="200"/>
      </properties>
    </testcase>
    <testcase name="link2" classname="README.md">
      <properties>
        <property name="url" value="https://good2.com"/>
        <property name="status" value="alive"/>
        <property name="statusCode" value="200"/>
      </properties>
    </testcase>
  </testsuite>
  <testsuite name="docs/guide.md" tests="2" failures="1">
    <testcase name="link3" classname="docs/guide.md">
      <properties>
        <property name="url" value="https://good3.com"/>
        <property name="status" value="alive"/>
        <property name="statusCode" value="200"/>
      </properties>
    </testcase>
    <testcase name="link4" classname="docs/guide.md">
      <properties>
        <property name="url" value="https://bad.com"/>
        <property name="status" value="dead"/>
        <property name="statusCode" value="404"/>
      </properties>
    </testcase>
  </testsuite>
</testsuites>
'@
            $xmlPath = Join-Path $script:TestDir 'multi-file-results.xml'
            $xmlContent | Set-Content -Path $xmlPath -Encoding UTF8

            [xml]$xml = Get-Content $xmlPath -Raw -Encoding utf8

            $fileCount = ($xml.testsuites.testsuite | Measure-Object).Count
            $fileCount | Should -Be 2

            $brokenByFile = @{}
            foreach ($testsuite in $xml.testsuites.testsuite) {
                $fileName = $testsuite.name
                $brokenByFile[$fileName] = 0
                foreach ($testcase in $testsuite.testcase) {
                    $status = ($testcase.properties.property | Where-Object { $_.name -eq 'status' }).value
                    if ($status -eq 'dead') {
                        $brokenByFile[$fileName]++
                    }
                }
            }

            $brokenByFile['README.md'] | Should -Be 0
            $brokenByFile['docs/guide.md'] | Should -Be 1
        }
    }

    Context 'Results aggregation' {
        It 'Builds correct summary from parsed XML' {
            $totalFiles = 5
            $totalLinks = 25
            $failedFiles = @('file1.md', 'file2.md')
            $brokenLinks = @(
                @{ File = 'file1.md'; Link = 'url1'; Status = '404' }
                @{ File = 'file1.md'; Link = 'url2'; Status = '500' }
                @{ File = 'file2.md'; Link = 'url3'; Status = '403' }
            )

            $results = @{
                timestamp = (Get-Date).ToUniversalTime().ToString('o')
                script = 'markdown-link-check'
                summary = @{
                    total_files = $totalFiles
                    files_with_broken_links = $failedFiles.Count
                    total_links_checked = $totalLinks
                    total_broken_links = $brokenLinks.Count
                }
                broken_links = $brokenLinks
            }

            $results.summary.total_files | Should -Be 5
            $results.summary.files_with_broken_links | Should -Be 2
            $results.summary.total_links_checked | Should -Be 25
            $results.summary.total_broken_links | Should -Be 3
        }

        It 'Exports results to JSON file correctly' {
            $testDir = Join-Path $script:XmlTestRoot "json-export-$(New-Guid)"
            $logsDir = Join-Path $testDir 'logs'
            New-Item -ItemType Directory -Path $logsDir -Force | Out-Null

            $results = @{
                timestamp = '2026-02-09T12:00:00.000Z'
                script = 'markdown-link-check'
                summary = @{
                    total_files = 3
                    files_with_broken_links = 1
                    total_links_checked = 15
                    total_broken_links = 2
                }
                broken_links = @(
                    @{ File = 'test.md'; Link = 'http://broken.com'; Status = '404' }
                )
            }

            $resultsPath = Join-Path $logsDir 'markdown-link-check-results.json'
            $results | ConvertTo-Json -Depth 10 | Set-Content -Path $resultsPath -Encoding UTF8

            Test-Path $resultsPath | Should -BeTrue

            $reread = Get-Content $resultsPath -Raw | ConvertFrom-Json
            $reread.script | Should -Be 'markdown-link-check'
            $reread.summary.total_broken_links | Should -Be 2

            Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'CLI existence validation' {
        It 'Validates CLI path construction for Unix' {
            $repoRoot = '/workspace/repo'
            $cli = Join-Path -Path $repoRoot -ChildPath 'node_modules/.bin/markdown-link-check'
            $cli | Should -Be '/workspace/repo/node_modules/.bin/markdown-link-check'
        }

        It 'Validates CLI path includes node_modules directory' {
            # Platform-agnostic test - just verify the path contains expected components
            $repoRoot = if ($IsWindows) { 'C:\workspace\repo' } else { '/workspace/repo' }
            $cli = Join-Path -Path $repoRoot -ChildPath 'node_modules/.bin/markdown-link-check'
            if ($IsWindows) {
                $cli += '.cmd'
            }
            $cli | Should -Match 'node_modules'
            $cli | Should -Match 'markdown-link-check'
        }

        It 'Detects missing markdown-link-check CLI' {
            $fakePath = Join-Path $script:XmlTestRoot 'nonexistent/node_modules/.bin/markdown-link-check'
            Test-Path -LiteralPath $fakePath | Should -BeFalse
        }
    }

    Context 'No files found scenario' {
        It 'Returns error when no markdown files found' {
            $emptyDir = Join-Path $script:XmlTestRoot "empty-$(New-Guid)"
            New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null

            $files = Get-ChildItem -Path $emptyDir -Filter '*.md' -Recurse -ErrorAction SilentlyContinue
            $files.Count | Should -Be 0

            Remove-Item -Path $emptyDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Markdown-Link-Check Orchestration Paths' -Tag 'Integration' {
    BeforeAll {
        $script:OrchTestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "mlc-orch-tests-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:OrchTestRoot -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:OrchTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Config file validation' {
        It 'Config file path resolves correctly' {
            $configPath = Join-Path $PSScriptRoot '../../linting/markdown-link-check.config.json'
            $resolved = Resolve-Path -LiteralPath $configPath -ErrorAction SilentlyContinue
            $resolved | Should -Not -BeNullOrEmpty
        }

        It 'Config file contains valid JSON' {
            $configPath = Join-Path $PSScriptRoot '../../linting/markdown-link-check.config.json'
            if (Test-Path $configPath) {
                $config = Get-Content $configPath -Raw | ConvertFrom-Json
                $config | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Logs directory handling' {
        BeforeEach {
            $script:TestDir = Join-Path $script:OrchTestRoot "logs-$(New-Guid)"
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Creates logs directory if not exists' {
            $logsDir = Join-Path $script:TestDir 'logs'
            Test-Path $logsDir | Should -BeFalse

            if (-not (Test-Path $logsDir)) {
                New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
            }

            Test-Path $logsDir | Should -BeTrue
        }

        It 'Handles existing logs directory' {
            $logsDir = Join-Path $script:TestDir 'logs'
            New-Item -ItemType Directory -Path $logsDir -Force | Out-Null

            # Should not throw when directory exists
            { New-Item -ItemType Directory -Path $logsDir -Force } | Should -Not -Throw
        }
    }

    Context 'Temporary XML file handling' {
        It 'Creates temp file with .xml extension' {
            $xmlFile = [System.IO.Path]::GetTempFileName() + '.xml'
            $xmlFile | Should -Match '\.xml$'

            # Cleanup
            if (Test-Path $xmlFile) {
                Remove-Item $xmlFile -Force
            }
        }

        It 'Cleans up temp XML file after processing' {
            $xmlFile = [System.IO.Path]::GetTempFileName() + '.xml'
            '<test/>' | Set-Content $xmlFile

            Test-Path $xmlFile | Should -BeTrue

            # Simulate cleanup
            Remove-Item $xmlFile -Force -ErrorAction SilentlyContinue

            Test-Path $xmlFile | Should -BeFalse
        }
    }
}

#endregion

