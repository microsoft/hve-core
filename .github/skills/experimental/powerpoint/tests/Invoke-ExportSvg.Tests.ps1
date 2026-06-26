#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# Variables set in It/Context blocks are read by dot-sourced functions through dynamic scoping
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

BeforeAll {
    . (Join-Path $PSScriptRoot '../scripts/Invoke-ExportSvg.ps1') -InputPath 'deck.pptx' -OutputDir 'svg/'
    Mock Write-Host {}

    # Shared stub directory for python executable
    $script:StubRoot = Join-Path ([System.IO.Path]::GetTempPath()) "pptx-svg-pester-$PID"
    New-Item -ItemType Directory -Path $script:StubRoot -Force | Out-Null

    $binDir = if ($IsWindows) { Join-Path $script:StubRoot 'Scripts' } else { Join-Path $script:StubRoot 'bin' }
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null

    # Platform-appropriate stub that exits with configurable code via STUB_EXIT_CODE env var.
    if ($IsWindows) {
        $script:PythonStub = Join-Path $binDir 'python.cmd'
        Set-Content -Path $script:PythonStub -Value '@if defined STUB_EXIT_CODE (exit /b %STUB_EXIT_CODE%) else (exit /b 0)' -NoNewline
    } else {
        $script:PythonStub = Join-Path $binDir 'python'
        Set-Content -Path $script:PythonStub -Value "#!/bin/sh`nexit `${STUB_EXIT_CODE:-0}" -NoNewline
        & chmod +x $script:PythonStub
    }
}

AfterAll {
    Remove-Item -Path $script:StubRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Test-UvAvailability' -Tag 'Unit' {
    It 'Returns resolved path when uv is available' {
        Mock Get-Command { [PSCustomObject]@{ Source = '/usr/bin/uv' } } -ParameterFilter { $Name -eq 'uv' }
        $result = Test-UvAvailability
        $result | Should -Be '/usr/bin/uv'
    }

    It 'Throws when uv is not installed' {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'uv' }
        { Test-UvAvailability } | Should -Throw '*uv is required*'
    }
}

Describe 'Initialize-PythonEnvironment' -Tag 'Unit' {
    BeforeAll {
        function uv { }
    }

    It 'Completes when uv sync succeeds' {
        Mock uv { $global:LASTEXITCODE = 0 }
        { Initialize-PythonEnvironment } | Should -Not -Throw
        Should -Invoke uv -Times 1
    }

    It 'Throws when uv sync fails' {
        Mock uv { $global:LASTEXITCODE = 1 }
        { Initialize-PythonEnvironment } | Should -Throw '*Failed to sync*'
    }
}

Describe 'Get-VenvPythonPath' -Tag 'Unit' {
    It 'Returns path under bin on non-Windows' -Skip:$IsWindows {
        $result = Get-VenvPythonPath
        $result | Should -BeLike '*/bin/python'
    }

    It 'Returns path under Scripts on Windows' -Skip:(-not $IsWindows) {
        $result = Get-VenvPythonPath
        $result | Should -BeLike '*\Scripts\python.exe'
    }
}

Describe 'Invoke-ExportSvg' -Tag 'Unit' {
    BeforeAll {
        Mock Get-VenvPythonPath { return $script:PythonStub }
    }

    Context 'when python script succeeds' {
        BeforeAll {
            $InputPath = 'deck.pptx'
            $OutputDir = 'svg/'
        }

        It 'Completes without error' {
            { Invoke-ExportSvg } | Should -Not -Throw
        }
    }

    Context 'when optional parameters are provided' {
        BeforeAll {
            $InputPath = 'deck.pptx'
            $OutputDir = 'svg/'
            $Slides = '1,3,5'
            $VerbosePreference = 'Continue'
        }

        It 'Completes without error' {
            { Invoke-ExportSvg } | Should -Not -Throw
        }
    }

    Context 'when python script fails' {
        BeforeAll {
            $InputPath = 'deck.pptx'
            $OutputDir = 'svg/'
        }

        BeforeEach { $env:STUB_EXIT_CODE = '1' }
        AfterEach { Remove-Item Env:STUB_EXIT_CODE -ErrorAction SilentlyContinue }

        It 'Throws with exit code message' {
            { Invoke-ExportSvg } | Should -Throw '*export_svg.py failed*'
        }
    }
}
