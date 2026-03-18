# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Shared utilities for PowerPoint skill scripts.

Provides YAML loading, EMU conversion, and validation helpers used by
build_deck.py, extract_content.py, validate_deck.py, and validate_slides.py.
"""

import logging
from pathlib import Path

import yaml

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2


def configure_logging(verbose: bool = False) -> None:
    """Configure logging based on verbosity level."""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(level=level, format="%(levelname)s: %(message)s")


def parse_slide_filter(slides_arg: str | None) -> set[int] | None:
    """Parse comma-separated slide numbers into a filter set."""
    if not slides_arg:
        return None
    return {int(s.strip()) for s in slides_arg.split(",")}


def emu_to_inches(emu_val) -> float:
    """Convert EMU to inches, rounded to 3 decimal places."""
    if emu_val is None:
        return 0.0
    return round(emu_val / 914400, 3)


def load_yaml(path: Path) -> dict:
    """Load a YAML file and return the parsed dictionary."""
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f) or {}
