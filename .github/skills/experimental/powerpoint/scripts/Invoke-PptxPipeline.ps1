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
    ./Invoke-PptxPipeline.ps1 -Action Build -ContentDir content/ -StylePath content/global/style.yaml -OutputPath slide-deck/presentation.pptx -SourcePath slide-deck/presentation.pptx -Slides "3,7,15"

.EXAMPLE
    ./Invoke-PptxPipeline.ps1 -Action Export -InputPath slide-deck/presentation.pptx -ImageOutputDir slide-deck/validation/ -Slides "1,3,5" -Resolution 150
#>

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
    [string]$SourcePath,

    [Parameter()]
    [string]$Slides,

    [Parameter()]
    [string]$ImageOutputDir,

    [Parameter()]
    [int]$Resolution = 150,

    [Parameter()]
    [switch]$SkipVenvSetup
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$VenvDir = Join-Path $ScriptDir '.venv'
$RequiredPackages = @('python-pptx', 'pyyaml', 'cairosvg', 'Pillow', 'pymupdf')

#region Environment Setup

function Test-PythonAvailability {
    <#
    .SYNOPSIS
        Verifies a Python 3 executable is available on PATH.
    .OUTPUTS
        [string] The resolved Python command name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    foreach ($cmd in @('python3', 'python')) {
        $resolved = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($resolved) {
            $version = & $cmd --version 2>&1
            if ($version -match 'Python 3') {
                return $cmd
            }
        }
    }
    throw 'Python 3 is required but was not found on PATH.'
}

function Initialize-PythonVenv {
    <#
    .SYNOPSIS
        Creates a Python virtual environment and installs required packages.
    .PARAMETER PythonCmd
        The Python executable to use for venv creation.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PythonCmd
    )

    if (-not (Test-Path $VenvDir)) {
        Write-Host "Creating virtual environment at $VenvDir"
        & $PythonCmd -m venv $VenvDir
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create virtual environment."
        }
    }

    $pipPath = Get-VenvPipPath
    Write-Host 'Installing dependencies...'
    & $pipPath install --quiet @RequiredPackages
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install dependencies: $($RequiredPackages -join ', ')"
    }
    Write-Host 'Dependencies installed.'
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

function Get-VenvPipPath {
    <#
    .SYNOPSIS
        Returns the path to the venv pip executable.
    .OUTPUTS
        [string] Absolute path to the venv pip binary.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($IsWindows) {
        return Join-Path $VenvDir 'Scripts/pip.exe'
    }
    return Join-Path $VenvDir 'bin/pip'
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
    param()

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
    param()

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
    param()

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
    param()

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
        Runs validate_deck.py with the provided parameters.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    $python = Get-VenvPythonPath
    $script = Join-Path $ScriptDir 'validate_deck.py'

    $arguments = @(
        $script,
        '--input', $InputPath
    )

    if ($ContentDir) {
        $arguments += '--content-dir'
        $arguments += $ContentDir
    }

    if ($Slides) {
        $arguments += '--slides'
        $arguments += $Slides
    }

    Write-Host "Validating deck $InputPath"
    & $python @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "validate_deck.py failed with exit code $LASTEXITCODE."
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
    ConvertTo-SlideImages -PdfPath $pdfOutput -OutputDir $ImageOutputDir -Dpi $Resolution

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
    .PARAMETER PdfPath
        Path to the PDF file to convert.
    .PARAMETER OutputDir
        Directory where JPG files will be saved.
    .PARAMETER Dpi
        Resolution in DPI for the rendered images.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PdfPath,

        [Parameter(Mandatory = $true)]
        [string]$OutputDir,

        [Parameter()]
        [int]$Dpi = 150
    )

    $pdftoppm = Get-Command 'pdftoppm' -ErrorAction SilentlyContinue
    if ($pdftoppm) {
        Write-Host "Converting PDF to JPG via pdftoppm (${Dpi} DPI)"
        $prefix = Join-Path $OutputDir 'slide'
        & pdftoppm -jpeg -r $Dpi $PdfPath $prefix
        if ($LASTEXITCODE -ne 0) {
            throw "pdftoppm failed with exit code $LASTEXITCODE."
        }

        # Rename pdftoppm output (slide-1.jpg → slide-001.jpg) for consistency
        Get-ChildItem -Path $OutputDir -Filter 'slide-*.jpg' | ForEach-Object {
            if ($_.Name -match '^slide-(\d+)\.jpg$') {
                $num = [int]$Matches[1]
                $newName = 'slide-{0:D3}.jpg' -f $num
                if ($_.Name -ne $newName) {
                    Rename-Item -Path $_.FullName -NewName $newName
                }
            }
        }
    }
    else {
        Write-Host 'pdftoppm not found, falling back to PyMuPDF'
        $python = Get-VenvPythonPath
        $renderScript = Join-Path $ScriptDir 'render_pdf_images.py'

        & $python $renderScript --input $PdfPath --output-dir $OutputDir --dpi $Dpi
        if ($LASTEXITCODE -ne 0) {
            throw "render_pdf_images.py failed with exit code $LASTEXITCODE."
        }
    }

    $imageCount = (Get-ChildItem -Path $OutputDir -Filter 'slide-*.jpg').Count
    Write-Host "Exported $imageCount slide image(s) to $OutputDir"
}

#endregion

#region Main

$pythonCmd = Test-PythonAvailability

if (-not $SkipVenvSetup) {
    Initialize-PythonVenv -PythonCmd $pythonCmd
}

switch ($Action) {
    'Build' {
        Assert-BuildParameters
        Invoke-BuildDeck
    }
    'Extract' {
        Assert-ExtractParameters
        Invoke-ExtractContent
    }
    'Validate' {
        Assert-ValidateParameters
        Invoke-ValidateDeck
    }
    'Export' {
        Assert-ExportParameters
        Invoke-ExportSlides
    }
}

#endregion
