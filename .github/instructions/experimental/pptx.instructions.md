---
description: "Shared conventions for PowerPoint Builder agent, subagent, and powerpoint skill"
applyTo: '**/.copilot-tracking/ppt/**'
---

# PowerPoint Builder Instructions

Shared conventions applied to all PowerPoint Builder workflows. These instructions govern the agent, subagent, and powerpoint skill.

This file covers conventions and design rules agents follow when building or updating slide decks. The `powerpoint` skill contains the technical reference for scripts, commands, and API constraints.

## Working Directory

All artifacts live under `.copilot-tracking/ppt/{{YYYY-MM-DD}}/{{ppt-name}}/` with this structure:

```text
.copilot-tracking/ppt/{{YYYY-MM-DD}}/{{ppt-name}}/
├── changes/          # Change tracking logs
├── content/          # YAML content definitions and images
│   ├── global/
│   │   ├── style.yaml       # Dimensions, defaults, template config, and theme metadata
│   │   └── voice-guide.md   # Voice and tone guidelines
│   ├── slide-001/
│   │   ├── content.yaml     # Slide 1 content and layout
│   │   ├── content-extra.py # (Optional) Custom Python for complex drawings
│   │   └── images/          # Slide-specific images
│   ├── slide-002/
│   │   ├── content.yaml
│   │   └── images/
│   └── ...
├── research/         # Subagent research outputs
└── slide-deck/       # Single output directory for the PPTX
    └── {{ppt-name}}.pptx
```

Include `<!-- markdownlint-disable-file -->` at the top of all markdown files created under `.copilot-tracking/`.

## Content Conventions

* Each slide is defined by a `content.yaml` file describing layout, text, shapes, and speaker notes.
* A global `style.yaml` defines dimensions, template configuration, layout mappings, metadata, and defaults. It does not enforce colors or fonts.
* Complex drawings that cannot be expressed in `content.yaml` go in a `content-extra.py` file with a `render(slide, style, content_dir)` function.
* All text content lives in `content.yaml` files; scripts do not hardcode text.
* All images live in slide `images/` directories.
* All color values use `#RRGGBB` hex format or `@theme_name` references. Named color references (`$color_name`) are not supported.
* All font names are specified as literal font family names (e.g., `Segoe UI`, `Cascadia Code`). Named font references (`$body_font`) are not supported.

## Image Conventions

* Prefer PNG format. python-pptx does NOT support SVG embedding. Convert SVG to PNG via `cairosvg` when needed.
* Consider alpha layers, positioning, and sizing when preparing images.
* Calculate pixel dimensions from target slide placement: `height_px = int(width_px / (target_width_inches / target_height_inches))`.
* Store caption metadata as a sidecar YAML file alongside each image.
* Background images use fill properties, not pasted images on top of slides.

## Script Conventions

* Widescreen 16:9 dimensions: `width=Inches(13.333)`, `height=Inches(7.5)`.
* For new decks, use blank layout (`prs.slide_layouts[6]`) with manual element placement.
* For update and cleanup workflows, preserve existing masters and layouts from the source deck.
* When updating an existing deck, always regenerate from content YAML rather than modifying the PPTX directly; update content files first, then regenerate into `slide-deck/`.
* Follow the repo's Python environment conventions (`uv-projects.instructions.md`) for virtual environment and dependency management.
* All dependencies are declared in `pyproject.toml` at the skill root. The `Invoke-PptxPipeline.ps1` orchestrator manages the virtual environment automatically. Never install packages with `pip install` directly.
* When scripts fail due to missing modules or import errors, follow the Environment Recovery steps in the `powerpoint` skill instructions.

### Build Mode: `--template` vs `--source`

The `build_deck.py` script has two mutually exclusive modes for working with existing PPTX files:

