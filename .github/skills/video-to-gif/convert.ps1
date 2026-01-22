<#
.SYNOPSIS
    Convert video files to optimized GIF animations using FFmpeg.

.DESCRIPTION
    This script converts video files to GIF animations using FFmpeg two-pass
    palette optimization. The two-pass approach generates a custom color palette
    from the source video, producing better color accuracy and smaller file sizes
    compared to single-pass conversion.

    Features HDR auto-detection with Hable tonemapping and workspace-first file search.

.PARAMETER InputPath
    Path to the input video file. Searches workspace, ~/Movies, ~/Downloads, ~/Desktop if not found.

.PARAMETER OutputPath
    Path for the output GIF file. Defaults to the input filename with .gif extension.

.PARAMETER Fps
    Frame rate for the output GIF. Valid range: 1-30. Default: 10.

.PARAMETER Width
    Output width in pixels. Height scales proportionally. Valid range: 100-3840. Default: 1280.

.PARAMETER Dither
    Dithering algorithm for color approximation.
    Options: sierra2_4a (default), floyd_steinberg, bayer, none.

.PARAMETER Loop
    GIF loop count. 0 means infinite loop. Default: 0.

.PARAMETER Start
    Start time in seconds for time range extraction.

.PARAMETER Duration
    Duration in seconds for time range extraction.

.PARAMETER SkipPalette
    Use single-pass mode instead of two-pass palette optimization.
    Faster processing but lower quality output.

.EXAMPLE
    ./convert.ps1 -InputPath video.mp4
    Converts video.mp4 to video.gif using default settings.

.EXAMPLE
    ./convert.ps1 -InputPath video.mp4 -OutputPath demo.gif -Fps 15 -Width 640
    Converts with custom frame rate and width.

.EXAMPLE
    ./convert.ps1 -InputPath video.mp4 -Start 5 -Duration 10
    Converts a 10-second clip starting at 5 seconds.

.EXAMPLE
    ./convert.ps1 -InputPath video.mp4 -Dither floyd_steinberg
    Converts using Floyd-Steinberg dithering for photographic content.

.EXAMPLE
    ./convert.ps1 -InputPath video.mp4 -SkipPalette
    Converts using faster single-pass mode.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 30)]
    [int]$Fps = 10,

    [Parameter(Mandatory = $false)]
    [ValidateRange(100, 3840)]
    [int]$Width = 1280,

    [Parameter(Mandatory = $false)]
    [ValidateSet('sierra2_4a', 'floyd_steinberg', 'bayer', 'none')]
    [string]$Dither = 'sierra2_4a',

    [Parameter(Mandatory = $false)]
    [ValidateSet('hable', 'reinhard', 'mobius', 'bt2390')]
    [string]$Tonemap = 'hable',

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, [int]::MaxValue)]
    [int]$Loop = 0,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, [double]::MaxValue)]
    [double]$Start,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0.1, [double]::MaxValue)]
    [double]$Duration,

    [Parameter(Mandatory = $false)]
    [switch]$SkipPalette
)

function Test-FFmpegAvailable {
    $ffmpegPath = Get-Command -Name 'ffmpeg' -ErrorAction SilentlyContinue
    if (-not $ffmpegPath) {
        Write-Error "FFmpeg is required but not installed."
        Write-Host ""
        Write-Host "Install FFmpeg:" -ForegroundColor Yellow
        Write-Host "  Chocolatey: choco install ffmpeg"
        Write-Host "  winget:     winget install FFmpeg.FFmpeg"
        Write-Host "  Manual:     https://ffmpeg.org/download.html"
        return $false
    }
    return $true
}

