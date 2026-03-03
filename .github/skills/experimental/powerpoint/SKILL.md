---
name: powerpoint
description: 'PowerPoint slide deck generation and management using python-pptx with YAML-driven content and styling - Brought to you by microsoft/hve-core'
---

# PowerPoint Skill

Generates, updates, and manages PowerPoint slide decks using `python-pptx` with YAML-driven content and styling definitions.

## Overview

This skill provides Python scripts that consume YAML configuration files to produce PowerPoint slide decks. Each slide is defined by a `content.yaml` file describing its layout, text, and shapes. A `style.yaml` file defines dimensions, template configuration, layout mappings, metadata, and defaults.

## Prerequisites

### PowerShell (Recommended)

The `Invoke-PptxPipeline.ps1` script handles virtual environment creation and dependency installation automatically. Requires Python 3 and PowerShell 7+.

### Python Dependencies (Manual)

```bash
pip install python-pptx pyyaml cairosvg Pillow pymupdf github-copilot-sdk
```

### System Dependencies (Export and Validation)

The Export and Validate actions require LibreOffice for PPTX-to-PDF conversion and optionally `pdftoppm` from poppler for PDF-to-JPG rendering. When `pdftoppm` is not available, PyMuPDF handles the image rendering.

The Validate action's vision-based checks require the GitHub Copilot CLI for model access.

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

### Copilot CLI (Vision Validation)

The `validate_slides.py` script uses the GitHub Copilot SDK to send slide images to vision-capable models. The Copilot CLI must be installed and authenticated:

```bash
# Install Copilot CLI
npm install -g @github/copilot-cli

# Authenticate (uses the same GitHub account as VS Code Copilot)
copilot auth login

# Verify
copilot --version
```

### Required Files

* `style.yaml` — Dimensions, defaults, template configuration, and metadata
* `content.yaml` — Per-slide content definition (text, shapes, images, layout)
* (Optional) `content-extra.py` — Custom Python for complex slide drawings

## Content Directory Structure

All slide content lives under the working directory's `content/` folder:

```text
content/
├── global/
│   ├── style.yaml              # Dimensions, defaults, template config, and theme metadata
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

The global `style.yaml` defines dimensions, template configuration, layout mappings, metadata, and defaults. Color and font choices are specified per-element in each slide's `content.yaml` rather than centralized in the style file.

See the [style.yaml template](style-yaml-template.md) for the full template, field reference, and usage instructions.

## Per-Slide Content Definition (`content.yaml`)

Each slide's `content.yaml` defines layout, text, shapes, and positioning. All position and size values are in inches. Color values use `#RRGGBB` hex format or `@theme_name` references.

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

### Build from a Template

```powershell
./scripts/Invoke-PptxPipeline.ps1 -Action Build `
  -ContentDir content/ `
  -StylePath content/global/style.yaml `
  -OutputPath slide-deck/presentation.pptx `
  -TemplatePath corporate-template.pptx
```

```bash
python scripts/build_deck.py \
  --content-dir content/ \
  --style content/global/style.yaml \
  --output slide-deck/presentation.pptx \
  --template corporate-template.pptx
```

Loads slide masters and layouts from the template PPTX. Layout names in each slide's `content.yaml` resolve against the template's layouts, with optional name mapping via the `layouts` section in `style.yaml`. Populate themed layout placeholders using the `placeholders` section in content YAML.

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

Opens the existing deck, clears shapes on the specified slides, rebuilds them in-place from their `content.yaml`, and saves. All other slides remain untouched.

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

#### Extract Specific Slides

```powershell
./scripts/Invoke-PptxPipeline.ps1 -Action Extract `
  -InputPath existing-deck.pptx `
  -OutputDir content/ `
  -Slides "3,7,15"
```

```bash
python scripts/extract_content.py \
  --input existing-deck.pptx \
  --output-dir content/ \
  --slides 3,7,15
```

Extracts only the specified slides (plus the global style). Useful for targeted updates on large decks.

#### Extraction Limitations

* **Linked images**: Picture shapes that reference external (linked) images instead of embedded blobs are recorded with `path: LINKED_IMAGE_NOT_EMBEDDED`. The script does not crash but the image must be re-embedded manually.
* **Inherited styling**: When text elements inherit font, size, or color from the slide master or layout, the extraction records no inline styling. Content YAML for these elements needs explicit font properties added before rebuild.
* **Style detection heuristics**: The `detect_global_style()` function uses frequency analysis across all slides. For decks with mixed styling, review and adjust `style.yaml` values manually after extraction.

### Validate a Deck

```powershell
./scripts/Invoke-PptxPipeline.ps1 -Action Validate `
  -InputPath slide-deck/presentation.pptx `
  -ContentDir content/
