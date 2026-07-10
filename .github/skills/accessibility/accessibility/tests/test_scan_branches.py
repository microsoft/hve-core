# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import subprocess
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import pytest
import scan


def test_normalize_results_non_dict_returns_empty_summary() -> None:
    result = scan.normalize_results("not-a-dict", target="https://example.com")

    assert result["target"] == "https://example.com"
    assert result["summary"] == {
        "violations": 0,
        "passes": 0,
        "incomplete": 0,
        "inapplicable": 0,
    }
    assert result["violations"] == []


def test_run_scan_raises_on_called_process_error() -> None:
    error = subprocess.CalledProcessError(1, "npx", stderr="boom")
    with patch("scan.subprocess.run", side_effect=error):
        with pytest.raises(scan.ScriptError, match="Scanner failed: boom"):
            scan.run_scan("https://example.com")


def test_run_scan_uses_placeholder_when_stderr_is_empty() -> None:
    error = subprocess.CalledProcessError(1, "npx", stderr="")
    with patch("scan.subprocess.run", side_effect=error):
        with pytest.raises(scan.ScriptError, match="No scanner output captured"):
            scan.run_scan("https://example.com")


def test_run_scan_raises_on_invalid_json() -> None:
    with patch("scan.subprocess.run") as mock_run:
        mock_run.return_value = SimpleNamespace(stdout="not json", stderr="")
        with pytest.raises(scan.ScriptError, match="invalid JSON"):
            scan.run_scan("https://example.com")


def test_run_scan_raises_on_non_dict_payload() -> None:
    with patch("scan.subprocess.run") as mock_run:
        mock_run.return_value = SimpleNamespace(stdout="[]", stderr="")
        with pytest.raises(scan.ScriptError, match="unexpected payload"):
            scan.run_scan("https://example.com")


def test_write_output_prints_to_stdout_when_no_path(capsys) -> None:
    scan.write_output({"a": 1}, None)

    assert '"a": 1' in capsys.readouterr().out


def test_write_output_creates_parent_directories_and_writes_file(
    tmp_path: Path,
) -> None:
    out = tmp_path / "nested" / "report.json"

    scan.write_output({"a": 1}, out)

    assert out.exists()
    assert '"a": 1' in out.read_text(encoding="utf-8")


def test_main_success_writes_output(tmp_path: Path) -> None:
    out = tmp_path / "report.json"
    with patch("scan.subprocess.run") as mock_run:
        mock_run.return_value = SimpleNamespace(stdout='{"violations": []}', stderr="")

        exit_code = scan.main(["https://example.com", "--output", str(out)])

    assert exit_code == scan.EXIT_SUCCESS
    assert out.exists()


def test_main_returns_error_code_on_script_error(capsys) -> None:
    with patch("scan.subprocess.run", side_effect=FileNotFoundError("npx")):
        exit_code = scan.main(["https://example.com"])

    assert exit_code == scan.EXIT_USAGE
    assert "Error:" in capsys.readouterr().err
