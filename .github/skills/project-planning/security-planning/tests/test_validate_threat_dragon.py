# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for Threat Dragon v2.6.2 model validation."""

from __future__ import annotations

import copy
import hashlib
import json
import subprocess
import sys
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import validate_threat_dragon  # noqa: E402

SCRIPT_PATH = SCRIPTS_DIR / "validate_threat_dragon.py"
GOLDEN = (
    ROOT
    / "tests"
    / "fixtures"
    / "threat-dragon"
    / "expected"
    / "commerce.threat-dragon.json"
)
SCHEMA_PROVENANCE = (
    ROOT / "assets" / "threat-dragon" / "threat-dragon-v2.6.2.provenance.json"
)


def _golden() -> dict[str, Any]:
    return json.loads(GOLDEN.read_text(encoding="utf-8"))


def _cell(model: dict[str, Any], diagram: int, shape: str) -> dict[str, Any]:
    return next(
        c for c in model["detail"]["diagrams"][diagram]["cells"] if c["shape"] == shape
    )


def _dangling_flow(model: dict[str, Any]) -> None:
    _cell(model, 0, "flow")["target"]["cell"] = "4d2f7a4b-8c33-5d6e-9f10-112233445566"


def _boundary_threat(model: dict[str, Any]) -> None:
    flow_threat = copy.deepcopy(_cell(model, 0, "flow")["data"]["threats"][0])
    flow_threat["id"] = "a6f0c1d2-1111-5222-8333-444455556666"
    _cell(model, 0, "trust-boundary-box")["data"]["threats"].append(flow_threat)


def _open_flag(model: dict[str, Any]) -> None:
    _cell(model, 0, "flow")["data"]["hasOpenThreats"] = False


def _bad_version(model: dict[str, Any]) -> None:
    model["version"] = "2.7.0"


def _bad_threat_top(model: dict[str, Any]) -> None:
    model["detail"]["threatTop"] = 9


def _bad_diagram_top(model: dict[str, Any]) -> None:
    model["detail"]["diagramTop"] = 5


def _duplicate_id(model: dict[str, Any]) -> None:
    cells = model["detail"]["diagrams"][0]["cells"]
    cells[1]["id"] = cells[0]["id"]


def _non_uuid5_id(model: dict[str, Any]) -> None:
    model["summary"]["id"] = "00000000-0000-4000-8000-000000000000"


def _gap_in_numbers(model: dict[str, Any]) -> None:
    flow_threat = _cell(model, 0, "flow")["data"]["threats"][0]
    flow_threat["number"] = 7
    model["detail"]["threatTop"] = 7


def _bad_status(model: dict[str, Any]) -> None:
    _cell(model, 0, "flow")["data"]["threats"][0]["status"] = "Closed"


def _schema_type(model: dict[str, Any]) -> None:
    model["detail"]["diagrams"][0]["id"] = "zero"


@pytest.mark.parametrize(
    ("mutate", "message"),
    [
        (_dangling_flow, "is not a node in the diagram"),
        (_boundary_threat, "trust boundaries cannot carry threats"),
        (_open_flag, "hasOpenThreats does not match"),
        (_bad_version, "$.version"),
        (_bad_threat_top, "threatTop"),
        (_bad_diagram_top, "diagramTop"),
        (_duplicate_id, "duplicate id"),
        (_non_uuid5_id, "UUID version 5"),
        (_gap_in_numbers, "contiguous"),
        (_bad_status, "unsupported status"),
        (_schema_type, "$.detail.diagrams[0].id: expected integer"),
    ],
    ids=lambda value: getattr(value, "__name__", ""),
)
def test_given_broken_model_when_validated_then_error_is_reported(
    mutate: Callable[[dict[str, Any]], None], message: str
) -> None:
    # Arrange
    model = _golden()
    mutate(model)

    # Act
    errors = validate_threat_dragon.validate_model(model)

    # Assert
    assert any(message in error for error in errors), errors


def test_given_golden_model_when_validated_then_no_errors() -> None:
    # Arrange
    model = _golden()

    # Act
    errors = validate_threat_dragon.validate_model(model)

    # Assert
    assert errors == []


def test_given_nullable_dash_when_validated_then_null_is_accepted() -> None:
    # Arrange
    model = _golden()
    body = _cell(model, 0, "actor")["attrs"]["body"]

    # Act
    body["strokeDasharray"] = None
    errors = validate_threat_dragon.validate_model(model)

    # Assert
    assert errors == []


def test_given_unsupported_schema_keyword_when_loaded_then_schema_error(
    tmp_path: Path,
) -> None:
    # Arrange
    schema_path = tmp_path / "schema.json"
    schema_path.write_text(
        json.dumps({"type": "object", "oneOf": []}), encoding="utf-8"
    )

    # Act and Assert
    with pytest.raises(validate_threat_dragon.SchemaError, match="oneOf"):
        validate_threat_dragon.load_schema(schema_path)


def test_given_vendored_schema_when_hashed_then_matches_provenance() -> None:
    # Arrange
    provenance = json.loads(SCHEMA_PROVENANCE.read_text(encoding="utf-8"))
    data = validate_threat_dragon.SCHEMA_PATH.read_bytes()

    # Act
    digest = hashlib.sha256(data).hexdigest().upper()

    # Assert
    assert digest == provenance["sha256"]
    assert len(data) == provenance["sizeBytes"]


@pytest.mark.parametrize(
    ("content", "expected_exit"),
    [(None, 0), ('{"version": "2.6.2"}', 1), ("{not json", 2)],
    ids=["valid", "invalid", "unreadable"],
)
def test_given_model_file_when_cli_runs_then_exit_code_matches(
    tmp_path: Path, content: str | None, expected_exit: int
) -> None:
    # Arrange
    path = tmp_path / "model.json"
    path.write_text(
        GOLDEN.read_text(encoding="utf-8") if content is None else content,
        encoding="utf-8",
    )

    # Act
    result = subprocess.run(
        [sys.executable, str(SCRIPT_PATH), str(path)],
        capture_output=True,
        text=True,
        check=False,
    )

    # Assert
    assert result.returncode == expected_exit, result.stderr


def test_given_missing_file_when_cli_runs_then_exit_two(tmp_path: Path) -> None:
    # Arrange
    path = tmp_path / "missing.json"

    # Act
    result = subprocess.run(
        [sys.executable, str(SCRIPT_PATH), str(path)],
        capture_output=True,
        text=True,
        check=False,
    )

    # Assert
    assert result.returncode == 2
