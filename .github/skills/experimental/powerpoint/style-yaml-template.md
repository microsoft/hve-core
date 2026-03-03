# Style YAML Template

Use this template when creating or updating the `global/style.yaml` file for a slide deck. This file defines dimensions, template configuration, layout mappings, metadata, defaults, and theme information.

## Instructions

* Place this file at `content/global/style.yaml` within the working directory.
* Dimensions control the slide canvas size. Standard 16:9 is 13.333" x 7.5".
* Template and layout configuration is optional and used with template-based builds.
* Metadata fields populate the presentation file properties.
* Defaults define per-element-type styling fallbacks.
* The `themes` section (populated during extraction) describes detected visual themes across the deck for contextual reference.

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

# Default element styling
defaults:
  title_bar:
    height_inches: 0.05
    color: "#0078D4"
    top_inches: 0
  accent_bar:
    height_inches: 0.03
    color: "#0078D4"
  card:
    fill: "#2D2D35"
    corner_radius_inches: 0.15
    border_color: "#3D3D45"
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
| `defaults` | `title_bar`, `accent_bar` | Default bar dimensions and colors (`#RRGGBB` hex) |
| `defaults` | `card` | Default card fill, corner radius, and border |
| `defaults` | `speaker_notes_required` | Whether speaker notes are enforced during validation |
