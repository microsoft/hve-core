---
name: powerpoint
description: 'PowerPoint slide deck generation and management using python-pptx with YAML-driven content and styling - Brought to you by microsoft/hve-core'
---

# PowerPoint Skill

Generates, updates, and manages PowerPoint slide decks using `python-pptx` with YAML-driven content and styling definitions.

## Overview

This skill provides Python scripts that consume YAML configuration files to produce PowerPoint slide decks. Each slide is defined by a `content.yaml` file describing its layout, text, and shapes. A global `style.yaml` file defines colors, typography, and shared styling. Per-slide content files can override global styles.

## Prerequisites

### PowerShell (Recommended)

The `Invoke-PptxPipeline.ps1` script handles virtual environment creation and dependency installation automatically. Requires Python 3 and PowerShell 7+.

### Python Dependencies (Manual)

```bash
pip install python-pptx pyyaml cairosvg Pillow pymupdf
```

### System Dependencies (Export)

The Export action requires LibreOffice for PPTX-to-PDF conversion and optionally `pdftoppm` from poppler for PDF-to-JPG rendering. When `pdftoppm` is not available, PyMuPDF handles the image rendering.

```bash
# macOS
brew install --cask libreoffice
brew install poppler        # optional, provides pdftoppm

# Linux
sudo apt-get install libreoffice poppler-utils

# Windows (winget preferred, choco fallback)
winget install TheDocumentFoundation.LibreOffice
# choco install libreoffice-still      # alternative
# poppler: no winget package; use choco install poppler (optional, provides pdftoppm)
```

### Required Files

* `style.yaml` — Global styling configuration (colors, fonts, dimensions)
* `content.yaml` — Per-slide content definition (text, shapes, images, layout)
* (Optional) `content-extra.py` — Custom Python for complex slide drawings

## Content Directory Structure

All slide content lives under the working directory's `content/` folder:

```text
content/
├── global/
│   ├── style.yaml              # Global styling for all slides
│   └── voice-guide.md          # Voice and tone guidelines
├── slide-001/
│   ├── content.yaml            # Slide 1 content and layout
│   └── images/                 # Slide-specific images
│       ├── background.png
│       └── background.yaml     # Image metadata sidecar
├── slide-002/
│   ├── content.yaml            # Slide 2 content and layout
│   ├── content-extra.py        # Custom Python for complex drawings
│   └── images/
│       └── screenshot.png
├── slide-003/
│   ├── content.yaml
│   └── images/
│       ├── diagram.png
│       └── diagram.yaml
└── ...
```

## Global Style Definition (`style.yaml`)

The global `style.yaml` defines shared styling applied to all slides unless overridden per-slide. Color references using `$color_name` resolve against the `colors` map.

See the [style.yaml template](style-yaml-template.md) for the full template, field reference, and usage instructions.

## Per-Slide Content Definition (`content.yaml`)

Each slide's `content.yaml` defines layout, text, shapes, and optional style overrides. All position and size values are in inches. Color values use `$color_name` references or direct hex (`#RRGGBB`).

See the [content.yaml template](content-yaml-template.md) for the full template, supported element types, supported shape types, and usage instructions.

## Complex Drawings (`content-extra.py`)

When a slide requires complex drawings that cannot be expressed through `content.yaml` element definitions, create a `content-extra.py` file in the slide folder. The `render()` function signature is fixed. The build script calls it after placing standard `content.yaml` elements.

See the [content-extra.py template](content-extra-py-template.md) for the full template, function parameters, and usage guidelines.

## Script Reference

All operations are available through the PowerShell orchestrator (`Invoke-PptxPipeline.ps1`) or directly via the Python scripts. The PowerShell script manages the Python virtual environment and dependency installation automatically.

### Build a Slide Deck

```powershell
./scripts/Invoke-PptxPipeline.ps1 -Action Build `
  -ContentDir content/ `
  -StylePath content/global/style.yaml `
  -OutputPath slide-deck/presentation.pptx
```

```bash
python scripts/build_deck.py \
  --content-dir content/ \
  --style content/global/style.yaml \
  --output slide-deck/presentation.pptx