```

The Validate action runs a two- or three-step pipeline:

1. **Export** — Renders slides to JPG images via LibreOffice (PPTX → PDF → JPG).
2. **PPTX validation** — Checks PPTX-only properties (`validate_deck.py`) for speaker notes and slide count.
3. **Vision validation** (optional) — Sends slide images to a vision-capable model via the Copilot SDK (`validate_slides.py`) for visual quality checks. Runs when `-ValidationPrompt` or `-ValidationPromptFile` is provided.

#### Validate with Vision Checks

```powershell
./scripts/Invoke-PptxPipeline.ps1 -Action Validate `
  -InputPath slide-deck/presentation.pptx `
  -ContentDir content/ `
  -ValidationPrompt "Check for text overlay, overflow, margin issues, color contrast" `
  -ValidationModel claude-haiku-4.5
```

Vision validation results are written to `validation-results.json` in the image output directory. A Markdown report is written to `validation-report.md` alongside the JSON, providing per-slide findings, severity counts, and cache statistics.

#### Validate with Concurrency

```powershell
./scripts/Invoke-PptxPipeline.ps1 -Action Validate `
  -InputPath slide-deck/presentation.pptx `
  -ContentDir content/ `
  -ValidationPrompt "Check for text overlay, overflow, margin issues, color contrast" `
  -ValidationConcurrency 5
```

Concurrent validation processes multiple slides in parallel (default: 3). Caching is auto-enabled at `{ImageOutputDir}/cache/` — results are keyed by image hash + prompt + model and subsequent runs skip unchanged slides. Pass `--no-cache` to `validate_slides.py` (or omit `-ValidationCacheDir` and override manually) to force re-validation.

#### Validate Specific Slides

```powershell
./scripts/Invoke-PptxPipeline.ps1 -Action Validate `
  -InputPath slide-deck/presentation.pptx `
  -ContentDir content/ `
  -Slides "3,7,15"
```

Validates only the specified slides. When content directories cover fewer slides than the PPTX, the slide count check reports an informational note rather than an error.

#### validate_slides.py CLI Reference

| Flag | Required | Default | Description |
|---|---|---|---|
| `--image-dir` | Yes | — | Directory containing `slide-NNN.jpg` images |
| `--prompt` | One of `--prompt` / `--prompt-file` | — | Validation prompt text |
| `--prompt-file` | One of `--prompt` / `--prompt-file` | — | Path to file containing the validation prompt |
| `--model` | No | `claude-haiku-4.5` | Vision model ID |
| `--output` | No | stdout | JSON results file path |
| `--report` | No | — | Markdown report file path |
| `--slides` | No | all | Comma-separated slide numbers to validate |
| `--concurrency` | No | `3` | Max concurrent slide validations |
| `--cache-dir` | No | `{image-dir}/cache` | Cache directory for validation results by image hash |
| `--no-cache` | No | — | Disable caching and re-validate all slides |
| `-v`, `--verbose` | No | — | Enable debug-level logging |

#### validate_deck.py CLI Reference

| Flag | Required | Default | Description |
|---|---|---|---|
| `--input` | Yes | — | Input PPTX file path |
| `--content-dir` | No | — | Content directory for slide count comparison |
| `--slides` | No | all | Comma-separated slide numbers to validate |
| `--output` | No | stdout | JSON results file path |
| `--report` | No | — | Markdown report file path |

#### Validation Outputs

When run through the pipeline, validation produces these files in the image output directory:

| File | Format | Content |
|---|---|---|
| `deck-validation-results.json` | JSON | Per-slide PPTX property issues (speaker notes, slide count) |
| `deck-validation-report.md` | Markdown | Human-readable report for PPTX property validation |
| `validation-results.json` | JSON | Per-slide vision issues with check type, severity, description, and location |
| `validation-report.md` | Markdown | Human-readable report with severity summary, cache statistics, and per-slide findings |
| `cache/{hash}.json` | JSON | Cached per-slide results keyed by SHA-256 of image + prompt + model |

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

## Script Architecture

