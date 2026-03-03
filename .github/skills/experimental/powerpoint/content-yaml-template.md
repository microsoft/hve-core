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

  - type: table
    left: 1.0
    top: 2.0
    width: 11.0
    height: 3.0
    columns:
      - width: 3.0
      - width: 4.0
      - width: 4.0
    rows:
      - cells:
          - text: "Feature"
            font_bold: true
            fill: "$accent_blue"
            font_color: "$text_white"
          - text: "Status"
            font_bold: true
            fill: "$accent_blue"
            font_color: "$text_white"
          - text: "Notes"
            font_bold: true
            fill: "$accent_blue"
            font_color: "$text_white"
      - cells:
          - text: "Authentication"
          - text: "Complete"
            font_color: "$accent_green"
          - text: "OAuth 2.0 with PKCE"
      - cells:
          - text: "Merge status"
            merge_right: 2        # merge this cell across 2 additional columns
          - text: ""
          - text: ""
    first_row: true               # style first row as header
    horz_banding: true            # alternate row shading

  - type: chart
    left: 1.0
    top: 2.0
    width: 10.0
    height: 5.0
    chart_type: column_clustered  # see Supported Chart Types table
    categories:
      - "Q1"
      - "Q2"
      - "Q3"
      - "Q4"
    series:
      - name: "Revenue"
        values: [100, 150, 130, 180]
      - name: "Costs"
        values: [80, 90, 85, 95]
    title: "Quarterly Results"
    has_legend: true

  - type: connector
    connector_type: elbow         # straight | elbow | curve
    begin_x: 2.0
    begin_y: 3.0
    end_x: 8.0
    end_y: 5.0
    line_color: "$accent_blue"
    line_width: 2
    dash_style: solid             # see Line Dash Styles table
    head_end: none                # none | arrow | triangle | stealth | diamond | oval
    tail_end: arrow

  - type: group
    left: 1.0
    top: 2.0
    width: 5.0
    height: 3.0
    elements:
      - type: shape
        shape: rectangle
        left: 1.0
        top: 2.0
        width: 2.0
        height: 1.0
        fill: "$accent_blue"
      - type: textbox
        left: 1.2
        top: 2.2
        width: 1.6
        height: 0.6
        text: "Group Title"
        font_color: "$text_white"

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
| `table` | Data table with headers, merging, and styling | `left`, `top`, `width`, `height`, `columns`, `rows` |
| `chart` | Data chart (bar, line, pie, scatter, etc.) | `left`, `top`, `width`, `height`, `chart_type`, `categories`, `series` |
| `connector` | Line connecting two points with optional arrows | `connector_type`, `begin_x`, `begin_y`, `end_x`, `end_y` |
| `group` | Container grouping nested child elements | `left`, `top`, `width`, `height`, `elements` |

## Supported Shape Types

| Shape | python-pptx Constant |
|---|---|
| `rectangle` | `MSO_SHAPE.RECTANGLE` |
| `rounded_rectangle` | `MSO_SHAPE.ROUNDED_RECTANGLE` |
| `oval` | `MSO_SHAPE.OVAL` |
| `circle` | `MSO_SHAPE.OVAL` (alias) |
| `diamond` | `MSO_SHAPE.DIAMOND` |
| `pentagon` | `MSO_SHAPE.PENTAGON` |
| `hexagon` | `MSO_SHAPE.HEXAGON` |
| `right_triangle` | `MSO_SHAPE.RIGHT_TRIANGLE` |
| `trapezoid` | `MSO_SHAPE.TRAPEZOID` |
| `parallelogram` | `MSO_SHAPE.PARALLELOGRAM` |
| `cross` | `MSO_SHAPE.CROSS` |
| `donut` | `MSO_SHAPE.DONUT` |
| `cloud` | `MSO_SHAPE.CLOUD` |
| `star_5_point` | `MSO_SHAPE.STAR_5_POINT` |
| `right_arrow` | `MSO_SHAPE.RIGHT_ARROW` |
| `left_arrow` | `MSO_SHAPE.LEFT_ARROW` |
| `up_arrow` | `MSO_SHAPE.UP_ARROW` |
| `down_arrow` | `MSO_SHAPE.DOWN_ARROW` |
| `left_right_arrow` | `MSO_SHAPE.LEFT_RIGHT_ARROW` |
| `notched_right_arrow` | `MSO_SHAPE.NOTCHED_RIGHT_ARROW` |
| `chevron` | `MSO_SHAPE.CHEVRON` |
| `flowchart_process` | `MSO_SHAPE.FLOWCHART_PROCESS` |
| `flowchart_decision` | `MSO_SHAPE.FLOWCHART_DECISION` |
| `flowchart_terminator` | `MSO_SHAPE.FLOWCHART_TERMINATOR` |
| `flowchart_data` | `MSO_SHAPE.FLOWCHART_DATA` |
| `left_brace` | `MSO_SHAPE.LEFT_BRACE` |
| `right_brace` | `MSO_SHAPE.RIGHT_BRACE` |
| `callout_rectangle` | `MSO_SHAPE.RECTANGULAR_CALLOUT` |
| `callout_rounded_rectangle` | `MSO_SHAPE.ROUNDED_RECTANGULAR_CALLOUT` |

