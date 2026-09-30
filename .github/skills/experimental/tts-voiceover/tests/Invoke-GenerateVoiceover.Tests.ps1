#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
    Pester tests for the tts-voiceover PowerShell wrapper.
.DESCRIPTION
    Covers the argument list forwarded to generate_voiceover.py and parameter
    validation, without invoking uv, Python, or a speech engine.
#>

BeforeAll {
    $script:WrapperPath = Join-Path (Split-Path $PSScriptRoot) 'scripts/Invoke-GenerateVoiceover.ps1'
    . $script:WrapperPath
}

Describe 'Get-VoiceoverArgument' -Tag 'Unit' {
    It 'Forwards -Engine piper as the discrete pair --engine, piper' {
        $arguments = Get-VoiceoverArgument -Engine piper

        $arguments | Should -Be @('--engine', 'piper')
    }

    It 'Adds no engine argument when -Engine is omitted' {
        $arguments = Get-VoiceoverArgument -ContentDir content

        $arguments | Should -Not -Contain '--engine'
        $arguments | Should -Be @('--content-dir', 'content')
    }

    It 'Returns an empty array when no parameter is set' {
        $arguments = Get-VoiceoverArgument

        , $arguments | Should -BeOfType [string[]]
        $arguments.Count | Should -Be 0
    }

    It 'Keeps each value as one argument even when it contains spaces' {
        $arguments = Get-VoiceoverArgument -Engine azure -Voice 'en-US-Jenny:DragonHDLatestNeural' `
            -ContentDir 'my slides/content' -DryRun -VerboseOutput

        $arguments | Should -Be @(
            '--dry-run',
            '--engine', 'azure',
            '--voice', 'en-US-Jenny:DragonHDLatestNeural',
            '--content-dir', 'my slides/content',
            '--verbose'
        )
    }
}

Describe 'Invoke-GenerateVoiceover.ps1 parameters' -Tag 'Unit' {
    It 'Rejects an unsupported engine before any setup runs' {
        { & $script:WrapperPath -Engine espeak } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Invoke-GenerateVoiceover.ps1'
    }
}
