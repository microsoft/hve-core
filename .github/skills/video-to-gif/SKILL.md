---
name: video-to-gif
description: 'Video-to-GIF conversion skill with FFmpeg two-pass optimization - Brought to you by microsoft/hve-core'
maturity: stable
---

# Video-to-GIF Conversion Skill

This skill converts video files to optimized GIF animations using FFmpeg two-pass palette optimization.

## Overview

The two-pass conversion process generates superior quality GIFs compared to single-pass approaches. Pass one analyzes the video and creates an optimized color palette. Pass two applies that palette to produce the final GIF with better color fidelity and smaller file sizes.

## Response Format

After successful conversion, include a file link to the GIF in the response with the absolute file path:

```markdown
/absolute/path/to/filename.gif
```

This allows the user to open the file and review it.

## Prerequisites

FFmpeg is required and must be available in your system PATH.

### macOS

```bash
brew install ffmpeg
```

### Linux (Debian/Ubuntu)

```bash
sudo apt update && sudo apt install ffmpeg
```

### Windows

Using Chocolatey:

```powershell
choco install ffmpeg
```

Using winget:

```powershell
winget install FFmpeg.FFmpeg
```

Verify installation:

```bash
ffmpeg -version
```

## Quick Start

Convert a video using default settings (10 FPS, 1280px width, sierra2_4a dithering):

```bash
./.github/skills/video-to-gif/scripts/convert.sh input.mp4
```

```powershell
./.github/skills/video-to-gif/scripts/convert.ps1 -InputPath input.mp4
```

Output saves to `input.gif` by default.

### File Search Behavior

When a filename is provided without a full path, the script searches in this order:

1. Current working directory
2. Workspace root (if inside a project)
3. `~/Movies/` (macOS) or `~/Videos/` (Linux)
4. `~/Downloads/`
5. `~/Desktop/`

This allows natural commands like `convert.sh demo.mov` without specifying full paths.

### HDR Handling

The script automatically detects HDR video content via ffprobe by checking for BT.2020 color primaries or SMPTE 2084 transfer characteristics. When HDR is detected, tonemapping is applied automatically to produce SDR-compatible GIF output with proper color preservation.

Use `--tonemap` to select the tonemapping algorithm:

| Algorithm | Characteristics                              |
| --------- | -------------------------------------------- |
| hable     | Filmic curve, good highlight rolloff (default) |
| reinhard  | Preserves more color saturation              |
| mobius    | Similar to reinhard with better highlights   |
| bt2390    | ITU standard, more conservative              |

## Parameters Reference

| Parameter        | Flag (bash)     | Flag (PowerShell) | Default      | Description                            |
| ---------------- | --------------- | ----------------- | ------------ | -------------------------------------- |
| Input file       | `--input`       | `-InputPath`      | (required)   | Source video file path                 |
| Output file      | `--output`      | `-OutputPath`     | `input.gif`  | Destination GIF file path              |
| Frame rate       | `--fps`         | `-Fps`            | 10           | Frames per second                      |
| Width            | `--width`       | `-Width`          | 1280         | Output width in pixels                 |
| Dithering        | `--dither`      | `-Dither`         | sierra2_4a   | Dithering algorithm                    |
| Tonemapping      | `--tonemap`     | `-Tonemap`        | hable        | HDR tonemapping algorithm              |
| Skip palette     | `--skip-palette`| `-SkipPalette`    | false        | Use single-pass mode                   |
| Start time       | `--start`       | `-Start`          | 0            | Start time in seconds                  |
| Duration         | `--duration`    | `-Duration`       | (full video) | Duration to convert in seconds         |
| Loop count       | `--loop`        | `-Loop`           | 0            | GIF loop count (0 = infinite)          |

### Frame Rate (FPS)

FPS controls animation smoothness and file size. Lower values reduce file size but create choppier motion.

| FPS | Use Case                 |
| --- | ------------------------ |
| 5   | Simple animations, icons |
| 10  | General use (default)    |
| 15  | Smooth motion, UI demos  |
| 24  | Near-video quality       |

### Width

Width sets the output horizontal resolution in pixels. Height scales proportionally to maintain aspect ratio.

| Width | Use Case                  |
| ----- | ------------------------- |
| 320   | Thumbnails, previews      |
| 640   | Documentation             |
| 800   | Presentations             |
| 1280  | High detail (default)     |

### Dithering Algorithms

Dithering determines how the 256-color GIF palette approximates the original colors.

| Algorithm       | Quality | Speed   | Best For                       |
| --------------- | ------- | ------- | ------------------------------ |
| sierra2_4a      | High    | Medium  | General use (default)          |
| floyd_steinberg | High    | Slow    | Photographic content           |
| bayer           | Medium  | Fast    | Graphics with solid colors     |
| none            | Low     | Fastest | Stylized/posterized look       |

### Time Range Selection

Use `--start` and `--duration` to convert a specific portion of the video:

```bash
# Start at 5 seconds, convert 10 seconds
./convert.sh --input video.mp4 --start 5 --duration 10
```

### Loop Control

Use `--loop` to control GIF repeat behavior:

