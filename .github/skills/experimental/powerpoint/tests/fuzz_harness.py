# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for PowerPoint skill priority modules.

Runs as a pytest test when Atheris is not installed (CI default).
Runs as an Atheris coverage-guided fuzz target when executed directly.
"""
from __future__ import annotations
import sys
from unittest.mock import MagicMock
sys.modules["cairosvg"] = MagicMock()

from contextlib import suppress

try:
    import atheris

    FUZZING = True
except ImportError:
    FUZZING = False

from extract_content import _has_formatting_variation
from pptx_colors import hex_brightness, resolve_color
from validate_deck import max_severity

# ---------------------------------------------------------------------------
# Fuzz targets — pure functions exercised by both modes
# ---------------------------------------------------------------------------


def fuzz_resolve_color(data):
    """Fuzz resolve_color with str and dict inputs."""
    fdp = atheris.FuzzedDataProvider(data)
    hex_str = "#" + fdp.ConsumeUnicodeNoSurrogates(6)
    with suppress(ValueError, IndexError):
        resolve_color(hex_str)
    theme_ref = "@" + fdp.ConsumeUnicodeNoSurrogates(20)
    with suppress(ValueError, IndexError):
        resolve_color(theme_ref)
    theme_dict = {
        "theme": fdp.ConsumeUnicodeNoSurrogates(15),
        "brightness": fdp.ConsumeFloatInRange(-1.0, 1.0),
    }
    with suppress(ValueError, IndexError):
        resolve_color(theme_dict)
    nested_dict = {"color": "#" + fdp.ConsumeUnicodeNoSurrogates(6)}
    with suppress(ValueError, IndexError):
        resolve_color(nested_dict)


def fuzz_hex_brightness(data):
    """Fuzz hex_brightness with arbitrary strings."""
    fdp = atheris.FuzzedDataProvider(data)
    hex_str = fdp.ConsumeUnicodeNoSurrogates(10)
    with suppress(ValueError, IndexError):
        hex_brightness(hex_str)


def fuzz_max_severity(data):
    """Fuzz max_severity with structured dict inputs."""
    fdp = atheris.FuzzedDataProvider(data)
    severities = ["error", "warning", "info", fdp.ConsumeUnicodeNoSurrogates(8)]
    num_slides = fdp.ConsumeIntInRange(0, 5)
    slides = []
    for _ in range(num_slides):
        num_issues = fdp.ConsumeIntInRange(0, 4)
        issues = [
            {"severity": severities[fdp.ConsumeIntInRange(0, len(severities) - 1)]}
            for _ in range(num_issues)
        ]
        slides.append({"issues": issues})
    num_deck_issues = fdp.ConsumeIntInRange(0, 3)
    deck_issues = [
        {"severity": severities[fdp.ConsumeIntInRange(0, len(severities) - 1)]}
        for _ in range(num_deck_issues)
    ]
    results = {}
    if fdp.ConsumeBool():
        results["slides"] = slides
    if fdp.ConsumeBool():
        results["deck_issues"] = deck_issues
    with suppress(KeyError):
        max_severity(results)

class MockFontColor:
    """Mock for pptx.dml.color.RGBColor."""
    def __init__(self, rgb_value):
        self.rgb = rgb_value

class MockFont:
    """Mock Font object for fuzzing with all 6 formatting properties."""
    def __init__(self, fdp):
        self.name = fdp.ConsumeUnicodeNoSurrogates(10) if fdp.ConsumeBool() else "Arial"
        self.bold = fdp.ConsumeBool()
        self.italic = fdp.ConsumeBool()
        self.underline = fdp.ConsumeBool()
        self.size = fdp.ConsumeIntInRange(0, 1000000) if fdp.ConsumeBool() else None  # EMU
        if fdp.ConsumeBool():
            self.color = MockFontColor(fdp.ConsumeIntInRange(0, 0xFFFFFF))
        else:
            self.color = MockFontColor(None)

class MockRun:
    """Mock Run object for fuzzing."""
    def __init__(self, fdp):
        self.font = MockFont(fdp)

def fuzz_has_formatting_variation(data):
    """Fuzz _has_formatting_variation with mock Run objects.
    
    Covers all 6 formatting properties:
    - font.name, font.bold, font.italic
    - font.underline, font.color.rgb, font.size
    """
    fdp = atheris.FuzzedDataProvider(data)
    num_runs = fdp.ConsumeIntInRange(0, 6)
    runs = [MockRun(fdp) for _ in range(num_runs)]
    _has_formatting_variation(runs)


FUZZ_TARGETS = [
    fuzz_resolve_color,
    fuzz_hex_brightness,
    fuzz_max_severity,
    fuzz_has_formatting_variation,
]


def fuzz_dispatch(data):
    """Route Atheris input to one of the registered fuzz targets."""
    if len(data) < 2:
        return
    idx = data[0] % len(FUZZ_TARGETS)
    FUZZ_TARGETS[idx](data[1:])


# ---------------------------------------------------------------------------
# pytest mode — property-based tests for the same targets
# ---------------------------------------------------------------------------

import pytest  # noqa: E402


class TestFuzzResolveColor:
    """Property tests for resolve_color edge cases."""

    @pytest.mark.parametrize(
        "value",
        [
            "#000000",
            "#FFFFFF",
            "#abcdef",
            "@accent1",
            "@nonexistent_theme",
            "",
            {"theme": "accent1", "brightness": 0.5},
            {"theme": "accent1"},
            {"color": "#FF0000"},
            {"color": "#FF0000", "theme": ""},
        ],
    )
    def test_resolve_color_returns_dict(self, value):
        result = resolve_color(value)
        assert isinstance(result, dict)

    def test_resolve_color_depth_limit(self):
        deep = {"color": {"color": {"color": "#000000"}}}
        with pytest.raises(ValueError, match="depth"):
            resolve_color(deep, max_depth=2)

    def test_resolve_color_short_hex(self):
        result = resolve_color("#AB")
        assert "rgb" in result
        assert str(result["rgb"]) == "000000"


class TestFuzzHexBrightness:
    """Property tests for hex_brightness."""

    @pytest.mark.parametrize(
        "hex_color,expected",
        [
            ("#000000", 0),
            ("#FFFFFF", 255),
            ("#FF0000", 76),
        ],
    )
    def test_known_values(self, hex_color, expected):
        assert hex_brightness(hex_color) == expected

    def test_short_hex_returns_zero(self):
        assert hex_brightness("#AB") == 0


class TestFuzzMaxSeverity:
    """Property tests for max_severity."""

    def test_empty_slides(self):
        assert max_severity({"slides": [], "deck_issues": []}) == "none"

    def test_error_dominates(self):
        results = {
            "slides": [{"issues": [{"severity": "info"}, {"severity": "error"}]}],
            "deck_issues": [{"severity": "warning"}],
        }
        assert max_severity(results) == "error"

    def test_warning_over_info(self):
        results = {
            "slides": [{"issues": [{"severity": "info"}]}],
            "deck_issues": [{"severity": "warning"}],
        }
        assert max_severity(results) == "warning"

    def test_missing_slides_key(self):
        with pytest.raises(KeyError):
            max_severity({"deck_issues": []})

    def test_missing_deck_issues_key(self):
        assert max_severity({"slides": []}) == "none"

# ---------------------------------------------------------------------------
# Deterministic test helper (NO atheris dependency)
# ---------------------------------------------------------------------------
def _make_test_run(name="Arial", bold=False, italic=False, underline=False, size=None, color_rgb=None):
    """Lightweight mock builder for deterministic pytest runs.
    
    Supports both dict-style access (for _has_formatting_variation) 
    and attribute-style access (for future object-based implementation).
    """
    class MockColor:
        def __init__(self, rgb): 
            self.rgb = rgb
        
        def __eq__(self, other):
            return isinstance(other, MockColor) and self.rgb == other.rgb
        
        def __hash__(self):
            return hash(self.rgb)
    
    class MockFont:
        def __init__(self):
            self.name = name
            self.bold = bold
            self.italic = italic
            self.underline = underline
            self.size = size
            self.color = MockColor(color_rgb)
        
        def __eq__(self, other):
            if not isinstance(other, MockFont):
                return False
            return (
                self.name == other.name and
                self.bold == other.bold and
                self.italic == other.italic and
                self.underline == other.underline and
                self.size == other.size and
                self.color == other.color
            )
        
        def __hash__(self):
            return hash((self.name, self.bold, self.italic, self.underline, self.size, self.color))
    
    class MockRun:
        def __init__(self): 
            self.font = MockFont()
        
        # Dict-style access for _has_formatting_variation compatibility
        def __contains__(self, key):
            return key in ["font", "size", "color", "bold", "italic", "underline"]
        
        def get(self, key, default=None):
            if key == "font":
                return self.font
            elif key == "size":
                return self.font.size
            elif key == "color":
                return self.font.color
            elif key == "bold":
                return self.font.bold
            elif key == "italic":
                return self.font.italic
            elif key == "underline":
                return self.font.underline
            return default
        
        def __eq__(self, other):
            return isinstance(other, MockRun) and self.font == other.font
        
        def __hash__(self):
            return hash(self.font)
    
    return MockRun()


class TestFuzzHasFormattingVariation:
    """Tests for _has_formatting_variation covering all 6 formatting properties."""

    def test_single_run(self):
        assert _has_formatting_variation([_make_test_run()]) is False

    def test_identical_runs(self):
        runs = [_make_test_run(), _make_test_run()]
        assert _has_formatting_variation(runs) is False

    def test_different_fonts(self):
        runs = [_make_test_run(name="Arial"), _make_test_run(name="Calibri")]
        assert _has_formatting_variation(runs) is True

    def test_empty_list(self):
        assert _has_formatting_variation([]) is False

    def test_underline_variation(self):
        runs = [_make_test_run(underline=True), _make_test_run(underline=False)]
        assert _has_formatting_variation(runs) is True

    def test_size_variation(self):
        runs = [_make_test_run(size=100_000), _make_test_run(size=200_000)]
        assert _has_formatting_variation(runs) is True

    def test_color_rgb_variation(self):
        runs = [_make_test_run(color_rgb=0xFF0000), _make_test_run(color_rgb=0x00FF00)]
        assert _has_formatting_variation(runs) is True

# ---------------------------------------------------------------------------
# Atheris entry point — only runs when executed directly with Atheris installed
# ---------------------------------------------------------------------------

if __name__ == "__main__" and FUZZING:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_dispatch)
    atheris.Fuzz()