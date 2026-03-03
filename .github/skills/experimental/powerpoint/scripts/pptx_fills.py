"""Fill and line application/extraction utilities for PowerPoint skill scripts.

Handles solid, gradient, and pattern fills plus line/border properties.
"""

from lxml import etree
from pptx.enum.dml import MSO_FILL, MSO_LINE_DASH_STYLE, MSO_PATTERN_TYPE
from pptx.oxml.ns import qn
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
        if "alpha" in fill_spec:
            alpha_val = str(int(fill_spec["alpha"] * 1000))
            solid_el = shape.fill._fill._solidFill
            if solid_el is not None and len(solid_el) > 0:
                color_el = solid_el[0]
                existing = color_el.find(qn('a:alpha'))
                if existing is not None:
                    existing.set('val', alpha_val)
                else:
                    alpha_sub = etree.SubElement(color_el, qn('a:alpha'))
                    alpha_sub.set('val', alpha_val)

    elif fill_type == "gradient":
        shape.fill.gradient()
        shape.fill.gradient_angle = fill_spec.get("angle", 90)
        stops_data = fill_spec.get("stops", [])

        # Add extra gradient stops if needed (python-pptx defaults to 2)
        existing_count = len(shape.fill.gradient_stops)
        if len(stops_data) > existing_count:
            gs_lst = shape.fill._fill._element.find(qn('a:gsLst'))
            if gs_lst is not None:
                for _ in range(len(stops_data) - existing_count):
                    new_gs = etree.SubElement(gs_lst, qn('a:gs'))
                    new_gs.set('pos', '0')
                    etree.SubElement(new_gs, qn('a:srgbClr')).set('val', '000000')

        for i, stop in enumerate(stops_data):
            if i < len(shape.fill.gradient_stops):
                gs = shape.fill.gradient_stops[i]
                color_spec = resolve_color(stop["color"], colors)
                apply_color_spec(gs.color, color_spec)
                gs.position = stop["position"]
                # Apply alpha on the gradient stop's color element
                if "alpha" in stop:
                    alpha_val = str(int(stop["alpha"] * 1000))
                    gs_el = gs._element
                    color_el = gs_el[0] if len(gs_el) > 0 else None
                    if color_el is not None:
                        existing = color_el.find(qn('a:alpha'))
                        if existing is not None:
                            existing.set('val', alpha_val)
                        else:
                            alpha_sub = etree.SubElement(color_el, qn('a:alpha'))
                            alpha_sub.set('val', alpha_val)

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
        # Apply alpha on pattern fore/back color elements
        patt_el = shape.fill._fill._pattFill
        if patt_el is not None:
            if "fore_alpha" in fill_spec:
                fg = patt_el.find(qn('a:fgClr'))
                if fg is not None and len(fg) > 0:
                    alpha_val = str(int(fill_spec["fore_alpha"] * 1000))
                    existing = fg[0].find(qn('a:alpha'))
                    if existing is not None:
                        existing.set('val', alpha_val)
                    else:
                        etree.SubElement(fg[0], qn('a:alpha')).set('val', alpha_val)
            if "back_alpha" in fill_spec:
                bg = patt_el.find(qn('a:bgClr'))
                if bg is not None and len(bg) > 0:
                    alpha_val = str(int(fill_spec["back_alpha"] * 1000))
                    existing = bg[0].find(qn('a:alpha'))
                    if existing is not None:
                        existing.set('val', alpha_val)
                    else:
                        etree.SubElement(bg[0], qn('a:alpha')).set('val', alpha_val)


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
            color = extract_color(fill.fore_color) or rgb_to_hex(fill.fore_color.rgb)
            # Check for alpha on the color element at XML level
            try:
                solid_el = fill._fill._solidFill
                if solid_el is not None and len(solid_el) > 0:
                    alpha_el = solid_el[0].find(qn('a:alpha'))
                    if alpha_el is not None:
                        alpha_val = int(alpha_el.get('val', '100000'))
                        return {"type": "solid", "color": color, "alpha": round(alpha_val / 1000, 1)}
            except (AttributeError, TypeError):
                pass
            return color

        if fill_type == MSO_FILL.GRADIENT:
            stops = []
            for gs in fill.gradient_stops:
                color = extract_color(gs.color)
                if color is not None:
                    stop_data = {
                        "position": gs.position,
                        "color": color,
                    }
                    # Extract alpha from the gradient stop's color element
                    alpha_el = gs._element.find('.//' + qn('a:alpha'))
                    if alpha_el is not None:
                        alpha_val = int(alpha_el.get('val', '100000'))
                        stop_data["alpha"] = round(alpha_val / 1000, 1)
                    stops.append(stop_data)
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
            result = {
                "type": "pattern",
                "pattern": pattern_name,
                "fore_color": extract_color(fill.fore_color) or rgb_to_hex(fill.fore_color.rgb),
                "back_color": extract_color(fill.back_color) or rgb_to_hex(fill.back_color.rgb),
            }
            # Extract alpha from pattern fore/back color elements
            try:
                patt_el = fill._fill._pattFill
                if patt_el is not None:
                    fg = patt_el.find(qn('a:fgClr'))
                    if fg is not None and len(fg) > 0:
                        alpha_el = fg[0].find(qn('a:alpha'))
                        if alpha_el is not None:
                            result["fore_alpha"] = round(int(alpha_el.get('val', '100000')) / 1000, 1)
                    bg = patt_el.find(qn('a:bgClr'))
                    if bg is not None and len(bg) > 0:
                        alpha_el = bg[0].find(qn('a:alpha'))
                        if alpha_el is not None:
                            result["back_alpha"] = round(int(alpha_el.get('val', '100000')) / 1000, 1)
            except (AttributeError, TypeError):
                pass
            return result
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


