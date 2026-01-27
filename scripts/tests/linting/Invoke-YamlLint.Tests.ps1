#Requires -Modules Pester
<#
.SYNOPSIS
    Pester tests for Invoke-YamlLint.ps1 script
.DESCRIPTION
    Tests for actionlint wrapper script:
    - Parameter validation
    - Tool availability checks
    - ChangedFilesOnly filtering
    - JSON parsing edge cases
    - GitHub Actions integration
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../linting/Invoke-YamlLint.ps1'
    $script:ModulePath = Join-Path $PSScriptRoot '../../linting/Modules/LintingHelpers.psm1'

    # Import LintingHelpers for mocking
    Import-Module $script:ModulePath -Force

    # Create stub function for actionlint so it can be mocked even when not installed
    function global:actionlint { '[]' }
}

AfterAll {
    Remove-Module LintingHelpers -Force -ErrorAction SilentlyContinue
    # Remove the actionlint stub function
    Remove-Item -Path 'Function:\actionlint' -Force -ErrorAction SilentlyContinue
}

#region Parameter Validation Tests

Describe 'Invoke-YamlLint Parameter Validation' -Tag 'Unit' {
    Context 'ChangedFilesOnly parameter' {
        BeforeEach {
            Mock Get-Command { [PSCustomObject]@{ Source = 'actionlint' } } -ParameterFilter { $Name -eq 'actionlint' }
            Mock actionlint { '[]' }
            Mock Get-ChangedFilesFromGit { @() }
            Mock Test-Path { $false } -ParameterFilter { $Path -eq '.github/workflows' }
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
        }

        It 'Accepts ChangedFilesOnly switch' {
            { & $script:ScriptPath -ChangedFilesOnly } | Should -Not -Throw
        }

        It 'Accepts BaseBranch with ChangedFilesOnly' {
            { & $script:ScriptPath -ChangedFilesOnly -BaseBranch 'develop' } | Should -Not -Throw
        }
    }

    Context 'OutputPath parameter' {
        BeforeEach {
            Mock Get-Command { [PSCustomObject]@{ Source = 'actionlint' } } -ParameterFilter { $Name -eq 'actionlint' }
            Mock actionlint { '[]' }
            Mock Test-Path { $false } -ParameterFilter { $Path -eq '.github/workflows' }
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
        }

        It 'Accepts custom output path' {
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) 'test-yaml-lint.json'
            { & $script:ScriptPath -OutputPath $outputPath } | Should -Not -Throw
        }
    }
}

#endregion

#region Tool Availability Tests

Describe 'actionlint Tool Availability' -Tag 'Unit' {
    Context 'Tool not installed' {
        BeforeEach {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'actionlint' }
            Mock Write-Error {}
        }

        It 'Reports error when actionlint not installed' {
            & $script:ScriptPath
            Should -Invoke Write-Error -Times 1
        }

        It 'Writes appropriate error message' {
            try { & $script:ScriptPath } catch { Write-Verbose 'Expected error' }
            Should -Invoke Write-Error -Times 1 -ParameterFilter {
                $Message -like '*actionlint is not installed*'
            }
        }
    }

    Context 'Tool installed' {
        BeforeEach {
            Mock Get-Command { [PSCustomObject]@{ Source = 'C:\tools\actionlint.exe' } } -ParameterFilter { $Name -eq 'actionlint' }
            Mock actionlint { '[]' }
            Mock Test-Path { $false } -ParameterFilter { $Path -eq '.github/workflows' }
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
        }

        It 'Proceeds when actionlint available' {
            { & $script:ScriptPath } | Should -Not -Throw
        }
    }
}

#endregion

#region File Discovery Tests

