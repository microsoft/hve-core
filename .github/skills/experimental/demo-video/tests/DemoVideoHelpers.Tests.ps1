#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

<#!
.SYNOPSIS
    Pester tests for the demo-video PowerShell wrapper.
.DESCRIPTION
    Covers wrapper parameter handling and argument forwarding without invoking FFmpeg.
#>

BeforeAll {
    $script:RepoRoot = git rev-parse --show-toplevel 2>$null
    if (-not $script:RepoRoot) {
        $script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot))
    }
    $script:WrapperPath = Join-Path $script:RepoRoot '.github/skills/experimental/demo-video/scripts/Invoke-AssembleVideo.ps1'
}

Describe 'Invoke-AssembleVideo.ps1 wrapper' -Tag 'Unit' {
    It 'Builds the expected Python argument list for all supported switches' {
        $scriptContent = Get-Content -Path $script:WrapperPath -Raw
        $scriptContent | Should -Match '\$PythonArgs = @\(\)'
        $scriptContent | Should -Match '--manifest'
        $scriptContent | Should -Match '--output'
        $scriptContent | Should -Match '--fps'
        $scriptContent | Should -Match '--resolution'
    }

    It 'Defines the expected wrapper parameters' {
        $scriptContent = Get-Content -Path $script:WrapperPath -Raw
        $scriptContent | Should -Match '\[string\]\$ManifestPath'
        $scriptContent | Should -Match '\[string\]\$OutputPath'
        $scriptContent | Should -Match '\[int\]\$Fps'
        $scriptContent | Should -Match '\[string\]\$Resolution'
    }
}
