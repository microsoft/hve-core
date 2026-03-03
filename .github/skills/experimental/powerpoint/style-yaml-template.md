# Style YAML Template

Use this template when creating or updating the `global/style.yaml` file for a slide deck. This file defines shared styling applied to all slides unless overridden per-slide.

## Instructions

* Place this file at `content/global/style.yaml` within the working directory.
* Color values use hex format (`#RRGGBB`).
* Color references in content files use `$color_name` syntax, which resolves against the `colors` map defined here.
* Typography values specify font families and point sizes.
* Default element styling applies to all slides unless overridden in a slide's `content.yaml` via the `style_overrides` section.
* Adjust dimensions to match the target slide format (standard 16:9 is 13.333" x 7.5").

## Template

```yaml
# Slide dimensions
dimensions:
  width_inches: 13.333
  height_inches: 7.5
  format: "16:9"

# Template configuration (optional)
template:
  path: "template.pptx"            # path to template PPTX file
  preserve_dimensions: true         # keep template slide dimensions

# Layout mapping (optional, used with templates)
layouts:
  title: "Title Slide"             # content.yaml layout name -> PowerPoint layout name
  content: "Title and Content"
  section: "Section Header"
  blank: 6                          # integer index fallback

# Presentation metadata (optional)
metadata:
  title: "HVE Workshop Deck"
  author: "Allen Greaves"
  subject: "AI-Assisted Engineering"
  keywords: "HVE, Copilot, AI"
  category: "Presentation"

# Color palette
colors:
  bg_dark: "#1B1B1F"
  bg_card: "#2D2D35"
  accent_blue: "#0078D4"
  accent_teal: "#00B4D8"
  accent_green: "#10B981"
  text_white: "#F8F8FC"
  text_gray: "#9CA3AF"
  code_inline: "#FFD700"
  border: "#3D3D45"

# Typography
typography:
  body_font: "Segoe UI"
  code_font: "Cascadia Code"
  heading_size: 28
  subheading_size: 22
  body_size: 16
  code_size: 14
  small_size: 12

# Default element styling
defaults:
  title_bar:
    height_inches: 0.05
    color: "$accent_blue"
    top_inches: 0
  accent_bar:
    height_inches: 0.03
    color: "$accent_blue"
  card:
    fill: "$bg_card"
    corner_radius_inches: 0.15
    border_color: "$border"
    border_width_pt: 1
  speaker_notes_required: true
```

## Field Reference

| Section | Field | Description |
|---|---|---|
| `dimensions` | `width_inches`, `height_inches` | Slide canvas size in inches |
| `dimensions` | `format` | Aspect ratio label (informational) |
| `template` | `path` | Path to a template PPTX file for themed builds |
| `template` | `preserve_dimensions` | Keep the template's slide dimensions when `true` |
| `layouts` | `<name>: <layout>` | Maps content.yaml layout names to PowerPoint layout names or indices |
| `metadata` | `title` | Presentation title set in file properties |
| `metadata` | `author` | Presentation author |
| `metadata` | `subject` | Presentation subject |
| `metadata` | `keywords` | Presentation keywords |
| `metadata` | `category` | Presentation category |
| `colors` | `<name>: <hex>` | Named color entries; referenced as `$name` in content files |
| `typography` | `body_font`, `code_font` | Font family names |
| `typography` | `*_size` | Default point sizes for each text tier |
| `defaults` | `title_bar`, `accent_bar` | Default bar dimensions and colors |
| `defaults` | `card` | Default card fill, corner radius, and border |
| `defaults` | `speaker_notes_required` | Whether speaker notes are enforced during validation |
