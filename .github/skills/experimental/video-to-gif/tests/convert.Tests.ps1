#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    function global:ffmpeg { param([Parameter(ValueFromRemainingArguments = $true)] [object[]]$Args) }
    function global:ffprobe { param([Parameter(ValueFromRemainingArguments = $true)] [object[]]$Args) }

    . (Join-Path $PSScriptRoot '../scripts/convert.ps1') -InputPath 'video.mp4'
    Mock Write-Host {}
    Mock Write-Error {}
}

AfterAll {
    # Remove the ffmpeg/ffprobe stubs so they do not leak into later test suites
    Remove-Item -Path 'Function:\ffmpeg' -Force -ErrorAction SilentlyContinue
    Remove-Item -Path 'Function:\ffprobe' -Force -ErrorAction SilentlyContinue
}

Describe 'Format-FileSize' -Tag 'Unit' {
    It 'Formats bytes values below one kilobyte' {
        Format-FileSize -Bytes 512 | Should -Be '512 bytes'
    }

    It 'Formats values in the kilobyte range' {
        Format-FileSize -Bytes 1536 | Should -Be '1.50 KB'
    }

    It 'Formats values in the megabyte range' {
        Format-FileSize -Bytes 2.5MB | Should -Be '2.50 MB'
    }
}

Describe 'Test-FFmpegAvailable' -Tag 'Unit' {
    It 'Returns false when ffmpeg is not installed' {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'ffmpeg' }

        Test-FFmpegAvailable | Should -BeFalse
    }

    It 'Returns true when ffmpeg is installed' {
        Mock Get-Command { [pscustomobject]@{ Name = 'ffmpeg' } } -ParameterFilter { $Name -eq 'ffmpeg' }

        Test-FFmpegAvailable | Should -BeTrue
    }
}

Describe 'Find-VideoFile' -Tag 'Unit' {
    BeforeEach {
        Push-Location $TestDrive
        Mock git { $global:LASTEXITCODE = 0; return $null }
    }

    AfterEach {
        Pop-Location
    }

    It 'Returns the resolved path for an existing video file' {
        $videoPath = Join-Path $TestDrive 'sample.mp4'
        Set-Content -Path $videoPath -Value 'video' -NoNewline

        $result = Find-VideoFile -Filename 'sample.mp4'

        $result | Should -Not -BeNullOrEmpty
        $result | Should -Be (Resolve-Path -Path $videoPath).Path
    }

    It 'Returns null for a missing video file' {
        $result = Find-VideoFile -Filename 'missing-video.mp4'

        $result | Should -BeNullOrEmpty
    }
}

Describe 'Test-HDRContent' -Tag 'Unit' {
    It 'Returns false when ffprobe is unavailable' {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'ffprobe' }

        Test-HDRContent -FilePath 'video.mp4' | Should -BeFalse
    }

    It 'Returns true when ffprobe reports HDR color metadata' {
        Mock Get-Command { [pscustomobject]@{ Name = 'ffprobe' } } -ParameterFilter { $Name -eq 'ffprobe' }
        Mock ffprobe { 'bt2020' }

        Test-HDRContent -FilePath 'video.mp4' | Should -BeTrue
    }

    It 'Returns false when ffprobe reports SDR content' {
        Mock Get-Command { [pscustomobject]@{ Name = 'ffprobe' } } -ParameterFilter { $Name -eq 'ffprobe' }
        Mock ffprobe { 'bt709' }

        Test-HDRContent -FilePath 'video.mp4' | Should -BeFalse
    }
}

Describe 'Invoke-SinglePassConversion' -Tag 'Unit' {
    It 'Returns true when the single-pass command exits successfully' {
        Mock ffmpeg { $global:LASTEXITCODE = 0 }

        $result = Invoke-SinglePassConversion -SourcePath 'video.mp4' -DestinationPath 'output.gif' -LoopCount 0 -BaseFilter 'fps=10' -TimeArgs @(-1)

        $result | Should -BeTrue
        Should -Invoke ffmpeg -Times 1 -Exactly
    }
}

