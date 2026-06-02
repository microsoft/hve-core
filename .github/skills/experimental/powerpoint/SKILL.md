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

Text contract: markdown-like list lines in `textbox.text` and `shape.text` are interpreted as PowerPoint lists during rendering. Unordered markers (`-`, `+`, `*`) become bulleted paragraphs, ordered markers (`1.`, `1)`) become auto-numbered paragraphs, and leading indentation maps to paragraph level.

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

Pipeline actions:

* **Build** — Generate a complete deck or rebuild specific slides; supports `-TemplatePath` (new deck from template) and `-SourcePath` (in-place partial rebuild).
* **Extract** — Recover `content.yaml` files and a populated `style.yaml` from an existing PPTX, with optional slide filtering.
* **Validate** — Two- or three-step pipeline that exports slides to JPG, runs PPTX-property checks (`validate_deck.py`), and optional vision-based quality validation (`validate_slides.py`).
* **Export** — Render slides to JPG (via LibreOffice and `pdftoppm`/PyMuPDF) or SVG (via LibreOffice and PyMuPDF).

Additional scripts: `build_deck.py --dry-run` for content validation without building, `generate_themes.py` for themed deck variants from color mappings, and `embed_audio.py` for embedding WAV narration.

For full command syntax, CLI flag reference, validation outputs, scope guidance, and per-action examples, see [references/scripts.md](references/scripts.md).

## Script Architecture

The build and extraction scripts use shared modules in the `scripts/` directory:

| Module                 | Purpose                                                                                                                                                                                                |
|------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `pptx_utils.py`        | Shared utilities: exit codes, logging configuration, slide filter parsing, unit conversion (`emu_to_inches()`), YAML loading                                                                           |
| `pptx_colors.py`       | Color resolution (`#hex`, `@theme`, dict with brightness), theme color map (16 entries)                                                                                                                |
| `pptx_fonts.py`        | Font resolution, family normalization, weight suffix handling, alignment mapping                                                                                                                       |
| `pptx_shapes.py`       | Shape constant map (29 entries + circle alias), auto-shape name mapping, rotation utilities                                                                                                            |
| `pptx_fills.py`        | Solid, gradient, and pattern fill application/extraction; line/border styling with dash styles                                                                                                         |
| `pptx_text.py`         | Text frame properties (margins, auto-size, vertical anchor), paragraph properties (spacing, level), run properties (underline, hyperlink), markdown-like list parsing to bullet/auto-number paragraphs |
| `pptx_tables.py`       | Table element creation and extraction with cell merging, banding, and per-cell styling                                                                                                                 |
| `pptx_charts.py`       | Chart element creation and extraction for 12 chart types (column, bar, line, pie, scatter, bubble, etc.)                                                                                               |
| `validate_deck.py`     | PPTX-only validation for speaker notes and slide count                                                                                                                                                 |
| `validate_geometry.py` | Structural validation for element edge margins, adjacent gaps, boundary overflow, and title clearance                                                                                                  |
| `validate_slides.py`   | Vision-based slide issue detection and quality validation via Copilot SDK with built-in checks and plain-text per-slide output                                                                         |
| `render_pdf_images.py` | PDF-to-JPG rendering via PyMuPDF with optional slide-number-based naming                                                                                                                               |
| `generate_themes.py`   | Theme variant generation from a base content directory using a color mapping YAML file                                                                                                                 |
| `embed_audio.py`       | WAV audio embedding into PPTX slides with per-slide file matching and off-screen audio icon placement                                                                                                  |
| `export_svg.py`        | PPTX-to-SVG export via LibreOffice PDF conversion and PyMuPDF SVG rendering                                                                                                                            |

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

When scripts fail due to missing modules, import errors, or a corrupt virtual environment, recover from the skill root with:

```bash
rm -rf .venv
uv sync
```

This recreates the virtual environment from scratch using `pyproject.toml` as the single source of truth. The `Invoke-PptxPipeline.ps1` orchestrator runs `uv sync` automatically on each invocation unless `-SkipVenvSetup` is passed.

When `uv` itself is not available, install it first (see Installing uv above), then retry. When Python 3.11+ is not available, run `uv python install 3.11` to have uv fetch and manage the interpreter.

> Brought to you by microsoft/hve-core

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
