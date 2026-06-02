---
title: 'PowerPoint Skill: Script Reference'
description: 'Reference for the PowerPoint skill PowerShell orchestrator and Python script invocations for slide deck operations.'
---

# PowerPoint Skill: Script Reference

All operations are available through the PowerShell orchestrator (`Invoke-PptxPipeline.ps1`) or directly via the Python scripts. The PowerShell script manages the Python virtual environment and dependency installation automatically via `uv sync`.

## Build a Slide Deck

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

## Build from a Template

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

## Update Specific Slides

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

## Extract Content from Existing PPTX

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

### Extract Specific Slides

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

### Extraction Limitations

* Picture shapes that reference external (linked) images instead of embedded blobs are recorded with `path: LINKED_IMAGE_NOT_EMBEDDED`. The script does not crash but the image must be re-embedded manually.
* When text elements inherit font, size, or color from the slide master or layout, the extraction records no inline styling. Content YAML for these elements needs explicit font properties added before rebuild.
* The `detect_global_style()` function uses frequency analysis across all slides. For decks with mixed styling, review and adjust `style.yaml` values manually after extraction.

## Validate a Deck

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

### Built-in System Message

The `validate_slides.py` script includes a built-in system message that focuses on issue detection only (not full slide description). It checks overlapping elements, text overflow/cutoff, decorative line mismatch after title wraps, citation/footer collisions, tight spacing, uneven gaps, insufficient edge margins, alignment inconsistencies, low contrast, narrow text boxes, and leftover placeholders. For dense slides, near-edge placement or tight boundaries are acceptable when readability is not materially affected. The `-ValidationPrompt` parameter provides supplementary user-level context and does not need to repeat these checks.

### Validate with Vision Checks

```powershell
./scripts/Invoke-PptxPipeline.ps1 -Action Validate `
  -InputPath slide-deck/presentation.pptx `
  -ContentDir content/ `
  -ValidationPrompt "Validate visual quality. Focus on recently modified slides for content accuracy." `
  -ValidationModel claude-haiku-4.5
```

Vision validation results are written to `validation-results.json` in the image output directory, containing raw model responses per slide with quality findings. Per-slide response text is also written to `slide-NNN-validation.txt` files next to each slide image.

### Validate Specific Slides

```powershell
./scripts/Invoke-PptxPipeline.ps1 -Action Validate `
  -InputPath slide-deck/presentation.pptx `
  -ContentDir content/ `
  -Slides "3,7,15"
