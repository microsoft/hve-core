# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for the hve-demo-material curriculum and caption parsers.

Runs as a pytest test when Atheris is not installed (CI default).
Runs as an Atheris coverage-guided fuzz target when executed directly.
"""

from __future__ import annotations

import sys
from contextlib import suppress

import pytest

try:
    import atheris

    FUZZING = True
except ImportError:
    FUZZING = False

from render_checks import CheckError, load_curriculum, parse_curriculum, parse_webvtt


def fuzz_curriculum_parser(data):
    """Fuzz the curriculum table parser with arbitrary markdown."""
    if not FUZZING:
        return

    fdp = atheris.FuzzedDataProvider(data)
    text = fdp.ConsumeUnicodeNoSurrogates(4000)
    with suppress(CheckError):
        parse_curriculum(text)


def fuzz_webvtt_parser(data):
    """Fuzz the WebVTT caption parser with arbitrary text."""
    if not FUZZING:
        return

    fdp = atheris.FuzzedDataProvider(data)
    text = fdp.ConsumeUnicodeNoSurrogates(4000)
    with suppress(CheckError):
        parse_webvtt(text)


def fuzz_dispatch(data):
    """Route caption-shaped input to the WebVTT parser, the rest to the curriculum."""
    if len(data) < 1:
        return
    if data.startswith(b"WEBVTT") or b"-->" in data[:256]:
        fuzz_webvtt_parser(data)
    else:
        fuzz_curriculum_parser(data)


class TestFuzzCurriculumParser:
    """Property-style tests for the curriculum parser."""

    def test_given_repository_curriculum_when_parsed_then_ranges_ordered(self):
        for contract in load_curriculum().values():
            assert contract["min"] < contract["max"]
            assert contract["sources"]

    def test_given_empty_text_when_parsed_then_raises_check_error(self):
        with pytest.raises(CheckError):
            parse_curriculum("")

    def test_given_headerless_captions_when_parsed_then_raises_check_error(self):
        with pytest.raises(CheckError):
            parse_webvtt("00:00:00.000 --> 00:00:01.000\nHi\n")


if __name__ == "__main__" and FUZZING:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_dispatch)
    atheris.Fuzz()