function Find-VideoFile {
    <#
    .SYNOPSIS
        Search for a video file in workspace and common directories.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Filename
    )

    # If absolute path or file exists at given path, return as-is
    if (Test-Path -Path $Filename -PathType Leaf) {
        return (Resolve-Path -Path $Filename).Path
    }

    # Build search locations in priority order
    $searchDirs = @(
        $PWD.Path
    )

    # Add git repository root if available
    try {
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $gitRoot) {
            $searchDirs += $gitRoot
        }
    }
    catch {
        Write-Verbose "Git not available or not in a repository: $_"
    }

    # Add common video directories
    if ($IsMacOS) {
        $searchDirs += @(
            (Join-Path -Path $HOME -ChildPath 'Movies')
            (Join-Path -Path $HOME -ChildPath 'Downloads')
            (Join-Path -Path $HOME -ChildPath 'Desktop')
        )
    }
    elseif ($IsWindows) {
        $searchDirs += @(
            (Join-Path -Path $HOME -ChildPath 'Videos')
            (Join-Path -Path $HOME -ChildPath 'Downloads')
            (Join-Path -Path $HOME -ChildPath 'Desktop')
        )
    }
    else {
        # Linux
        $searchDirs += @(
            (Join-Path -Path $HOME -ChildPath 'Videos')
            (Join-Path -Path $HOME -ChildPath 'Downloads')
            (Join-Path -Path $HOME -ChildPath 'Desktop')
        )
    }

    foreach ($dir in $searchDirs) {
        $candidatePath = Join-Path -Path $dir -ChildPath $Filename
        if (Test-Path -Path $candidatePath -PathType Leaf) {
            return $candidatePath
        }
    }

    # File not found
    return $null
}

function Test-HDRContent {
    <#
    .SYNOPSIS
        Detect if video contains HDR content using ffprobe.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $ffprobePath = Get-Command -Name 'ffprobe' -ErrorAction SilentlyContinue
    if (-not $ffprobePath) {
        return $false
    }

    try {
        $colorInfo = & ffprobe -v error -select_streams v:0 `
            -show_entries stream=color_primaries,color_transfer `
            -of csv=p=0 $FilePath 2>$null

        # Check for HDR indicators: bt2020 primaries or smpte2084 transfer
        if ($colorInfo -match 'bt2020|smpte2084') {
            return $true
        }
    }
    catch {
        Write-Verbose "ffprobe failed, assuming SDR content: $_"
    }

    return $false
}

function Format-FileSize {
    param([long]$Bytes)

    if ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    }
    elseif ($Bytes -ge 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    }
    else {
        return "$Bytes bytes"
    }
}

function Invoke-SinglePassConversion {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [int]$LoopCount,
        [string]$BaseFilter,
        [double[]]$TimeArgs
    )

    Write-Verbose "Running single-pass conversion..."

    $arguments = @()

    # Add time range arguments before input
    if ($TimeArgs -and $TimeArgs.Count -gt 0) {
        if ($PSBoundParameters.ContainsKey('Start') -or $TimeArgs[0] -ge 0) {
            $arguments += @('-ss', $TimeArgs[0])
        }
        if ($TimeArgs.Count -gt 1 -and $TimeArgs[1] -gt 0) {
            $arguments += @('-t', $TimeArgs[1])
        }
    }

    $arguments += @(
        '-i', $SourcePath
        '-vf', $BaseFilter
        '-loop', $LoopCount
        '-y', $DestinationPath
    )

    & ffmpeg @arguments
    return $LASTEXITCODE -eq 0
}

function Invoke-TwoPassConversion {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [string]$DitherAlgorithm,
        [int]$LoopCount,
        [string]$BaseFilter,
        [double[]]$TimeArgs
    )

    $paletteFile = Join-Path -Path $env:TEMP -ChildPath "palette_$PID.png"

    try {
        # Build time arguments array
        $timeArguments = @()
        if ($TimeArgs -and $TimeArgs.Count -gt 0) {
            if ($TimeArgs[0] -ge 0) {
                $timeArguments += @('-ss', $TimeArgs[0])
            }
            if ($TimeArgs.Count -gt 1 -and $TimeArgs[1] -gt 0) {
                $timeArguments += @('-t', $TimeArgs[1])
            }
        }

        # Pass 1: Generate palette
        Write-Host "Pass 1: Generating optimized palette..."
        $paletteFilter = "$BaseFilter,palettegen=stats_mode=diff"

        $pass1Args = $timeArguments + @(
            '-i', $SourcePath
            '-vf', $paletteFilter
            '-y', $paletteFile
        )

        & ffmpeg @pass1Args
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Palette generation failed."
            return $false
        }

        # Pass 2: Create GIF
        Write-Host "Pass 2: Creating GIF with palette..."
        $filterComplex = "${BaseFilter}[x];[x][1:v]paletteuse=dither=${DitherAlgorithm}:diff_mode=rectangle"

        $pass2Args = $timeArguments + @(
            '-i', $SourcePath
            '-i', $paletteFile
            '-filter_complex', $filterComplex
            '-loop', $LoopCount
            '-y', $DestinationPath
        )

        & ffmpeg @pass2Args
        return $LASTEXITCODE -eq 0
    }
    finally {
        # Cleanup palette file
        if (Test-Path -Path $paletteFile) {
            Remove-Item -Path $paletteFile -Force -ErrorAction SilentlyContinue
        }
    }
}

