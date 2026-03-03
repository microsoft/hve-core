---
description: "Shared conventions for PowerPoint Builder agent, subagent, and powerpoint skill"
applyTo: '**/.copilot-tracking/ppt/**'
---

# PowerPoint Builder Instructions

Shared conventions applied to all PowerPoint Builder workflows. These instructions govern the agent, subagent, and powerpoint skill.

## Working Directory

All artifacts live under `.copilot-tracking/ppt/{{YYYY-MM-DD}}/{{ppt-name}}/` with this structure:

```text
.copilot-tracking/ppt/{{YYYY-MM-DD}}/{{ppt-name}}/
├── changes/          # Change tracking logs
├── content/          # YAML content definitions and images
│   ├── global/
│   │   ├── style.yaml       # Global styling for all slides
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
* A global `style.yaml` defines colors, typography, and shared element styling.
* Per-slide `content.yaml` files can override global styles via `style_overrides`.
* Complex drawings that cannot be expressed in `content.yaml` go in a `content-extra.py` file with a `render(slide, style, content_dir)` function.
* All text content lives in `content.yaml` files; scripts do not hardcode text.
* All images live in slide `images/` directories.
* Color references use `$color_name` syntax resolving against the global `style.yaml` colors map.
* Font references use `$body_font` or `$code_font` resolving against the global typography.

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

## Validation Criteria

### Element Positioning

* **Text overlay**: Trace vertical positions mathematically: `bottom = top + height`, verify `bottom + 0.2 < next_element_top`.
* **Width overflow**: Verify `left + width <= 13.333` for every element.
* **Insufficient margin**: All elements must maintain at least 0.5" from slide edges.
* **Element spacing**: Adjacent elements must have at least 0.3" gap.
* **Column alignment**: Similar or repeated elements (cards, columns) must align consistently.

### Visual Quality

* **Overlapping elements**: No text through shapes, lines through words, or stacked elements.
* **Text overflow or cut-off**: No text cut off at edges or box boundaries.
* **Decorative line positioning**: Lines positioned for single-line text must adjust when titles wrap to two lines.
* **Citation collisions**: Source citations or footers must not collide with content above.
* **Uneven gaps**: No large empty areas alongside cramped areas on the same slide.
* **Narrow text boxes**: Text boxes must not be too narrow, causing excessive wrapping.
* **Leftover placeholders**: No leftover placeholder content from templates.

### Color and Contrast

* **Low-contrast text**: Verify sufficient contrast between text color and background (avoid light gray text on cream backgrounds).
* **Low-contrast icons**: Avoid dark icons on dark backgrounds without a contrasting circle or container.
* **Readable fill combinations**: When using accent colors as fills, darken to ~60% saturation for white text readability.

### Content Completeness

* **Speaker notes**: Required on all content slides.
* **Consistent styling**: Fonts, colors, and element styling must be consistent across all slides.
* **Proper fonts**: No mismatched or fallback fonts.

## python-pptx Constraints

* python-pptx does NOT support SVG images. Always convert to PNG via `cairosvg` or `Pillow`.
* python-pptx cannot create new slide masters or layouts programmatically. Use blank layouts or start from a template PPTX.
* Transitions and animations are preserved when opening and saving existing files, but cannot be created or modified via the API.
* Accessing `background.fill` on slides with inherited backgrounds replaces them with `NoFill`. Check `slide.follow_master_background` before accessing the fill property.

## Default Color Palette

```python
BG_DARK      = RGBColor(0x1B, 0x1B, 0x1F)   # Near-black background
BG_CARD      = RGBColor(0x2D, 0x2D, 0x35)   # Card/panel background
ACCENT_BLUE  = RGBColor(0x00, 0x78, 0xD4)   # Microsoft Blue
ACCENT_TEAL  = RGBColor(0x00, 0xB4, 0xD8)   # Teal highlight
ACCENT_GREEN = RGBColor(0x10, 0xB9, 0x81)   # Success green
TEXT_WHITE    = RGBColor(0xF8, 0xF8, 0xFC)   # Primary text
TEXT_GRAY     = RGBColor(0x9C, 0xA3, 0xAF)   # Secondary text
CODE_INLINE   = RGBColor(0xFF, 0xD7, 0x00)   # Gold for inline code
```

## Default Typography

| Role | Font | Usage |
|---|---|---|
| Body text | Segoe UI | All non-code text |
| Inline code | Cascadia Code | Code references within text |