## Supported Chart Types

| Chart Type | python-pptx Constant |
|---|---|
| `column_clustered` | `XL_CHART_TYPE.COLUMN_CLUSTERED` |
| `column_stacked` | `XL_CHART_TYPE.COLUMN_STACKED` |
| `bar_clustered` | `XL_CHART_TYPE.BAR_CLUSTERED` |
| `bar_stacked` | `XL_CHART_TYPE.BAR_STACKED` |
| `line` | `XL_CHART_TYPE.LINE` |
| `line_markers` | `XL_CHART_TYPE.LINE_MARKERS` |
| `pie` | `XL_CHART_TYPE.PIE` |
| `doughnut` | `XL_CHART_TYPE.DOUGHNUT` |
| `area` | `XL_CHART_TYPE.AREA` |
| `radar` | `XL_CHART_TYPE.RADAR` |
| `scatter` | `XL_CHART_TYPE.XY_SCATTER` |
| `bubble` | `XL_CHART_TYPE.BUBBLE` |

## Line Dash Styles

| Style | python-pptx Constant |
|---|---|
| `solid` | `MSO_LINE_DASH_STYLE.SOLID` |
| `dash` | `MSO_LINE_DASH_STYLE.DASH` |
| `dash_dot` | `MSO_LINE_DASH_STYLE.DASH_DOT` |
| `dash_dot_dot` | `MSO_LINE_DASH_STYLE.DASH_DOT_DOT` |
| `long_dash` | `MSO_LINE_DASH_STYLE.LONG_DASH` |
| `long_dash_dot` | `MSO_LINE_DASH_STYLE.LONG_DASH_DOT` |
| `round_dot` | `MSO_LINE_DASH_STYLE.ROUND_DOT` |
| `square_dot` | `MSO_LINE_DASH_STYLE.SQUARE_DOT` |

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
| `font_color` | `string` | `$text_white` | Text color as `$name`, `#RRGGBB`, or `@theme_name` |
| `font_bold` | `bool` | `false` | Bold text weight. `bold` is accepted as an alias |
| `italic` | `bool` | `false` | Italic text style |
| `underline` | `bool` | `false` | Underline text decoration |
| `alignment` | `string` | inherited | Paragraph alignment: `left`, `center`, `right`, `justify` |
| `hyperlink` | `string` | — | URL applied to the text run |
| `space_before` | `float` | — | Space before paragraph in points |
| `space_after` | `float` | — | Space after paragraph in points |
| `line_spacing` | `float` | — | Line spacing in points |
| `level` | `int` | `0` | Paragraph indentation level (0–8) |
| `margin_left` | `float` | — | Text frame left margin in inches |
| `margin_right` | `float` | — | Text frame right margin in inches |
| `margin_top` | `float` | — | Text frame top margin in inches |
| `margin_bottom` | `float` | — | Text frame bottom margin in inches |
| `auto_size` | `string` | — | Auto-size behavior: `none`, `fit` (shape to fit text), `shrink` (text to fit shape) |
| `vertical_anchor` | `string` | — | Vertical text alignment within frame: `top`, `middle`, `bottom` |

## Shape Text Fields

When a shape contains inline text, use these prefixed fields:

| Field | Type | Default | Description |
|---|---|---|---|
| `text` | `string` | — | Text displayed inside the shape |
| `text_font` | `string` | `$body_font` | Font family for shape text |
| `text_size` | `int` | `16` | Font size in points for shape text |
| `text_color` | `string` | — | Text color as `$name` or `#RRGGBB` |
| `text_bold` | `bool` | `false` | Bold text weight for shape text |

## Color Syntax

Color values in content YAML accept four formats:

| Syntax | Example | Description |
|---|---|---|
| Named reference | `"$accent_blue"` | Resolves against the `colors` map in `style.yaml` |
| Hex value | `"#0078D4"` | Direct RGB hex color |
| Theme reference | `"@accent_1"` | Maps to the presentation theme's `MSO_THEME_COLOR` enum |
| Theme with brightness | `{theme: "accent_1", brightness: 0.4}` | Theme color with brightness adjustment (-1.0 to 1.0) |

