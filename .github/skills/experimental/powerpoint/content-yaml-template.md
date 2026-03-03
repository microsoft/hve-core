# Content YAML Template

Use this template when creating or updating a slide's `content.yaml` file. Each slide folder (`content/slide-NNN/`) contains one `content.yaml` that defines the slide's layout, text, shapes, and optional style overrides.

## Instructions

* All position and size values (`left`, `top`, `width`, `height`) are in inches.
* Color values use `$color_name` references (resolved from `style.yaml`) or direct hex (`#RRGGBB`).
* Elements render in the order listed — later elements draw on top of earlier ones.
* Speaker notes are required on all content slides when `speaker_notes_required: true` is set in the global style.
* Use `style_overrides` to change colors or typography for a specific slide without modifying the global style.
* The `layout` field is informational and helps describe the slide structure; it does not auto-apply a PowerPoint layout.
* The `background` block sets a per-slide background fill. When omitted, the `bg_dark` color from the global style applies.
* The `rotation` field (degrees, 0–360) is supported on `shape`, `textbox`, and `image` elements. Omit or set to 0 for no rotation.

## Template

```yaml
# Slide metadata
slide: 1
title: "Production-Grade AI-Assisted Software Engineering"
section: "Introduction"
layout: "title"       # title | content | divider | two-column | blank

# Optional per-slide background (overrides global bg_dark)
background:
  fill: "#1B1B1F"     # solid color fill; use $color_name or #RRGGBB

# Optional per-slide style overrides (merged over global style.yaml)
style_overrides:
  colors:
    bg_dark: "#0D1117"
  typography:
    heading_size: 36

# Elements placed on the slide, rendered in order
elements:
  - type: shape
    shape: rectangle
    left: 0
    top: 0
    width: 13.333
    height: 0.12
    fill: "$accent_blue"

  - type: textbox
    left: 0.8
    top: 1.5
    width: 11.0
    height: 1.8
    text: "Production-Grade AI-Assisted\nSoftware Engineering"
    font: "$body_font"
    font_size: 36
    font_color: "$text_white"
    font_bold: true
    alignment: left       # left | center | right | justify

  - type: textbox
    left: 0.8
    top: 4.4
    width: 10.0
    height: 0.8
    text: "Beyond Vibe Coding: Engineering with AI for Real-World Software"
    font: "$body_font"
    font_size: 20
    font_color: "$text_gray"

  - type: shape
    shape: rounded_rectangle
    left: 0.8
    top: 1.5
    width: 2.8
    height: 0.55
    fill: "$accent_blue"
    corner_radius: 0.1
    rotation: 270           # degrees; vertical text bottom-to-top
    text: "HYPER-VELOCITY ENGINEERING"
    text_font: "$body_font"
    text_size: 11
    text_color: "$text_white"
    text_bold: true

  - type: image
    path: "images/background.png"
    left: 0
    top: 0
    width: 13.333
    height: 7.5
    rotation: 0              # optional; degrees 0-360

  - type: rich_text
    left: 0.8
    top: 5.8
    width: 10.0
    height: 0.6
    segments:
      - text: "GitHub Copilot  |  "
        font: "$body_font"
        size: 14
        color: "$text_gray"
      - text: "context engineering"
        font: "$code_font"
        size: 14
        color: "$code_inline"
      - text: "  |  RPI Workflow"
        font: "$body_font"
        size: 14
        color: "$text_gray"

  - type: card
    left: 0.8
    top: 1.4
    width: 5.5
    height: 2.8
    title: "WHAT MOST TEAMS DO"
    title_color: "$text_white"
    title_size: 16
    title_bold: true
    accent_bar: true
    accent_color: "$accent_teal"
    content:
      - bullet: "Open Copilot Chat, type a prompt, paste the result"
        color: "$text_white"
      - bullet: "No structure, no verification, no persistence"
        color: "$text_gray"

  - type: arrow_flow
    left: 1.0
    top: 3.0
    width: 11.0
    height: 1.5
    items:
      - label: "Research"
        color: "$accent_blue"
      - label: "Plan"
        color: "$accent_teal"
      - label: "Implement"
        color: "$accent_green"

  - type: numbered_step
    left: 1.0
    top: 2.0
    width: 5.0
    height: 0.8
    number: 1
    label: "Configure VS Code Extensions"
    description: "Install the HVE extension pack."
    accent_color: "$accent_blue"

# Speaker notes (required for all content slides)
speaker_notes: |
  Welcome to the HVE workshop. This presentation covers how to use AI
  as a reliable engineering partner rather than a copy-paste tool.
  Key points: structured workflows, context engineering, verification.
```

