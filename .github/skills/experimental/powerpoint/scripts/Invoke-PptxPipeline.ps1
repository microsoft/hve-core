#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Orchestrates PowerPoint slide deck operations via Python scripts.

.DESCRIPTION
    Manages the Python virtual environment and dispatches to the correct Python
    script for building, extracting, or validating PowerPoint slide decks. Sets
    up a venv with required dependencies on first run.

.PARAMETER Action
    The operation to perform: Build, Extract, or Validate.

.PARAMETER ContentDir
    Path to the content/ directory containing slide folders and global style.
    Required for Build; optional for Validate.

.PARAMETER StylePath
    Path to the global style.yaml file. Required for Build.

.PARAMETER OutputPath
    Output PPTX file path. Required for Build.

.PARAMETER InputPath
    Input PPTX file path. Required for Extract and Validate.

.PARAMETER OutputDir
    Output directory for extracted content. Required for Extract.

.PARAMETER SourcePath
    Source PPTX for partial rebuilds. Optional for Build.

.PARAMETER TemplatePath
    Template PPTX file path for themed builds. Optional for Build.

.PARAMETER Slides
    Comma-separated slide numbers to rebuild. Requires SourcePath. Optional for Build.

.PARAMETER SkipVenvSetup
    Skip virtual environment creation and dependency installation.

.PARAMETER ImageOutputDir
    Output directory for exported slide images. Required for Export.

.PARAMETER Resolution
    DPI resolution for exported slide images. Defaults to 150. Optional for Export.

.EXAMPLE
    ./Invoke-PptxPipeline.ps1 -Action Build -ContentDir content/ -StylePath content/global/style.yaml -OutputPath slide-deck/presentation.pptx

.EXAMPLE
    ./Invoke-PptxPipeline.ps1 -Action Extract -InputPath existing-deck.pptx -OutputDir content/

.EXAMPLE
    ./Invoke-PptxPipeline.ps1 -Action Validate -InputPath slide-deck/presentation.pptx -ContentDir content/

.EXAMPLE
    ./Invoke-PptxPipeline.ps1 -Action Build -ContentDir content/ -StylePath content/global/style.yaml -OutputPath slide-deck/presentation.pptx -TemplatePath template.pptx

.EXAMPLE
    ./Invoke-PptxPipeline.ps1 -Action Build -ContentDir content/ -StylePath content/global/style.yaml -OutputPath slide-deck/presentation.pptx -SourcePath slide-deck/presentation.pptx -Slides "3,7,15"

.EXAMPLE
    ./Invoke-PptxPipeline.ps1 -Action Export -InputPath slide-deck/presentation.pptx -ImageOutputDir slide-deck/validation/ -Slides "1,3,5" -Resolution 150
#>

# Invoke-* functions consume these script-level parameters through dynamic scoping
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'TemplatePath',
    Justification = 'Consumed by Invoke-BuildDeck through dynamic scoping')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Resolution',
    Justification = 'Consumed by Invoke-ExportSlides through dynamic scoping')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'ValidationPrompt',
    Justification = 'Consumed by Invoke-ValidateDeck through dynamic scoping')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'ValidationPromptFile',
    Justification = 'Consumed by Invoke-ValidateDeck through dynamic scoping')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'ValidationModel',
    Justification = 'Consumed by Invoke-ValidateDeck through dynamic scoping')]
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Build', 'Extract', 'Validate', 'Export')]
    [string]$Action,

    [Parameter()]
    [string]$ContentDir,

    [Parameter()]
    [string]$StylePath,

    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [string]$InputPath,

    [Parameter()]
    [string]$OutputDir,

    [Parameter()]
    [string]$TemplatePath,

    [Parameter()]
    [string]$SourcePath,

    [Parameter()]
    [string]$Slides,

    [Parameter()]
    [string]$ImageOutputDir,

    [Parameter()]
    [int]$Resolution = 150,

    [Parameter()]
    [string]$ValidationPrompt,

    [Parameter()]
    [string]$ValidationPromptFile,

    [Parameter()]
    [string]$ValidationModel = 'claude-haiku-4.5',

    [Parameter()]
    [switch]$SkipVenvSetup
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$SkillRoot = Split-Path $ScriptDir
$VenvDir = Join-Path $SkillRoot '.venv'

