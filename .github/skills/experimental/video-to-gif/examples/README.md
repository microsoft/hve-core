---
title: Video-to-GIF Examples
description: Usage examples and test data generation for video-to-gif skill
author: Microsoft
ms.date: 2026-01-18
ms.topic: reference
keywords:
  - video
  - gif
  - ffmpeg
  - examples
estimated_reading_time: 3
---

## Quick Usage Examples

### Basic Conversion

```bash
# Convert with defaults (10 FPS, 480px, sierra2_4a dithering)
../convert.sh video.mp4

# Specify output filename
../convert.sh --input video.mp4 --output demo.gif
```

```powershell
# Convert with defaults
../convert.ps1 -InputPath video.mp4

# Specify output filename
../convert.ps1 -InputPath video.mp4 -OutputPath demo.gif
```

### High Quality Demo

```bash
../convert.sh --input presentation.mp4 --fps 15 --width 800 --dither floyd_steinberg
```

```powershell
../convert.ps1 -InputPath presentation.mp4 -Fps 15 -Width 800 -Dither floyd_steinberg
```

### Small File Size

```bash
../convert.sh --input video.mp4 --fps 5 --width 320 --dither bayer
```

```powershell
../convert.ps1 -InputPath video.mp4 -Fps 5 -Width 320 -Dither bayer
```

## Test Video Generation

Create a test video using FFmpeg's test source filter. This generates a 5-second video with color bars and a timer.

```bash
ffmpeg -f lavfi -i "testsrc=duration=5:size=640x480:rate=30" \
  -c:v libx264 -pix_fmt yuv420p test-video.mp4
```

Alternative test patterns:

```bash
# Color bars with audio
ffmpeg -f lavfi -i "smptebars=duration=5:size=640x480:rate=30" \
  -f lavfi -i "sine=frequency=1000:duration=5" \
  -c:v libx264 -c:a aac -pix_fmt yuv420p test-bars.mp4

# Mandelbrot fractal zoom
ffmpeg -f lavfi -i "mandelbrot=size=640x480:rate=30" \
  -t 5 -c:v libx264 -pix_fmt yuv420p test-fractal.mp4

# Random noise
ffmpeg -f lavfi -i "nullsrc=size=640x480:rate=30,geq=random(1)*255:128:128" \
  -t 3 -c:v libx264 -pix_fmt yuv420p test-noise.mp4
```

## Quality Comparison

Compare dithering algorithms by converting the same source with different settings:

```bash
# Generate all variants
for dither in sierra2_4a floyd_steinberg bayer none; do
  ../convert.sh --input test-video.mp4 --output "test-${dither}.gif" --dither "${dither}"
done
```

```powershell
# Generate all variants
@('sierra2_4a', 'floyd_steinberg', 'bayer', 'none') | ForEach-Object {
    ../convert.ps1 -InputPath test-video.mp4 -OutputPath "test-$_.gif" -Dither $_
}
```

Expected results:

| Algorithm       | File Size | Visual Quality | Processing Time |
| --------------- | --------- | -------------- | --------------- |
| sierra2_4a      | Medium    | High           | Medium          |
| floyd_steinberg | Medium    | Highest        | Slow            |
| bayer           | Smaller   | Medium         | Fast            |
| none            | Smallest  | Low            | Fastest         |

## File Size Optimization

Strategies for reducing GIF file size:

### Reduce Frame Rate

Lower frame rates significantly reduce file size. For simple animations, 5-8 FPS is often sufficient.

```bash
../convert.sh --input video.mp4 --fps 5
```

### Reduce Dimensions

Smaller dimensions dramatically reduce file size. 320px width works well for thumbnails.

```bash
../convert.sh --input video.mp4 --width 320
```

### Trim Source Duration

Shorter videos produce smaller GIFs. Trim before conversion:

```bash
# Extract 3 seconds starting at 00:05
ffmpeg -i video.mp4 -ss 00:00:05 -t 3 -c copy trimmed.mp4
../convert.sh trimmed.mp4
```

### Combine Optimizations

Stack multiple optimizations for maximum compression:

```bash
../convert.sh --input video.mp4 --fps 8 --width 320 --dither bayer
```

## Batch Conversion

Convert multiple videos in a directory:

```bash
for video in *.mp4; do
  ../convert.sh --input "${video}"
done
```

```powershell
Get-ChildItem -Filter "*.mp4" | ForEach-Object {
    ../convert.ps1 -InputPath $_.FullName
}
```

Convert with consistent settings:

```bash
for video in *.mp4; do
  ../convert.sh --input "${video}" --fps 12 --width 640 --dither sierra2_4a
done
```

```powershell
Get-ChildItem -Filter "*.mp4" | ForEach-Object {
    ../convert.ps1 -InputPath $_.FullName -Fps 12 -Width 640 -Dither sierra2_4a
}
```

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
