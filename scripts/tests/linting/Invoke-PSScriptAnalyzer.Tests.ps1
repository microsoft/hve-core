#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Pester tests for Invoke-PSScriptAnalyzer.ps1 script
.DESCRIPTION
    Tests for PSScriptAnalyzer wrapper script:
    - Parameter validation
    - Module availability checks
    - ChangedFilesOnly filtering
    - CI integration
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../linting/Invoke-PSScriptAnalyzer.ps1'
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

#region Parameter Validation Tests

Describe 'Invoke-PSScriptAnalyzer Parameter Validation' -Tag 'Unit' {
    Context 'ChangedFilesOnly parameter' {
        BeforeEach {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Invoke-ScriptAnalyzer { @() }
            Mock Get-ChangedFilesFromGit { @('script.ps1') }
            Mock Get-FilesRecursive { @() }
            Mock Set-CIOutput {}
            Mock Set-CIEnv {}
            Mock Write-CIStepSummary {}
            Mock Write-CIAnnotation {}
            Mock Out-File {}
        }

        It 'Accepts ChangedFilesOnly switch' {
            { Invoke-PSScriptAnalyzerCore -ChangedFilesOnly } | Should -Not -Throw
        }

        It 'Accepts BaseBranch with ChangedFilesOnly' {
            { Invoke-PSScriptAnalyzerCore -ChangedFilesOnly -BaseBranch 'develop' } | Should -Not -Throw
        }
    }

    Context 'ConfigPath parameter' {
        BeforeEach {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Invoke-ScriptAnalyzer { @() }
            Mock Get-FilesRecursive { @() }
            Mock Set-CIOutput {}
            Mock Set-CIEnv {}
            Mock Write-CIStepSummary {}
            Mock Write-CIAnnotation {}
            Mock Out-File {}
        }

        It 'Uses default config path when not specified' {
            # Script defaults to scripts/linting/PSScriptAnalyzer.psd1
            { Invoke-PSScriptAnalyzerCore } | Should -Not -Throw
        }

        It 'Accepts custom config path' {
            $configPath = Join-Path $PSScriptRoot '../../linting/PSScriptAnalyzer.psd1'
            { Invoke-PSScriptAnalyzerCore -ConfigPath $configPath } | Should -Not -Throw
        }
    }

    Context 'OutputPath parameter' {
        BeforeEach {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Invoke-ScriptAnalyzer { @() }
            Mock Get-FilesRecursive { @() }
            Mock Set-CIOutput {}
            Mock Set-CIEnv {}
            Mock Write-CIStepSummary {}
            Mock Write-CIAnnotation {}
            Mock Out-File {}
        }

        It 'Accepts custom output path' {
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) 'test-output.json'
            { Invoke-PSScriptAnalyzerCore -OutputPath $outputPath } | Should -Not -Throw
        }
    }
}

#endregion

#region Module Availability Tests

Describe 'PSScriptAnalyzer Module Availability' -Tag 'Unit' {
    Context 'Module not installed' {
        BeforeEach {
            Mock Get-Module { $null } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Install-Module {} -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Import-Module { throw 'Module not found' } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Write-Error {}
            Mock Out-File {}
        }

        It 'Reports error when module unavailable' {
            { Invoke-PSScriptAnalyzerCore } | Should -Throw
        }
    }

    Context 'Module installed' {
        BeforeEach {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Invoke-ScriptAnalyzer { @() }
            Mock Get-FilesRecursive { @() }
            Mock Set-CIOutput {}
            Mock Set-CIEnv {}
            Mock Write-CIStepSummary {}
            Mock Write-CIAnnotation {}
            Mock Out-File {}
        }

        It 'Proceeds when module available' {
            { Invoke-PSScriptAnalyzerCore } | Should -Not -Throw
        }
    }
}

#endregion

#region File Discovery Tests

Describe 'File Discovery' -Tag 'Unit' {
    Context 'All files mode' {
        BeforeEach {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Invoke-ScriptAnalyzer { @() }
            Mock Set-CIOutput {}
            Mock Set-CIEnv {}
            Mock Write-CIStepSummary {}
            Mock Write-CIAnnotation {}
            Mock Out-File {}
        }

        It 'Uses Get-FilesRecursive for all files' {
            Mock Get-FilesRecursive {
                return @('script1.ps1', 'script2.ps1')
            }

            Invoke-PSScriptAnalyzerCore
            Should -Invoke Get-FilesRecursive -Times 1
        }
    }

    Context 'Changed files only mode' {
        BeforeEach {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Invoke-ScriptAnalyzer { @() }
            Mock Get-FilesRecursive { @() }
            Mock Set-CIOutput {}
            Mock Set-CIEnv {}
            Mock Write-CIStepSummary {}
            Mock Write-CIAnnotation {}
            Mock Out-File {}
        }

        It 'Uses Get-ChangedFilesFromGit when ChangedFilesOnly specified' {
            Mock Get-ChangedFilesFromGit {
                return @('changed.ps1')
            }

            Invoke-PSScriptAnalyzerCore -ChangedFilesOnly
            Should -Invoke Get-ChangedFilesFromGit -Times 1
        }

        It 'Passes BaseBranch to Get-ChangedFilesFromGit' {
            Mock Get-ChangedFilesFromGit {
                return @('changed.ps1')
            }

            Invoke-PSScriptAnalyzerCore -ChangedFilesOnly -BaseBranch 'develop'
            Should -Invoke Get-ChangedFilesFromGit -Times 1 -ParameterFilter {
                $BaseBranch -eq 'develop'
            }
        }
    }
}

#endregion

#region CI Integration Tests

