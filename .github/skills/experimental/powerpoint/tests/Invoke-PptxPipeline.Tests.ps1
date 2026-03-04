#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# Variables set in It/Context blocks are read by dot-sourced functions through dynamic scoping
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

BeforeAll {
    . (Join-Path $PSScriptRoot '../scripts/Invoke-PptxPipeline.ps1') -Action Build
    Mock Write-Host {}

    # Shared stub directory for python executable
    $script:StubRoot = Join-Path ([System.IO.Path]::GetTempPath()) "pptx-pester-$PID"
    New-Item -ItemType Directory -Path $script:StubRoot -Force | Out-Null

    $binDir = if ($IsWindows) { Join-Path $script:StubRoot 'Scripts' } else { Join-Path $script:StubRoot 'bin' }
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    $pythonName = if ($IsWindows) { 'python.exe' } else { 'python' }
    $script:PythonStub = Join-Path $binDir $pythonName

    # Shell stub that exits with configurable code via STUB_EXIT_CODE env var
    Set-Content -Path $script:PythonStub -Value "#!/bin/sh`nexit `${STUB_EXIT_CODE:-0}" -NoNewline
    if (-not $IsWindows) { & chmod +x $script:PythonStub }
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

Describe 'Assert-BuildParameters' -Tag 'Unit' {
    Context 'when required parameters are missing' {
        It 'Throws when ContentDir is missing' {
            { Assert-BuildParameters -ContentDir '' -StylePath 'style.yaml' -OutputPath 'output.pptx' } | Should -Throw '*requires -ContentDir*'
        }

        It 'Throws when StylePath is missing' {
            { Assert-BuildParameters -ContentDir 'content/' -StylePath '' -OutputPath 'output.pptx' } | Should -Throw '*requires -StylePath*'
        }

        It 'Throws when OutputPath is missing' {
            { Assert-BuildParameters -ContentDir 'content/' -StylePath 'style.yaml' -OutputPath '' } | Should -Throw '*requires -OutputPath*'
        }

        It 'Throws when Slides specified without SourcePath' {
            { Assert-BuildParameters -ContentDir 'content/' -StylePath 'style.yaml' -OutputPath 'output.pptx' -Slides '1,2,3' -SourcePath '' } | Should -Throw '*-Slides requires -SourcePath*'
        }
    }

    Context 'when all required parameters are provided' {
        It 'Does not throw' {
            { Assert-BuildParameters -ContentDir 'content/' -StylePath 'style.yaml' -OutputPath 'output.pptx' } | Should -Not -Throw
        }

        It 'Does not throw with Slides and SourcePath' {
            { Assert-BuildParameters -ContentDir 'content/' -StylePath 'style.yaml' -OutputPath 'output.pptx' -Slides '1,2,3' -SourcePath 'source.pptx' } | Should -Not -Throw
        }
    }
}

Describe 'Assert-ExtractParameters' -Tag 'Unit' {
    It 'Throws when InputPath is missing' {
        { Assert-ExtractParameters -InputPath '' -OutputDir 'output/' } | Should -Throw '*requires -InputPath*'
    }

    It 'Throws when OutputDir is missing' {
        { Assert-ExtractParameters -InputPath 'input.pptx' -OutputDir '' } | Should -Throw '*requires -OutputDir*'
    }

    It 'Does not throw when all parameters provided' {
        { Assert-ExtractParameters -InputPath 'input.pptx' -OutputDir 'output/' } | Should -Not -Throw
    }
}

Describe 'Assert-ValidateParameters' -Tag 'Unit' {
    It 'Throws when InputPath is missing' {
        { Assert-ValidateParameters -InputPath '' } | Should -Throw '*requires -InputPath*'
    }

    It 'Does not throw when InputPath provided' {
        { Assert-ValidateParameters -InputPath 'input.pptx' } | Should -Not -Throw
    }
}

Describe 'Assert-ExportParameters' -Tag 'Unit' {
    It 'Throws when InputPath is missing' {
        { Assert-ExportParameters -InputPath '' -ImageOutputDir 'images/' } | Should -Throw '*requires -InputPath*'
    }

    It 'Throws when ImageOutputDir is missing' {
        { Assert-ExportParameters -InputPath 'input.pptx' -ImageOutputDir '' } | Should -Throw '*requires -ImageOutputDir*'
    }

    It 'Does not throw when all parameters provided' {
        { Assert-ExportParameters -InputPath 'input.pptx' -ImageOutputDir 'images/' } | Should -Not -Throw
    }
}

Describe 'Invoke-BuildDeck' -Tag 'Unit' {
    BeforeAll {
        Mock Get-VenvPythonPath { return $script:PythonStub }
    }

    Context 'when python script succeeds' {
        BeforeAll {
            $ContentDir = 'content/'
            $StylePath = 'style.yaml'
            $OutputPath = 'output.pptx'
        }

        It 'Completes without error' {
            { Invoke-BuildDeck } | Should -Not -Throw
        }
    }

    Context 'when optional parameters are provided' {
        BeforeAll {
            $ContentDir = 'content/'
            $StylePath = 'style.yaml'
            $OutputPath = 'output.pptx'
            $TemplatePath = 'template.pptx'
            $SourcePath = 'source.pptx'
            $Slides = '1,3,5'
        }

        It 'Completes without error' {
            { Invoke-BuildDeck } | Should -Not -Throw
        }
    }

    Context 'when python script fails' {
        BeforeAll {
            $ContentDir = 'content/'
            $StylePath = 'style.yaml'
            $OutputPath = 'output.pptx'
        }

        BeforeEach { $env:STUB_EXIT_CODE = '1' }
        AfterEach { Remove-Item Env:STUB_EXIT_CODE -ErrorAction SilentlyContinue }

        It 'Throws with exit code message' {
            { Invoke-BuildDeck } | Should -Throw '*build_deck.py failed*'
        }
    }
}

Describe 'Invoke-ExtractContent' -Tag 'Unit' {
    BeforeAll {
        Mock Get-VenvPythonPath { return $script:PythonStub }
    }

    Context 'when python script succeeds' {
        BeforeAll {
            $InputPath = 'input.pptx'
            $OutputDir = 'output/'
        }

        It 'Completes without error' {
            { Invoke-ExtractContent } | Should -Not -Throw
        }
    }

    Context 'when python script fails' {
        BeforeAll {
            $InputPath = 'input.pptx'
            $OutputDir = 'output/'
        }

        BeforeEach { $env:STUB_EXIT_CODE = '1' }
        AfterEach { Remove-Item Env:STUB_EXIT_CODE -ErrorAction SilentlyContinue }

        It 'Throws with exit code message' {
            { Invoke-ExtractContent } | Should -Throw '*extract_content.py failed*'
        }
    }
}

Describe 'Invoke-ExportSlides' -Tag 'Unit' {
    BeforeAll {
        Mock Get-VenvPythonPath { return $script:PythonStub }
        Mock ConvertTo-SlideImages {}
        Mock Test-Path { $false } -ParameterFilter { $Path -like '*slides.pdf' }
    }

    Context 'when LibreOffice is available' {
        BeforeAll {
            Mock Get-Command { [PSCustomObject]@{ Source = '/usr/bin/libreoffice' } } -ParameterFilter { $Name -eq 'libreoffice' }
            $InputPath = Join-Path $TestDrive 'test.pptx'
            $ImageOutputDir = Join-Path $TestDrive 'export-images'
            $Resolution = 150
        }

        It 'Completes without error' {
            { Invoke-ExportSlides } | Should -Not -Throw
        }

        It 'Calls ConvertTo-SlideImages' {
            Invoke-ExportSlides
            Should -Invoke ConvertTo-SlideImages -Times 1
        }
    }

    Context 'when LibreOffice is not available' {
        BeforeAll {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'libreoffice' }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'soffice' }
            $InputPath = 'test.pptx'
            $ImageOutputDir = Join-Path $TestDrive 'no-libre'
        }

        It 'Throws with install instructions' {
            { Invoke-ExportSlides } | Should -Throw '*LibreOffice is required*'
        }
    }

    Context 'when export_slides.py fails' {
        BeforeAll {
            Mock Get-Command { [PSCustomObject]@{ Source = '/usr/bin/libreoffice' } } -ParameterFilter { $Name -eq 'libreoffice' }
            $InputPath = Join-Path $TestDrive 'test.pptx'
            $ImageOutputDir = Join-Path $TestDrive 'fail-images'
        }

        BeforeEach { $env:STUB_EXIT_CODE = '1' }
        AfterEach { Remove-Item Env:STUB_EXIT_CODE -ErrorAction SilentlyContinue }

        It 'Throws with exit code message' {
            { Invoke-ExportSlides } | Should -Throw '*export_slides.py failed*'
        }
    }
}