Describe 'Invoke-TwoPassConversion' -Tag 'Unit' {
    BeforeEach {
        $env:TEMP = $TestDrive
    }

    AfterEach {
        Remove-Item Env:TEMP -ErrorAction SilentlyContinue
    }

    It 'Removes the temporary palette file after a successful conversion' {
        $paletteFile = Join-Path $TestDrive "palette_$PID.png"
        $destinationPath = Join-Path $TestDrive 'output.gif'

        Mock ffmpeg {
            $global:LASTEXITCODE = 0
            Set-Content -Path $paletteFile -Value 'palette' -NoNewline
        }

        $result = Invoke-TwoPassConversion -SourcePath 'video.mp4' -DestinationPath $destinationPath -DitherAlgorithm 'bayer' -LoopCount 0 -BaseFilter 'fps=10' -TimeArgs @(-1)

        $result | Should -BeTrue
        Test-Path -Path $paletteFile | Should -BeFalse
    }

    It 'Returns false when palette generation fails' {
        Mock ffmpeg { $global:LASTEXITCODE = 1 }

        $result = Invoke-TwoPassConversion -SourcePath 'video.mp4' -DestinationPath 'output.gif' -DitherAlgorithm 'bayer' -LoopCount 0 -BaseFilter 'fps=10' -TimeArgs @(-1)

        $result | Should -BeFalse
    }
}

Describe 'Invoke-VideoConversion' -Tag 'Unit' {
    BeforeEach {
        Mock Test-FFmpegAvailable { $true }
        Mock Test-HDRContent { $false }
        Mock Find-VideoFile { 'video.mp4' }
    }

    It 'Uses the two-pass path and formats the output size when conversion succeeds' {
        $outputPath = Join-Path $TestDrive 'converted.gif'
        $outputDir = Split-Path -Parent $outputPath
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

        Mock Invoke-TwoPassConversion {
            Set-Content -Path $DestinationPath -Value 'gif-data' -NoNewline
            return $true
        }
        Mock Invoke-SinglePassConversion { throw 'single pass should not be used' }

        { Invoke-VideoConversion -InputPath 'video.mp4' -OutputPath $outputPath -Start 5 -Duration 10 } | Should -Not -Throw

        Should -Invoke Invoke-TwoPassConversion -Times 1 -Exactly
        (Get-Item -Path $outputPath).Length | Should -BeGreaterThan 0
    }

    It 'Uses a default output path derived from an existing input file' {
        $sourcePath = Join-Path $TestDrive 'sample.mp4'
        Set-Content -Path $sourcePath -Value 'video' -NoNewline

        Mock Invoke-TwoPassConversion {
            Set-Content -Path $DestinationPath -Value 'gif-data' -NoNewline
            return $true
        }

        { Invoke-VideoConversion -InputPath $sourcePath } | Should -Not -Throw

        Test-Path -Path (Join-Path $TestDrive 'sample.gif') | Should -BeTrue
        Should -Invoke Invoke-TwoPassConversion -Times 1 -Exactly
    }

    It 'Applies the HDR-specific filter path when HDR content is detected' {
        $outputPath = Join-Path $TestDrive 'hdr.gif'
        New-Item -ItemType Directory -Path $TestDrive -Force | Out-Null

        Mock Test-HDRContent { $true }
        Mock Invoke-TwoPassConversion {
            Set-Content -Path $DestinationPath -Value 'gif-data' -NoNewline
            return $true
        }

        { Invoke-VideoConversion -InputPath 'video.mp4' -OutputPath $outputPath -Start 5 -Duration 10 } | Should -Not -Throw

        Should -Invoke Invoke-TwoPassConversion -Times 1 -Exactly -ParameterFilter { $BaseFilter -match 'tonemap' }
    }

    It 'Throws when the input file cannot be found' {
        Mock Find-VideoFile { $null }

        { Invoke-VideoConversion -InputPath 'missing-video.mp4' } | Should -Throw '*Input file not found*'
    }

    It 'Uses the single-pass path when SkipPalette is supplied' {
        $outputPath = Join-Path $TestDrive 'single-pass.gif'
        $outputDir = Split-Path -Parent $outputPath
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

        Mock Invoke-SinglePassConversion {
            Set-Content -Path $DestinationPath -Value 'gif-data' -NoNewline
            return $true
        }
        Mock Invoke-TwoPassConversion { throw 'two pass should not be used' }

        { Invoke-VideoConversion -InputPath 'video.mp4' -OutputPath $outputPath -SkipPalette } | Should -Not -Throw

        Should -Invoke Invoke-SinglePassConversion -Times 1 -Exactly
        Should -Invoke Invoke-TwoPassConversion -Times 0 -Exactly
    }

    It 'Throws when the helper reports conversion failure' {
        $outputPath = Join-Path $TestDrive 'failed.gif'
        $outputDir = Split-Path -Parent $outputPath
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

        Mock Invoke-TwoPassConversion { return $false }
        Mock Invoke-SinglePassConversion { return $false }

        { Invoke-VideoConversion -InputPath 'video.mp4' -OutputPath $outputPath } | Should -Throw '*Conversion failed*'
    }
}