Describe 'File Discovery' -Tag 'Unit' {
    Context 'All files mode' {
        BeforeEach {
            Mock Get-Command { [PSCustomObject]@{ Source = 'actionlint' } } -ParameterFilter { $Name -eq 'actionlint' }
            Mock actionlint { '[]' }
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
        }

        It 'Uses Get-ChildItem when workflows directory exists' {
            Mock Test-Path { $true } -ParameterFilter { $Path -eq '.github/workflows' }
            Mock Get-ChildItem {
                @(
                    [PSCustomObject]@{ FullName = '.github/workflows/ci.yml'; Extension = '.yml' },
                    [PSCustomObject]@{ FullName = '.github/workflows/release.yaml'; Extension = '.yaml' }
                )
            } -ParameterFilter { $Path -eq '.github/workflows' }

            & $script:ScriptPath
            Should -Invoke Get-ChildItem -Times 1 -ParameterFilter { $Path -eq '.github/workflows' }
        }

        It 'Returns no files when workflows directory missing' {
            Mock Test-Path { $false } -ParameterFilter { $Path -eq '.github/workflows' }

            & $script:ScriptPath
            Should -Invoke Set-GitHubOutput -Times 1 -ParameterFilter { $Name -eq 'count' -and $Value -eq '0' }
        }

        It 'Filters to only .yml and .yaml extensions' {
            Mock Test-Path { $true } -ParameterFilter { $Path -eq '.github/workflows' }
            Mock Get-ChildItem {
                @(
                    [PSCustomObject]@{ FullName = '.github/workflows/ci.yml'; Extension = '.yml' },
                    [PSCustomObject]@{ FullName = '.github/workflows/config.json'; Extension = '.json' },
                    [PSCustomObject]@{ FullName = '.github/workflows/release.yaml'; Extension = '.yaml' }
                )
            } -ParameterFilter { $Path -eq '.github/workflows' }

            & $script:ScriptPath
            # Should only count 2 files (yml and yaml, not json)
            Should -Invoke Set-GitHubOutput -Times 1 -ParameterFilter { $Name -eq 'count' -and $Value -eq '2' }
        }
    }

    Context 'Changed files only mode' {
        BeforeEach {
            Mock Get-Command { [PSCustomObject]@{ Source = 'actionlint' } } -ParameterFilter { $Name -eq 'actionlint' }
            Mock actionlint { '[]' }
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
        }

        It 'Uses Get-ChangedFilesFromGit when ChangedFilesOnly specified' {
            Mock Get-ChangedFilesFromGit { @('.github/workflows/ci.yml') }

            & $script:ScriptPath -ChangedFilesOnly
            Should -Invoke Get-ChangedFilesFromGit -Times 1
        }

        It 'Passes BaseBranch to Get-ChangedFilesFromGit' {
            Mock Get-ChangedFilesFromGit { @() }

            & $script:ScriptPath -ChangedFilesOnly -BaseBranch 'develop'
            Should -Invoke Get-ChangedFilesFromGit -Times 1 -ParameterFilter {
                $BaseBranch -eq 'develop'
            }
        }

        It 'Filters changed files to workflows directory only' {
            Mock Get-ChangedFilesFromGit {
                @(
                    '.github/workflows/ci.yml',
                    'scripts/test.yml',
                    '.github/workflows/build.yaml'
                )
            }

            & $script:ScriptPath -ChangedFilesOnly
            # Should only count 2 workflow files
            Should -Invoke Set-GitHubOutput -Times 1 -ParameterFilter { $Name -eq 'count' -and $Value -eq '2' }
        }
    }

    Context 'No files found' {
        BeforeEach {
            Mock Get-Command { [PSCustomObject]@{ Source = 'actionlint' } } -ParameterFilter { $Name -eq 'actionlint' }
            Mock Test-Path { $false } -ParameterFilter { $Path -eq '.github/workflows' }
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
        }

        It 'Sets count and issues to 0 when no files found' {
            & $script:ScriptPath
            Should -Invoke Set-GitHubOutput -Times 1 -ParameterFilter { $Name -eq 'count' -and $Value -eq '0' }
            Should -Invoke Set-GitHubOutput -Times 1 -ParameterFilter { $Name -eq 'issues' -and $Value -eq '0' }
        }

        It 'Exits with code 0 when no files found' {
            { & $script:ScriptPath } | Should -Not -Throw
        }
    }
}

#endregion

#region JSON Parsing Tests