Describe 'Invoke-ValidateDeck' -Tag 'Unit' {
    BeforeAll {
        Mock Get-VenvPythonPath { return $script:PythonStub }
        Mock Invoke-ExportSlides {}
    }

    Context 'when all steps succeed' {
        BeforeAll {
            $InputPath = Join-Path $TestDrive 'deck.pptx'
            $ImageOutputDir = ''
            $ValidationCacheDir = ''
            $ValidationPrompt = ''
            $ValidationPromptFile = ''
        }

        It 'Completes without error' {
            { Invoke-ValidateDeck } | Should -Not -Throw
        }
    }

    Context 'when validate_deck.py exits with code 2' {
        BeforeAll {
            $InputPath = Join-Path $TestDrive 'deck.pptx'
            $ImageOutputDir = ''
            $ValidationCacheDir = ''
            $ValidationPrompt = ''
            $ValidationPromptFile = ''
        }

        BeforeEach { $env:STUB_EXIT_CODE = '2' }
        AfterEach { Remove-Item Env:STUB_EXIT_CODE -ErrorAction SilentlyContinue }

        It 'Throws with error message' {
            { Invoke-ValidateDeck } | Should -Throw '*validate_deck.py encountered an error*'
        }
    }

    Context 'when validate_deck.py exits with code 1 (warnings)' {
        BeforeAll {
            $InputPath = Join-Path $TestDrive 'deck.pptx'
            $ImageOutputDir = ''
            $ValidationCacheDir = ''
            $ValidationPrompt = ''
            $ValidationPromptFile = ''
        }

        BeforeEach { $env:STUB_EXIT_CODE = '1' }
        AfterEach { Remove-Item Env:STUB_EXIT_CODE -ErrorAction SilentlyContinue }

        It 'Does not throw' {
            { Invoke-ValidateDeck } | Should -Not -Throw
        }
    }

    Context 'when vision validation is enabled' {
        BeforeAll {
            $InputPath = Join-Path $TestDrive 'deck.pptx'
            $ImageOutputDir = ''
            $ValidationCacheDir = ''
            $ValidationPrompt = 'Check slide quality'
            $ValidationPromptFile = ''
            $ValidationModel = 'test-model'
            $ValidationConcurrency = 1
        }

        It 'Completes without error' {
            { Invoke-ValidateDeck } | Should -Not -Throw
        }
    }
}

