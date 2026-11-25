# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for the TM7 generator."""

from __future__ import annotations

import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import generate_tm7  # noqa: E402

try:
    import atheris
except ImportError:
    atheris = None
    FUZZING = False
else:
    FUZZING = True


def fuzz_spec_loader(data: bytes) -> None:
    """Fuzz the YAML/JSON spec loader over arbitrary bytes."""
    with tempfile.TemporaryDirectory() as temp_dir:
        path = Path(temp_dir) / "spec.yaml"
        path.write_bytes(data)
        try:
            generate_tm7.load_spec(path)
        except (generate_tm7.GenerationError, UnicodeError, ValueError):
            return


def fuzz_tm7_importer(data: bytes) -> None:
    """Fuzz the hardened TM7 importer over arbitrary bytes."""
    with tempfile.TemporaryDirectory() as temp_dir:
        path = Path(temp_dir) / "model.tm7"
        path.write_bytes(data)
        try:
            generate_tm7.parse_hardened_xml(path)
        except (generate_tm7.GenerationError, UnicodeError, ET.ParseError, ValueError):
            return


FUZZ_TARGETS = [
    fuzz_spec_loader,
    fuzz_tm7_importer,
]


def fuzz_dispatch(data: bytes) -> None:
    """Route data to a fuzz target."""
    if len(data) < 2:
        return
    FUZZ_TARGETS[data[0] % len(FUZZ_TARGETS)](data[1:])


class TestGenerateTm7FuzzHarness:
    """Pytest property tests mirroring the fuzz target behavior."""

    @pytest.mark.parametrize("payload", [b"", b"{", b"<", b"\x00", b"\xff"])
    def test_given_arbitrary_bytes_when_load_spec_then_no_uncaught_exception(
        self,
        payload: bytes,
    ) -> None:
        # Arrange
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "spec.yaml"
            path.write_bytes(payload)

            # Act and Assert
            try:
                result = generate_tm7.load_spec(path)
            except (generate_tm7.GenerationError, UnicodeError, ValueError):
                return
            assert isinstance(result, dict)

    @pytest.mark.parametrize(
        "payload",
        [b"", b"<", b"<!DOCTYPE", b"\x00", b"\xff"],
    )
    def test_given_arbitrary_bytes_when_parse_tm7_then_no_uncaught_exception(
        self,
        payload: bytes,
    ) -> None:
        # Arrange
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "model.tm7"
            path.write_bytes(payload)

            # Act and Assert
            try:
                result = generate_tm7.parse_hardened_xml(path)
            except (generate_tm7.GenerationError, UnicodeError, ValueError):
                return
            assert isinstance(result, ET.Element)


if __name__ == "__main__" and FUZZING:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_dispatch)
    atheris.Fuzz()