```

Reads all `content/slide-*/content.yaml` files in numeric order and generates the complete deck. Executes `content-extra.py` files when present.

### Update Specific Slides

```powershell
./scripts/Invoke-PptxPipeline.ps1 -Action Build `
  -ContentDir content/ `
  -StylePath content/global/style.yaml `
  -OutputPath slide-deck/presentation.pptx `
  -SourcePath slide-deck/presentation.pptx `
  -Slides "3,7,15"
```

```bash
python scripts/build_deck.py \
  --content-dir content/ \
  --style content/global/style.yaml \
  --source slide-deck/presentation.pptx \
  --output slide-deck/presentation.pptx \
  --slides 3,7,15
```

Opens the existing deck, regenerates only the specified slides from their `content.yaml`, and saves.

### Extract Content from Existing PPTX

```powershell
./scripts/Invoke-PptxPipeline.ps1 -Action Extract `
  -InputPath existing-deck.pptx `
  -OutputDir content/
```

```bash
python scripts/extract_content.py \
  --input existing-deck.pptx \
  --output-dir content/
```

Extracts text, shapes, images, and styling from an existing PPTX into the `content/` folder structure. Creates `content.yaml` files for each slide and populates the `global/style.yaml` from detected patterns.

### Validate a Deck

```powershell
./scripts/Invoke-PptxPipeline.ps1 -Action Validate `
  -InputPath slide-deck/presentation.pptx `
  -ContentDir content/
```

```bash
python scripts/validate_deck.py \
  --input slide-deck/presentation.pptx \
  --content-dir content/
```

Validates the generated deck against the content definitions. Checks for text overlay, width overflow, missing speaker notes, color readability, and element bounds.

### Export Slides to Images

```powershell
./scripts/Invoke-PptxPipeline.ps1 -Action Export `
  -InputPath slide-deck/presentation.pptx `
  -ImageOutputDir slide-deck/validation/ `
  -Slides "1,3,5" `
  -Resolution 150
```

```bash
# Step 1: PPTX to PDF
python scripts/export_slides.py \
  --input slide-deck/presentation.pptx \
  --output slide-deck/validation/slides.pdf \
  --slides 1,3,5

# Step 2: PDF to JPG (pdftoppm from poppler)
pdftoppm -jpeg -r 150 slide-deck/validation/slides.pdf slide-deck/validation/slide
```

Converts specified slides to JPG images for visual inspection. The PowerShell orchestrator handles both steps automatically and uses a PyMuPDF fallback when `pdftoppm` is not installed.

**Dependencies**: Requires LibreOffice for PPTX-to-PDF conversion and either `pdftoppm` (from `poppler`) or `pymupdf` (pip) for PDF-to-JPG rendering.

## python-pptx Constraints

* python-pptx does NOT support SVG images. Always convert to PNG via `cairosvg` or `Pillow`.
* python-pptx cannot create new slide masters or layouts programmatically. Use blank layouts or start from a template PPTX.
* Transitions and animations are preserved when opening and saving existing files, but cannot be created or modified via the API.
* Accessing `background.fill` on slides with inherited backgrounds replaces them with `NoFill`. Check `slide.follow_master_background` before accessing the fill property.

## Validation Rules

* Text overlay: `bottom = top + height`; verify `bottom + 0.2 < next_element_top`.
* Width overflow: `left + width <= 13.333` for every element.
* Color readability: when using accent colors as fills, darken to ~60% saturation for white text.
* Speaker notes: required on all content slides.
* Image format: SVG files cause runtime errors; always use PNG.
* Font consistency: verify no mismatched or fallback fonts.

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| SVG runtime error | python-pptx cannot embed SVG | Convert to PNG via `cairosvg` before adding |
| Text overlay between elements | Insufficient vertical spacing | Verify `bottom + 0.2 < next_element_top` for all adjacent elements |
| Width overflow off-slide | Element extends beyond slide boundary | Ensure `left + width <= 13.333` for widescreen 16:9 |
| Bright accent color unreadable as fill | White text on bright background | Darken accent to ~60% saturation for box fills |
| Background fill replaced with NoFill | Accessed `background.fill` on inherited background | Check `slide.follow_master_background` before accessing |
| Missing speaker notes | Notes not specified in `content.yaml` | Add `speaker_notes` field to every content slide |

> Brought to you by microsoft/hve-core
