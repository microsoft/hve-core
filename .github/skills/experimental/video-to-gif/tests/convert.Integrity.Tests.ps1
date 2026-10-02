#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
    Pester tests for convert.ps1 timeout, output-integrity, and cleanup behavior.
.DESCRIPTION
    Exercises the converter through in-session mocks, a child pwsh process for the
    script entry point, and short-lived pwsh child processes for the bounded
    process helper. No FFmpeg, media, or network access is required.
#>

BeforeAll {
    function global:ffmpeg { param([Parameter(ValueFromRemainingArguments = $true)] [object[]]$Args) }
    function global:ffprobe { param([Parameter(ValueFromRemainingArguments = $true)] [object[]]$Args) }

    $script:ConvertScript = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/convert.ps1')).Path
    $script:PwshPath = (Get-Process -Id $PID).Path

    . $script:ConvertScript -InputPath 'video.mp4'
    Mock Write-Host {}
    Mock Write-Error {}
}

AfterAll {
    Remove-Item -Path 'Function:\ffmpeg' -Force -ErrorAction SilentlyContinue
    Remove-Item -Path 'Function:\ffprobe' -Force -ErrorAction SilentlyContinue
}

Describe 'convert.ps1 entry point' -Tag 'Unit' {
    It 'Accepts -TimeoutSeconds without a parameter-binding error' {
        $missingInput = Join-Path $TestDrive 'missing-input.mp4'

        $output = & $script:PwshPath -NoProfile -File $script:ConvertScript -InputPath $missingInput -TimeoutSeconds 5 2>&1 | Out-String

        $LASTEXITCODE | Should -Be 1
        $output | Should -Not -Match 'parameter cannot be found'
        $output | Should -Match 'FFmpeg is not available|Input file not found'
    }

    It 'Reaches input resolution when ffmpeg is on PATH' -Skip:$IsWindows {
        $binDir = Join-Path $TestDrive 'bin'
        New-Item -ItemType Directory -Path $binDir -Force | Out-Null
        $shim = Join-Path $binDir 'ffmpeg'
        Set-Content -Path $shim -Value "#!/bin/sh`nexit 0`n" -NoNewline
        & chmod +x $shim
        $missingInput = Join-Path $TestDrive 'missing-input.mp4'
        $originalPath = $env:PATH

        try {
            $env:PATH = "$binDir$([System.IO.Path]::PathSeparator)$originalPath"
            $output = & $script:PwshPath -NoProfile -File $script:ConvertScript -InputPath $missingInput -TimeoutSeconds 5 2>&1 | Out-String
        }
        finally {
            $env:PATH = $originalPath
        }

        $LASTEXITCODE | Should -Be 1
        $output | Should -Match 'Input file not found'
    }
}

Describe 'Invoke-VideoConversion timeout forwarding' -Tag 'Unit' {
    BeforeEach {
        Mock Test-FFmpegAvailable { $true }
        Mock Test-HDRContent { $false }
        $script:SourcePath = Join-Path $TestDrive 'timeout-source.mp4'
        Set-Content -Path $script:SourcePath -Value 'synthetic' -NoNewline
        $script:OutputPath = Join-Path $TestDrive 'timeout-output.gif'
    }

    It 'Forwards TimeoutSeconds to the two-pass conversion and the HDR probe' {
        Mock Invoke-TwoPassConversion {
            Set-Content -Path $DestinationPath -Value 'gif' -NoNewline
            return $true
        }

        Invoke-VideoConversion -InputPath $script:SourcePath -OutputPath $script:OutputPath -TimeoutSeconds 42

        Should -Invoke Invoke-TwoPassConversion -Times 1 -Exactly -ParameterFilter { $TimeoutSeconds -eq 42 }
        Should -Invoke Test-HDRContent -Times 1 -Exactly -ParameterFilter { $TimeoutSeconds -eq 42 }
    }

    It 'Forwards TimeoutSeconds to the single-pass conversion' {
        Mock Invoke-SinglePassConversion {
            Set-Content -Path $DestinationPath -Value 'gif' -NoNewline
            return $true
        }

        Invoke-VideoConversion -InputPath $script:SourcePath -OutputPath $script:OutputPath -TimeoutSeconds 17 -SkipPalette

        Should -Invoke Invoke-SinglePassConversion -Times 1 -Exactly -ParameterFilter { $TimeoutSeconds -eq 17 }
    }
}

