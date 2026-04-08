---
name: powerpoint
description: 'PowerPoint slide deck generation and management using python-pptx with YAML-driven content and styling - Brought to you by microsoft/hve-core'
license: MIT
compatibility: 'Requires uv, Python 3.11+, PowerShell 7+, and LibreOffice'
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-03-18"
---

# PowerPoint Skill

Generates, updates, and manages PowerPoint slide decks using `python-pptx` with YAML-driven content and styling definitions.

## Overview

This skill provides Python scripts that consume YAML configuration files to produce PowerPoint slide decks. Each slide is defined by a `content.yaml` file describing its layout, text, and shapes. A `style.yaml` file defines dimensions, template configuration, layout mappings, metadata, and defaults.

SKILL.md covers technical reference: prerequisites, commands, script architecture, API constraints, and troubleshooting. For conventions and design rules (element positioning, visual quality, color and contrast, contextual styling), follow `pptx.instructions.md`.

## Prerequisites

### PowerShell

The `Invoke-PptxPipeline.ps1` script handles virtual environment creation and dependency installation automatically via `uv sync`. Requires `uv`, Python 3.11+, and PowerShell 7+.

### Installing uv

If `uv` is not installed:

```bash
# macOS / Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# Windows
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

# Via pip (fallback)
pip install uv
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

### Security Validation

Before executing a `content-extra.py` file, the build script performs AST-based static analysis to reject dangerous code. Validation runs automatically unless the `--allow-scripts` flag is passed.

**Allowed imports:**

* `pptx` and all `pptx.*` submodules
* Safe standard-library modules (e.g., `math`, `copy`, `json`, `re`, `pathlib`, `collections`, `itertools`, `functools`, `typing`, `enum`, `dataclasses`, `decimal`, `fractions`, `string`, `textwrap`)

**Blocked imports:**

* `subprocess`, `os`, `shutil`, `socket`, `ctypes`, `signal`, `multiprocessing`, `threading`, `http`, `urllib`, `ftplib`, `smtplib`, `imaplib`, `poplib`, `xmlrpc`, `webbrowser`, `code`, `codeop`, `compileall`, `py_compile`, `zipimport`, `pkgutil`, `runpy`, `ensurepip`, `venv`, `sqlite3`, `tempfile`, `shelve`, `dbm`, `pickle`, `marshal`, `importlib`, `sys`, `telnetlib`
* Any third-party package not on the allowlist

**Blocked builtins:**

* Dangerous: `eval`, `exec`, `__import__`, `compile`, `breakpoint`
* Indirect bypass: `getattr`, `setattr`, `delattr`, `globals`, `locals`, `vars`

**Runtime namespace restriction:**

Even after AST validation passes, the executed module runs in a restricted namespace where `__builtins__` is limited to safe builtins only. The dangerous and indirect-bypass builtins listed above are removed from the module namespace before execution (`__import__` is kept because the import machinery requires it; the AST checker blocks direct `__import__()` calls).

**`--allow-scripts` flag:**

Pass `--allow-scripts` to skip AST validation and namespace restriction for trusted content. This flag is required when a `content-extra.py` script legitimately needs blocked imports or builtins.

```bash
python scripts/build_deck.py \
  --content-dir content/ \
  --style content/global/style.yaml \
  --output slide-deck/presentation.pptx \
  --allow-scripts
```

When validation fails, the build raises `ContentExtraError` with a message identifying the violation and file path.

## Script Reference

All operations are available through the PowerShell orchestrator (`Invoke-PptxPipeline.ps1`) or directly via the Python scripts. The PowerShell script manages the Python virtual environment and dependency installation automatically via `uv sync`.

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

> [!WARNING]
> `--template` creates a NEW presentation inheriting only slide masters, layouts, and theme from the template. All existing slides are discarded. Use `--source` for partial rebuilds.

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

> [!IMPORTANT]
> Use `--source` (not `--template`) for partial rebuilds. Combining `--template` and `--source` is not supported.

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

Opens the existing deck, clears shapes on the specified slides, rebuilds them in-place from their `content.yaml`, and saves. All other slides remain untouched. After building, verify the output slide count matches the original deck.

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

* Picture shapes that reference external (linked) images instead of embedded blobs are recorded with `path: LINKED_IMAGE_NOT_EMBEDDED`. The script does not crash but the image must be re-embedded manually.
* When text elements inherit font, size, or color from the slide master or layout, the extraction records no inline styling. Content YAML for these elements needs explicit font properties added before rebuild.
* The `detect_global_style()` function uses frequency analysis across all slides. For decks with mixed styling, review and adjust `style.yaml` values manually after extraction.

### Validate a Deck

```powershell
./scripts/Invoke-PptxPipeline.ps1 -Action Validate `
  -InputPath slide-deck/presentation.pptx `
  -ContentDir content/
