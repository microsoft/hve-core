# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for the VEX gate helper logic.

Runs as a pytest test when Atheris is not installed.
Runs as an Atheris coverage-guided fuzz target when executed directly.
"""

from __future__ import annotations

import sys

import vex_gate

try:
    import atheris
except ImportError:
    atheris = None
    FUZZING = False
else:
    FUZZING = True


def fuzz_parse_finding_ids(data: bytes) -> None:
    """Fuzz parsing of detection-issue table bodies."""
    provider = atheris.FuzzedDataProvider(data)
    body = provider.ConsumeUnicodeNoSurrogates(provider.remaining_bytes())
    vex_gate.parse_finding_ids(body)


def fuzz_all_terminal(data: bytes) -> None:
    """Fuzz terminal-status evaluation over arbitrary document shapes."""
    provider = atheris.FuzzedDataProvider(data)
    name = provider.ConsumeUnicodeNoSurrogates(40)
    status = provider.ConsumeUnicodeNoSurrogates(20)
    finding = provider.ConsumeUnicodeNoSurrogates(40)
    document = {"statements": [{"vulnerability": {"name": name}, "status": status}]}
    vex_gate.all_terminal(document, [finding])


def fuzz_evaluate(data: bytes) -> None:
    """Fuzz the end-to-end proceed/skip decision."""
    provider = atheris.FuzzedDataProvider(data)
    body = provider.ConsumeUnicodeNoSurrogates(provider.ConsumeIntInRange(0, 200))
    name = provider.ConsumeUnicodeNoSurrogates(40)
    status = provider.ConsumeUnicodeNoSurrogates(20)
    document = {"statements": [{"vulnerability": {"name": name}, "status": status}]}
    vex_gate.evaluate(body, document)


FUZZ_TARGETS = [
    fuzz_parse_finding_ids,
    fuzz_all_terminal,
    fuzz_evaluate,
]


def fuzz_dispatch(data: bytes) -> None:
    """Route input to one fuzz target."""
    if len(data) < 2:
        return
    target_index = data[0] % len(FUZZ_TARGETS)
    FUZZ_TARGETS[target_index](data[1:])


class TestVexGateFuzzHarness:
    """Property tests mirroring fuzz-target behavior (run under pytest)."""

    def test_parse_never_raises_on_arbitrary_text(self) -> None:
        for body in ("", "|", "||", "| |", "no pipes", "| CVE-2020-1 |"):
            assert isinstance(vex_gate.parse_finding_ids(body), list)

    def test_all_terminal_handles_malformed_documents(self) -> None:
        for document in ({}, {"statements": None}, {"statements": ["x"]}):
            assert vex_gate.all_terminal(document, ["CVE-2020-1"]) is False

    def test_evaluate_is_boolean(self) -> None:
        result = vex_gate.evaluate("| CVE-2020-1 | a |", {"statements": []})
        assert result is True


if __name__ == "__main__" and FUZZING:
    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_dispatch)
    atheris.Fuzz()
