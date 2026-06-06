# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Tests for the ``python -m mural`` package entry point.

Guards against regression of the ``be4bb61e`` package-split bug where
``scripts/mural/__main__.py`` was missing and every documented
``python -m mural ...`` invocation in ``SKILL.md`` failed with
``No module named mural.__main__``.
"""

from __future__ import annotations

import pathlib
import runpy
import subprocess
import sys
from typing import Any
from unittest import mock

import pytest

PACKAGE_DIR = pathlib.Path(__file__).resolve().parent.parent / "scripts" / "mural"
SCRIPTS_DIR = PACKAGE_DIR.parent


def test_main_module_file_exists() -> None:
    assert (PACKAGE_DIR / "__main__.py").is_file()


def test_main_module_invokes_package_main(mural_module: Any) -> None:
    with mock.patch.object(mural_module, "main", return_value=0) as fake_main:
        with pytest.raises(SystemExit) as excinfo:
            runpy.run_module("mural", run_name="__main__")

    assert excinfo.value.code == 0
    fake_main.assert_called_once_with()


def test_python_dash_m_mural_help_exits_zero() -> None:
    result = subprocess.run(
        [sys.executable, "-m", "mural", "--help"],
        cwd=SCRIPTS_DIR,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )

    assert result.returncode == 0, (
        f"`python -m mural --help` failed (exit {result.returncode}).\n"
        f"stderr: {result.stderr}\nstdout: {result.stdout}"
    )
    assert "usage: mural" in result.stdout
