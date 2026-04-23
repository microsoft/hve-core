#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
    Pester tests for TtsVoiceoverHelpers PowerShell module.
.DESCRIPTION
    Tests for the shared helper functions used by the tts-voiceover skill
    PowerShell wrappers:
    - Test-UvAvailability
    - Initialize-PythonEnvironment
    - Get-VenvPythonPath
#>

BeforeAll {
    $script:RepoRoot = git rev-parse --show-toplevel 2>$null
    if (-not $script:RepoRoot) {
        $script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot))
    }
    $script:ModulePath = Join-Path $script:RepoRoot `
        '.github/skills/experimental/tts-voiceover/scripts/Modules/TtsVoiceoverHelpers.psm1'
    Import-Module $script:ModulePath -Force
}

AfterAll {
    Remove-Module TtsVoiceoverHelpers -Force -ErrorAction SilentlyContinue
}

Describe 'Test-UvAvailability' -Tag 'Unit' {
    Context 'When uv is available on PATH' {
        BeforeEach {
            Mock Get-Command {
                [PSCustomObject]@{ Source = '/usr/local/bin/uv' }
            } -ModuleName TtsVoiceoverHelpers
        }

        It 'Returns the uv command path' {
            $result = Test-UvAvailability
            $result | Should -Be '/usr/local/bin/uv'
        }
    }

    Context 'When uv is not on PATH' {
        BeforeEach {
            Mock Get-Command { $null } -ModuleName TtsVoiceoverHelpers
        }

        It 'Throws with installation instructions' {
            { Test-UvAvailability } | Should -Throw '*uv is required*'
        }
    }
}

Describe 'Initialize-PythonEnvironment' -Tag 'Unit' {
    Context 'When uv sync succeeds' {
        BeforeEach {
            Mock Write-Host {} -ModuleName TtsVoiceoverHelpers
            # Mock the external uv command by setting LASTEXITCODE via script
            $script:uvCallCount = 0
        }

        It 'Completes without error when uv sync returns 0' {
            # Create a temporary directory to act as skill root
            $tmpDir = Join-Path $TestDrive 'skill-root'
            New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $tmpDir 'pyproject.toml') -Force | Out-Null

            # Mock the uv command within the module scope
            Mock -CommandName 'uv' -ModuleName TtsVoiceoverHelpers -MockWith {
                $global:LASTEXITCODE = 0
            }

            { Initialize-PythonEnvironment -SkillRoot $tmpDir } | Should -Not -Throw
        }
    }

    Context 'When uv sync fails' {
        BeforeEach {
            Mock Write-Host {} -ModuleName TtsVoiceoverHelpers
        }

        It 'Throws when uv sync returns non-zero' {
            $tmpDir = Join-Path $TestDrive 'skill-fail'
            New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

            Mock -CommandName 'uv' -ModuleName TtsVoiceoverHelpers -MockWith {
                $global:LASTEXITCODE = 1
            }

            { Initialize-PythonEnvironment -SkillRoot $tmpDir } | Should -Throw '*Failed to sync*'
        }
    }
}

Describe 'Get-VenvPythonPath' -Tag 'Unit' {
    Context 'On non-Windows platforms' {
        It 'Returns bin/python path' {
            # Only run on non-Windows
            if (-not $IsWindows) {
                $result = Get-VenvPythonPath -VenvDir '/tmp/test-venv'
                $result | Should -Be '/tmp/test-venv/bin/python'
            } else {
                Set-ItResult -Skipped -Because 'Test runs on Linux/macOS only'
            }
        }
    }

    Context 'Path construction' {
        It 'Joins VenvDir with correct subdirectory' {
            $venvDir = Join-Path $TestDrive 'my-venv'
            $result = Get-VenvPythonPath -VenvDir $venvDir
            if ($IsWindows) {
                $result | Should -BeLike '*Scripts/python.exe'
            } else {
                $result | Should -BeLike '*bin/python'
            }
        }

        It 'Handles trailing separator in VenvDir' {
            $venvDir = (Join-Path $TestDrive 'venv-trailing') + [IO.Path]::DirectorySeparatorChar
            $result = Get-VenvPythonPath -VenvDir $venvDir
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Parameter validation' {
        It 'VenvDir is a mandatory parameter' {
            $cmd = Get-Command Get-VenvPythonPath
            $param = $cmd.Parameters['VenvDir']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory |
                Should -Be $true
        }
    }
}