| Value | Behavior           |
| ----- | ------------------ |
| 0     | Loop forever       |
| 1     | Play once          |
| N     | Play N times       |

## Two-Pass vs Single-Pass

### Two-Pass (Default)

Two-pass conversion creates a custom palette from the source video, then applies it:

```bash
# Pass 1: Generate palette
ffmpeg -i input.mp4 \
  -vf "fps=10,scale=1280:-1:flags=lanczos,palettegen=stats_mode=diff" \
  -y /tmp/palette.png

# Pass 2: Create GIF
ffmpeg -i input.mp4 -i /tmp/palette.png \
  -filter_complex "fps=10,scale=1280:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=sierra2_4a:diff_mode=rectangle" \
  -loop 0 -y output.gif
```

Two-pass produces better color accuracy and typically smaller files.

### Single-Pass

Single-pass skips palette generation and uses FFmpeg's default 256-color palette:

```bash
ffmpeg -i input.mp4 \
  -vf "fps=10,scale=1280:-1:flags=lanczos" \
  -loop 0 -y output.gif
```

Single-pass processes faster but produces lower quality output with potential color banding.

Use single-pass via `--skip-palette` (bash) or `-SkipPalette` (PowerShell).

## Script Reference

### convert.sh (Bash)

```bash
# Basic usage
./convert.sh video.mp4

# Custom output path
./convert.sh --input video.mp4 --output demo.gif

# Adjust quality parameters
./convert.sh --input video.mp4 --fps 15 --width 640 --dither floyd_steinberg

# HDR video with custom tonemapping
./convert.sh --input hdr-video.mov --tonemap reinhard

# Extract a 10-second clip starting at 5 seconds
./convert.sh --input video.mp4 --start 5 --duration 10

# Create a GIF that plays only once
./convert.sh --input video.mp4 --loop 1

# Fast single-pass mode
./convert.sh --input video.mp4 --skip-palette
```

### convert.ps1 (PowerShell)

```powershell
# Basic usage
./convert.ps1 -InputPath video.mp4

# Custom output path
./convert.ps1 -InputPath video.mp4 -OutputPath demo.gif

# Adjust quality parameters
./convert.ps1 -InputPath video.mp4 -Fps 15 -Width 640 -Dither floyd_steinberg

# HDR video with custom tonemapping
./convert.ps1 -InputPath hdr-video.mov -Tonemap reinhard

# Extract a 10-second clip starting at 5 seconds
./convert.ps1 -InputPath video.mp4 -Start 5 -Duration 10

# Create a GIF that plays only once
./convert.ps1 -InputPath video.mp4 -Loop 1

# Fast single-pass mode
./convert.ps1 -InputPath video.mp4 -SkipPalette
```

## Examples

### HDR Video Conversion

HDR content is detected automatically. No special flags are needed:

```bash
./convert.sh hdr-footage.mov
```

The script applies hable tonemapping by default. Use `--tonemap` to try different algorithms:

```bash
# Use reinhard for more saturated colors
./convert.sh --input hdr-footage.mov --tonemap reinhard
```

### Time Range Extraction

Extract a specific segment from a longer video:

```bash
# Convert seconds 30-45 of a screencast
./convert.sh --input screencast.mp4 --start 30 --duration 15 --fps 15
```

### Documentation Thumbnails

Create compact thumbnails for documentation:

```bash
./convert.sh --input demo.mp4 --width 320 --fps 8
```

## Troubleshooting

### FFmpeg not found

Verify FFmpeg is in your PATH:

```bash
which ffmpeg  # macOS/Linux
where.exe ffmpeg  # Windows
```

If FFmpeg is installed but not found, add its directory to your PATH environment variable.

### File not found

Ensure the file exists at the specified path. If providing only a filename, the script searches the workspace first, then common directories (`~/Movies/`, `~/Downloads/`, `~/Desktop/`). Use an absolute path if the file is in a different location.

### Output file is too large

Reduce file size with these adjustments:

* Lower FPS (try 8 or 5)
* Reduce width (try 640 or 320)
* Use `bayer` dithering for faster processing
* Use `--duration` to convert only a portion of the video

### Colors appear washed out

Switch to `floyd_steinberg` dithering for photographic content. Avoid `none` dithering unless a stylized look is intended.

### HDR content looks wrong

Ensure FFmpeg 4.0+ is installed with zscale filter support. The script requires libzimg for HDR tonemapping. Install via:

```bash
# macOS
brew install zimg
brew reinstall ffmpeg

# Ubuntu
sudo apt install libzimg-dev
```

If colors still appear off, try a different tonemapping algorithm with `--tonemap`. The `reinhard` algorithm preserves more saturation, while `bt2390` provides more conservative results.

### Conversion fails with filter error

Ensure FFmpeg version 4.0 or later is installed. The `palettegen` and `paletteuse` filters require this version.

```bash
ffmpeg -version
```

### Temporary palette file remains

The scripts clean up `/tmp/palette.png` (or `$env:TEMP\palette.png` on Windows) automatically. If conversion fails mid-process, remove this file manually.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
