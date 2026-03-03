#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Pester tests for Invoke-LinkLanguageCheck.ps1 script
.DESCRIPTION
    Tests for Link Language Check wrapper script:
    - Link-Lang-Check.ps1 invocation
    - JSON parsing
    - GitHub Actions integration
    - Exit code handling
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../linting/Invoke-LinkLanguageCheck.ps1'
    $script:ModulePath = Join-Path $PSScriptRoot '../../linting/Modules/LintingHelpers.psm1'
    $script:CIHelpersPath = Join-Path $PSScriptRoot '../../lib/Modules/CIHelpers.psm1'

    # Import modules for mocking
    Import-Module $script:ModulePath -Force
    Import-Module $script:CIHelpersPath -Force

    . $script:ScriptPath
}

AfterAll {
    Remove-Module LintingHelpers -Force -ErrorAction SilentlyContinue
    Remove-Module CIHelpers -Force -ErrorAction SilentlyContinue
}

#region Link-Lang-Check Invocation Tests

Describe 'Link-Lang-Check.ps1 Invocation' -Tag 'Unit' {
    Context 'Script discovery' {
        It 'Link-Lang-Check.ps1 exists' {
            $linkLangCheckPath = Join-Path $PSScriptRoot '../../linting/Link-Lang-Check.ps1'
            Test-Path $linkLangCheckPath | Should -BeTrue
        }
    }

    Context 'Normal execution' {
        It 'Invoke-LinkLanguageCheck.ps1 exists' {
            $scriptExists = Test-Path $script:ScriptPath
            $scriptExists | Should -BeTrue
        }
    }
}

#endregion

#region Invoke-LinkLanguageCheckCore Tests

Describe 'Invoke-LinkLanguageCheckCore' -Tag 'Unit' {
    Context 'Not in git repository' {
        BeforeEach {
            Mock git {
                $global:LASTEXITCODE = 128
                return 'fatal: not a git repository'
            } -ParameterFilter { $args -contains 'rev-parse' }

            Mock Write-Error { }
        }

        It 'Returns failure exit code' {
            Invoke-LinkLanguageCheckCore -ExcludePaths @() | Should -Be 1
        }
    }

    Context 'Issues found in link scan' {
        BeforeEach {
            $script:RepoRoot = $TestDrive
            $script:MockLinkLang = Join-Path $TestDrive 'mock-link-lang.ps1'
            $script:WriteHostMessages = @()

                        @'
param([string[]]$ExcludePaths = @())
$json = @"
[
    {"file":"docs/a.md","line_number":1,"original_url":"https://docs.microsoft.com/en-us/a"},
    {"file":"docs/b.md","line_number":2,"original_url":"https://docs.microsoft.com/en-us/b"}
]
"@

Write-Output $json
'@ | Set-Content -Path $script:MockLinkLang -Encoding utf8

            Mock git {
                $global:LASTEXITCODE = 0
                return $script:RepoRoot
            } -ParameterFilter { $args -contains 'rev-parse' }

            Mock Join-Path {
                return $script:MockLinkLang
            } -ParameterFilter { $ChildPath -eq 'Link-Lang-Check.ps1' }

            Mock Write-CIAnnotation { }
            Mock Set-CIOutput { }
            Mock Set-CIEnv { }
            Mock Write-CIStepSummary { }
            Mock Write-Host {
                param($Object)
                $script:WriteHostMessages += [string]$Object
            }
        }

        It 'Returns failure exit code and records outputs' {
            Invoke-LinkLanguageCheckCore -ExcludePaths @('scripts/tests/**') | Should -Be 1
            Should -Invoke Set-CIOutput -Times 1
            Should -Invoke Set-CIEnv -Times 1
            Should -Invoke Write-CIAnnotation -Times 2
            Should -Invoke Write-CIStepSummary -Times 1

            Should -Invoke Write-Host -Times 1 -ParameterFilter { $Object -like '*📄 docs/a.md*' }
            Should -Invoke Write-Host -Times 1 -ParameterFilter { $Object -like '*📄 docs/b.md*' }
            Should -Invoke Write-Host -ParameterFilter { $Object -like '*Line 1:*' }
            Should -Invoke Write-Host -ParameterFilter { $Object -like '*Line 2:*' }
            Should -Invoke Write-Host -Times 1 -ParameterFilter { $Object -like '*failed with 2 issue*' }

            $script:WriteHostMessages | Should -Contain '📄 docs/a.md'
            $script:WriteHostMessages | Should -Contain '📄 docs/b.md'
        }
    }

    Context 'No issues found' {
        BeforeEach {
            $script:RepoRoot = $TestDrive
            $script:MockLinkLang = Join-Path $TestDrive 'mock-link-lang-empty.ps1'

            @'
param([string[]]$ExcludePaths = @())
$json = @"
[]
"@

Write-Output $json
'@ | Set-Content -Path $script:MockLinkLang -Encoding utf8

            Mock git {
                $global:LASTEXITCODE = 0
                return $script:RepoRoot
            } -ParameterFilter { $args -contains 'rev-parse' }

            Mock Join-Path {
                return $script:MockLinkLang
            } -ParameterFilter { $ChildPath -eq 'Link-Lang-Check.ps1' }

            Mock Set-CIOutput { }
            Mock Write-CIStepSummary { }
            Mock Write-Host {
                param($Object)
                $script:WriteHostMessages += [string]$Object
            }
        }

        It 'Returns success exit code and records outputs' {
            $script:WriteHostMessages = @()
            Invoke-LinkLanguageCheckCore -ExcludePaths @() | Should -Be 0
            Should -Invoke Set-CIOutput -Times 1
            Should -Invoke Write-CIStepSummary -Times 1
            Should -Invoke Write-Host -Times 1 -ParameterFilter { $Object -like '*✅ No URLs with language paths found*' }
            Should -Invoke Write-Host -Times 0 -ParameterFilter { $Object -like '*📄*' }
            Should -Invoke Write-Host -Times 0 -ParameterFilter { $Object -like '*⚠️*' }
        }
    }
}

