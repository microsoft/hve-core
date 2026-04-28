# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Generate themed content directory variants from a base deck's content.

Reads a themes.yaml color mapping file and produces a complete content
directory copy for each theme with all hex colors remapped in YAML and
Python files while copying images as-is.

Usage::

    python generate_themes.py --content-dir content/ \
        --themes themes.yaml --output-dir ../
"""

import argparse
import logging
import re
import shutil
import sys
from pathlib import Path

import yaml

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2

logger = logging.getLogger(__name__)


def configure_logging(verbose: bool = False) -> None:
    """Configure logging based on verbosity level."""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(level=level, format="%(levelname)s: %(message)s")


def create_parser() -> argparse.ArgumentParser:
    """Create and configure argument parser."""
    parser = argparse.ArgumentParser(
        description="Generate themed content directory variants from a base deck."
    )
    parser.add_argument(
        "--content-dir",
        type=Path,
        required=True,
        help="Path to the base theme's content directory.",
    )
    parser.add_argument(
        "--themes",
        type=Path,
        required=True,
        help="Path to a YAML file defining theme color mappings.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        required=True,
        help="Parent directory where themed content directories are created.",
    )
    parser.add_argument("-v", "--verbose", action="store_true")
    return parser


def load_themes(themes_path: Path) -> dict:
    """Load and validate the themes YAML file.

    Returns the ``themes`` mapping keyed by theme-id.
    """
    text = themes_path.read_text(encoding="utf-8")
    data = yaml.safe_load(text)
    if not isinstance(data, dict) or "themes" not in data:
        raise ValueError("themes YAML must contain a top-level 'themes' key")
    themes = data["themes"]
    for theme_id, cfg in themes.items():
        if "colors" not in cfg or not isinstance(cfg["colors"], dict):
            raise ValueError(f"Theme '{theme_id}' must contain a 'colors' mapping")
    return themes


def remap_hex_in_text(text: str, color_map: dict[str, str]) -> str:
    """Replace ``#RRGGBB`` hex color values using *color_map*.

    Keys and values in *color_map* must include the leading ``#``.
    Matching is case-insensitive.
    """
    result = text
    for old_hex, new_hex in color_map.items():
        old_bare = old_hex.lstrip("#")
        new_bare = new_hex.lstrip("#")
        result = re.sub(
            rf"#{re.escape(old_bare)}",
            f"#{new_bare}",
            result,
            flags=re.IGNORECASE,
        )
    return result


def remap_rgb_in_python(text: str, color_map: dict[str, str]) -> str:
    """Replace ``RGBColor(0xRR, 0xGG, 0xBB)`` and ``"#RRGGBB"`` patterns.

    Keys and values in *color_map* must include the leading ``#``.
    """
    result = text
    for old_hex, new_hex in color_map.items():
        old_bare = old_hex.lstrip("#")
        new_bare = new_hex.lstrip("#")

        old_r = int(old_bare[0:2], 16)
        old_g = int(old_bare[2:4], 16)
        old_b = int(old_bare[4:6], 16)
        new_r = int(new_bare[0:2], 16)
        new_g = int(new_bare[2:4], 16)
        new_b = int(new_bare[4:6], 16)

        # RGBColor(0xRR, 0xGG, 0xBB)
        old_pattern = (
            rf"RGBColor\(\s*0x{old_r:02X}\s*,\s*0x{old_g:02X}\s*,"
            rf"\s*0x{old_b:02X}\s*\)"
        )
        new_value = f"RGBColor(0x{new_r:02X}, 0x{new_g:02X}, 0x{new_b:02X})"
        result = re.sub(old_pattern, new_value, result, flags=re.IGNORECASE)

        # "#RRGGBB" string literals
        result = re.sub(
            rf'"#{re.escape(old_bare)}"',
            f'"#{new_bare}"',
            result,
            flags=re.IGNORECASE,
        )
    return result


def process_file(src: Path, dest: Path, color_map: dict[str, str]) -> None:
    """Copy *src* to *dest*, remapping colors for YAML and Python files."""
    if src.suffix == ".yaml":
        text = src.read_text(encoding="utf-8")
        text = remap_hex_in_text(text, color_map)
        dest.write_text(text, encoding="utf-8")
    elif src.suffix == ".py":
        text = src.read_text(encoding="utf-8")
        text = remap_rgb_in_python(text, color_map)
        text = remap_hex_in_text(text, color_map)
        dest.write_text(text, encoding="utf-8")
    else:
        shutil.copy2(src, dest)


def process_directory(src_dir: Path, dest_dir: Path, color_map: dict[str, str]) -> None:
    """Recursively process *src_dir* into *dest_dir*, remapping colors."""
    dest_dir.mkdir(parents=True, exist_ok=True)
    for entry in sorted(src_dir.iterdir()):
        dest_entry = dest_dir / entry.name
        if entry.is_dir():
            process_directory(entry, dest_entry, color_map)
        elif entry.is_file():
            process_file(entry, dest_entry, color_map)


def update_style_metadata(style_path: Path, theme_id: str, label: str) -> None:
    """Patch theme name and append label to title in style.yaml."""
    if not style_path.exists():
        return
    text = style_path.read_text(encoding="utf-8")
    # Update theme name field
    text = re.sub(
        r'(name:\s*")[^"]*(")',
        rf"\g<1>{theme_id}\2",
        text,
        count=1,
    )

    # Append theme label to title when not already present
    def _append_label(m: re.Match) -> str:
        prefix, title, suffix = m.group(1), m.group(2), m.group(3)
        if label in title:
            return m.group(0)
        return f"{prefix}{title} ({label}){suffix}"

    text = re.sub(
        r'(title:\s*")([^"]*?)(")',
        _append_label,
        text,
        count=1,
    )
    style_path.write_text(text, encoding="utf-8")


def generate_theme(
    content_dir: Path,
    output_dir: Path,
    deck_name: str,
    theme_id: str,
    theme_config: dict,
) -> Path:
    """Generate a complete themed copy of *content_dir*."""
    color_map = theme_config["colors"]
    label = theme_config.get("label", theme_id)

    output_base = output_dir / f"{deck_name}-{theme_id}"
    output_content = output_base / "content"
    output_deck = output_base / "slide-deck"

    if output_content.exists():
        shutil.rmtree(output_content)

    process_directory(content_dir, output_content, color_map)

    output_deck.mkdir(parents=True, exist_ok=True)
    (output_deck / ".gitkeep").touch()

    # Patch style.yaml metadata inside the themed content
    style_candidates = [
        output_content / "global" / "style.yaml",
        output_content / "style.yaml",
    ]
    for style_path in style_candidates:
        update_style_metadata(style_path, theme_id, label)

    logger.info("Generated: %s/", output_base.name)
    return output_base


def run(args: argparse.Namespace) -> int:
    """Execute theme generation."""
    content_dir = args.content_dir.resolve()
    themes_path = args.themes.resolve()
    output_dir = args.output_dir.resolve()

    if not content_dir.is_dir():
        logger.error("Content directory does not exist: %s", content_dir)
        return EXIT_ERROR
    if not themes_path.is_file():
        logger.error("Themes file does not exist: %s", themes_path)
        return EXIT_ERROR

    themes = load_themes(themes_path)
    deck_name = content_dir.parent.name
    output_dir.mkdir(parents=True, exist_ok=True)

    logger.info("Generating %d themed variant(s) for '%s' ...", len(themes), deck_name)

    for theme_id, theme_config in themes.items():
        generate_theme(content_dir, output_dir, deck_name, theme_id, theme_config)

    logger.info("All themes generated successfully.")
    return EXIT_SUCCESS


def main() -> int:
    """Main entry point."""
    parser = create_parser()
    args = parser.parse_args()
    configure_logging(args.verbose)
    try:
        return run(args)
    except KeyboardInterrupt:
        print("\nInterrupted by user", file=sys.stderr)
        return 130
    except BrokenPipeError:
        sys.stderr.close()
        return EXIT_FAILURE
    except Exception as e:
        logger.error("%s", e)
        return EXIT_FAILURE


if __name__ == "__main__":
    sys.exit(main())
