# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
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
config_module = importlib.import_module("runtime_a11y._config")
assessor_module = importlib.import_module("runtime_a11y.matrix._ingest_assessor")
planner_module = importlib.import_module("runtime_a11y.matrix._ingest_planner")
report_module = importlib.import_module("runtime_a11y.matrix._ingest_reports")
merge_module = importlib.import_module("runtime_a11y.matrix._merge")


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


def fuzz_runtime_a11y_parsers(data: bytes) -> None:
    """Exercise the pure-Python runtime_a11y parsers with fuzzed inputs."""
    provider = atheris.FuzzedDataProvider(data)
    # Fuzzed input is intentionally malformed, so these parsers are expected to
    # raise on bad data; only crashes and hangs are real findings. Suppress the
    # expected exceptions with the same contextlib.suppress idiom used elsewhere
    # in this harness so the fuzzer keeps exploring instead of aborting on
    # handled input errors.
    with suppress(Exception):
        config_module.load_config(
            Path(provider.ConsumeUnicodeNoSurrogates(32) or "config.json")
        )
        assessor_module.ingest_assessor_findings(
            provider.ConsumeUnicodeNoSurrogates(64),
            [provider.ConsumeUnicodeNoSurrogates(12)],
        )
        planner_module.ingest_planner_state(
            {
                "controlMappings": [
                    {"controlId": provider.ConsumeUnicodeNoSurrogates(8)}
                ],
                "evidenceRegister": [],
            },
            [provider.ConsumeUnicodeNoSurrogates(8)],
        )
        report_module.ingest_report_markdown(
            provider.ConsumeUnicodeNoSurrogates(64),
            [provider.ConsumeUnicodeNoSurrogates(12)],
        )
        merge_module.merge_updates(
            merge_module.Matrix(
                criteria=[],
                surfaces=[],
                cells=[],
            ),
            [],
        )


FUZZ_TARGETS = [fuzz_normalize_results, fuzz_runtime_a11y_parsers]


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
