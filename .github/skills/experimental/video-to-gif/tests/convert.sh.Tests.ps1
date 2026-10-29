#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
    Pester tests for convert.sh cleanup, exit status, path safety, and timeout behavior.
.DESCRIPTION
    Runs the real Bash converter against synthetic input files with ffmpeg and
    ffprobe replaced by PATH shims, so no media tools or media files are needed.
    Requires Bash and coreutils timeout; skipped on Windows.
#>

# Discovery-time capability probe: these tests execute the real Bash script.
$script:BashTestsAvailable = (-not $IsWindows) -and
    [bool](Get-Command bash -ErrorAction SilentlyContinue) -and
    [bool](Get-Command timeout -ErrorAction SilentlyContinue)

BeforeAll {
    $script:ConvertSh = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/convert.sh')).Path

    function script:New-ShimEnvironment {
        $root = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName())
        $paths = [pscustomobject]@{
            Root    = $root
            Bin     = Join-Path $root 'bin'
            Work    = Join-Path $root 'work'
            Temp    = Join-Path $root 'tmp'
            HomeDir = Join-Path $root 'home'
            Log     = Join-Path $root 'ffmpeg-calls.log'
        }
        New-Item -ItemType Directory -Path $paths.Bin, $paths.Work, $paths.Temp, $paths.HomeDir -Force | Out-Null

        $ffmpegShim = @(
            '#!/bin/sh'
            'printf ''%s\n'' "$*" >> "$SHIM_LOG"'
            'case "$SHIM_MODE" in'
            '  fail) exit 1 ;;'
            '  sleep) exec sleep 3 ;;'
            'esac'
            'for last; do :; done'
            'printf ''GIF89a'' > "$last"'
            'exit 0'
        ) -join "`n"
        Set-Content -Path (Join-Path $paths.Bin 'ffmpeg') -Value "$ffmpegShim`n" -NoNewline
        Set-Content -Path (Join-Path $paths.Bin 'ffprobe') -Value "#!/bin/sh`nexit 0`n" -NoNewline
        & chmod +x (Join-Path $paths.Bin 'ffmpeg') (Join-Path $paths.Bin 'ffprobe')
        return $paths
    }

    function script:Invoke-ConvertSh {
        param(
            [Parameter(Mandatory = $true)]
            [pscustomobject]$ShimEnvironment,

            [Parameter(Mandatory = $true)]
            [string[]]$Arguments,

            [Parameter(Mandatory = $false)]
            [string]$ShimMode = 'success',

            [Parameter(Mandatory = $false)]
            [string]$TimeoutSeconds = '30'
        )

        $saved = @{
            PATH                 = $env:PATH
            TMPDIR               = $env:TMPDIR
            HOME                 = $env:HOME
            SHIM_LOG             = $env:SHIM_LOG
            SHIM_MODE            = $env:SHIM_MODE
            VIDEO_TO_GIF_TIMEOUT = $env:VIDEO_TO_GIF_TIMEOUT
            CONVERT_SH           = $env:CONVERT_SH
            CONVERT_ARG_COUNT    = $env:CONVERT_ARG_COUNT
        }

        Push-Location $ShimEnvironment.Work
        try {
            $env:PATH = "$($ShimEnvironment.Bin)$([System.IO.Path]::PathSeparator)$($saved.PATH)"
            $env:TMPDIR = $ShimEnvironment.Temp
            $env:HOME = $ShimEnvironment.HomeDir
            $env:SHIM_LOG = $ShimEnvironment.Log
            $env:SHIM_MODE = $ShimMode
            $env:VIDEO_TO_GIF_TIMEOUT = $TimeoutSeconds

            # PowerShell expands wildcards in variable-sourced native arguments on Unix,
            # so arguments reach bash through the environment to stay literal.
            $env:CONVERT_SH = $script:ConvertSh
            $env:CONVERT_ARG_COUNT = [string]$Arguments.Count
            for ($i = 0; $i -lt $Arguments.Count; $i++) {
                Set-Item -Path "Env:CONVERT_ARG_$i" -Value $Arguments[$i]
            }

            $output = & bash -c 'args=(); for ((i = 0; i < CONVERT_ARG_COUNT; i++)); do name="CONVERT_ARG_${i}"; args+=("${!name}"); done; exec bash "${CONVERT_SH}" "${args[@]}"' 2>&1 | Out-String
            return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
        }
        finally {
            Pop-Location
            for ($i = 0; $i -lt $Arguments.Count; $i++) {
                Remove-Item -Path "Env:CONVERT_ARG_$i" -ErrorAction SilentlyContinue
            }
            foreach ($name in $saved.Keys) {
                if ($null -eq $saved[$name]) {
                    Remove-Item -Path "Env:$name" -ErrorAction SilentlyContinue
                }
                else {
                    Set-Item -Path "Env:$name" -Value $saved[$name]
                }
            }
        }
    }

    function script:Get-LeakedPaletteDirectory {
        param([pscustomobject]$ShimEnvironment)
        return @(Get-ChildItem -Path $ShimEnvironment.Temp -Directory -Filter 'video-to-gif.*' -ErrorAction SilentlyContinue)
    }
}