The build and extraction scripts use shared modules in the `scripts/` directory:

| Module | Purpose |
|---|---|
| `pptx_utils.py` | Unit conversion (`emu_to_inches()`), YAML loading |
| `pptx_colors.py` | Color resolution (`#hex`, `@theme`, dict with brightness), theme color map (16 entries) |
| `pptx_fonts.py` | Font resolution, family normalization, weight suffix handling, alignment mapping |
| `pptx_shapes.py` | Shape constant map (29 entries + circle alias), auto-shape name mapping, rotation utilities |
| `pptx_fills.py` | Solid, gradient, and pattern fill application/extraction; line/border styling with dash styles |
| `pptx_text.py` | Text frame properties (margins, auto-size, vertical anchor), paragraph properties (spacing, level), run properties (underline, hyperlink) |
| `pptx_tables.py` | Table element creation and extraction with cell merging, banding, and per-cell styling |
| `pptx_charts.py` | Chart element creation and extraction for 12 chart types (column, bar, line, pie, scatter, bubble, etc.) |
| `validate_deck.py` | PPTX-only validation for speaker notes and slide count |
| `validate_slides.py` | Vision-based slide validation via Copilot SDK with auto-caching and Markdown report generation |

## python-pptx Constraints

* python-pptx does NOT support SVG images. Always convert to PNG via `cairosvg` or `Pillow`.
* python-pptx cannot create new slide masters or layouts programmatically. Use blank layouts or start from a template PPTX with the `--template` argument.
* Transitions and animations are preserved when opening and saving existing files, but cannot be created or modified via the API.
* When extracting content, slide master and layout inheritance means many text elements have no inline styling. Add explicit font properties in content YAML before rebuilding.
* The Export and Validate actions require LibreOffice for PPTX-to-PDF conversion. The PowerShell orchestrator checks for LibreOffice availability before starting and provides platform-specific install instructions if missing.
* Accessing `background.fill` on slides with inherited backgrounds replaces them with `NoFill`. Check `slide.follow_master_background` before accessing the fill property.
* Gradient fills use the python-pptx `GradientFill` API with `GradientStop` objects. Each stop specifies a position (0–100) and a color.
* Theme colors resolve via `MSO_THEME_COLOR` enum. Brightness adjustments apply through the color format's `brightness` property.
* Template-based builds load layouts by name or index. Layout name resolution falls back to index 6 (blank) when no match is found.

## Validation Rules

### Visual Checks (via `validate_slides.py`)

These checks are performed by `validate_slides.py` using a vision-capable model through the Copilot SDK. The script receives a validation prompt describing what to check and sends each slide image to the model:

* **Text overlay**: Text overlapping other elements; verified visually from rendered images.
* **Width overflow**: Elements exceeding slide width; visible as clipped content at edges.
* **Height overflow**: Elements exceeding slide height; visible as clipped content at edges.
* **Font consistency**: Inconsistent font families across slides; detected visually.
* **Edge margins**: Elements within 0.5" of slide edges; detected from rendered layout.
* **Element spacing**: Overlapping or colliding elements with insufficient gaps.
* **Color contrast**: Low contrast between text color and background fill.
* **Narrow text boxes**: Text boxes too narrow for their content; visible as excessive wrapping.
* **Leftover placeholders**: Unused template placeholder text remaining in slides.

### PPTX-Only Checks (via `validate_deck.py`)

These checks require direct PPTX inspection and cannot be detected from images:

* **Speaker notes**: Required on all content slides; notes are invisible in rendered images.

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| SVG runtime error | python-pptx cannot embed SVG | Convert to PNG via `cairosvg` before adding |
| Text overlay between elements | Insufficient vertical spacing | Verify `bottom + 0.2 < next_element_top` for all adjacent elements |
| Width overflow off-slide | Element extends beyond slide boundary | Ensure `left + width <= 13.333` for widescreen 16:9 |
| Bright accent color unreadable as fill | White text on bright background | Darken accent to ~60% saturation for box fills |
| Background fill replaced with NoFill | Accessed `background.fill` on inherited background | Check `slide.follow_master_background` before accessing |
| Missing speaker notes | Notes not specified in `content.yaml` | Add `speaker_notes` field to every content slide |
| LibreOffice not found during Validate | Validate exports slides to images first | Install LibreOffice: `brew install --cask libreoffice` (macOS) |

> Brought to you by microsoft/hve-core
