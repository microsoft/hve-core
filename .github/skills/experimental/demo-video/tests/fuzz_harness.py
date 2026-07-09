# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for the demo-video manifest validator.

Runs as a pytest test when Atheris is not installed (CI default).
Runs as an Atheris coverage-guided fuzz target when executed directly.
"""

from __future__ import annotations

import sys
import tempfile
from contextlib import suppress
from pathlib import Path

import pytest

try:
    import atheris

    FUZZING = True
except ImportError:
    FUZZING = False

from assemble_video import ManifestError, _read_manifest, _validate_manifest


def fuzz_manifest_validator(data):
    """Fuzz the manifest reader and validator with arbitrary YAML bytes."""
    if not FUZZING:
        return

    fdp = atheris.FuzzedDataProvider(data)
    payload = fdp.ConsumeUnicodeNoSurrogates(2000)
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".yml", delete=False, encoding="utf-8"
    ) as tmp:
        tmp.write(payload)
        tmp_path = Path(tmp.name)
    try:
        with suppress(Exception):
            manifest_data = _read_manifest(tmp_path)
            _validate_manifest(manifest_data)
    finally:
        tmp_path.unlink(missing_ok=True)


def fuzz_dispatch(data):
    """Route Atheris input to the manifest validator target."""
    if len(data) < 1:
        return
    fuzz_manifest_validator(data)


class TestFuzzManifestValidator:
    """Property-style tests for the manifest validator."""

    def test_given_valid_manifest_when_validated_then_returns_normalized_segments(
        self, tmp_path
    ):
        manifest_path = tmp_path / "segments.yml"
        manifest_path.write_text(
            "output: demo.mp4\n"
            "resolution: 1280x720\n"
            "fps: 24\n"
            "segments:\n"
            "  - visual: intro.png\n"
            "    narration: intro.wav\n",
            encoding="utf-8",
        )

        config, segments = _validate_manifest(
            _read_manifest(manifest_path),
        )

        assert config["output"] == "demo.mp4"
        assert config["resolution"] == "1280x720"
        assert config["fps"] == 24
        assert len(segments) == 1
        assert segments[0]["narration"] == "intro.wav"

    def test_given_empty_segments_when_validated_then_raises(self, tmp_path):
        manifest_path = tmp_path / "segments.yml"
        manifest_path.write_text("segments: []\n", encoding="utf-8")

        with pytest.raises(ManifestError, match="non-empty 'segments'"):
            _validate_manifest(_read_manifest(manifest_path))


if __name__ == "__main__" and FUZZING:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_dispatch)
    atheris.Fuzz()