Available theme color names: `accent_1` through `accent_6`, `dark_1`, `dark_2`, `light_1`, `light_2`, `text_1`, `text_2`, `background_1`, `background_2`, `hyperlink`, `followed_hyperlink`.

## Fill Syntax

The `fill` field on shapes and backgrounds accepts three formats:

### Solid fill

```yaml
fill: "$accent_blue"       # named reference
fill: "#0078D4"             # hex value
fill: "@accent_1"           # theme color
```

### Gradient fill

```yaml
fill:
  type: "gradient"
  angle: 90                 # gradient direction in degrees
  stops:
    - position: 0
      color: "#0078D4"
    - position: 50
      color: "#00B4D8"
    - position: 100
      color: "#10B981"
```

### Pattern fill

```yaml
fill:
  type: "pattern"
  pattern: "cross"          # MSO_PATTERN_TYPE name (e.g., cross, diagonal_stripe)
  foreground: "#000000"
  background: "#FFFFFF"
```

## Line Properties

Line/border properties apply to shapes and connectors:

| Field | Type | Description |
|---|---|---|
| `line_color` | `string` | Line color (any color syntax) |
| `line_width` | `float` | Line width in points |
| `dash_style` | `string` | Dash style (see Line Dash Styles table) |

## Connector Fields

| Field | Type | Default | Description |
|---|---|---|---|
| `connector_type` | `string` | `straight` | Connector routing: `straight`, `elbow`, `curve` |
| `begin_x` | `float` | — | Start X position in inches |
| `begin_y` | `float` | — | Start Y position in inches |
| `end_x` | `float` | — | End X position in inches |
| `end_y` | `float` | — | End Y position in inches |
| `head_end` | `string` | `none` | Start arrowhead: `none`, `arrow`, `triangle`, `stealth`, `diamond`, `oval` |
| `tail_end` | `string` | `none` | End arrowhead: `none`, `arrow`, `triangle`, `stealth`, `diamond`, `oval` |

## Table Fields

| Field | Type | Default | Description |
|---|---|---|---|
| `columns` | `list` | — | Column definitions with `width` in inches |
| `rows` | `list` | — | Row definitions with `cells` list |
| `first_row` | `bool` | `false` | Apply first-row (header) banding |
| `last_row` | `bool` | `false` | Apply last-row banding |
| `first_col` | `bool` | `false` | Apply first-column banding |
| `last_col` | `bool` | `false` | Apply last-column banding |
| `horz_banding` | `bool` | `false` | Apply horizontal row banding |
| `vert_banding` | `bool` | `false` | Apply vertical column banding |

### Cell Fields

| Field | Type | Description |
|---|---|---|
| `text` | `string` | Cell text content |
| `fill` | `string` | Cell background color |
| `font_color` | `string` | Cell text color |
| `font_bold` | `bool` | Bold text in cell |
| `font_size` | `int` | Font size in points |
| `font` | `string` | Font family |
| `vertical_anchor` | `string` | Vertical alignment: `top`, `middle`, `bottom` |
| `merge_right` | `int` | Merge across N additional columns |
| `merge_down` | `int` | Merge across N additional rows |

## Chart Fields

| Field | Type | Default | Description |
|---|---|---|---|
| `chart_type` | `string` | `column_clustered` | Chart type (see Supported Chart Types table) |
| `categories` | `list` | — | Category labels for x-axis |
| `series` | `list` | — | Data series; each has `name` and `values` |
| `title` | `string` | — | Chart title |
| `has_legend` | `bool` | `true` | Display chart legend |

Scatter and bubble charts use `data_points` instead of `categories`/`values`:

```yaml
series:
  - name: "Scatter Data"
    data_points:
      - x: 1.0
        y: 2.5
      - x: 3.0
        y: 4.1
```

## Placeholder Content

When using a template PPTX with themed layouts, populate layout placeholders with the `placeholders` section:

```yaml
slide: 1
layout: "Title Slide"
placeholders:
  0: "Presentation Title"      # placeholder index 0 (typically title)
  1: "Subtitle text here"      # placeholder index 1 (typically subtitle)
elements: []
speaker_notes: |
  Opening slide with template placeholders populated.
```

Placeholder indices correspond to the layout's placeholder positions. Use the `--template` argument with `build_deck.py` to load layouts from the template file, and define layout name mappings in `style.yaml` under the `layouts` section.