#region Environment Setup

function Test-UvAvailability {
    <#
    .SYNOPSIS
        Verifies uv is available on PATH.
    .OUTPUTS
        [string] The resolved uv command path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $resolved = Get-Command 'uv' -ErrorAction SilentlyContinue
    if ($resolved) {
        return $resolved.Source
    }
    throw 'uv is required but was not found on PATH. Install with: curl -LsSf https://astral.sh/uv/install.sh | sh'
}

function Initialize-PythonEnvironment {
    <#
    .SYNOPSIS
        Syncs the Python virtual environment and dependencies via uv.
    .DESCRIPTION
        Runs uv sync from the skill root directory. Creates the virtual
        environment and installs all dependencies declared in pyproject.toml.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    Write-Host 'Syncing Python environment via uv...'
    & uv sync --directory $SkillRoot
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to sync Python environment via uv.'
    }
    Write-Host 'Environment synchronized.'
}

function Get-VenvPythonPath {
    <#
    .SYNOPSIS
        Returns the path to the venv Python executable.
    .OUTPUTS
        [string] Absolute path to the venv python binary.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($IsWindows) {
        return Join-Path $VenvDir 'Scripts/python.exe'
    }
    return Join-Path $VenvDir 'bin/python'
}

#endregion

#region Parameter Validation

function Assert-BuildParameters {
    <#
    .SYNOPSIS
        Validates that required parameters for Build action are present.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter()]
        [string]$ContentDir,

        [Parameter()]
        [string]$StylePath,

        [Parameter()]
        [string]$OutputPath,

        [Parameter()]
        [string]$Slides,

        [Parameter()]
        [string]$SourcePath
    )

    if (-not $ContentDir) {
        throw 'Build action requires -ContentDir.'
    }
    if (-not $StylePath) {
        throw 'Build action requires -StylePath.'
    }
    if (-not $OutputPath) {
        throw 'Build action requires -OutputPath.'
    }
    if ($Slides -and -not $SourcePath) {
        throw '-Slides requires -SourcePath for partial rebuilds.'
    }
}

function Assert-ExtractParameters {
    <#
    .SYNOPSIS
        Validates that required parameters for Extract action are present.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter()]
        [string]$InputPath,

        [Parameter()]
        [string]$OutputDir
    )

    if (-not $InputPath) {
        throw 'Extract action requires -InputPath.'
    }
    if (-not $OutputDir) {
        throw 'Extract action requires -OutputDir.'
    }
}

function Assert-ValidateParameters {
    <#
    .SYNOPSIS
        Validates that required parameters for Validate action are present.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter()]
        [string]$InputPath
    )

    if (-not $InputPath) {
        throw 'Validate action requires -InputPath.'
    }
}

function Assert-ExportParameters {
    <#
    .SYNOPSIS
        Validates that required parameters for Export action are present.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter()]
        [string]$InputPath,

        [Parameter()]
        [string]$ImageOutputDir
    )

    if (-not $InputPath) {
        throw 'Export action requires -InputPath.'
    }
    if (-not $ImageOutputDir) {
        throw 'Export action requires -ImageOutputDir.'
    }
}

#endregion

#region Script Execution

function Invoke-BuildDeck {
    <#
    .SYNOPSIS
        Runs build_deck.py with the provided parameters.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    $python = Get-VenvPythonPath
    $script = Join-Path $ScriptDir 'build_deck.py'

    $arguments = @(
        $script,
        '--content-dir', $ContentDir,
        '--style', $StylePath,
        '--output', $OutputPath
    )

    if ($TemplatePath) {
        $arguments += '--template'
        $arguments += $TemplatePath
    }
    if ($SourcePath) {
        $arguments += '--source'
        $arguments += $SourcePath
    }
    if ($Slides) {
        $arguments += '--slides'
        $arguments += $Slides
    }

    Write-Host "Building deck from $ContentDir -> $OutputPath"
    & $python @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "build_deck.py failed with exit code $LASTEXITCODE."
    }
}