Describe 'Test-HDRContent bounded probe' -Tag 'Unit' {
    BeforeEach {
        Mock Get-Command { [pscustomobject]@{ Name = 'ffprobe' } } -ParameterFilter { $Name -eq 'ffprobe' }
        Mock Write-Warning {}
    }

    It 'Runs ffprobe through the bounded process helper with the timeout' {
        Mock Invoke-BoundedProcess { [pscustomobject]@{ ExitCode = 0; StdOut = 'bt709,bt709' } }

        Test-HDRContent -FilePath 'video.mp4' -TimeoutSeconds 7 | Should -BeFalse

        Should -Invoke Invoke-BoundedProcess -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq 'ffprobe' -and $TimeoutSeconds -eq 7 -and $Arguments -contains 'video.mp4'
        }
    }

    It 'Detects HDR from bounded probe output' {
        Mock Invoke-BoundedProcess { [pscustomobject]@{ ExitCode = 0; StdOut = 'bt2020,smpte2084' } }

        Test-HDRContent -FilePath 'video.mp4' | Should -BeTrue
    }

    It 'Treats a timed-out probe as SDR and warns' {
        Mock Invoke-BoundedProcess { throw 'ffprobe timed out after 1 seconds.' }

        Test-HDRContent -FilePath 'video.mp4' -TimeoutSeconds 1 | Should -BeFalse

        Should -Invoke Write-Warning -Times 1 -Exactly
    }

    It 'Treats a failed probe as SDR' {
        Mock Invoke-BoundedProcess { [pscustomobject]@{ ExitCode = 1; StdOut = 'bt2020' } }

        Test-HDRContent -FilePath 'video.mp4' | Should -BeFalse
    }
}

Describe 'Invoke-BoundedProcess' -Tag 'Unit' {
    It 'Terminates a process that exceeds the timeout' {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        { Invoke-BoundedProcess -FilePath $script:PwshPath -Arguments @('-NoProfile', '-Command', 'Start-Sleep -Seconds 30') -TimeoutSeconds 1 } |
            Should -Throw '*timed out after 1 seconds*'

        $stopwatch.Stop()
        $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 10
    }

    It 'Returns the exit code and captured standard output' {
        $result = Invoke-BoundedProcess -FilePath $script:PwshPath -Arguments @('-NoProfile', '-Command', "Write-Output 'bt2020'; exit 3") -TimeoutSeconds 60 -CaptureOutput

        $result.ExitCode | Should -Be 3
        $result.StdOut | Should -Match 'bt2020'
    }
}

Describe 'Same-path output safety' -Tag 'Unit' {
    BeforeEach {
        Mock Test-FFmpegAvailable { $true }
        Mock Test-HDRContent { $false }
        Mock Invoke-TwoPassConversion { $true }
        Mock Invoke-SinglePassConversion { $true }
        $script:GifInput = Join-Path $TestDrive 'clip.gif'
        Set-Content -Path $script:GifInput -Value 'original-gif' -NoNewline
    }

    It 'Refuses an explicit output path equal to the input path' {
        { Invoke-VideoConversion -InputPath $script:GifInput -OutputPath $script:GifInput } |
            Should -Throw '*same as the input*'

        Should -Invoke Invoke-TwoPassConversion -Times 0 -Exactly
        Get-Content -Path $script:GifInput -Raw | Should -Be 'original-gif'
    }

    It 'Refuses the default output path for a .gif input' {
        { Invoke-VideoConversion -InputPath $script:GifInput } | Should -Throw '*same as the input*'

        Should -Invoke Invoke-TwoPassConversion -Times 0 -Exactly
    }

    Context 'when the output parent is a directory link' {
        BeforeEach {
            $script:RealDirectory = Join-Path $TestDrive 'real'
            $script:LinkedDirectory = Join-Path $TestDrive 'linked'
            New-Item -ItemType Directory -Path $script:RealDirectory -Force | Out-Null
            $script:LinkedSource = Join-Path $script:RealDirectory 'source.gif'
            Set-Content -LiteralPath $script:LinkedSource -Value 'original-gif' -NoNewline
            $script:LinkCreated = $false
            $script:LinkCreationError = $null

            try {
                $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
                New-Item -ItemType $linkType -Path $script:LinkedDirectory -Target $script:RealDirectory -ErrorAction Stop | Out-Null
                $script:LinkCreated = $true
            }
            catch {
                $script:LinkCreationError = $_.Exception.Message
            }
        }

        AfterEach {
            if ($script:LinkCreated) {
                [System.IO.Directory]::Delete($script:LinkedDirectory, $false)
            }
        }

        It 'Refuses an output alias to the input through the linked parent' {
            if (-not $script:LinkCreated) {
                Set-ItResult -Skipped -Because "Directory links are unavailable: $script:LinkCreationError"
                return
            }
            $aliasedOutput = Join-Path $script:LinkedDirectory 'source.gif'

            { Invoke-VideoConversion -InputPath $script:LinkedSource -OutputPath $aliasedOutput } |
                Should -Throw '*same as the input*'

            Should -Invoke Invoke-TwoPassConversion -Times 0 -Exactly
            Get-Content -LiteralPath $script:LinkedSource -Raw | Should -Be 'original-gif'
        }

        It 'Allows a distinct output beneath the linked parent' {
            if (-not $script:LinkCreated) {
                Set-ItResult -Skipped -Because "Directory links are unavailable: $script:LinkCreationError"
                return
            }
            $distinctOutput = Join-Path $script:LinkedDirectory 'converted.gif'
            Mock Invoke-TwoPassConversion {
                Set-Content -LiteralPath $DestinationPath -Value 'converted-gif' -NoNewline
                return $true
            }

            { Invoke-VideoConversion -InputPath $script:LinkedSource -OutputPath $distinctOutput } |
                Should -Not -Throw

            Should -Invoke Invoke-TwoPassConversion -Times 1 -Exactly
            Test-Path -LiteralPath $distinctOutput -PathType Leaf | Should -BeTrue
            Get-Content -LiteralPath $script:LinkedSource -Raw | Should -Be 'original-gif'
        }
    }
}