## Supported Element Types

| Type | Description | Required Fields |
|---|---|---|
| `shape` | Rectangle, rounded rectangle, arrow, etc. | `shape`, `left`, `top`, `width`, `height` |
| `textbox` | Plain text box | `left`, `top`, `width`, `height`, `text` |
| `rich_text` | Mixed font/color text segments | `left`, `top`, `width`, `height`, `segments` |
| `image` | PNG image placement | `path`, `left`, `top`, `width`, `height` |
| `card` | Styled panel with optional title and bullets | `left`, `top`, `width`, `height` |
| `arrow_flow` | Horizontal arrow flow diagram | `left`, `top`, `width`, `height`, `items` |
| `numbered_step` | Numbered step with label and description | `left`, `top`, `width`, `height`, `number`, `label` |

## Supported Shape Types

| Shape | python-pptx Constant |
|---|---|
| `rectangle` | `MSO_SHAPE.RECTANGLE` |
| `rounded_rectangle` | `MSO_SHAPE.ROUNDED_RECTANGLE` |
| `right_arrow` | `MSO_SHAPE.RIGHT_ARROW` |
| `chevron` | `MSO_SHAPE.CHEVRON` |
| `oval` | `MSO_SHAPE.OVAL` |
| `diamond` | `MSO_SHAPE.DIAMOND` |
| `pentagon` | `MSO_SHAPE.PENTAGON` |
| `hexagon` | `MSO_SHAPE.HEXAGON` |
| `right_triangle` | `MSO_SHAPE.RIGHT_TRIANGLE` |

## Slide-Level Fields

| Field | Type | Description |
|---|---|---|
| `slide` | `int` | 1-based slide number |
| `title` | `string` | Slide title (informational) |
| `section` | `string` | Optional section grouping |
| `layout` | `string` | Informational layout hint: `title`, `content`, `divider`, `two-column`, `blank` |
| `background` | `object` | Per-slide background; contains `fill` with a color value. Overrides global `bg_dark` |
| `style_overrides` | `object` | Per-slide color and typography overrides merged over global style |
| `speaker_notes` | `string` | Speaker notes text; required when `speaker_notes_required` is true |

## Common Element Fields

These optional fields apply to `shape`, `textbox`, and `image` element types:

| Field | Type | Default | Description |
|---|---|---|---|
| `left` | `float` | — | Horizontal position in inches |
| `top` | `float` | — | Vertical position in inches |
| `width` | `float` | — | Element width in inches |
| `height` | `float` | — | Element height in inches |
| `name` | `string` | auto | Shape name for identification |
| `rotation` | `float` | `0` | Rotation in degrees (0–360); 90 = clockwise quarter turn, 270 = counter-clockwise |

## Textbox Fields

| Field | Type | Default | Description |
|---|---|---|---|
| `text` | `string` | — | Text content; use `\n` for line breaks |
| `font` | `string` | `$body_font` | Font family name or `$reference` |
| `font_size` | `int` | `body_size` | Font size in points |
| `font_color` | `string` | `$text_white` | Text color as `$name` or `#RRGGBB` |
| `font_bold` | `bool` | `false` | Bold text weight. `bold` is accepted as an alias |
| `italic` | `bool` | `false` | Italic text style |
| `alignment` | `string` | inherited | Paragraph alignment: `left`, `center`, `right`, `justify` |

## Shape Text Fields

When a shape contains inline text, use these prefixed fields:

| Field | Type | Default | Description |
|---|---|---|---|
| `text` | `string` | — | Text displayed inside the shape |
| `text_font` | `string` | `$body_font` | Font family for shape text |
| `text_size` | `int` | `16` | Font size in points for shape text |
| `text_color` | `string` | — | Text color as `$name` or `#RRGGBB` |
| `text_bold` | `bool` | `false` | Bold text weight for shape text |
