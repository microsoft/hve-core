---
name: image-optimize
description: 'Image optimization skill for web and documentation assets - Brought to you by microsoft/hve-core'
maturity: stable
---

# Image Optimize Skill

This skill optimizes images for web and documentation use, reducing file sizes while maintaining visual quality. Supports compression, format conversion, and batch processing.

## Overview

Image optimization reduces file sizes for faster page loads and smaller repository sizes. This skill uses ImageMagick or sharp (Node.js) to compress images, convert formats, and batch process directories.

## Response Format

After successful optimization, include a summary of the results:

```markdown
Optimized 5 images:
- image1.png: 1.2MB → 450KB (62% reduction)
- image2.jpg: 800KB → 320KB (60% reduction)
...

Output directory: /absolute/path/to/output/
```

## Prerequisites

ImageMagick is required for the bash script. The PowerShell script can use either ImageMagick or sharp.

### macOS

```bash
brew install imagemagick
```

### Linux (Debian/Ubuntu)

```bash
sudo apt update && sudo apt install imagemagick
```

### Windows

Using Chocolatey:

```powershell
choco install imagemagick
```

Using winget:

```powershell
winget install ImageMagick.ImageMagick
```

### Node.js Alternative (sharp)

```bash
npm install -g sharp-cli
```

Verify installation:

```bash
magick -version  # ImageMagick
# or
sharp --version  # Node.js sharp
```

## Quick Start

Optimize a single image with default settings:

```bash
./.github/skills/image-optimize/scripts/optimize.sh input.png
```

```powershell
./.github/skills/image-optimize/scripts/optimize.ps1 -InputPath input.png
```

Batch optimize a directory:

```bash
./.github/skills/image-optimize/scripts/optimize.sh --input ./images --recursive
```

## Parameters Reference

| Parameter | Flag (bash) | Flag (PowerShell) | Default | Description |
|-----------|-------------|-------------------|---------|-------------|
| Input | `--input` | `-InputPath` | (required) | Source image or directory |
| Output | `--output` | `-OutputPath` | `optimized/` | Destination path |
| Quality | `--quality` | `-Quality` | 85 | JPEG/WebP quality (1-100) |
| Format | `--format` | `-Format` | (preserve) | Output format (png, jpg, webp) |
| Width | `--width` | `-Width` | (preserve) | Maximum width in pixels |
| Height | `--height` | `-Height` | (preserve) | Maximum height in pixels |
| Recursive | `--recursive` | `-Recursive` | false | Process subdirectories |
| Strip | `--strip` | `-Strip` | true | Remove metadata (EXIF, etc.) |

### Quality Settings

Quality affects file size and visual fidelity for lossy formats (JPEG, WebP).

| Quality | Use Case | Typical Reduction |
|---------|----------|-------------------|
| 95 | High-quality photography | 20-40% |
| 85 | General use (default) | 40-60% |
| 75 | Web thumbnails | 60-75% |
| 60 | Maximum compression | 75-85% |

### Format Conversion

| Format | Best For | Notes |
|--------|----------|-------|
| PNG | Screenshots, graphics with transparency | Lossless, larger files |
| JPEG | Photographs, complex images | Lossy, smallest for photos |
| WebP | Modern web delivery | Best compression, wide support |

## Usage Examples

### Compress PNG Screenshots

```bash
# Optimize PNGs for documentation
./optimize.sh --input screenshot.png --quality 90

# Convert to WebP for smaller size
./optimize.sh --input screenshot.png --format webp --quality 85
```

### Batch Process Documentation Images

```bash
# Optimize all images in docs/images/
./optimize.sh --input ./docs/images --recursive --quality 80

# Convert all to WebP
./optimize.sh --input ./docs/images --recursive --format webp
```

### Resize for Thumbnails

```bash
# Create 320px wide thumbnails
./optimize.sh --input ./images --width 320 --output ./thumbnails

# Resize maintaining aspect ratio
./optimize.sh --input large-image.jpg --width 800 --height 600
```

### Strip Metadata for Privacy

```bash
# Remove EXIF data (location, camera info)
./optimize.sh --input photo.jpg --strip
```

## PowerShell Examples

```powershell
# Basic optimization
./optimize.ps1 -InputPath screenshot.png

# Batch with format conversion
./optimize.ps1 -InputPath ./docs/images -Recursive -Format webp -Quality 80

# Resize and compress
./optimize.ps1 -InputPath large-photo.jpg -Width 1200 -Quality 85 -OutputPath optimized.jpg
```

## Output Structure

When processing directories, the output mirrors the input structure:

```text
Input:                      Output:
docs/images/                optimized/docs/images/
├── screenshot1.png         ├── screenshot1.png
├── screenshot2.png         ├── screenshot2.png
└── diagrams/               └── diagrams/
    └── arch.png                └── arch.png
```

## Optimization Strategies

### Documentation Images

```bash
# Screenshots: PNG with compression
./optimize.sh --input ./docs --recursive --quality 90

# Diagrams: Keep PNG for crisp lines
./optimize.sh --input ./diagrams --format png --quality 95
```

### Web Assets

```bash
# Convert to WebP for modern browsers
./optimize.sh --input ./assets --recursive --format webp --quality 80

# Create multiple sizes for responsive images
./optimize.sh --input hero.jpg --width 1920 --output hero-large.webp --format webp
./optimize.sh --input hero.jpg --width 960 --output hero-medium.webp --format webp
./optimize.sh --input hero.jpg --width 480 --output hero-small.webp --format webp
```

### Repository Size Reduction

```bash
# Aggressive compression for repo size
./optimize.sh --input . --recursive --quality 75 --strip
```

## Troubleshooting

### ImageMagick not found

Verify ImageMagick is in your PATH:

```bash
which magick  # macOS/Linux
where.exe magick  # Windows
```

### Permission denied on output

Ensure the output directory exists and is writable:

```bash
mkdir -p ./optimized
chmod 755 ./optimized
```

### Quality too low

If images appear degraded, increase the quality value:

```bash
./optimize.sh --input image.jpg --quality 90
```

### WebP not supported

Ensure ImageMagick was compiled with WebP support:

```bash
magick -list format | grep -i webp
```

If missing, reinstall ImageMagick with WebP:

```bash
# macOS
brew reinstall imagemagick

# Ubuntu
sudo apt install libwebp-dev
sudo apt reinstall imagemagick
```

### Large files not shrinking

Some images are already optimized. Try:

1. Converting to a different format (PNG → WebP)
2. Reducing dimensions with `--width`
3. Lowering quality for acceptable visual loss

## Integration with CI/CD

Add image optimization to your workflow:

```yaml
- name: Optimize documentation images
  run: |
    ./.github/skills/image-optimize/scripts/optimize.sh \
      --input ./docs/images \
      --recursive \
      --quality 85
```

## References

- [ImageMagick Documentation](https://imagemagick.org/script/command-line-processing.php)
- [WebP Compression Study](https://developers.google.com/speed/webp/docs/compression)
- [sharp Documentation](https://sharp.pixelplumbing.com/)

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
