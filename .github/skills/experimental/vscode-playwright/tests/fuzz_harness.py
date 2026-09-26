# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for the vscode-playwright capture plan validator.

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

from capture_vscode import PlanError, read_plan, validate_plan


def fuzz_plan_validator(data):
    """Fuzz the plan reader and validator with arbitrary YAML bytes."""
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
        with suppress(PlanError):
            validate_plan(read_plan(tmp_path))
    finally:
        tmp_path.unlink(missing_ok=True)


def fuzz_dispatch(data):
    """Route Atheris input to the plan validator target."""
    if len(data) < 1:
        return
    fuzz_plan_validator(data)


class TestFuzzPlanValidator:
    """Property-style tests for the capture plan validator."""

    def test_given_valid_plan_when_validated_then_returns_captures(self, tmp_path):
        plan_path = tmp_path / "plan.yml"
        plan_path.write_text(
            "resolution: 1920x1080\n"
            "captures:\n"
            "  - id: manifest\n"
            "    file: plugin.json\n"
            "    output: frames/manifest.png\n",
            encoding="utf-8",
        )

        settings, captures = validate_plan(read_plan(plan_path))

        assert settings["width"] == 1920
        assert captures[0]["id"] == "manifest"

    def test_given_non_mapping_plan_when_read_then_raises(self, tmp_path):
        plan_path = tmp_path / "plan.yml"
        plan_path.write_text("- just\n- a list\n", encoding="utf-8")

        with pytest.raises(PlanError, match="YAML mapping"):
            read_plan(plan_path)


if __name__ == "__main__" and FUZZING:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_dispatch)
    atheris.Fuzz()
