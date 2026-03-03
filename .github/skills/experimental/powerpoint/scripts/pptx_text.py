"""Text frame, paragraph, and run property utilities for PowerPoint skill scripts.

Centralizes enhanced text properties (margins, auto-size, spacing, underline,
hyperlinks) used by build_deck.py and extract_content.py.
"""

from pptx.enum.text import MSO_AUTO_SIZE, MSO_VERTICAL_ANCHOR
from pptx.util import Inches, Pt

AUTO_SIZE_MAP = {
    "none": MSO_AUTO_SIZE.NONE,
    "fit": MSO_AUTO_SIZE.SHAPE_TO_FIT_TEXT,
    "shrink": MSO_AUTO_SIZE.TEXT_TO_FIT_SHAPE,
}

AUTO_SIZE_REVERSE = {
    MSO_AUTO_SIZE.NONE: "none",
    MSO_AUTO_SIZE.SHAPE_TO_FIT_TEXT: "fit",
    MSO_AUTO_SIZE.TEXT_TO_FIT_SHAPE: "shrink",
}

VERTICAL_ANCHOR_MAP = {
    "top": MSO_VERTICAL_ANCHOR.TOP,
    "middle": MSO_VERTICAL_ANCHOR.MIDDLE,
    "bottom": MSO_VERTICAL_ANCHOR.BOTTOM,
}

VERTICAL_ANCHOR_REVERSE = {
    MSO_VERTICAL_ANCHOR.TOP: "top",
    MSO_VERTICAL_ANCHOR.MIDDLE: "middle",
    MSO_VERTICAL_ANCHOR.BOTTOM: "bottom",
}

# EMU per inch constant for margin conversions
_EMU_PER_INCH = 914400


def apply_text_properties(text_frame, elem: dict):
    """Apply text frame-level properties from element definition.

    Supports: margin_left/right/top/bottom (inches), auto_size, vertical_anchor, word_wrap.
    """
    if "margin_left" in elem:
        text_frame.margin_left = Inches(elem["margin_left"])
    if "margin_right" in elem:
        text_frame.margin_right = Inches(elem["margin_right"])
    if "margin_top" in elem:
        text_frame.margin_top = Inches(elem["margin_top"])
    if "margin_bottom" in elem:
        text_frame.margin_bottom = Inches(elem["margin_bottom"])
    if "auto_size" in elem:
        text_frame.auto_size = AUTO_SIZE_MAP.get(elem["auto_size"], MSO_AUTO_SIZE.NONE)
    if "vertical_anchor" in elem:
        text_frame.vertical_anchor = VERTICAL_ANCHOR_MAP.get(elem["vertical_anchor"])
    if "word_wrap" in elem:
        text_frame.word_wrap = elem["word_wrap"]


def apply_paragraph_properties(paragraph, elem: dict):
    """Apply paragraph-level properties.

    Supports: space_before, space_after (pts), line_spacing (pts or factor), level.
    """
    if "space_before" in elem:
        paragraph.space_before = Pt(elem["space_before"])
    if "space_after" in elem:
        paragraph.space_after = Pt(elem["space_after"])
    if "line_spacing" in elem:
        val = elem["line_spacing"]
        if isinstance(val, float) and val < 10:
            # Factor-based spacing (e.g. 1.5 = 150%)
            paragraph.line_spacing = val
        else:
            paragraph.line_spacing = Pt(val)
    if "level" in elem:
        paragraph.level = elem["level"]


def apply_run_properties(run, elem: dict, colors: dict):
    """Apply run-level font properties beyond basic font/size/color/bold/italic.

    Supports: underline, hyperlink, char_spacing.
    When a hyperlink is set, the font color is re-applied afterward to prevent
    the automatic theme hyperlink color from overriding the intended color.
    """
    if elem.get("underline"):
        run.font.underline = True
    if "hyperlink" in elem:
        run.hyperlink.address = elem["hyperlink"]
        # Re-apply font color after hyperlink to override auto-coloring
        from pptx_colors import apply_color_to_font, resolve_color
        color_key = next((k for k in ("font_color", "text_color", "color") if k in elem), None)
        if color_key:
            apply_color_to_font(run.font.color, resolve_color(elem[color_key], colors))
    if "char_spacing" in elem:
        _apply_char_spacing(run.font, elem["char_spacing"])


def _apply_char_spacing(font, spacing_pt: float):
    """Apply character spacing to a font via the spc attribute on a:rPr.

    Args:
        font: python-pptx font object.
        spacing_pt: Spacing in points (converted to hundredths of a point for XML).
    """
    rpr = font._element
    spc_val = str(int(spacing_pt * 100))
    rpr.set('spc', spc_val)


def extract_text_frame_properties(text_frame) -> dict:
    """Extract text frame-level properties (margins, auto_size, vertical_anchor)."""
    props = {}
    if text_frame.margin_left is not None:
        props["margin_left"] = round(text_frame.margin_left / _EMU_PER_INCH, 3)
    if text_frame.margin_right is not None:
        props["margin_right"] = round(text_frame.margin_right / _EMU_PER_INCH, 3)
    if text_frame.margin_top is not None:
        props["margin_top"] = round(text_frame.margin_top / _EMU_PER_INCH, 3)
    if text_frame.margin_bottom is not None:
        props["margin_bottom"] = round(text_frame.margin_bottom / _EMU_PER_INCH, 3)
    if text_frame.auto_size is not None:
        label = AUTO_SIZE_REVERSE.get(text_frame.auto_size)
        if label:
            props["auto_size"] = label
    if text_frame.vertical_anchor is not None:
        label = VERTICAL_ANCHOR_REVERSE.get(text_frame.vertical_anchor)
        if label:
            props["vertical_anchor"] = label
    return props


def extract_paragraph_properties(paragraph) -> dict:
    """Extract paragraph-level spacing properties."""
    props = {}
    if paragraph.space_before is not None:
        props["space_before"] = round(paragraph.space_before.pt, 1)
    if paragraph.space_after is not None:
        props["space_after"] = round(paragraph.space_after.pt, 1)
    if paragraph.line_spacing is not None:
        if isinstance(paragraph.line_spacing, float):
            props["line_spacing"] = paragraph.line_spacing
        else:
            props["line_spacing"] = round(paragraph.line_spacing.pt, 1)
    if paragraph.level and paragraph.level > 0:
        props["level"] = paragraph.level
    return props


def extract_run_properties(run) -> dict:
    """Extract run-level properties beyond basic font info (underline, hyperlink, char_spacing)."""
    props = {}
    if run.font.underline:
        props["underline"] = True
    try:
        if run.hyperlink and run.hyperlink.address:
            props["hyperlink"] = run.hyperlink.address
    except (AttributeError, TypeError):
        pass
    # Character spacing
    from pptx_fonts import _extract_char_spacing
    spc = _extract_char_spacing(run.font)
    if spc is not None:
        props["char_spacing"] = spc
    return props
