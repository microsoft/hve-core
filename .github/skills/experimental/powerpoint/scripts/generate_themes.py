#!/usr/bin/env python3
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

from __future__ import annotations

import argparse
import logging
import re
import shutil
import sys
from pathlib import Path
from typing import Any

from pptx_utils import (
    EXIT_ERROR,
    EXIT_FAILURE,
    EXIT_SUCCESS,
    configure_logging,
)

# ruamel.yaml is used intentionally for round-trip fidelity in
# update_style_metadata: preserves comments, key ordering, and quoting
# style when patching style.yaml files. pyyaml cannot preserve these.
from ruamel.yaml import YAML

logger = logging.getLogger(__name__)


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
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="Enable verbose output"
    )
    return parser


def load_themes(themes_path: Path) -> dict[str, Any]:
    """Load and validate the themes YAML file.

    Returns the ``themes`` mapping keyed by theme-id.
    """
    ryaml = YAML(typ="safe")
    data = ryaml.load(themes_path.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or "themes" not in data:
        raise ValueError("themes YAML must contain a top-level 'themes' key")
    themes = data["themes"]
    for theme_id, cfg in themes.items():
        if "colors" not in cfg or not isinstance(cfg["colors"], dict):
            raise ValueError(f"Theme '{theme_id}' must contain a 'colors' mapping")
        for k, v in cfg["colors"].items():
            if not isinstance(k, str) or not isinstance(v, str):
                raise ValueError(
                    f"Theme '{theme_id}' color map keys and values must be "
                    f"strings; got {k!r}: {v!r}"
                )
    return themes


def remap_hex_in_text(text: str, color_map: dict[str, str]) -> str:
    """Replace ``#RRGGBB`` hex color values using *color_map*.

    Uses a single-pass regex callback to avoid chain remapping where
    one substitution's output feeds the next (e.g., A→B then B→C
    would incorrectly produce C instead of the intended B).

    Keys and values in *color_map* may optionally include the leading ``#``;
    the prefix is stripped before matching.  Matching is case-insensitive.
    """
    bare_map = {k.lstrip("#").lower(): v.lstrip("#") for k, v in color_map.items()}
    invalid = {k: v for k, v in bare_map.items() if len(k) != 6 or len(v) != 6}
    if invalid:
        raise ValueError(
            f"Color map entries must be 6-character hex strings; invalid: {invalid}"
        )
    if not bare_map:
        return text
    pattern = re.compile(
        r"#(" + "|".join(re.escape(k) for k in bare_map) + r")",
        re.IGNORECASE,
    )
    return pattern.sub(lambda m: f"#{bare_map[m.group(1).lower()]}", text)


def remap_rgb_in_python(text: str, color_map: dict[str, str]) -> str:
    """Replace ``RGBColor(0xRR, 0xGG, 0xBB)``, ``"#RRGGBB"``, and
    ``'#RRGGBB'`` patterns.

    Uses a single-pass regex callback to avoid chain remapping where
    one substitution's output feeds the next.

    Keys and values in *color_map* may optionally include the leading ``#``;
    the prefix is stripped before matching.
    """
    bare_map: dict[str, str] = {}
    for old_hex, new_hex in color_map.items():
        old_bare = old_hex.lstrip("#").upper()
        bare_map[old_bare] = new_hex.lstrip("#").upper()

    invalid = {k: v for k, v in bare_map.items() if len(k) != 6 or len(v) != 6}
    if invalid:
        raise ValueError(
            f"Color map entries must be 6-character hex strings; invalid: {invalid}"
        )

    if not bare_map:
        return text

    def _rgb_pattern(hex6: str) -> str:
        r = int(hex6[0:2], 16)
        g = int(hex6[2:4], 16)
        b = int(hex6[4:6], 16)
        return rf"RGBColor\(\s*0x{r:02X}\s*,\s*0x{g:02X}\s*,\s*0x{b:02X}\s*\)"

    def _hex_pattern_double(hex6: str) -> str:
        return rf'"#{re.escape(hex6)}"'

    def _hex_pattern_single(hex6: str) -> str:
        return rf"'#{re.escape(hex6)}'"

    # Build combined pattern matching RGBColor(...), "#RRGGBB", and '#RRGGBB'
    rgb_parts = [f"({_rgb_pattern(k)})" for k in bare_map]
    hex_dbl_parts = [f"({_hex_pattern_double(k)})" for k in bare_map]
    hex_sgl_parts = [f"({_hex_pattern_single(k)})" for k in bare_map]
    combined = re.compile(
        "|".join(rgb_parts + hex_dbl_parts + hex_sgl_parts), re.IGNORECASE
    )

    keys = list(bare_map.keys())
    n = len(keys)

    def _replace(m: re.Match) -> str:
        for i, k in enumerate(keys):
            # Groups 1..n are RGBColor, n+1..2n double-quoted, 2n+1..3n single-quoted
            if m.group(i + 1) is not None:
                v = bare_map[k]
                r = int(v[0:2], 16)
                g = int(v[2:4], 16)
                b = int(v[4:6], 16)
                return f"RGBColor(0x{r:02X}, 0x{g:02X}, 0x{b:02X})"
            if m.group(n + i + 1) is not None:
                return f'"#{bare_map[k]}"'
            if m.group(2 * n + i + 1) is not None:
                return f"'#{bare_map[k]}'"
        return m.group(0)

    return combined.sub(_replace, text)


def process_file(src: Path, dest: Path, color_map: dict[str, str]) -> None:
    """Copy *src* to *dest*, remapping colors for YAML and Python files."""
    if src.suffix == ".yaml":
        text = src.read_text(encoding="utf-8")
        text = remap_hex_in_text(text, color_map)
        dest.write_text(text, encoding="utf-8")
    elif src.suffix == ".py":
        text = src.read_text(encoding="utf-8")
        # remap_rgb_in_python handles both RGBColor(...) and "#RRGGBB" quoted
        # forms in a single pass; skip remap_hex_in_text to avoid chain remap
        text = remap_rgb_in_python(text, color_map)
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
    """Patch theme name and append label to title in style.yaml.

    Uses ruamel.yaml for round-trip fidelity: preserves comments,
    key ordering, and quoting style from the original file.
    """
    if not style_path.exists():
        return
    ryaml = YAML()
    ryaml.preserve_quotes = True
    data = ryaml.load(style_path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        return

    # Update theme name in the themes list
    themes = data.get("themes", [])
    if isinstance(themes, list) and themes:
        first = themes[0]
        if isinstance(first, dict):
            first["name"] = theme_id

    # Append theme label to metadata title
    metadata = data.get("metadata", {})
    if isinstance(metadata, dict):
        title = metadata.get("title", "")
        if label not in title:
            metadata["title"] = f"{title} ({label})" if title else label

    with style_path.open("w", encoding="utf-8") as f:
        ryaml.dump(data, f)


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
