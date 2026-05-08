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
from types import SimpleNamespace
from unittest.mock import patch

try:
    import atheris

    FUZZING = True
except ImportError:
    FUZZING = False

import graphify_wrapper
from graphify_wrapper import build_graph


class _StubCompleted:
    returncode = 0


def _stub_executable() -> str:
    return "/nonexistent/graphify-fuzz-stub"


def _stub_run(*_args, **_kwargs) -> _StubCompleted:
    return _StubCompleted()


def fuzz_build_graph_mode(data: bytes) -> None:
    """Fuzz build_graph mode validation. The wrapper must reject unknown modes
    with ValueError without ever invoking subprocess.

    Neutralizes the subprocess boundary for the duration of each call so valid
    modes ("fast"/"standard"/"deep") never spawn the upstream `graphify` CLI.
    Without this, `deep` mode would upload cwd contents to a remote service.

    Uses ``unittest.mock.patch.object`` so the stub is scoped to this call's
    context manager rather than mutating the global ``subprocess`` module
    attribute (which would leak across workers under pytest-xdist or other
    in-process parallel runners). The wrapper's ``subprocess`` reference is
    rebound to a ``SimpleNamespace`` fake so the real stdlib module is never
    touched.
    """
    if FUZZING:
        fdp = atheris.FuzzedDataProvider(data)
        mode = fdp.ConsumeUnicodeNoSurrogates(16)
    else:
        mode = data.decode("utf-8", errors="ignore")[:16]
    fake_subprocess = SimpleNamespace(run=_stub_run)
    with (
        patch.object(graphify_wrapper, "graphify_executable", _stub_executable),
        patch.object(graphify_wrapper, "subprocess", fake_subprocess),
        suppress(ValueError),
    ):
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