Describe 'Conversion output integrity' -Tag 'Unit' {
    BeforeEach {
        Mock Test-FFmpegAvailable { $true }
        Mock Test-HDRContent { $false }
        $script:SourcePath = Join-Path $TestDrive 'integrity-source.mp4'
        Set-Content -Path $script:SourcePath -Value 'synthetic' -NoNewline
        $script:DestinationPath = Join-Path $TestDrive 'integrity-output.gif'
        Remove-Item -Path $script:DestinationPath -Force -ErrorAction SilentlyContinue
    }

    It 'Passes -y so an existing destination is overwritten (documented behavior)' {
        $script:capturedArgs = [System.Collections.Generic.List[object[]]]::new()
        Mock Invoke-FFmpegProcess {
            $script:capturedArgs.Add($Arguments)
            return $true
        }

        Invoke-TwoPassConversion -SourcePath $script:SourcePath -DestinationPath $script:DestinationPath -DitherAlgorithm 'bayer' -LoopCount 0 -BaseFilter 'fps=10' -TimeArgs @(-1) | Out-Null

        $passTwo = [string[]]$script:capturedArgs[1]
        $yIndex = [array]::IndexOf($passTwo, '-y')
        $yIndex | Should -BeGreaterThan -1
        $passTwo[$yIndex + 1] | Should -Be $script:DestinationPath
    }

    It 'Leaves a partial GIF in place when pass two fails (current behavior)' {
        Mock Invoke-FFmpegProcess {
            $target = [string]$Arguments[-1]
            if ($target -like '*palette.png') {
                Set-Content -Path $target -Value 'palette' -NoNewline
                return $true
            }
            Set-Content -Path $target -Value 'partial' -NoNewline
            return $false
        }

        { Invoke-VideoConversion -InputPath $script:SourcePath -OutputPath $script:DestinationPath } |
            Should -Throw '*Conversion failed*'

        Get-Content -Path $script:DestinationPath -Raw | Should -Be 'partial'
    }

    It 'Removes the palette directory when pass two throws' {
        $script:capturedPalette = $null
        Mock Invoke-FFmpegProcess {
            $target = [string]$Arguments[-1]
            if ($target -like '*palette.png') {
                $script:capturedPalette = $target
                Set-Content -Path $target -Value 'palette' -NoNewline
                return $true
            }
            throw 'ffmpeg timed out after 1 seconds.'
        }

        { Invoke-TwoPassConversion -SourcePath $script:SourcePath -DestinationPath $script:DestinationPath -DitherAlgorithm 'bayer' -LoopCount 0 -BaseFilter 'fps=10' -TimeArgs @(-1) } |
            Should -Throw '*timed out*'

        $script:capturedPalette | Should -Not -BeNullOrEmpty
        Test-Path -Path (Split-Path -Parent $script:capturedPalette) | Should -BeFalse
    }
}

Describe 'Find-VideoFile search order (current behavior)' -Tag 'Unit' {
    BeforeEach {
        $script:WorkDir = Join-Path $TestDrive 'work'
        $script:RepoDir = Join-Path $TestDrive 'repo-root'
        New-Item -ItemType Directory -Path $script:WorkDir, $script:RepoDir -Force | Out-Null
        Set-Content -Path (Join-Path $script:RepoDir 'demo.mp4') -Value 'repo-copy' -NoNewline
        Mock git { $global:LASTEXITCODE = 0; return $script:RepoDir }
        Push-Location $script:WorkDir
    }

    AfterEach {
        Pop-Location
        Remove-Item -Path (Join-Path $script:WorkDir 'demo.mp4') -Force -ErrorAction SilentlyContinue
    }

    It 'Returns the working-directory match before the repository-root match' {
        Set-Content -Path (Join-Path $script:WorkDir 'demo.mp4') -Value 'work-copy' -NoNewline

        $result = Find-VideoFile -Filename 'demo.mp4'

        Get-Content -Path $result -Raw | Should -Be 'work-copy'
    }

    It 'Falls back to the repository-root match when the working directory has none' {
        $result = Find-VideoFile -Filename 'demo.mp4'

        Get-Content -Path $result -Raw | Should -Be 'repo-copy'
    }
}
