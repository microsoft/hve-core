# Content Extra Python Template

Use this template when a slide requires complex drawings that cannot be expressed through `content.yaml` element definitions. Create a `content-extra.py` file in the slide's content folder alongside its `content.yaml`.

## Instructions

* The `render()` function signature is fixed — do not change the parameter list.
* The build script calls `render()` after placing standard `content.yaml` elements, so custom shapes draw on top of YAML-defined elements.
* Use the `style` dictionary to access resolved colors, typography, and defaults for consistency with the rest of the deck.
* Use the `content_dir` path to reference images or other assets in the slide's folder.
* Import only from `pptx` and Python standard library modules. Do not add external dependencies beyond those listed in the skill prerequisites.

## Template

```python
"""Custom drawing for slide NNN — description of what this draws."""
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor


def render(slide, style, content_dir):
    """Add custom elements to the slide.

    Args:
        slide: python-pptx slide object (already created with base elements).
        style: Resolved style dictionary (global merged with per-slide overrides).
        content_dir: Path to this slide's content directory for image references.
    """
    colors = style["colors"]
    # Custom drawing logic here
    # Example: complex layered architecture diagram
    layers = [
        ("Application Layer", colors["accent_blue"], 1.0),
        ("Service Layer", colors["accent_teal"], 2.5),
        ("Data Layer", colors["accent_green"], 4.0),
    ]
    for label, color, top in layers:
        shape = slide.shapes.add_shape(
            1,  # MSO_SHAPE.RECTANGLE
            Inches(2.0), Inches(top), Inches(9.0), Inches(1.2)
        )
        shape.fill.solid()
        shape.fill.fore_color.rgb = RGBColor.from_string(color.lstrip("#"))
        tf = shape.text_frame
        tf.text = label
```

## Function Parameters

| Parameter | Type | Description |
|---|---|---|
| `slide` | `pptx.slide.Slide` | The slide object with base elements already placed from `content.yaml` |
| `style` | `dict` | Resolved style dictionary with `colors`, `typography`, and `defaults` keys |
| `content_dir` | `pathlib.Path` | Path to the slide's content directory for referencing local assets |

## Guidelines

* Keep custom scripts focused on a single slide's needs. If the same drawing pattern repeats across slides, consider defining a new element type in `content.yaml` instead.
* Use `style["colors"]` for all color values rather than hardcoding hex strings to maintain consistency when the palette changes.
* Test the script independently by importing the function and passing mock objects before running the full build.
