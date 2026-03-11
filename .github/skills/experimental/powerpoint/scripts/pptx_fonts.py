"""Font normalization, matching, and extraction utilities.

Centralizes font-related constants and functions used by
build_deck.py, extract_content.py, and validate_deck.py.
"""

from pptx.enum.text import PP_ALIGN
from pptx_colors import rgb_to_hex

FONT_WEIGHT_SUFFIXES = (
    " Semibold",
    " SemiBold",
    " Bold",
    " Light",
    " Thin",
    " Black",
    " Medium",
    " ExtraBold",
    " ExtraLight",
)

ALIGNMENT_MAP = {
    "left": PP_ALIGN.LEFT,
    "center": PP_ALIGN.CENTER,
    "right": PP_ALIGN.RIGHT,
    "justify": PP_ALIGN.JUSTIFY,
}

ALIGNMENT_REVERSE_MAP = {1: "left", 2: "center", 3: "right", 4: "justify"}


def normalize_font_family(name: str) -> str:
    """Strip weight suffixes from a font name to get the base family."""
    for suffix in FONT_WEIGHT_SUFFIXES:
        if name.endswith(suffix):
            return name[: -len(suffix)]
    return name


def font_family_matches(font_name: str, expected_fonts: set[str]) -> bool:
    """Check if a font matches expected fonts.

    Weight variants (e.g. Segoe UI Semibold) are treated as
    compatible with the base family.
    """
    if font_name in expected_fonts:
        return True
    base = font_name
    for suffix in FONT_WEIGHT_SUFFIXES:
        if font_name.endswith(suffix):
            base = font_name[: -len(suffix)]
            break
    for expected in expected_fonts:
        exp_base = expected
        for suffix in FONT_WEIGHT_SUFFIXES:
            if expected.endswith(suffix):
                exp_base = expected[: -len(suffix)]
                break
        if base == exp_base:
            return True
    return False


def extract_font_info(font) -> dict:
    """Extract font information from a python-pptx font object."""
    info = {}
    if font.name:
        info["font"] = font.name
    if font.size:
        info["size"] = int(font.size.pt)
    try:
        if font.color and font.color.rgb:
            info["color"] = rgb_to_hex(font.color.rgb)
    except (AttributeError, TypeError):
        pass
    if font.bold:
        info["bold"] = True
    if font.italic:
        info["italic"] = True
    if font.underline:
        info["underline"] = True
    # Character spacing (spc attribute in hundredths of a point)
    spc = _extract_char_spacing(font)
    if spc is not None:
        info["char_spacing"] = spc
    return info


def _extract_char_spacing(font) -> float | None:
    """Extract character spacing from font's underlying XML (a:rPr spc attribute).

    Returns spacing in points (spc is stored in hundredths of a point).
    """
    try:
        rpr = font._element
        spc_val = rpr.get("spc")
        if spc_val is not None:
            return int(spc_val) / 100.0
    except (AttributeError, TypeError):
        pass
    return None


def extract_paragraph_font(paragraph) -> dict:
    """Extract font properties from a paragraph's default run properties.

    python-pptx exposes paragraph-level defaults via ``paragraph.font``.
    Many PPTX files store styling here rather than on individual runs.
    """
    info = {}
    font = paragraph.font
    if font.name:
        info["font"] = font.name
    if font.size:
        info["size"] = int(font.size.pt)
    try:
        if font.color and font.color.rgb:
            info["color"] = rgb_to_hex(font.color.rgb)
    except (AttributeError, TypeError):
        pass
    if font.bold is True:
        info["bold"] = True
    if font.italic is True:
        info["italic"] = True
    return info


def extract_alignment(paragraph) -> str | None:
    """Map a paragraph alignment enum to a string."""
    al = paragraph.alignment
    if al is None:
        return None
    return ALIGNMENT_REVERSE_MAP.get(int(al))
