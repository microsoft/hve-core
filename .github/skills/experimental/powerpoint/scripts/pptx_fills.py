"""Fill and line application/extraction utilities for PowerPoint skill scripts.

Handles solid, gradient, and pattern fills plus line/border properties.
"""

from pptx.enum.dml import MSO_FILL, MSO_LINE_DASH_STYLE, MSO_PATTERN_TYPE
from pptx.util import Pt

from pptx_colors import apply_color_spec, apply_color_to_fill, extract_color, resolve_color, rgb_to_hex

DASH_STYLE_MAP = {
    "solid": MSO_LINE_DASH_STYLE.SOLID,
    "dash": MSO_LINE_DASH_STYLE.DASH,
    "dash_dot": MSO_LINE_DASH_STYLE.DASH_DOT,
    "dash_dot_dot": MSO_LINE_DASH_STYLE.DASH_DOT_DOT,
    "long_dash": MSO_LINE_DASH_STYLE.LONG_DASH,
    "long_dash_dot": MSO_LINE_DASH_STYLE.LONG_DASH_DOT,
    "round_dot": MSO_LINE_DASH_STYLE.ROUND_DOT,
    "square_dot": MSO_LINE_DASH_STYLE.SQUARE_DOT,
}

DASH_STYLE_REVERSE = {v: k for k, v in DASH_STYLE_MAP.items()}


def apply_fill(shape, fill_spec, colors: dict):
    """Apply fill specification to a shape or background.

    Supports:
      str — solid fill via resolve_color()
      dict with type: gradient — gradient fill with angle and stops
      dict with type: pattern — pattern fill with fore/back colors
      dict with type: solid — explicit solid fill
      None — no fill (background)
    """
    if fill_spec is None:
        shape.fill.background()
        return

    if isinstance(fill_spec, str):
        shape.fill.solid()
        color_spec = resolve_color(fill_spec, colors)
        apply_color_to_fill(shape.fill, color_spec)
        return

    if not isinstance(fill_spec, dict):
        return

    fill_type = fill_spec.get("type", "solid")

    if fill_type == "solid":
        shape.fill.solid()
        color_spec = resolve_color(fill_spec.get("color", "#000000"), colors)
        apply_color_to_fill(shape.fill, color_spec)

    elif fill_type == "gradient":
        shape.fill.gradient()
        shape.fill.gradient_angle = fill_spec.get("angle", 90)
        for i, stop in enumerate(fill_spec.get("stops", [])):
            if i < len(shape.fill.gradient_stops):
                gs = shape.fill.gradient_stops[i]
                color_spec = resolve_color(stop["color"], colors)
                apply_color_spec(gs.color, color_spec)
                gs.position = stop["position"]

    elif fill_type == "pattern":
        shape.fill.patterned()
        pattern_name = fill_spec.get("pattern", "CROSS").upper()
        shape.fill.pattern = getattr(
            MSO_PATTERN_TYPE, pattern_name, MSO_PATTERN_TYPE.CROSS
        )
        fore_spec = resolve_color(fill_spec.get("fore_color", "#000000"), colors)
        back_spec = resolve_color(fill_spec.get("back_color", "#FFFFFF"), colors)
        apply_color_spec(shape.fill.fore_color, fore_spec)
        apply_color_spec(shape.fill.back_color, back_spec)


def extract_fill(fill) -> dict | str | None:
    """Extract fill information from a shape's fill object.

    Returns:
      str — hex color string for solid fills
      dict — structured fill spec for gradient or pattern fills
      None — no fill or background fill
    """
    try:
        fill_type = fill.type
        if fill_type is None or fill_type == MSO_FILL.BACKGROUND:
            return None

        if fill_type == MSO_FILL.SOLID:
            return extract_color(fill.fore_color) or rgb_to_hex(fill.fore_color.rgb)

        if fill_type == MSO_FILL.GRADIENT:
            stops = []
            for gs in fill.gradient_stops:
                color = extract_color(gs.color)
                if color is not None:
                    stops.append({
                        "position": gs.position,
                        "color": color,
                    })
            result = {"type": "gradient", "stops": stops}
            try:
                result["angle"] = fill.gradient_angle
            except ValueError:
                pass
            return result

        if fill_type == MSO_FILL.PATTERNED:
            pattern_val = fill.pattern
            pattern_name = "cross"
            for attr in dir(MSO_PATTERN_TYPE):
                if attr.startswith("_"):
                    continue
                try:
                    if getattr(MSO_PATTERN_TYPE, attr) == pattern_val:
                        pattern_name = attr.lower()
                        break
                except (AttributeError, TypeError):
                    pass
            return {
                "type": "pattern",
                "pattern": pattern_name,
                "fore_color": extract_color(fill.fore_color) or rgb_to_hex(fill.fore_color.rgb),
                "back_color": extract_color(fill.back_color) or rgb_to_hex(fill.back_color.rgb),
            }
    except (AttributeError, TypeError):
        pass

    return None


def apply_line(shape, elem: dict, colors: dict):
    """Apply line/border properties from element definition.

    Reads line_color, line_width, and dash_style from elem dict.
    """
    if "line_color" in elem:
        color_spec = resolve_color(elem["line_color"], colors)
        apply_color_spec(shape.line.color, color_spec)
        shape.line.width = Pt(elem.get("line_width", 1))
        if "dash_style" in elem:
            shape.line.dash_style = DASH_STYLE_MAP.get(
                elem["dash_style"], MSO_LINE_DASH_STYLE.SOLID
            )
    else:
        shape.line.fill.background()


def extract_line(shape) -> dict:
    """Extract line/border properties from a shape."""
    result = {}
    try:
        line = shape.line
        if line.color and line.color.type is not None:
            result["line_color"] = extract_color(line.color) or rgb_to_hex(line.color.rgb)
        if line.width:
            result["line_width"] = round(line.width.pt, 1)
        if line.dash_style and line.dash_style != MSO_LINE_DASH_STYLE.SOLID:
            result["dash_style"] = DASH_STYLE_REVERSE.get(
                line.dash_style, "solid"
            )
    except (AttributeError, TypeError):
        pass
    return result
