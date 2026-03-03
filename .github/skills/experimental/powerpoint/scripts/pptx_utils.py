"""Shared utilities for PowerPoint skill scripts.

Provides YAML loading and EMU conversion used by
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