* **`--template`** creates a NEW presentation from the template, inheriting only slide masters, layouts, and theme colors. All existing slides in the template are discarded. Only slides defined in `content/` are added. Use for full rebuilds and new decks with corporate branding.
* **`--source`** opens an existing deck and rebuilds specified slides in-place. All slides not in `--slides` remain untouched. Use for partial rebuilds when updating specific slides in a large deck.
* **Never combine `--template` and `--source`** in the same command. If both are provided, `--template` behavior takes precedence and all non-specified slides are lost.

For partial rebuild workflows (update a few slides in an existing deck):

1. Copy the original PPTX to the output location if source and output paths differ.
2. Run `build_deck.py --source <deck> --output <deck> --slides N,M`.
3. Verify the output slide count matches the original.

## Validation Criteria

These criteria define the quality standards agents verify after building or updating slides. The Validate pipeline runs three checks in sequence: PPTX property validation (`validate_deck.py`), geometric validation (`validate_geometry.py`), and optionally vision-based validation (`validate_slides.py`).

Geometric validation runs automatically during the Validate action and checks the element positioning rules below programmatically. It catches margin violations, boundary overflow, and insufficient gaps without requiring vision model access.

### Element Positioning

* Trace vertical positions mathematically: `bottom = top + height`, verify `bottom + 0.2 < next_element_top`.
* Verify `left + width <= 13.333` for every element to prevent width overflow.
* All elements must maintain at least 0.5" from slide edges.
* Adjacent elements must have at least 0.3" gap.
* Similar or repeated elements (cards, columns) must align consistently.

### Visual Quality

* No text through shapes, lines through words, or stacked elements.
* No text cut off at edges or box boundaries.
* Lines positioned for single-line text must adjust when titles wrap to two lines.
* Source citations or footers must not collide with content above.
* No large empty areas alongside cramped areas on the same slide.
* Text boxes must not be too narrow, causing excessive wrapping.
* No leftover placeholder content from templates.

### Color and Contrast

* Verify sufficient contrast between text color and background (avoid light gray text on cream backgrounds).
* Avoid dark icons on dark backgrounds without a contrasting circle or container.
* When using accent colors as fills, darken to ~60% saturation for white text readability.

### Content Completeness

* Speaker notes are required on all content slides.
* Fonts, colors, and element styling must be consistent with the visual theme of surrounding slides. Use contextual styling from nearby slides to maintain coherence across the deck.
* No mismatched or fallback fonts.
* No leftover placeholder content from templates.

## Color Conventions

Use `#RRGGBB` hex values or `@theme_name` references for all colors. See the Color Syntax section in `content-yaml-template.md` for the full specification including theme brightness adjustments and dict syntax.

### Theme Colors in content-extra.py

When `style.yaml` defines a `themes` section, the build script populates `style["colors"]` with the first theme's color map. Use `style.get("colors", {}).get("accent_blue", "#0078D4")` in `content-extra.py` to reference theme-aware colors. This enables theme portability — the same script produces correct colors across all theme variants without regex replacement.

## Contextual Styling

Slide decks often contain multiple visual themes (title slides, content slides, section dividers, dark vs. light themes). Rather than enforcing a single global style, derive colors, fonts, and layout patterns from context:

* When creating new slides, examine existing slides in the deck that serve a similar purpose (title, content, divider, closing). Match the visual treatment, including background, text colors, fonts, and accent colors, from those reference slides.
* When inserting between existing slides, look at the slides immediately before and after the insertion point. Match the visual theme of the surrounding slides.
* For extracted decks, use the `themes` section in `style.yaml` to identify which slides use light vs. dark treatments. Apply the appropriate theme when authoring new content.
* For template-based builds, use `@theme_name` references so slides adapt to whatever theme the template defines.

## Gradient Fill Conventions

* Use gradient fills sparingly for visual emphasis on hero elements, section dividers, or background accents.
* Keep gradient stops to 2–3 colors for readability. More stops increase visual complexity.
* Specify gradient angle to control direction (0 = left-to-right, 90 = top-to-bottom, 270 = bottom-to-top).