Describe 'ConvertTo-SlideImages' -Tag 'Unit' {
    Context 'when pdftoppm is available' {
        BeforeAll {
            Mock Get-Command { [PSCustomObject]@{ Source = '/usr/bin/pdftoppm' } } -ParameterFilter { $Name -eq 'pdftoppm' }
            # Define function so Pester can mock an uninstalled command
            function pdftoppm { }
        }

        It 'Calls pdftoppm and completes' {
            Mock pdftoppm { $global:LASTEXITCODE = 0 }
            $outDir = Join-Path $TestDrive 'pdftoppm-test'
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
            $pdfPath = Join-Path $TestDrive 'slides.pdf'
            Set-Content -Path $pdfPath -Value 'dummy'

            { ConvertTo-SlideImages -PdfPath $pdfPath -OutputDir $outDir } | Should -Not -Throw
            Should -Invoke pdftoppm -Times 1
        }

        It 'Renames output files for zero-padded consistency' {
            Mock pdftoppm { $global:LASTEXITCODE = 0 }
            $outDir = Join-Path $TestDrive 'rename-test'
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
            $pdfPath = Join-Path $TestDrive 'rename.pdf'
            Set-Content -Path $pdfPath -Value 'dummy'

            # Pre-create files matching pdftoppm output pattern
            Set-Content -Path (Join-Path $outDir 'slide-1.jpg') -Value 'img'
            Set-Content -Path (Join-Path $outDir 'slide-10.jpg') -Value 'img'

            ConvertTo-SlideImages -PdfPath $pdfPath -OutputDir $outDir

            Test-Path (Join-Path $outDir 'slide-001.jpg') | Should -BeTrue
            Test-Path (Join-Path $outDir 'slide-010.jpg') | Should -BeTrue
        }

        It 'Throws when pdftoppm fails' {
            Mock pdftoppm { $global:LASTEXITCODE = 1 }
            $outDir = Join-Path $TestDrive 'fail-test'
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
            $pdfPath = Join-Path $TestDrive 'fail.pdf'
            Set-Content -Path $pdfPath -Value 'dummy'

            { ConvertTo-SlideImages -PdfPath $pdfPath -OutputDir $outDir } | Should -Throw '*pdftoppm failed*'
        }
    }

    Context 'when pdftoppm is not available' {
        BeforeAll {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'pdftoppm' }
            Mock Get-VenvPythonPath { return $script:PythonStub }
        }

        It 'Falls back to PyMuPDF render script' {
            $outDir = Join-Path $TestDrive 'fallback-test'
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
            $pdfPath = Join-Path $TestDrive 'fallback.pdf'
            Set-Content -Path $pdfPath -Value 'dummy'

            { ConvertTo-SlideImages -PdfPath $pdfPath -OutputDir $outDir } | Should -Not -Throw
        }

        It 'Throws when render script fails' {
            $outDir = Join-Path $TestDrive 'fallback-fail'
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
            $pdfPath = Join-Path $TestDrive 'fallback-fail.pdf'
            Set-Content -Path $pdfPath -Value 'dummy'

            $env:STUB_EXIT_CODE = '1'
            try {
                { ConvertTo-SlideImages -PdfPath $pdfPath -OutputDir $outDir } | Should -Throw '*render_pdf_images.py failed*'
            }
            finally {
                Remove-Item Env:STUB_EXIT_CODE -ErrorAction SilentlyContinue
            }
        }
    }
}