Describe 'actionlint Output Parsing' -Tag 'Unit' {
    BeforeEach {
        Mock Get-Command { [PSCustomObject]@{ Source = 'actionlint' } } -ParameterFilter { $Name -eq 'actionlint' }
        Mock Test-Path { $true } -ParameterFilter { $Path -eq '.github/workflows' }
        Mock Get-ChildItem {
            @([PSCustomObject]@{ FullName = '.github/workflows/ci.yml'; Extension = '.yml' })
        } -ParameterFilter { $Path -eq '.github/workflows' }
        Mock Set-GitHubOutput {}
        Mock Set-GitHubEnv {}
        Mock Write-GitHubStepSummary {}
        Mock Write-GitHubAnnotation {}
        Mock New-Item {}
        Mock Out-File {}
    }

    Context 'Empty output scenarios' {
        It 'Handles null output gracefully' {
            Mock actionlint { $null }

            & $script:ScriptPath
            Should -Invoke Set-GitHubOutput -Times 1 -ParameterFilter { $Name -eq 'issues' -and $Value -eq '0' }
        }

        It 'Handles "null" string output' {
            Mock actionlint { 'null' }

            & $script:ScriptPath
            Should -Invoke Set-GitHubOutput -Times 1 -ParameterFilter { $Name -eq 'issues' -and $Value -eq '0' }
        }

        It 'Handles empty array output' {
            Mock actionlint { '[]' }

            & $script:ScriptPath
            Should -Invoke Set-GitHubOutput -Times 1 -ParameterFilter { $Name -eq 'issues' -and $Value -eq '0' }
        }
    }

    Context 'Single issue output' {
        It 'Converts single object to array' {
            Mock actionlint {
                '{"message":"test error","filepath":".github/workflows/ci.yml","line":10,"column":5}'
            }

            & $script:ScriptPath
            Should -Invoke Write-GitHubAnnotation -Times 1
            Should -Invoke Set-GitHubOutput -Times 1 -ParameterFilter { $Name -eq 'issues' -and $Value -eq '1' }
        }
    }

    Context 'Multiple issues output' {
        It 'Parses array of issues correctly' {
            Mock actionlint {
                '[{"message":"error 1","filepath":".github/workflows/ci.yml","line":10,"column":5},{"message":"error 2","filepath":".github/workflows/ci.yml","line":20,"column":3}]'
            }

            & $script:ScriptPath
            Should -Invoke Write-GitHubAnnotation -Times 2
            Should -Invoke Set-GitHubOutput -Times 1 -ParameterFilter { $Name -eq 'issues' -and $Value -eq '2' }
        }
    }

    Context 'Invalid JSON output' {
        It 'Handles malformed JSON gracefully' {
            Mock actionlint { 'not valid json {{{' }
            Mock Write-Warning {}

            & $script:ScriptPath
            Should -Invoke Write-Warning -Times 1
            Should -Invoke Set-GitHubOutput -Times 1 -ParameterFilter { $Name -eq 'issues' -and $Value -eq '0' }
        }
    }
}

#endregion

#region Issue Processing Tests