Describe 'CI Integration' -Tag 'Unit' {
    Context 'Write-CIAnnotation calls' {
        BeforeEach {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Get-FilesRecursive { @('test.ps1') }
            Mock Set-CIOutput {}
            Mock Set-CIEnv {}
            Mock Write-CIStepSummary {}
            Mock Write-CIAnnotation {}
            Mock Out-File {}
        }

        It 'Calls Write-CIAnnotation for each issue' {
            Mock Invoke-ScriptAnalyzer {
                return @(
                    [PSCustomObject]@{
                        ScriptPath  = 'test.ps1'
                        Line        = 10
                        Column      = 5
                        RuleName    = 'PSAvoidUsingInvokeExpression'
                        Severity    = 'Warning'
                        Message     = 'Avoid using Invoke-Expression'
                    }
                )
            }

            try { Invoke-PSScriptAnalyzerCore } catch { $null = $_ }
            Should -Invoke Write-CIAnnotation -Times 1
        }

        It 'Sets CI output for file count' {
            Mock Invoke-ScriptAnalyzer { @() }

            Invoke-PSScriptAnalyzerCore
            Should -Invoke Set-CIOutput -Times 1 -ParameterFilter {
                $Name -eq 'count'
            }
        }
    }
}

#endregion

#region Output Tests

Describe 'Output Generation' -Tag 'Unit' {
    BeforeAll {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'JSON output file' {
        BeforeEach {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Get-FilesRecursive { @('test.ps1') }
            Mock Set-CIOutput {}
            Mock Set-CIEnv {}
            Mock Write-CIStepSummary {}
            Mock Write-CIAnnotation {}

            Mock Invoke-ScriptAnalyzer {
                return @(
                    [PSCustomObject]@{
                        ScriptPath  = 'test.ps1'
                        Line        = 10
                        Column      = 5
                        RuleName    = 'TestRule'
                        Severity    = 'Warning'
                        Message     = 'Test message'
                    }
                )
            }

            $script:OutputFile = Join-Path $script:TempDir 'output.json'
        }

        It 'Creates JSON output file' {
            try { Invoke-PSScriptAnalyzerCore -OutputPath $script:OutputFile } catch { $null = $_ }
            Test-Path $script:OutputFile | Should -BeTrue
        }

        It 'Output file contains valid JSON' {
            try { Invoke-PSScriptAnalyzerCore -OutputPath $script:OutputFile } catch { $null = $_ }
            { Get-Content $script:OutputFile | ConvertFrom-Json } | Should -Not -Throw
        }
    }
}

#endregion

#region Exit Code Tests

Describe 'Exit Code Handling' -Tag 'Unit' {
    Context 'No issues found' {
        BeforeEach {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Get-FilesRecursive { @() }
            Mock Set-CIOutput {}
            Mock Set-CIEnv {}
            Mock Write-CIStepSummary {}
            Mock Write-CIAnnotation {}
            Mock Invoke-ScriptAnalyzer { @() }
            Mock Out-File {}
        }

        It 'Returns success when no issues' {
            { Invoke-PSScriptAnalyzerCore } | Should -Not -Throw
        }
    }

    Context 'Issues found' {
        BeforeEach {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Get-FilesRecursive { @('test.ps1') }
            Mock Set-CIOutput {}
            Mock Set-CIEnv {}
            Mock Write-CIStepSummary {}
            Mock Write-CIAnnotation {}
            Mock Out-File {}

            Mock Invoke-ScriptAnalyzer {
                return @(
                    [PSCustomObject]@{
                        ScriptPath = 'test.ps1'
                        Severity   = 'Error'
                        RuleName   = 'TestRule'
                        Message    = 'Error found'
                        Line       = 1
                        Column     = 1
                    }
                )
            }
        }

        It 'Throws when issues found' {
            { Invoke-PSScriptAnalyzerCore } | Should -Throw '*issue*'
        }
    }
}

#endregion

#region PATH Sanitization Tests

Describe 'PATH Sanitization Logic' -Tag 'Unit' {
    # Validates the PATH filtering expression used in Main Execution to strip
    # /mnt/* (WSL Windows mount) entries that cause slow 9P lookups.

    It 'Strips /mnt/* entries from PATH' {
        $sep = [System.IO.Path]::PathSeparator
        $original = "/usr/bin${sep}/mnt/c/Windows/System32${sep}/home/user/bin${sep}/mnt/d/Tools"
        $result = ($original -split [System.IO.Path]::PathSeparator |
            Where-Object { $_ -notlike '/mnt/*' }) -join [System.IO.Path]::PathSeparator
        $result | Should -Be "/usr/bin${sep}/home/user/bin"
    }

    It 'Preserves all entries when no /mnt/* paths present' {
        $original = '/usr/bin:/home/user/bin:/usr/local/bin'
        $result = ($original -split [System.IO.Path]::PathSeparator |
            Where-Object { $_ -notlike '/mnt/*' }) -join [System.IO.Path]::PathSeparator
        $result | Should -Be $original
    }

    It 'Handles PATH with only /mnt/* entries' {
        $sep = [System.IO.Path]::PathSeparator
        $original = "/mnt/c/Windows${sep}/mnt/d/Tools"
        $result = ($original -split [System.IO.Path]::PathSeparator |
            Where-Object { $_ -notlike '/mnt/*' }) -join [System.IO.Path]::PathSeparator
        $result | Should -BeNullOrEmpty
    }

    It 'Does not strip similar but non-matching paths' {
        $sep = [System.IO.Path]::PathSeparator
        $original = "/mnt${sep}/usr/mnt/bin${sep}/home/mnt"
        $result = ($original -split [System.IO.Path]::PathSeparator |
            Where-Object { $_ -notlike '/mnt/*' }) -join [System.IO.Path]::PathSeparator
        $result | Should -Be $original
    }
}

#endregion