function Invoke-ExtractContent {
    <#
    .SYNOPSIS
        Runs extract_content.py with the provided parameters.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    $python = Get-VenvPythonPath
    $script = Join-Path $ScriptDir 'extract_content.py'

    $arguments = @(
        $script,
        '--input', $InputPath,
        '--output-dir', $OutputDir
    )

    if ($Slides) {
        $arguments += '--slides'
        $arguments += $Slides
    }

    Write-Host "Extracting content from $InputPath -> $OutputDir"
    & $python @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "extract_content.py failed with exit code $LASTEXITCODE."
    }
}

function Invoke-ValidateDeck {
    <#
    .SYNOPSIS
        Exports slides to images, runs PPTX property checks, and optionally runs
        Copilot SDK vision validation.
    .DESCRIPTION
        Chains Export (PPTX to JPG images), validate_deck.py (speaker notes,
        slide count), and validate_slides.py (vision-based quality checks via
        Copilot SDK). The vision step runs when ValidationPrompt or
        ValidationPromptFile is provided.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    $python = Get-VenvPythonPath
    $hasVisionPrompt = $ValidationPrompt -or $ValidationPromptFile
    $totalSteps = if ($hasVisionPrompt) { 5 } else { 4 }

    # Default image output directory when not specified
    if (-not $ImageOutputDir) {
        $ImageOutputDir = Join-Path (Split-Path $InputPath) 'validation'
    }

    # Step 1: Export slides to images
    Write-Host "Step 1/$totalSteps`: Exporting slides to images..."
    Invoke-ExportSlides

    # Step 2: Run PPTX-only checks (speaker notes, slide count)
    Write-Host "Step 2/$totalSteps`: Running PPTX property checks..."
    $pptxScript = Join-Path $ScriptDir 'validate_deck.py'
    $pptxArgs = @(
        $pptxScript,
        '--input', $InputPath
    )
    if ($ContentDir) {
        $pptxArgs += '--content-dir'
        $pptxArgs += $ContentDir
    }
    if ($Slides) {
        $pptxArgs += '--slides'
        $pptxArgs += $Slides
    }
    $deckOutputPath = Join-Path $ImageOutputDir 'deck-validation-results.json'
    $pptxArgs += '--output'
    $pptxArgs += $deckOutputPath
    $deckReportPath = Join-Path $ImageOutputDir 'deck-validation-report.md'
    $pptxArgs += '--report'
    $pptxArgs += $deckReportPath
    $pptxArgs += '--per-slide-dir'
    $pptxArgs += $ImageOutputDir

    & $python @pptxArgs
    if ($LASTEXITCODE -eq 2) {
        throw "validate_deck.py encountered an error (exit code $LASTEXITCODE)."
    }
    if ($LASTEXITCODE -eq 1) {
        Write-Host "PPTX property checks found warnings — see $deckReportPath"
    }

    # Step 3: Run geometric validation (margin, gap, overflow checks)
    Write-Host "Step 3/$totalSteps`: Running geometric validation..."
    $geomScript = Join-Path $ScriptDir 'validate_geometry.py'
    $geomArgs = @(
        $geomScript,
        '--input', $InputPath
    )
    if ($Slides) {
        $geomArgs += '--slides'
        $geomArgs += $Slides
    }
    $geomOutputPath = Join-Path $ImageOutputDir 'geometry-validation-results.json'
    $geomArgs += '--output'
    $geomArgs += $geomOutputPath
    $geomReportPath = Join-Path $ImageOutputDir 'geometry-validation-report.md'
    $geomArgs += '--report'
    $geomArgs += $geomReportPath
    $geomArgs += '--per-slide-dir'
    $geomArgs += $ImageOutputDir
    if ($VerbosePreference -eq 'Continue') {
        $geomArgs += '-v'
    }

    & $python @geomArgs
    if ($LASTEXITCODE -eq 2) {
        throw "validate_geometry.py encountered an error (exit code $LASTEXITCODE)."
    }
    if ($LASTEXITCODE -eq 1) {
        Write-Host "Geometric validation found warnings — see $geomReportPath"
    }

    # Step 4: Run Copilot SDK vision validation (when prompt provided)
    if ($hasVisionPrompt) {
        Write-Host "Step 4/$totalSteps`: Running Copilot SDK vision validation..."
        $visionScript = Join-Path $ScriptDir 'validate_slides.py'
        $visionArgs = @(
            $visionScript,
            '--image-dir', $ImageOutputDir,
            '--model', $ValidationModel
        )
        if ($ValidationPrompt) {
            $visionArgs += '--prompt'
            $visionArgs += $ValidationPrompt
        }
        if ($ValidationPromptFile) {
            $visionArgs += '--prompt-file'
            $visionArgs += $ValidationPromptFile
        }
        $visionOutputPath = Join-Path $ImageOutputDir 'validation-results.json'
        $visionArgs += '--output'
        $visionArgs += $visionOutputPath
        if ($Slides) {
            $visionArgs += '--slides'
            $visionArgs += $Slides
        }

        & $python @visionArgs
        if ($LASTEXITCODE -ne 0) {
            throw "validate_slides.py failed with exit code $LASTEXITCODE."
        }
        Write-Host "Vision validation results: $visionOutputPath"
    }
}

