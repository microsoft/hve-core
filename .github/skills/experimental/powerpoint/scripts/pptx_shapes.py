# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Shape constants, maps, and rotation utilities for PowerPoint skill scripts.

Provides the expanded SHAPE_MAP (30+ entries), an inverse AUTO_SHAPE_NAME_MAP
for extraction, and rotation helper functions.
"""

from pptx.enum.shapes import MSO_SHAPE

SHAPE_MAP = {
    # Original 9
    "rectangle": MSO_SHAPE.RECTANGLE,
    "rounded_rectangle": MSO_SHAPE.ROUNDED_RECTANGLE,
    "right_arrow": MSO_SHAPE.RIGHT_ARROW,
    "chevron": MSO_SHAPE.CHEVRON,
    "oval": MSO_SHAPE.OVAL,
    "diamond": MSO_SHAPE.DIAMOND,
    "pentagon": MSO_SHAPE.PENTAGON,
    "hexagon": MSO_SHAPE.HEXAGON,
    "right_triangle": MSO_SHAPE.RIGHT_TRIANGLE,
    # Arrows
    "left_arrow": MSO_SHAPE.LEFT_ARROW,
    "up_arrow": MSO_SHAPE.UP_ARROW,
    "down_arrow": MSO_SHAPE.DOWN_ARROW,
    "left_right_arrow": MSO_SHAPE.LEFT_RIGHT_ARROW,
    "notched_right_arrow": MSO_SHAPE.NOTCHED_RIGHT_ARROW,
    # Flowchart
    "flowchart_process": MSO_SHAPE.FLOWCHART_PROCESS,
    "flowchart_decision": MSO_SHAPE.FLOWCHART_DECISION,
    "flowchart_terminator": MSO_SHAPE.FLOWCHART_TERMINATOR,
    "flowchart_data": MSO_SHAPE.FLOWCHART_DATA,
    # Common shapes
    "cross": MSO_SHAPE.CROSS,
    "donut": MSO_SHAPE.DONUT,
    "star_5_point": MSO_SHAPE.STAR_5_POINT,
    "cloud": MSO_SHAPE.CLOUD,
    "trapezoid": MSO_SHAPE.TRAPEZOID,
    "parallelogram": MSO_SHAPE.PARALLELOGRAM,
    "left_brace": MSO_SHAPE.LEFT_BRACE,
    "right_brace": MSO_SHAPE.RIGHT_BRACE,
    "callout_rectangle": MSO_SHAPE.RECTANGULAR_CALLOUT,
    "callout_rounded_rectangle": MSO_SHAPE.ROUNDED_RECTANGULAR_CALLOUT,
    # Alias
    "circle": MSO_SHAPE.OVAL,
}

# Inverse map: MSO_AUTO_SHAPE_TYPE enum value -> YAML shape name
# Excludes "circle" alias so "oval" is the canonical name for MSO_SHAPE.OVAL
AUTO_SHAPE_NAME_MAP = {v: k for k, v in SHAPE_MAP.items() if k != "circle"}


def apply_rotation(shape, rotation: float | None):
    """Apply rotation in degrees to a shape when specified."""
    if rotation is not None and rotation != 0:
        shape.rotation = rotation


def extract_rotation(shape) -> float | None:
    """Extract rotation in degrees, returning None when zero."""
    rot = shape.rotation
    if rot and rot != 0.0:
        return rot
    return None