```

The Validate action runs a two- or three-step pipeline:

1. **Export** — Clears stale slide images from the output directory, then renders slides to JPG images via LibreOffice (PPTX → PDF → JPG). When `-Slides` is used, output images are named to match original slide numbers (e.g., `slide-023.jpg` for slide 23), not sequential PDF page numbers.
2. **PPTX validation** — Checks PPTX-only properties (`validate_deck.py`) for speaker notes and slide count.
3. **Vision validation** (optional) — Sends slide images to a vision-capable model via the Copilot SDK (`validate_slides.py`) for visual quality checks. Runs when `-ValidationPrompt` or `-ValidationPromptFile` is provided.

For validation criteria (element positioning, visual quality, color contrast, content completeness), see `pptx.instructions.md` Validation Criteria.

#### Built-in System Message

The `validate_slides.py` script includes a built-in system message that focuses on issue detection only (not full slide description). It checks overlapping elements, text overflow/cutoff, decorative line mismatch after title wraps, citation/footer collisions, tight spacing, uneven gaps, insufficient edge margins, alignment inconsistencies, low contrast, narrow text boxes, and leftover placeholders. For dense slides, near-edge placement or tight boundaries are acceptable when readability is not materially affected. The `-ValidationPrompt` parameter provides supplementary user-level context and does not need to repeat these checks.

#### Validate with Vision Checks

```powershell
./scripts/Invoke-PptxPipeline.ps1 -Action Validate `
  -InputPath slide-deck/presentation.pptx `
  -ContentDir content/ `
  -ValidationPrompt "Validate visual quality. Focus on recently modified slides for content accuracy." `
  -ValidationModel claude-haiku-4.5
```

Vision validation results are written to `validation-results.json` in the image output directory, containing raw model responses per slide with quality findings. Per-slide response text is also written to `slide-NNN-validation.txt` files next to each slide image.

#### Validate Specific Slides

```powershell
./scripts/Invoke-PptxPipeline.ps1 -Action Validate `
  -InputPath slide-deck/presentation.pptx `
  -ContentDir content/ `
  -Slides "3,7,15"
```

Validates only the specified slides. When content directories cover fewer slides than the PPTX, the slide count check reports an informational note rather than an error.

#### validate_slides.py CLI Reference

| Flag              | Required                            | Default            | Description                                   |
|-------------------|-------------------------------------|--------------------|-----------------------------------------------|
| `--image-dir`     | Yes                                 | —                  | Directory containing `slide-NNN.jpg` images   |
| `--prompt`        | One of `--prompt` / `--prompt-file` | —                  | Validation prompt text                        |
| `--prompt-file`   | One of `--prompt` / `--prompt-file` | —                  | Path to file containing the validation prompt |
| `--model`         | No                                  | `claude-haiku-4.5` | Vision model ID                               |
| `--output`        | No                                  | stdout             | JSON results file path                        |
| `--slides`        | No                                  | all                | Comma-separated slide numbers to validate     |
| `-v`, `--verbose` | No                                  | —                  | Enable debug-level logging                    |

#### validate_deck.py CLI Reference

| Flag              | Required | Default | Description                                                           |
|-------------------|----------|---------|-----------------------------------------------------------------------|
| `--input`         | Yes      | —       | Input PPTX file path                                                  |
| `--content-dir`   | No       | —       | Content directory for slide count comparison                          |
| `--slides`        | No       | all     | Comma-separated slide numbers to validate                             |
| `--output`        | No       | stdout  | JSON results file path                                                |
| `--report`        | No       | —       | Markdown report file path                                             |
| `--per-slide-dir` | No       | —       | Directory for per-slide JSON files (`slide-NNN-deck-validation.json`) |

#### Validation Outputs

When run through the pipeline, validation produces these files in the image output directory:

| File                             | Format   | Content                                                             |
|----------------------------------|----------|---------------------------------------------------------------------|
| `deck-validation-results.json`   | JSON     | Per-slide PPTX property issues (speaker notes, slide count)         |
| `deck-validation-report.md`      | Markdown | Human-readable report for PPTX property validation                  |
| `validation-results.json`        | JSON     | Consolidated vision model responses with quality findings           |
| `slide-NNN-validation.txt`       | Text     | Per-slide vision response text (next to `slide-NNN.jpg`)            |
| `slide-NNN-deck-validation.json` | JSON     | Per-slide PPTX property validation result (next to `slide-NNN.jpg`) |

Per-slide vision text files are written alongside their corresponding `slide-NNN.jpg` images, enabling agents to read validation findings for individual slides without parsing the consolidated JSON file.

#### Validation Scope for Changed Slides

When validating after modifying or adding specific slides, always validate a block that includes **one slide before** and **one slide after** the changed or added slides. This catches edge-proximity issues, transition inconsistencies, and spacing problems that arise between adjacent slides.

For example, when slides 5 and 6 were changed, validate slides 4 through 7:

