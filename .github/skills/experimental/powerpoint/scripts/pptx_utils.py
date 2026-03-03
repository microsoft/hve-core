"""Shared utilities for PowerPoint skill scripts.

Provides YAML loading, EMU conversion, and style merging used by
build_deck.py, extract_content.py, and validate_deck.py.
"""

from pathlib import Path

import yaml


def emu_to_inches(emu_val) -> float:
    """Convert EMU to inches, rounded to 3 decimal places."""
    if emu_val is None:
        return 0.0
    return round(emu_val / 914400, 3)


def load_yaml(path: Path) -> dict:
    """Load a YAML file and return the parsed dictionary."""
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def merge_styles(global_style: dict, overrides: dict | None) -> dict:
    """Deep-merge per-slide style overrides into the global style."""
    if not overrides:
        return global_style.copy()
    merged = {}
    for key in global_style:
        if key in overrides and isinstance(global_style[key], dict) and isinstance(overrides[key], dict):
            merged[key] = {**global_style[key], **overrides[key]}
        elif key in overrides:
            merged[key] = overrides[key]
        else:
            merged[key] = global_style[key]
    for key in overrides:
        if key not in merged:
            merged[key] = overrides[key]
    return merged