function Invoke-ExportSlides {
    <#
    .SYNOPSIS
        Exports PPTX slides to PDF then converts to JPG images.
    .DESCRIPTION
        Calls export_slides.py to convert PPTX to PDF, then uses pdftoppm
        (from poppler) or a PyMuPDF fallback to render PDF pages as JPGs.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    $python = Get-VenvPythonPath
    $exportScript = Join-Path $ScriptDir 'export_slides.py'

    # Pre-flight: verify LibreOffice is available (required for PPTX-to-PDF)
    $libreoffice = Get-Command 'libreoffice' -ErrorAction SilentlyContinue
    if (-not $libreoffice) {
        $libreoffice = Get-Command 'soffice' -ErrorAction SilentlyContinue
    }
    if (-not $libreoffice) {
        $installHint = if ($IsMacOS) { 'brew install --cask libreoffice' }
            elseif ($IsWindows) { 'winget install TheDocumentFoundation.LibreOffice' }
            else { 'sudo apt-get install libreoffice' }
        throw "LibreOffice is required for PPTX-to-PDF export but was not found on PATH. Install with: $installHint"
    }

    # Ensure output directory exists
    if (-not (Test-Path $ImageOutputDir)) {
        New-Item -ItemType Directory -Path $ImageOutputDir -Force | Out-Null
    }

    # Clear stale slide images from prior runs to prevent validate_slides.py
    # from picking up outdated images that no longer represent the current deck.
    $staleImages = Get-ChildItem -Path $ImageOutputDir -Filter 'slide-*.jpg' -ErrorAction SilentlyContinue
    if ($staleImages) {
        $staleImages | Remove-Item -Force
        Write-Host "Cleared $($staleImages.Count) stale slide image(s) from $ImageOutputDir"
    }

    $pdfOutput = Join-Path $ImageOutputDir 'slides.pdf'

    # Build arguments for export_slides.py
    $arguments = @(
        $exportScript,
        '--input', $InputPath,
        '--output', $pdfOutput
    )
    if ($Slides) {
        $arguments += '--slides'
        $arguments += $Slides
    }

    Write-Host "Exporting slides from $InputPath to PDF"
    & $python @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "export_slides.py failed with exit code $LASTEXITCODE."
    }

    # Convert PDF to JPG images
    ConvertTo-SlideImages -PdfPath $pdfOutput -OutputDir $ImageOutputDir -Dpi $Resolution -SlideNumbers $Slides

    # Clean up intermediate PDF
    if (Test-Path $pdfOutput) {
        Remove-Item $pdfOutput -Force
        Write-Host 'Cleaned up intermediate PDF.'
    }
}

