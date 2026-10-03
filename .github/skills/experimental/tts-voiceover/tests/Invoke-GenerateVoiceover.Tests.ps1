#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
    Pester tests for the tts-voiceover generation wrappers.
.DESCRIPTION
    Covers the argument list forwarded to generate_voiceover.py, parameter
    validation, and wrapper documentation, without invoking uv, Python, or a
    speech engine.
#>

BeforeAll {
    $script:SkillRoot = Split-Path -Parent $PSScriptRoot
    $script:WrapperPath = Join-Path $script:SkillRoot 'scripts/Invoke-GenerateVoiceover.ps1'
    $script:BashWrapper = Join-Path $script:SkillRoot 'scripts/generate-voiceover.sh'
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

    It 'Forwards --collapse-newlines only when the switch is set' {
        Get-VoiceoverArgument -CollapseNewlines | Should -Be @('--collapse-newlines')
        Get-VoiceoverArgument -ContentDir content | Should -Not -Contain '--collapse-newlines'
    }

    It 'Keeps each value as one argument even when it contains spaces' {
        $arguments = Get-VoiceoverArgument -Engine azure -Voice 'en-US-Jenny:DragonHDLatestNeural' `
            -ContentDir 'my slides/content' -DryRun -CollapseNewlines -VerboseOutput

        $arguments | Should -Be @(
            '--dry-run',
            '--engine', 'azure',
            '--voice', 'en-US-Jenny:DragonHDLatestNeural',
            '--content-dir', 'my slides/content',
            '--collapse-newlines',
            '--verbose'
        )
    }
}

Describe 'Invoke-GenerateVoiceover.ps1 parameters' -Tag 'Unit' {
    It 'Declares a CollapseNewlines switch' {
        $command = Get-Command -Name $script:WrapperPath
        $command.Parameters['CollapseNewlines'].ParameterType | Should -Be ([switch])
    }

    It 'Rejects an unsupported engine before any setup runs' {
        { & $script:WrapperPath -Engine espeak } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Invoke-GenerateVoiceover.ps1'
    }
}

Describe 'generate-voiceover.sh wrapper' -Tag 'Unit' {
    It 'Documents --collapse-newlines in its usage text' {
        Get-Content -Path $script:BashWrapper -Raw | Should -Match '--collapse-newlines'
    }
}
