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
    # Extract functions from script using AST
    $scriptPath = Join-Path $PSScriptRoot '../../linting/Markdown-Link-Check.ps1'
    $scriptContent = Get-Content -Path $scriptPath -Raw
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$null, [ref]$null)
    $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

    foreach ($func in $functions) {
        . ([scriptblock]::Create($func.Extent.Text))
    }

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

#endregion
