# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Unit tests for moderate.py covering CLI surface and threshold logic.

These tests stub the `detoxify.Detoxify` model to avoid downloading the
~470 MB checkpoint at test time. They exercise argument parsing, record
loading, threshold edge cases, output schema, and exit codes.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any

import pytest

SCRIPT_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SCRIPT_DIR))

import moderate  # noqa: E402


class _FakeModel:
    """Stand-in for Detoxify that returns deterministic scores keyed by text."""

    def __init__(self, _name: str) -> None:
        self._name = _name

    def predict(self, text: str) -> dict[str, float]:
        lowered = text.lower()
        if "kill" in lowered or "threat" in lowered:
            return {"toxicity": 0.95, "threat": 0.9, "insult": 0.4, "identity_attack": 0.1}
        if "stupid" in lowered or "idiot" in lowered:
            return {"toxicity": 0.6, "threat": 0.05, "insult": 0.7, "identity_attack": 0.05}
        return {"toxicity": 0.05, "threat": 0.01, "insult": 0.02, "identity_attack": 0.01}


@pytest.fixture
def fake_detoxify(monkeypatch: pytest.MonkeyPatch) -> None:
    """Inject a fake Detoxify into sys.modules so classify_records uses it."""
    import types

    fake_module = types.ModuleType("detoxify")
    fake_module.Detoxify = _FakeModel  # type: ignore[attr-defined]
    monkeypatch.setitem(sys.modules, "detoxify", fake_module)


def _write_records(tmp_path: Path, records: list[dict[str, Any]]) -> Path:
    """Write JSON-lines records to a temporary file and return its path."""
    path = tmp_path / "input.jsonl"
    with path.open("w", encoding="utf-8") as f:
        for record in records:
            f.write(json.dumps(record) + "\n")
    return path


def _read_output(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def test_clean_text_passes(tmp_path: Path, fake_detoxify: None) -> None:
    records = [{"id": "clean-1", "text": "Hello world, this is a friendly message."}]
    input_path = _write_records(tmp_path, records)
    output_path = tmp_path / "out.json"

    loaded = moderate.load_records(input_path)
    results = moderate.classify_records(loaded, "unbiased", threshold=0.5)
    moderate.write_output(results, output_path)

    data = _read_output(output_path)
    assert data["summary"]["total"] == 1
    assert data["summary"]["flaggedCount"] == 0
    assert data["records"][0]["flagged"] is False
    assert data["records"][0]["flaggedLabels"] == []


def test_threat_text_flagged(tmp_path: Path, fake_detoxify: None) -> None:
    records = [{"id": "threat-1", "text": "I will threat you with violence"}]
    input_path = _write_records(tmp_path, records)
    output_path = tmp_path / "out.json"

    loaded = moderate.load_records(input_path)
    results = moderate.classify_records(loaded, "unbiased", threshold=0.5)
    moderate.write_output(results, output_path)

    data = _read_output(output_path)
    assert data["summary"]["flaggedCount"] == 1
    assert data["records"][0]["flagged"] is True
    assert "toxicity" in data["records"][0]["flaggedLabels"]
    assert "threat" in data["records"][0]["flaggedLabels"]


def test_threshold_below_score_flags(tmp_path: Path, fake_detoxify: None) -> None:
    records = [{"id": "insult-1", "text": "You are an idiot"}]
    input_path = _write_records(tmp_path, records)
    output_path = tmp_path / "out.json"

    loaded = moderate.load_records(input_path)
    # threshold 0.3 is below the insult score (0.7), should flag
    results = moderate.classify_records(loaded, "unbiased", threshold=0.3)
    moderate.write_output(results, output_path)

    data = _read_output(output_path)
    assert data["records"][0]["flagged"] is True
    assert "insult" in data["records"][0]["flaggedLabels"]


def test_threshold_above_score_passes(tmp_path: Path, fake_detoxify: None) -> None:
    records = [{"id": "insult-2", "text": "You are an idiot"}]
    input_path = _write_records(tmp_path, records)
    output_path = tmp_path / "out.json"

    loaded = moderate.load_records(input_path)
    # threshold 0.95 is above all scores
    results = moderate.classify_records(loaded, "unbiased", threshold=0.95)
    moderate.write_output(results, output_path)

    data = _read_output(output_path)
    assert data["records"][0]["flagged"] is False


def test_per_record_threshold_overrides_batch_default(tmp_path: Path, fake_detoxify: None) -> None:
    records = [
        {"id": "strict", "text": "You are an idiot", "threshold": 0.3},
        {"id": "lenient", "text": "You are an idiot", "threshold": 0.95},
    ]
    input_path = _write_records(tmp_path, records)

    loaded = moderate.load_records(input_path)
    results = moderate.classify_records(loaded, "unbiased", threshold=0.5)

    assert results[0]["flagged"] is True
    assert results[0]["threshold"] == 0.3
    assert results[1]["flagged"] is False
    assert results[1]["threshold"] == 0.95


def test_multilingual_model_selectable(tmp_path: Path, fake_detoxify: None) -> None:
    records = [{"id": "multi-1", "text": "Bonjour le monde"}]
    input_path = _write_records(tmp_path, records)
    output_path = tmp_path / "out.json"

    loaded = moderate.load_records(input_path)
    results = moderate.classify_records(loaded, "multilingual", threshold=0.5)
    moderate.write_output(results, output_path)

    data = _read_output(output_path)
    assert data["summary"]["total"] == 1


def test_load_records_skips_malformed_lines(tmp_path: Path) -> None:
    path = tmp_path / "mixed.jsonl"
    path.write_text(
        '{"id": "ok-1", "text": "valid"}\n'
        "not-json\n"
        '{"id": "ok-2"}\n'  # missing text
        '{"id": "ok-3", "text": "valid-2"}\n',
        encoding="utf-8",
    )

    records = moderate.load_records(path)
    assert [r["id"] for r in records] == ["ok-1", "ok-3"]


def test_empty_input_writes_empty_output(tmp_path: Path) -> None:
    input_path = _write_records(tmp_path, [])
    output_path = tmp_path / "out.json"

    sys.argv = [
        "moderate.py",
        "--input",
        str(input_path),
        "--output",
        str(output_path),
    ]
    exit_code = moderate.main()
    assert exit_code == 0
    data = _read_output(output_path)
    assert data == {"records": [], "summary": {"total": 0, "flaggedCount": 0}}


def test_invalid_threshold_returns_error_exit(tmp_path: Path) -> None:
    input_path = _write_records(tmp_path, [{"id": "x", "text": "y"}])
    output_path = tmp_path / "out.json"
    sys.argv = [
        "moderate.py",
        "--input",
        str(input_path),
        "--output",
        str(output_path),
        "--threshold",
        "1.5",
    ]
    assert moderate.main() == moderate.EXIT_ERROR


def test_cli_help_lists_required_flags() -> None:
    result = subprocess.run(
        [sys.executable, str(SCRIPT_DIR / "moderate.py"), "--help"],
        check=True,
        capture_output=True,
        text=True,
    )
    assert "--input" in result.stdout
    assert "--threshold" in result.stdout
    assert "--model" in result.stdout
    assert "--output" in result.stdout
