# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Polyglot fuzz harness for the graphify skill wrapper.

Runs as a pytest test when Atheris is not installed (CI default).
Runs as an Atheris coverage-guided fuzz target when executed directly.
"""

from __future__ import annotations

import sys
from contextlib import suppress
from pathlib import Path

try:
    import atheris

    FUZZING = True
except ImportError:
    FUZZING = False

from graphify_wrapper import build_graph


def fuzz_build_graph_mode(data: bytes) -> None:
    """Fuzz build_graph mode validation. The wrapper must reject unknown modes
    with ValueError without ever invoking subprocess."""
    if FUZZING:
        fdp = atheris.FuzzedDataProvider(data)
        mode = fdp.ConsumeUnicodeNoSurrogates(16)
    else:
        mode = data.decode("utf-8", errors="ignore")[:16]
    with suppress(ValueError):
        build_graph(Path("."), mode=mode, update=False)


def test_fuzz_build_graph_mode() -> None:
    """Pytest entry point — feeds a small fixed corpus through the harness."""
    for sample in (b"", b"fast", b"deep", b"unknown", b"\x00\x01\x02"):
        fuzz_build_graph_mode(sample)


def main() -> None:
    atheris.Setup(sys.argv, fuzz_build_graph_mode)
    atheris.Fuzz()


if __name__ == "__main__" and FUZZING:
    main()