def extract_effect_list(shape) -> dict | None:
    """Extract outer shadow effect from a shape's effectLst.

    Returns dict with shadow properties when present, None otherwise.
    """
    try:
        sp = shape._element
        effect_lst = sp.find('.//' + qn('a:effectLst'))
        if effect_lst is None or len(effect_lst) == 0:
            return None
        shadow = effect_lst.find(qn('a:outerShdw'))
        if shadow is None:
            return None
        result = {"type": "outer_shadow"}
        for attr in ('blurRad', 'dist', 'dir', 'algn', 'rotWithShape'):
            val = shadow.get(attr)
            if val is not None:
                result[attr] = val
        color_el = shadow[0] if len(shadow) > 0 else None
        if color_el is not None:
            tag = color_el.tag.split('}')[-1]
            if tag == 'prstClr':
                result["color"] = color_el.get('val', 'black')
                result["color_type"] = "preset"
            elif tag == 'srgbClr':
                result["color"] = '#' + color_el.get('val', '000000')
                result["color_type"] = "rgb"
            alpha_el = color_el.find(qn('a:alpha'))
            if alpha_el is not None:
                result["alpha"] = round(int(alpha_el.get('val', '100000')) / 1000, 1)
        return result
    except (AttributeError, TypeError, IndexError):
        return None


def apply_effect_list(shape, effect: dict):
    """Apply outer shadow effect to a shape's spPr element."""
    if not effect or effect.get("type") != "outer_shadow":
        return
    sp_pr = shape._element.find(qn('p:spPr'))
    if sp_pr is None:
        sp_pr = shape._element.spPr

    # Remove existing effectLst
    existing = sp_pr.find(qn('a:effectLst'))
    if existing is not None:
        sp_pr.remove(existing)

    effect_lst = etree.SubElement(sp_pr, qn('a:effectLst'))
    shadow = etree.SubElement(effect_lst, qn('a:outerShdw'))
    for attr in ('blurRad', 'dist', 'dir', 'algn', 'rotWithShape'):
        if attr in effect:
            shadow.set(attr, str(effect[attr]))

    color_type = effect.get("color_type", "preset")
    color_val = effect.get("color", "black")
    if color_type == "preset":
        color_el = etree.SubElement(shadow, qn('a:prstClr'))
        color_el.set('val', color_val)
    elif color_type == "rgb":
        color_el = etree.SubElement(shadow, qn('a:srgbClr'))
        color_el.set('val', color_val.lstrip('#'))
    else:
        color_el = etree.SubElement(shadow, qn('a:prstClr'))
        color_el.set('val', 'black')

    if "alpha" in effect:
        alpha_sub = etree.SubElement(color_el, qn('a:alpha'))
        alpha_sub.set('val', str(int(effect["alpha"] * 1000)))