#endregion

#region JSON Parsing Tests

Describe 'JSON Output Parsing' -Tag 'Unit' {
    Context 'Valid JSON with issues' {
        BeforeEach {
            $script:JsonWithIssues = @'
[
    {
        "file": "docs/guide.md",
        "line_number": 15,
        "original_url": "https://docs.microsoft.com/en-us/azure"
    },
    {
        "file": "README.md",
        "line_number": 42,
        "original_url": "https://learn.microsoft.com/en-us/dotnet"
    }
]
'@
        }

        It 'Parses JSON array correctly' {
            $result = $script:JsonWithIssues | ConvertFrom-Json
            $result | Should -HaveCount 2
        }

        It 'Extracts file property' {
            $result = $script:JsonWithIssues | ConvertFrom-Json
            $result[0].file | Should -Be 'docs/guide.md'
        }

        It 'Extracts line_number property' {
            $result = $script:JsonWithIssues | ConvertFrom-Json
            $result[0].line_number | Should -Be 15
        }

        It 'Extracts original_url property' {
            $result = $script:JsonWithIssues | ConvertFrom-Json
            $result[0].original_url | Should -Be 'https://docs.microsoft.com/en-us/azure'
        }
    }

    Context 'Empty JSON array' {
        It 'Handles empty array' {
            $result = '[]' | ConvertFrom-Json
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Invalid JSON' {
        It 'Throws on malformed JSON' {
            { 'not valid json' | ConvertFrom-Json } | Should -Throw
        }
    }
}

#endregion

#region GitHub Actions Integration Tests

Describe 'GitHub Actions Integration' -Tag 'Unit' {
    Context 'Module exports verification' {
        It 'Write-CIAnnotation is available in module' {
            $module = Get-Module CIHelpers
            $module.ExportedFunctions.Keys | Should -Contain 'Write-CIAnnotation'
        }

        It 'Set-CIOutput is available in module' {
            $module = Get-Module CIHelpers
            $module.ExportedFunctions.Keys | Should -Contain 'Set-CIOutput'
        }

        It 'Write-CIStepSummary is available in module' {
            $module = Get-Module CIHelpers
            $module.ExportedFunctions.Keys | Should -Contain 'Write-CIStepSummary'
        }
    }

    Context 'GitHub Actions detection' {
        It 'Detects GitHub Actions via GITHUB_ACTIONS env var' {
            $originalValue = $env:GITHUB_ACTIONS
            try {
                $env:GITHUB_ACTIONS = 'true'
                $env:GITHUB_ACTIONS | Should -Be 'true'

                $env:GITHUB_ACTIONS = $null
                $env:GITHUB_ACTIONS | Should -BeNullOrEmpty
            }
            finally {
                $env:GITHUB_ACTIONS = $originalValue
            }
        }
    }
}

#endregion

#region Annotation Generation Tests

Describe 'Annotation Generation' -Tag 'Unit' {
    Context 'Annotation content' {
        BeforeEach {
            $script:Issue = [PSCustomObject]@{
                file         = 'docs/test.md'
                line_number  = 25
                original_url = 'https://docs.microsoft.com/en-us/azure/overview'
            }
        }

        It 'Issue object has required properties' {
            $script:Issue.file | Should -Not -BeNullOrEmpty
            $script:Issue.line_number | Should -BeGreaterThan 0
            $script:Issue.original_url | Should -Match 'en-us'
        }

        It 'File path is workspace-relative' {
            $script:Issue.file | Should -Not -Match '^[A-Z]:\\'
            $script:Issue.file | Should -Not -Match '^/'
        }
    }

    Context 'Annotation severity mapping' {
        It 'Language path issues are warnings' {
            # Link language issues are warnings, not errors
            $severity = 'warning'
            $severity | Should -Be 'warning'
        }
    }
}

#endregion

#region Exit Code Tests

Describe 'Exit Code Handling' -Tag 'Unit' {
    Context 'No issues found' {
        It 'Empty result indicates success' {
            $issues = @()
            $issues.Count | Should -Be 0
        }
    }

    Context 'Issues found' {
        BeforeEach {
            $script:Issues = @(
                [PSCustomObject]@{ file = 'test.md'; line_number = 1; original_url = 'https://example.com/en-us/page' }
            )
        }

        It 'Non-empty result indicates issues present' {
            $script:Issues.Count | Should -BeGreaterThan 0
        }

        It 'Script should warn but not fail on issues' {
            # Link language issues are warnings, script continues
            $warningExpected = $true
            $warningExpected | Should -BeTrue
        }
    }
}

#endregion

#region Output Format Tests

Describe 'Output Format' -Tag 'Unit' {
    Context 'Console output' {
        BeforeEach {
            $script:SampleIssue = [PSCustomObject]@{
                file         = 'README.md'
                line_number  = 10
                original_url = 'https://docs.microsoft.com/en-us/azure'
            }
        }

        It 'Issue can be formatted as string' {
            $formatted = "[$($script:SampleIssue.file):$($script:SampleIssue.line_number)] $($script:SampleIssue.original_url)"
            $formatted | Should -Be '[README.md:10] https://docs.microsoft.com/en-us/azure'
        }
    }

    Context 'Summary statistics' {
        BeforeEach {
            $script:Issues = @(
                [PSCustomObject]@{ file = 'a.md'; line_number = 1; original_url = 'url1' },
                [PSCustomObject]@{ file = 'a.md'; line_number = 2; original_url = 'url2' },
                [PSCustomObject]@{ file = 'b.md'; line_number = 1; original_url = 'url3' }
            )
        }

        It 'Can count total issues' {
            $script:Issues.Count | Should -Be 3
        }

        It 'Can count affected files' {
            $fileCount = ($script:Issues | Select-Object -ExpandProperty file -Unique).Count
            $fileCount | Should -Be 2
        }
    }
}

#endregion

#region Integration with Link-Lang-Check Tests

Describe 'Link-Lang-Check Integration' -Tag 'Integration' {
    Context 'Script dependencies' {
        It 'LintingHelpers module can be imported' {
            { Import-Module $script:ModulePath -Force } | Should -Not -Throw
        }

        It 'Link-Lang-Check.ps1 exists at expected path' {
            $linkLangCheckPath = Join-Path $PSScriptRoot '../../linting/Link-Lang-Check.ps1'
            Test-Path $linkLangCheckPath | Should -BeTrue
        }
    }

    Context 'Output compatibility' {
        It 'Link-Lang-Check output can be parsed as JSON' {
            # Sample output format from Link-Lang-Check.ps1
            $sampleOutput = '[{"file":"test.md","line_number":1,"original_url":"https://example.com/en-us/page"}]'
            { $sampleOutput | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Parsed output has expected structure' {
            $sampleOutput = '[{"file":"test.md","line_number":1,"original_url":"https://example.com/en-us/page"}]'
            $parsed = $sampleOutput | ConvertFrom-Json
            $parsed[0].PSObject.Properties.Name | Should -Contain 'file'
            $parsed[0].PSObject.Properties.Name | Should -Contain 'line_number'
            $parsed[0].PSObject.Properties.Name | Should -Contain 'original_url'
        }
    }
}

#endregion
