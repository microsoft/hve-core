# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Property tests for pptx_colors module."""

import re

import pytest
from conftest import make_blank_slide
from hypothesis import given, settings
from hypothesis import strategies as st
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.util import Inches
from pptx_colors import (
    apply_color_spec,
    extract_color,
    hex_brightness,
    resolve_color,
    rgb_to_hex,
)
from strategies import color_inputs, hex_color


@pytest.mark.hypothesis
class TestFuzzResolveColor:
    """Property tests for resolve_color."""

    @given(value=color_inputs)
    def test_always_returns_dict(self, value):
        result = resolve_color(value, colors={})
        assert isinstance(result, dict)

    @given(value=color_inputs)
    def test_contains_rgb_or_theme_key(self, value):
        result = resolve_color(value, colors={})
        assert "rgb" in result or "theme" in result

    @given(value=hex_color)
    def test_idempotent_for_hex(self, value):
        first = resolve_color(value, colors={})
        hex_str = rgb_to_hex(first["rgb"])
        second = resolve_color(hex_str, colors={})
        assert first["rgb"] == second["rgb"]


@pytest.mark.hypothesis
class TestFuzzHexBrightness:
    """Property tests for hex_brightness."""

    @given(value=hex_color)
    def test_result_in_valid_range(self, value):
        result = hex_brightness(value)
        assert isinstance(result, int)
        assert 0 <= result <= 255


@pytest.mark.hypothesis
class TestFuzzRgbToHex:
    """Property tests for rgb_to_hex."""

    @given(
        r=st.integers(min_value=0, max_value=255),
        g=st.integers(min_value=0, max_value=255),
        b=st.integers(min_value=0, max_value=255),
    )
    def test_output_format(self, r, g, b):
        result = rgb_to_hex(RGBColor(r, g, b))
        assert isinstance(result, str)
        assert re.fullmatch(r"#[0-9A-Fa-f]{6}", result)


@pytest.mark.hypothesis
class TestFuzzColorRoundTrip:
    """Property tests for apply/extract color round-trip."""

    @settings(deadline=None, max_examples=50)
    @given(
        r=st.integers(min_value=0, max_value=255),
        g=st.integers(min_value=0, max_value=255),
        b=st.integers(min_value=0, max_value=255),
    )
    def test_apply_extract_preserves_color_type(self, r, g, b):
        slide = make_blank_slide()
        shape = slide.shapes.add_shape(
            MSO_SHAPE.RECTANGLE, Inches(1), Inches(1), Inches(2), Inches(2)
        )
        shape.fill.solid()
        color_spec = {"rgb": RGBColor(r, g, b)}
        apply_color_spec(shape.fill.fore_color, color_spec)
        extracted = extract_color(shape.fill.fore_color)
        expected = f"#{r:02X}{g:02X}{b:02X}"
        assert extracted == expected
