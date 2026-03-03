"""Color resolution and conversion utilities for PowerPoint skill scripts.

Supports $name references against a color dictionary, #RRGGBB hex values,
and @theme_name references for theme colors.
"""

from pptx.dml.color import RGBColor
from pptx.enum.dml import MSO_THEME_COLOR

THEME_COLOR_MAP = {
    "accent_1": MSO_THEME_COLOR.ACCENT_1,
    "accent_2": MSO_THEME_COLOR.ACCENT_2,
    "accent_3": MSO_THEME_COLOR.ACCENT_3,
    "accent_4": MSO_THEME_COLOR.ACCENT_4,
    "accent_5": MSO_THEME_COLOR.ACCENT_5,
    "accent_6": MSO_THEME_COLOR.ACCENT_6,
    "dark_1": MSO_THEME_COLOR.DARK_1,
    "dark_2": MSO_THEME_COLOR.DARK_2,
    "light_1": MSO_THEME_COLOR.LIGHT_1,
    "light_2": MSO_THEME_COLOR.LIGHT_2,
    "text_1": MSO_THEME_COLOR.TEXT_1,
    "text_2": MSO_THEME_COLOR.TEXT_2,
    "background_1": MSO_THEME_COLOR.BACKGROUND_1,
    "background_2": MSO_THEME_COLOR.BACKGROUND_2,
    "hyperlink": MSO_THEME_COLOR.HYPERLINK,
    "followed_hyperlink": MSO_THEME_COLOR.FOLLOWED_HYPERLINK,
}

_THEME_COLOR_REVERSE = {v: k for k, v in THEME_COLOR_MAP.items()}


def resolve_color(value: str | dict, colors: dict) -> dict:
    """Resolve a color value to an RGB or theme color specification.

    Supports:
      $name — resolves against colors dict (recursively)
      #RRGGBB — direct hex value
      @theme_name — theme color reference
      dict — {theme: name, brightness: float} for theme with brightness

    Returns:
      {"rgb": RGBColor(...)} for $name and #hex values
      {"theme": MSO_THEME_COLOR.X} for @theme_name values
      {"theme": MSO_THEME_COLOR.X, "brightness": float} for dict with brightness
    """
    if isinstance(value, dict):
        theme_name = value.get("theme", "")
        theme_color = THEME_COLOR_MAP.get(theme_name)
        if theme_color:
            result = {"theme": theme_color}
            if "brightness" in value:
                result["brightness"] = value["brightness"]
            return result
        return resolve_color(value.get("color", "#000000"), colors)

    if not isinstance(value, str):
        return {"rgb": RGBColor(0, 0, 0)}

    if value.startswith("$"):
        resolved = colors.get(value[1:], "#000000")
        return resolve_color(resolved, colors)

    if value.startswith("@"):
        theme_color = THEME_COLOR_MAP.get(value[1:])
        if theme_color:
            return {"theme": theme_color}
        return {"rgb": RGBColor(0, 0, 0)}

    hex_str = value.lstrip("#")
    return {"rgb": RGBColor(int(hex_str[0:2], 16), int(hex_str[2:4], 16), int(hex_str[4:6], 16))}


def apply_color_spec(color_format, color_spec: dict):
    """Apply a resolved color spec to any ColorFormat object."""
    if "rgb" in color_spec:
        color_format.rgb = color_spec["rgb"]
    elif "theme" in color_spec:
        color_format.theme_color = color_spec["theme"]
        if "brightness" in color_spec:
            color_format.brightness = color_spec["brightness"]


def apply_color_to_fill(fill, color_spec: dict):
    """Apply a resolved color spec to a fill's fore_color."""
    apply_color_spec(fill.fore_color, color_spec)


def apply_color_to_font(font_color, color_spec: dict):
    """Apply a resolved color spec to a font color."""
    apply_color_spec(font_color, color_spec)


def extract_color(color_obj) -> str | dict | None:
    """Extract color from a python-pptx color object, preserving theme info.

    Returns:
      str — "@theme_name" for scheme colors, "#RRGGBB" for RGB colors
      None — when color type is not set
    """
    try:
        color_type = color_obj.type
        if color_type is None:
            return None

        from pptx.enum.dml import MSO_COLOR_TYPE

        if color_type == MSO_COLOR_TYPE.SCHEME:
            theme_color = color_obj.theme_color
            name = _THEME_COLOR_REVERSE.get(theme_color)
            if name:
                return f"@{name}"
            try:
                return rgb_to_hex(color_obj.rgb)
            except (AttributeError, TypeError):
                return None

        if color_type == MSO_COLOR_TYPE.RGB:
            return rgb_to_hex(color_obj.rgb)
    except (AttributeError, TypeError):
        pass

    return None


def rgb_to_hex(rgb_color) -> str | None:
    """Convert an RGBColor to a hex string (#RRGGBB)."""
    if rgb_color is None:
        return None
    return f"#{rgb_color}"


def hex_brightness(hex_color: str) -> int:
    """Calculate perceived brightness (0-255) from a hex color string."""
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return int(0.299 * r + 0.587 * g + 0.114 * b)
