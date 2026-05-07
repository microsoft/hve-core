# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Thin wrapper around the upstream `graphify` CLI.

This skill orchestrates the upstream graphifyy package; it does not reimplement
graph construction. The wrapper exists so the skill exposes a stable subprocess
entry point and so tests can mock the CLI boundary.
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path


class GraphifyNotInstalledError(RuntimeError):
    """Raised when the `graphify` CLI binary cannot be located on PATH."""


def graphify_executable() -> str:
    """Return the absolute path to the `graphify` CLI or raise."""
    path = shutil.which("graphify")
    if path is None:
        raise GraphifyNotInstalledError(
            "graphify CLI not found on PATH. Install with `pip install graphifyy`."
        )
    return path


def build_graph(target: Path, mode: str = "standard", update: bool = True) -> int:
    """Invoke `graphify <target> --mode <mode> [--update]` and return its exit code."""
    if mode not in {"fast", "standard", "deep"}:
        raise ValueError(f"unsupported mode: {mode!r}")
    cmd = [graphify_executable(), str(target), "--mode", mode]
    if update:
        cmd.append("--update")
    return subprocess.run(cmd, check=False).returncode