Describe 'convert.sh two-pass cleanup and exit status' -Tag 'Unit' -Skip:(-not $script:BashTestsAvailable) {
    It 'Exits 0 and removes the palette directory after a successful conversion' {
        $shimEnv = New-ShimEnvironment
        Set-Content -Path (Join-Path $shimEnv.Work 'input.mp4') -Value 'synthetic' -NoNewline

        $result = Invoke-ConvertSh -ShimEnvironment $shimEnv -Arguments @('--input', 'input.mp4', '--output', 'out.gif')

        $result.Output | Should -Not -Match 'unbound variable'
        $result.ExitCode | Should -Be 0
        Test-Path -Path (Join-Path $shimEnv.Work 'out.gif') | Should -BeTrue
        Get-LeakedPaletteDirectory -ShimEnvironment $shimEnv | Should -HaveCount 0
    }

    It 'Exits nonzero and removes the palette directory when ffmpeg fails' {
        $shimEnv = New-ShimEnvironment
        Set-Content -Path (Join-Path $shimEnv.Work 'input.mp4') -Value 'synthetic' -NoNewline

        $result = Invoke-ConvertSh -ShimEnvironment $shimEnv -Arguments @('--input', 'input.mp4', '--output', 'out.gif') -ShimMode 'fail'

        $result.ExitCode | Should -Not -Be 0
        Get-LeakedPaletteDirectory -ShimEnvironment $shimEnv | Should -HaveCount 0
    }

    It 'Terminates ffmpeg after VIDEO_TO_GIF_TIMEOUT and removes the palette directory' {
        $shimEnv = New-ShimEnvironment
        Set-Content -Path (Join-Path $shimEnv.Work 'input.mp4') -Value 'synthetic' -NoNewline
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        $result = Invoke-ConvertSh -ShimEnvironment $shimEnv -Arguments @('--input', 'input.mp4', '--output', 'out.gif') -ShimMode 'sleep' -TimeoutSeconds '1'

        $stopwatch.Stop()
        $result.ExitCode | Should -Not -Be 0
        $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 5
        Get-LeakedPaletteDirectory -ShimEnvironment $shimEnv | Should -HaveCount 0
    }
}

Describe 'convert.sh output and input path safety' -Tag 'Unit' -Skip:(-not $script:BashTestsAvailable) {
    It 'Refuses the default output path for a .gif input' {
        $shimEnv = New-ShimEnvironment
        $gifInput = Join-Path $shimEnv.Work 'clip.gif'
        Set-Content -Path $gifInput -Value 'original-gif' -NoNewline

        $result = Invoke-ConvertSh -ShimEnvironment $shimEnv -Arguments @('--input', 'clip.gif')

        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'same as the input'
        Test-Path -Path $shimEnv.Log | Should -BeFalse
        Get-Content -Path $gifInput -Raw | Should -Be 'original-gif'
    }

    It 'Refuses an explicit output path that resolves to the input path' {
        $shimEnv = New-ShimEnvironment
        Set-Content -Path (Join-Path $shimEnv.Work 'clip.gif') -Value 'original-gif' -NoNewline

        $result = Invoke-ConvertSh -ShimEnvironment $shimEnv -Arguments @('--input', 'clip.gif', '--output', './clip.gif')

        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'same as the input'
        Test-Path -Path $shimEnv.Log | Should -BeFalse
    }

    It 'Treats glob characters in a requested filename literally' {
        $shimEnv = New-ShimEnvironment
        Set-Content -Path (Join-Path $shimEnv.Work 'take1.mp4') -Value 'other-file' -NoNewline

        $result = Invoke-ConvertSh -ShimEnvironment $shimEnv -Arguments @('--input', 'take[1].mp4', '--output', 'out.gif')

        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'Input file not found'
        $result.Output | Should -Not -Match '(?m)^Found:'
        Test-Path -Path $shimEnv.Log | Should -BeFalse
    }

    It 'Resolves a shared 15-character prefix to an existing file (current behavior)' {
        $shimEnv = New-ShimEnvironment
        Set-Content -Path (Join-Path $shimEnv.Work 'recording-alpha-001.mp4') -Value 'synthetic' -NoNewline

        $result = Invoke-ConvertSh -ShimEnvironment $shimEnv -Arguments @('--input', 'recording-alpha-999.mp4', '--output', 'out.gif')

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match '(?m)^Found: .*recording-alpha-001\.mp4'
    }

    It 'Rejects a non-numeric --fps before invoking ffmpeg' {
        $shimEnv = New-ShimEnvironment
        Set-Content -Path (Join-Path $shimEnv.Work 'input.mp4') -Value 'synthetic' -NoNewline

        $result = Invoke-ConvertSh -ShimEnvironment $shimEnv -Arguments @('--input', 'input.mp4', '--fps', '10,drawtext=text=x')

        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match '--fps must be an integer'
        Test-Path -Path $shimEnv.Log | Should -BeFalse
    }
}