function ConvertTo-SlideImages {
    <#
    .SYNOPSIS
        Converts PDF pages to JPG images using pdftoppm or PyMuPDF fallback.
    .DESCRIPTION
        When SlideNumbers is provided, output images are named to match the
        original slide numbers (e.g. slide-023.jpg) instead of sequential
        numbering (slide-001.jpg). This ensures validate_slides.py can find
        images by their actual slide number after filtered exports.
    .PARAMETER PdfPath
        Path to the PDF file to convert.
    .PARAMETER OutputDir
        Directory where JPG files will be saved.
    .PARAMETER Dpi
        Resolution in DPI for the rendered images.
    .PARAMETER SlideNumbers
        Comma-separated original slide numbers for output naming. When the
        PDF contains a filtered subset of slides, this maps each sequential
        PDF page to the correct original slide number in the filename.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PdfPath,

        [Parameter(Mandatory = $true)]
        [string]$OutputDir,

        [Parameter()]
        [int]$Dpi = 150,

        [Parameter()]
        [string]$SlideNumbers
    )

    $pdftoppm = Get-Command 'pdftoppm' -ErrorAction SilentlyContinue
    if ($pdftoppm) {
        Write-Host "Converting PDF to JPG via pdftoppm (${Dpi} DPI)"
        $prefix = Join-Path $OutputDir 'slide'
        & pdftoppm -jpeg -r $Dpi $PdfPath $prefix
        if ($LASTEXITCODE -ne 0) {
            throw "pdftoppm failed with exit code $LASTEXITCODE."
        }

        # Collect sequentially-numbered output files sorted by number
        $seqFiles = Get-ChildItem -Path $OutputDir -Filter 'slide-*.jpg' |
            Where-Object { $_.Name -match '^slide-(\d+)\.jpg$' } |
            Sort-Object { [int]($_.Name -replace '^slide-(\d+)\.jpg$', '$1') }

        if ($SlideNumbers) {
            # Rename from sequential numbers to original slide numbers
            $targetNums = $SlideNumbers -split ',' | ForEach-Object { [int]$_.Trim() }
            $idx = 0
            foreach ($file in $seqFiles) {
                if ($idx -lt $targetNums.Count) {
                    $newName = 'slide-{0:D3}.jpg' -f $targetNums[$idx]
                    if ($file.Name -ne $newName) {
                        Rename-Item -Path $file.FullName -NewName $newName
                    }
                    $idx++
                }
            }
        }
        else {
            # Zero-pad to 3 digits for consistency (slide-1.jpg -> slide-001.jpg)
            foreach ($file in $seqFiles) {
                if ($file.Name -match '^slide-(\d+)\.jpg$') {
                    $num = [int]$Matches[1]
                    $newName = 'slide-{0:D3}.jpg' -f $num
                    if ($file.Name -ne $newName) {
                        Rename-Item -Path $file.FullName -NewName $newName
                    }
                }
            }
        }
    }
    else {
        Write-Host 'pdftoppm not found, falling back to PyMuPDF'
        $python = Get-VenvPythonPath
        $renderScript = Join-Path $ScriptDir 'render_pdf_images.py'

        $renderArgs = @($renderScript, '--input', $PdfPath, '--output-dir', $OutputDir, '--dpi', $Dpi)
        if ($SlideNumbers) {
            $renderArgs += '--slide-numbers'
            $renderArgs += $SlideNumbers
        }

        & $python @renderArgs
        if ($LASTEXITCODE -ne 0) {
            throw "render_pdf_images.py failed with exit code $LASTEXITCODE."
        }
    }

    $imageCount = (Get-ChildItem -Path $OutputDir -Filter 'slide-*.jpg').Count
    Write-Host "Exported $imageCount slide image(s) to $OutputDir"
}

#endregion

#region Main

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $SkipVenvSetup) {
        Test-UvAvailability | Out-Null
        Initialize-PythonEnvironment
    }

    switch ($Action) {
        'Build' {
            Assert-BuildParameters -ContentDir $ContentDir -StylePath $StylePath -OutputPath $OutputPath -Slides $Slides -SourcePath $SourcePath
            Invoke-BuildDeck
        }
        'Extract' {
            Assert-ExtractParameters -InputPath $InputPath -OutputDir $OutputDir
            Invoke-ExtractContent
        }
        'Validate' {
            Assert-ValidateParameters -InputPath $InputPath
            Invoke-ValidateDeck
        }
        'Export' {
            Assert-ExportParameters -InputPath $InputPath -ImageOutputDir $ImageOutputDir
            Invoke-ExportSlides
        }
    }
}

#endregion