Describe 'Issue Processing' -Tag 'Unit' {
    BeforeEach {
        Mock Get-Command { [PSCustomObject]@{ Source = 'actionlint' } } -ParameterFilter { $Name -eq 'actionlint' }
        Mock Test-Path { $true } -ParameterFilter { $Path -eq '.github/workflows' }
        Mock Get-ChildItem {
            @([PSCustomObject]@{ FullName = '.github/workflows/ci.yml'; Extension = '.yml' })
        } -ParameterFilter { $Path -eq '.github/workflows' }
        Mock Set-GitHubOutput {}
        Mock Set-GitHubEnv {}
        Mock Write-GitHubStepSummary {}
        Mock Write-GitHubAnnotation {}
        Mock New-Item {}
        Mock Out-File {}
    }

    Context 'Annotation creation' {
        It 'Creates annotation with correct parameters for each issue' {
            Mock actionlint {
                '{"message":"property runs-on is required","filepath":".github/workflows/ci.yml","line":15,"column":5}'
            }

            & $script:ScriptPath
            Should -Invoke Write-GitHubAnnotation -Times 1 -ParameterFilter {
                $Type -eq 'error' -and
                $Message -eq 'property runs-on is required' -and
                $File -eq '.github/workflows/ci.yml' -and
                $Line -eq 15 -and
                $Column -eq 5
            }
        }

        It 'Creates annotation for each issue in array' {
            Mock actionlint {
                '[{"message":"error 1","filepath":"file1.yml","line":1,"column":1},{"message":"error 2","filepath":"file2.yml","line":2,"column":2}]'
            }

            & $script:ScriptPath
            Should -Invoke Write-GitHubAnnotation -Times 2
        }
    }

    Context 'Host output' {
        It 'Writes formatted error message to host' {
            Mock actionlint {
                '{"message":"test message","filepath":".github/workflows/ci.yml","line":10,"column":5}'
            }
            Mock Write-Host {}

            & $script:ScriptPath
            # Verify error output format includes file:line:column: message
            Should -Invoke Write-Host -ParameterFilter {
                $Object -like '*ci.yml:10:5*test message*'
            }
        }
    }
}

#endregion

#region Output Generation Tests

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
            Mock Get-Command { [PSCustomObject]@{ Source = 'actionlint' } } -ParameterFilter { $Name -eq 'actionlint' }
            Mock Test-Path { $true } -ParameterFilter { $Path -eq '.github/workflows' }
            Mock Get-ChildItem {
                @([PSCustomObject]@{ FullName = '.github/workflows/ci.yml'; Extension = '.yml' })
            } -ParameterFilter { $Path -eq '.github/workflows' }
            Mock actionlint { '[]' }
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}

            $script:OutputFile = Join-Path $script:TempDir 'yaml-lint-results.json'
        }

        It 'Creates JSON output file at specified path' {
            # Use real filesystem for this test
            & $script:ScriptPath -OutputPath $script:OutputFile
            Test-Path $script:OutputFile | Should -BeTrue
        }

        It 'Output file contains valid JSON' {
            & $script:ScriptPath -OutputPath $script:OutputFile
            { Get-Content $script:OutputFile | ConvertFrom-Json } | Should -Not -Throw
        }
    }

    Context 'Directory creation' {
        BeforeEach {
            Mock Get-Command { [PSCustomObject]@{ Source = 'actionlint' } } -ParameterFilter { $Name -eq 'actionlint' }
            Mock Test-Path { $true } -ParameterFilter { $Path -eq '.github/workflows' }
            Mock Get-ChildItem {
                @([PSCustomObject]@{ FullName = '.github/workflows/ci.yml'; Extension = '.yml' })
            } -ParameterFilter { $Path -eq '.github/workflows' }
            Mock actionlint { '[]' }
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
        }

        It 'Creates logs directory if missing' {
            $newDir = Join-Path $script:TempDir 'newlogs'
            $outputPath = Join-Path $newDir 'results.json'

            & $script:ScriptPath -OutputPath $outputPath
            Test-Path $newDir | Should -BeTrue
        }
    }
}

#endregion

#region GitHub Actions Integration Tests