```powershell
./scripts/Invoke-PptxPipeline.ps1 -Action Validate `
  -InputPath slide-deck/presentation.pptx `
  -ContentDir content/ `
  -Slides "4,5,6,7" `
  -ValidationPrompt "Check for text overlay, overflow, margin issues, color contrast"
```

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

Converts specified slides to JPG images for visual inspection. The PowerShell orchestrator handles both steps automatically, clears stale images before exporting, names output images to match original slide numbers when `-Slides` is used, and uses a PyMuPDF fallback when `pdftoppm` is not installed.

When running the two-step process manually (outside the pipeline), note that `render_pdf_images.py` uses sequential numbering by default. Pass `--slide-numbers` to map output images to original slide positions:

```bash
python scripts/render_pdf_images.py \
  --input slide-deck/validation/slides.pdf \
  --output-dir slide-deck/validation/ \
  --dpi 150 \
  --slide-numbers 1,3,5
```

**Dependencies**: Requires LibreOffice for PPTX-to-PDF conversion and either `pdftoppm` (from `poppler`) or `pymupdf` (pip) for PDF-to-JPG rendering.

## Script Architecture

The build and extraction scripts use shared modules in the `scripts/` directory:

| Module                 | Purpose                                                                                                                                   |
|------------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| `pptx_utils.py`        | Shared utilities: exit codes, logging configuration, slide filter parsing, unit conversion (`emu_to_inches()`), YAML loading              |
| `pptx_colors.py`       | Color resolution (`#hex`, `@theme`, dict with brightness), theme color map (16 entries)                                                   |
| `pptx_fonts.py`        | Font resolution, family normalization, weight suffix handling, alignment mapping                                                          |
| `pptx_shapes.py`       | Shape constant map (29 entries + circle alias), auto-shape name mapping, rotation utilities                                               |
| `pptx_fills.py`        | Solid, gradient, and pattern fill application/extraction; line/border styling with dash styles                                            |
| `pptx_text.py`         | Text frame properties (margins, auto-size, vertical anchor), paragraph properties (spacing, level), run properties (underline, hyperlink) |
| `pptx_tables.py`       | Table element creation and extraction with cell merging, banding, and per-cell styling                                                    |
| `pptx_charts.py`       | Chart element creation and extraction for 12 chart types (column, bar, line, pie, scatter, bubble, etc.)                                  |
| `validate_deck.py`     | PPTX-only validation for speaker notes and slide count                                                                                    |
| `validate_slides.py`   | Vision-based slide issue detection and quality validation via Copilot SDK with built-in checks and plain-text per-slide output            |
| `render_pdf_images.py` | PDF-to-JPG rendering via PyMuPDF with optional slide-number-based naming                                                                  |

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

## Troubleshooting

| Issue                                  | Cause                                              | Solution                                                                                         |
|----------------------------------------|----------------------------------------------------|--------------------------------------------------------------------------------------------------|
| SVG runtime error                      | python-pptx cannot embed SVG                       | Convert to PNG via `cairosvg` before adding                                                      |
| Text overlay between elements          | Insufficient vertical spacing                      | Follow element positioning conventions in `pptx.instructions.md`                                 |
| Width overflow off-slide               | Element extends beyond slide boundary              | Follow element positioning conventions in `pptx.instructions.md`                                 |
| Bright accent color unreadable as fill | White text on bright background                    | Darken accent to ~60% saturation for box fills                                                   |
| Background fill replaced with NoFill   | Accessed `background.fill` on inherited background | Check `slide.follow_master_background` before accessing                                          |
| Missing speaker notes                  | Notes not specified in `content.yaml`              | Add `speaker_notes` field to every content slide                                                 |
| LibreOffice not found during Validate  | Validate exports slides to images first            | Install LibreOffice: `brew install --cask libreoffice` (macOS)                                   |
| `uv` not found                         | uv package manager not installed                   | Install uv: `curl -LsSf https://astral.sh/uv/install.sh \| sh` (macOS/Linux) or `pip install uv` |
| Python not found by uv                 | No Python 3.11+ on PATH                            | Install via `uv python install 3.11` or `pyenv install 3.11`                                     |
| `uv sync` fails                        | Missing or corrupt `.venv`                         | Delete `.venv/` at the skill root and re-run `uv sync`                                           |
| Import errors in scripts               | Dependencies not installed or stale venv           | Run `uv sync` from the skill root to recreate the environment                                    |

## Environment Recovery

When scripts fail due to missing modules, import errors, or a corrupt virtual environment, recover with:

```bash
cd .github/skills/experimental/powerpoint
rm -rf .venv
uv sync
```

This recreates the virtual environment from scratch using `pyproject.toml` as the single source of truth. The `Invoke-PptxPipeline.ps1` orchestrator runs `uv sync` automatically on each invocation unless `-SkipVenvSetup` is passed.

When `uv` itself is not available, install it first (see Installing uv above), then retry. When Python 3.11+ is not available, run `uv python install 3.11` to have uv fetch and manage the interpreter.

> Brought to you by microsoft/hve-core

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