```

Validates only the specified slides. When content directories cover fewer slides than the PPTX, the slide count check reports an informational note rather than an error.

### validate_slides.py CLI Reference

| Flag              | Required                            | Default            | Description                                   |
|-------------------|-------------------------------------|--------------------|-----------------------------------------------|
| `--image-dir`     | Yes                                 | —                  | Directory containing `slide-NNN.jpg` images   |
| `--prompt`        | One of `--prompt` / `--prompt-file` | —                  | Validation prompt text                        |
| `--prompt-file`   | One of `--prompt` / `--prompt-file` | —                  | Path to file containing the validation prompt |
| `--model`         | No                                  | `claude-haiku-4.5` | Vision model ID                               |
| `--output`        | No                                  | stdout             | JSON results file path                        |
| `--slides`        | No                                  | all                | Comma-separated slide numbers to validate     |
| `-v`, `--verbose` | No                                  | —                  | Enable debug-level logging                    |

### validate_deck.py CLI Reference

| Flag              | Required | Default | Description                                                           |
|-------------------|----------|---------|-----------------------------------------------------------------------|
| `--input`         | Yes      | —       | Input PPTX file path                                                  |
| `--content-dir`   | No       | —       | Content directory for slide count comparison                          |
| `--slides`        | No       | all     | Comma-separated slide numbers to validate                             |
| `--output`        | No       | stdout  | JSON results file path                                                |
| `--report`        | No       | —       | Markdown report file path                                             |
| `--per-slide-dir` | No       | —       | Directory for per-slide JSON files (`slide-NNN-deck-validation.json`) |

### Validation Outputs

When run through the pipeline, validation produces these files in the image output directory:

| File                             | Format   | Content                                                             |
|----------------------------------|----------|---------------------------------------------------------------------|
| `deck-validation-results.json`   | JSON     | Per-slide PPTX property issues (speaker notes, slide count)         |
| `deck-validation-report.md`      | Markdown | Human-readable report for PPTX property validation                  |
| `validation-results.json`        | JSON     | Consolidated vision model responses with quality findings           |
| `slide-NNN-validation.txt`       | Text     | Per-slide vision response text (next to `slide-NNN.jpg`)            |
| `slide-NNN-deck-validation.json` | JSON     | Per-slide PPTX property validation result (next to `slide-NNN.jpg`) |

Per-slide vision text files are written alongside their corresponding `slide-NNN.jpg` images, enabling agents to read validation findings for individual slides without parsing the consolidated JSON file.

### Validation Scope for Changed Slides

When validating after modifying or adding specific slides, always validate a block that includes **one slide before** and **one slide after** the changed or added slides. This catches edge-proximity issues, transition inconsistencies, and spacing problems that arise between adjacent slides.

For example, when slides 5 and 6 were changed, validate slides 4 through 7:

```powershell
./scripts/Invoke-PptxPipeline.ps1 -Action Validate `
  -InputPath slide-deck/presentation.pptx `
  -ContentDir content/ `
  -Slides "4,5,6,7" `
  -ValidationPrompt "Check for text overlay, overflow, margin issues, color contrast"
```

## Export Slides to Images

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

## Dry-Run Validation

```bash
python scripts/build_deck.py \
  --content-dir content/ \
  --style content/global/style.yaml \
  --dry-run
```

Validates content files without producing a PPTX. Parses all `content.yaml` files, checks for speaker notes, runs AST validation on `content-extra.py` scripts, and counts image assets. Exit codes:

* code 0: no errors found
* code 1: one or more slide-level content errors (YAML parse failures, invalid scripts)
* code 2: configuration error (e.g., no slide content found in the content directory)

## Generate Theme Variants

```bash
python scripts/generate_themes.py \
  --content-dir content/ \
  --themes themes.yaml \
  --output-dir ../
```

Generates themed content directories from a base content directory using a color mapping YAML file. The themes YAML defines color replacement tables:

```yaml
themes:
  fluent:
    label: "Microsoft Fluent"
    colors:
      "#1B1B1F": "#FFFFFF"
      "#F8F8FC": "#242424"
```

Each theme gets its own output directory with remapped `content.yaml`, `style.yaml`, and `content-extra.py` files. Images are copied as-is. Run `build_deck.py` on each themed directory to produce the PPTX.

## Embed Audio

```bash
python scripts/embed_audio.py \
  --input slide-deck/presentation.pptx \
  --audio-dir voice-over/ \
  --output slide-deck/presentation-narrated.pptx
```

Embeds WAV audio files into PPTX slides. Audio files are matched to slides by naming convention (`slide-001.wav`, `slide-002.wav`, etc.). The audio icon is placed off-screen (below the slide boundary) to keep it hidden during presentation. Pass `--slides` to embed audio on specific slides only.

**Dependencies**: Requires `pillow` (`pip install pillow`) for poster frame generation.

> [!NOTE]
> WAV files are embedded uncompressed. For large narrated decks, consider pre-compressing audio before embedding to manage PPTX file size.

## Export Slides to SVG

```bash
python scripts/export_svg.py \
  --input slide-deck/presentation.pptx \
  --output-dir slide-deck/svg/ \
  --slides 3,5,10
```

Exports slides to SVG format via LibreOffice (PPTX → PDF) and PyMuPDF (PDF → SVG). Output files are named `slide-NNN.svg`. Pass `--slides` to export specific slides. **Dependencies**: Requires LibreOffice and `pymupdf`.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
