# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for PowerPoint skill priority modules.

Runs as a pytest test when Atheris is not installed (CI default).
Runs as an Atheris coverage-guided fuzz target when executed directly.
"""

from __future__ import annotations

import sys
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


def fuzz_has_formatting_variation(data):
    """Fuzz _has_formatting_variation with lists of run dicts."""
    fdp = atheris.FuzzedDataProvider(data)
    num_runs = fdp.ConsumeIntInRange(0, 6)
    runs = []
    for _ in range(num_runs):
        run = {}
        if fdp.ConsumeBool():
            run["font"] = fdp.ConsumeUnicodeNoSurrogates(10)
        if fdp.ConsumeBool():
            run["size"] = fdp.ConsumeIntInRange(6, 72)
        if fdp.ConsumeBool():
            run["color"] = "#" + fdp.ConsumeUnicodeNoSurrogates(6)
        if fdp.ConsumeBool():
            run["bold"] = fdp.ConsumeBool()
        if fdp.ConsumeBool():
            run["italic"] = fdp.ConsumeBool()
        if fdp.ConsumeBool():
            run["underline"] = fdp.ConsumeBool()
        runs.append(run)
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


class TestFuzzHasFormattingVariation:
    """Property tests for _has_formatting_variation."""

    def test_single_run(self):
        assert _has_formatting_variation([{"font": "Arial"}]) is False

    def test_identical_runs(self):
        runs = [{"font": "Arial", "bold": True}, {"font": "Arial", "bold": True}]
        assert _has_formatting_variation(runs) is False

    def test_different_fonts(self):
        runs = [{"font": "Arial"}, {"font": "Calibri"}]
        assert _has_formatting_variation(runs) is True

    def test_empty_list(self):
        assert _has_formatting_variation([]) is False


# ---------------------------------------------------------------------------
# Atheris entry point — only runs when executed directly with Atheris installed
# ---------------------------------------------------------------------------

if __name__ == "__main__" and FUZZING:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_dispatch)
    atheris.Fuzz()
