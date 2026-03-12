---
description: 'Custom Python rendering template for complex slide drawings beyond content.yaml capabilities'
---

# Content Extra Python Template

Use this template when a slide requires complex drawings that cannot be expressed through `content.yaml` element definitions. Create a `content-extra.py` file in the slide's content folder alongside its `content.yaml`.

## Instructions

* The `render()` function signature is fixed — do not change the parameter list.
* The build script calls `render()` after placing standard `content.yaml` elements, so custom shapes draw on top of YAML-defined elements.
* Use the `style` dictionary to access defaults and metadata.
* Use `#RRGGBB` hex values for all colors. Named color references (`$color_name`) are not supported.
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
        style: Style dictionary with defaults and metadata.
        content_dir: Path to this slide's content directory for image references.
    """
    # Custom drawing logic here
    # Example: complex layered architecture diagram
    layers = [
        ("Application Layer", "#0078D4", 1.0),
        ("Service Layer", "#00B4D8", 2.5),
        ("Data Layer", "#10B981", 4.0),
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
| `style` | `dict` | Style dictionary with `defaults` and `metadata` keys |
| `content_dir` | `pathlib.Path` | Path to the slide's content directory for referencing local assets |

## Guidelines

* Keep custom scripts focused on a single slide's needs. If the same drawing pattern repeats across slides, consider defining a new element type in `content.yaml` instead.
* Use `#RRGGBB` hex values for all colors to keep the script self-contained and independent of global style configuration.
* Test the script independently by importing the function and passing mock objects before running the full build.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