Describe 'GitHub Actions Integration' -Tag 'Unit' {
    BeforeEach {
        Mock Get-Command { [PSCustomObject]@{ Source = 'actionlint' } } -ParameterFilter { $Name -eq 'actionlint' }
        Mock Test-Path { $true } -ParameterFilter { $Path -eq '.github/workflows' }
        Mock Get-ChildItem {
            @([PSCustomObject]@{ FullName = '.github/workflows/ci.yml'; Extension = '.yml' })
        } -ParameterFilter { $Path -eq '.github/workflows' }
        Mock Set-GitHubOutput {}
        Mock Set-GitHubEnv {}
        Mock Write-GitHubStepSummary {}
        Mock Write-GitHubAnnotation {}
        Mock New-Item {}
        Mock Out-File {}
    }

    Context 'GitHub outputs' {
        It 'Sets count output with file count' {
            Mock actionlint { '[]' }

            & $script:ScriptPath
            Should -Invoke Set-GitHubOutput -Times 1 -ParameterFilter { $Name -eq 'count' }
        }

        It 'Sets issues output with issue count' {
            Mock actionlint { '[]' }

            & $script:ScriptPath
            Should -Invoke Set-GitHubOutput -Times 1 -ParameterFilter { $Name -eq 'issues' }
        }

        It 'Sets errors output with error count' {
            Mock actionlint { '[]' }

            & $script:ScriptPath
            Should -Invoke Set-GitHubOutput -Times 1 -ParameterFilter { $Name -eq 'errors' }
        }
    }

    Context 'GitHub environment variables' {
        It 'Sets YAML_LINT_FAILED when issues found' {
            Mock actionlint {
                '{"message":"error","filepath":"ci.yml","line":1,"column":1}'
            }

            try { & $script:ScriptPath } catch { Write-Verbose 'Expected error' }
            Should -Invoke Set-GitHubEnv -Times 1 -ParameterFilter {
                $Name -eq 'YAML_LINT_FAILED' -and $Value -eq 'true'
            }
        }

        It 'Does not set YAML_LINT_FAILED when no issues' {
            Mock actionlint { '[]' }

            & $script:ScriptPath
            Should -Invoke Set-GitHubEnv -Times 0 -ParameterFilter {
                $Name -eq 'YAML_LINT_FAILED'
            }
        }
    }

    Context 'GitHub step summary' {
        It 'Writes success summary when no issues' {
            Mock actionlint { '[]' }

            & $script:ScriptPath
            Should -Invoke Write-GitHubStepSummary -Times 2
        }

        It 'Writes failure summary with table when issues found' {
            Mock actionlint {
                '{"message":"error","filepath":"ci.yml","line":1,"column":1}'
            }

            try { & $script:ScriptPath } catch { Write-Verbose 'Expected error' }
            Should -Invoke Write-GitHubStepSummary -Times 2
        }
    }
}

#endregion

#region Exit Code Tests

Describe 'Exit Code Handling' -Tag 'Unit' {
    Context 'Success scenarios (exit 0)' {
        BeforeEach {
            Mock Get-Command { [PSCustomObject]@{ Source = 'actionlint' } } -ParameterFilter { $Name -eq 'actionlint' }
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
            Mock New-Item {}
            Mock Out-File {}
        }

        It 'Returns success when no files to analyze' {
            Mock Test-Path { $false } -ParameterFilter { $Path -eq '.github/workflows' }

            { & $script:ScriptPath } | Should -Not -Throw
        }

        It 'Returns success when files have no issues' {
            Mock Test-Path { $true } -ParameterFilter { $Path -eq '.github/workflows' }
            Mock Get-ChildItem {
                @([PSCustomObject]@{ FullName = '.github/workflows/ci.yml'; Extension = '.yml' })
            } -ParameterFilter { $Path -eq '.github/workflows' }
            Mock actionlint { '[]' }

            { & $script:ScriptPath } | Should -Not -Throw
        }
    }

    Context 'Failure scenarios (exit 1)' {
        BeforeEach {
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
        }

        It 'Exits with error when actionlint not installed' {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'actionlint' }
            Mock Write-Error {}

            & $script:ScriptPath
            Should -Invoke Write-Error -Times 1 -ParameterFilter {
                $Message -like '*actionlint is not installed*'
            }
        }

        It 'Exits with error when issues found' {
            Mock Get-Command { [PSCustomObject]@{ Source = 'actionlint' } } -ParameterFilter { $Name -eq 'actionlint' }
            Mock Test-Path { $true } -ParameterFilter { $Path -eq '.github/workflows' }
            Mock Get-ChildItem {
                @([PSCustomObject]@{ FullName = '.github/workflows/ci.yml'; Extension = '.yml' })
            } -ParameterFilter { $Path -eq '.github/workflows' }
            Mock actionlint {
                '{"message":"error found","filepath":"ci.yml","line":1,"column":1}'
            }
            Mock New-Item {}
            Mock Out-File {}

            & $script:ScriptPath
            Should -Invoke Write-GitHubAnnotation -Times 1
        }
    }
}

#endregion