# Main execution
if (-not (Test-FFmpegAvailable)) {
    exit 1
}

# Search for input file
$resolvedInput = $null
if (Test-Path -Path $InputPath -PathType Leaf) {
    $resolvedInput = (Resolve-Path -Path $InputPath).Path
}
else {
    $resolvedInput = Find-VideoFile -Filename $InputPath
    if ($resolvedInput) {
        Write-Host "Found: $resolvedInput"
    }
    else {
        $searchLocations = @(
            "current directory"
            "workspace root"
        )
        if ($IsMacOS) {
            $searchLocations += @("~/Movies", "~/Downloads", "~/Desktop")
        }
        else {
            $searchLocations += @("~/Videos", "~/Downloads", "~/Desktop")
        }
        Write-Error "Input file not found: $InputPath`nSearched: $($searchLocations -join ', ')"
        exit 1
    }
}

# Set default output path if not specified
if ([string]::IsNullOrEmpty($OutputPath)) {
    $inputItem = Get-Item -Path $resolvedInput
    $OutputPath = Join-Path -Path $inputItem.DirectoryName -ChildPath "$($inputItem.BaseName).gif"
}

# Detect HDR content
$isHDR = Test-HDRContent -FilePath $resolvedInput

# Build base filter chain
$baseFilter = "fps=$Fps,scale=${Width}:-1:flags=lanczos"

# Add HDR tonemapping if detected
# Convert HDR to SDR using selected tonemapping algorithm, then explicitly convert to sRGB for accurate GIF colors
if ($isHDR) {
    $hdrFilter = "zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=${Tonemap}:desat=0,zscale=t=iec61966-2-1:m=bt709:r=full,format=rgb24"
    $baseFilter = "$hdrFilter,$baseFilter"
}

# Build time arguments
$timeArgs = @()
if ($PSBoundParameters.ContainsKey('Start')) {
    $timeArgs += $Start
}
else {
    $timeArgs += -1  # Sentinel value indicating no start time
}
if ($PSBoundParameters.ContainsKey('Duration')) {
    $timeArgs += $Duration
}

Write-Host "Converting: $resolvedInput"
Write-Host "Output:     $OutputPath"
Write-Host "Settings:   $Fps FPS, ${Width}px width, $Dither dithering, loop=$Loop"

if ($PSBoundParameters.ContainsKey('Start') -or $PSBoundParameters.ContainsKey('Duration')) {
    $startDisplay = if ($PSBoundParameters.ContainsKey('Start')) { "${Start}s" } else { "0s" }
    $durationDisplay = if ($PSBoundParameters.ContainsKey('Duration')) { "${Duration}s" } else { "full" }
    Write-Host "Time range: start=$startDisplay, duration=$durationDisplay"
}

if ($isHDR) {
    Write-Host "HDR:        Detected, applying $Tonemap tonemapping"
}

if ($SkipPalette) {
    Write-Host "Mode:       Single-pass (faster, lower quality)"
    Write-Host ""

    $success = Invoke-SinglePassConversion `
        -SourcePath $resolvedInput `
        -DestinationPath $OutputPath `
        -LoopCount $Loop `
        -BaseFilter $baseFilter `
        -TimeArgs $timeArgs
}
else {
    Write-Host "Mode:       Two-pass palette optimization"
    Write-Host ""

    $success = Invoke-TwoPassConversion `
        -SourcePath $resolvedInput `
        -DestinationPath $OutputPath `
        -DitherAlgorithm $Dither `
        -LoopCount $Loop `
        -BaseFilter $baseFilter `
        -TimeArgs $timeArgs
}

if ($success -and (Test-Path -Path $OutputPath)) {
    $outputFile = Get-Item -Path $OutputPath
    $formattedSize = Format-FileSize -Bytes $outputFile.Length
    Write-Host ""
    Write-Host "Conversion complete: $OutputPath ($formattedSize)" -ForegroundColor Green
}
else {
    Write-Error "Conversion failed. Output file was not created."
    exit 1
}
