# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for accessibility scanner normalization.

Runs as a pytest test when Atheris is not installed.
Runs as an Atheris coverage-guided fuzz target when executed directly.
"""

from __future__ import annotations

import importlib
import sys
from contextlib import suppress
from pathlib import Path

try:
    import atheris
except ImportError:
    atheris = None
    FUZZING = False
else:
    FUZZING = True

_SKILL_ROOT = Path(__file__).resolve().parent.parent
_SCRIPTS_DIR = _SKILL_ROOT / "scripts"
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

scan = importlib.import_module("scan")


def fuzz_normalize_results(data: bytes) -> None:
    """Fuzz normalization of arbitrary raw axe payloads."""
    provider = atheris.FuzzedDataProvider(data)
    payload = {
        "violations": [
            {
                "id": provider.ConsumeUnicodeNoSurrogates(20),
                "impact": provider.ConsumeUnicodeNoSurrogates(12),
                "description": provider.ConsumeUnicodeNoSurrogates(40),
                "nodes": [{"target": [provider.ConsumeUnicodeNoSurrogates(8)]}],
            }
        ],
        "passes": [],
        "incomplete": [],
        "inapplicable": [],
    }
    scan.normalize_results(payload, provider.ConsumeUnicodeNoSurrogates(30))


FUZZ_TARGETS = [fuzz_normalize_results]


def fuzz_dispatch(data: bytes) -> None:
    """Route input to one fuzz target."""
    if len(data) < 2:
        return
    FUZZ_TARGETS[data[0] % len(FUZZ_TARGETS)](data[1:])


class TestScanFuzzHarness:
    """Property tests mirroring fuzz-target behavior."""

    def test_normalize_results_handles_missing_sections(self) -> None:
        assert scan.normalize_results({}, target="https://example.com") == {
            "target": "https://example.com",
            "summary": {
                "violations": 0,
                "passes": 0,
                "incomplete": 0,
                "inapplicable": 0,
            },
            "violations": [],
        }

    def test_normalize_results_handles_non_list_sections(self) -> None:
        with suppress(TypeError):
            scan.normalize_results(
                {"violations": {"id": "bad"}}, target="https://example.com"
            )


if __name__ == "__main__" and FUZZING:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_dispatch)
    atheris.Fuzz()
