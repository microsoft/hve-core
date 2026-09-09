# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for feasibility profile parsing.

Runs as a pytest test when Atheris is not installed.
Runs as an Atheris coverage-guided fuzz target when executed directly.
"""

from __future__ import annotations

import sys
from contextlib import suppress

from validate_feasibility import FeasibilityValidationError, parse_profile

try:
    import atheris
except ImportError:
    atheris = None
    FUZZING = False
else:
    FUZZING = True


def fuzz_parse_profile(data: bytes) -> None:
    """Exercise profile extraction and parsing with arbitrary input."""
    text = data.decode("utf-8", errors="replace")
    with suppress(FeasibilityValidationError):
        parse_profile(text)


class TestFeasibilityFuzzHarness:
    """Property tests mirroring fuzz-target behavior."""

    def test_parser_rejects_or_returns_mapping(self) -> None:
        for text in ("", "```yaml\na: 1\n```", "<!-- BEGIN -->"):
            with suppress(FeasibilityValidationError):
                assert isinstance(parse_profile(text), dict)


if __name__ == "__main__" and FUZZING:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_parse_profile)
    atheris.Fuzz()
