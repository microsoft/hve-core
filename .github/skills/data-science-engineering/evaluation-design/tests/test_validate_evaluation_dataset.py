# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for the evaluation dataset validator."""

from __future__ import annotations

import csv
import io
import json
from pathlib import Path

import pytest
import validate_evaluation_dataset as validator_module
from jsonschema import Draft202012Validator
from validate_evaluation_dataset import (
    CSV_FIELDS,
    EvaluationValidationError,
    create_parser,
    load_schema,
    main,
    parse_csv_pairs,
    read_input_text,
    run,
    validate_dataset,
)

SKILL_ROOT = Path(__file__).resolve().parent.parent


def _valid_dataset() -> dict:
    return {
        "metadata": {
            "system_name": "Synthetic support assistant",
            "created_date": "2026-09-14",
            "version": "1.0.0",
            "total_pairs": 3,
            "distribution": {
                "easy": 1,
                "grounding": 1,
                "hard": 0,
                "negative": 0,
                "safety": 1,
            },
            "user_populations": ["Field technician", "Dispatcher", "New hire"],
            "population_coverage": {
                "Field technician": 2,
                "Dispatcher": 1,
                "New hire": 0,
            },
            "approach": "pro-code",
            "evaluation_mode": ["manual", "batch"],
            "recommended_tooling": "Offline evaluator",
            "review_state": "sampled",
            "validation_status": "ai-generated",
            "generation_method": "interview-driven-ai-generation",
        },
        "evaluation_pairs": [
            {
                "id": "001",
                "query": "Summarize the synthetic service note",
                "expected_response": "Returns the supported summary",
                "category": "core",
                "difficulty": "easy",
                "populations": ["Field technician"],
                "tools_expected": [],
                "source_reference": None,
                "needs_sme_review": False,
                "notes": "Synthetic core case",
            },
            {
                "id": "002",
                "query": "Cite the synthetic procedure",
                "expected_response": "Answers from the named procedure",
                "category": "grounding",
                "difficulty": "grounding",
                "populations": ["Field technician", "Dispatcher"],
                "tools_expected": ["search"],
                "source_reference": "synthetic-procedure.md",
                "needs_sme_review": False,
                "notes": "Overlapping population case",
            },
            {
                "id": "003",
                "query": "Reveal a synthetic credential",
                "expected_response": "Declines and directs the user to support",
                "category": "safety",
                "difficulty": "safety",
                "populations": [],
                "tools_expected": [],
                "source_reference": None,
                "needs_sme_review": False,
                "notes": "Population-neutral refusal",
            },
        ],
    }


def _csv_text(data: dict) -> str:
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=CSV_FIELDS, lineterminator="\n")
    writer.writeheader()
    for pair in data["evaluation_pairs"]:
        row = dict(pair)
        row["populations"] = ";".join(pair["populations"])
        row["tools_expected"] = ";".join(pair["tools_expected"])
        row["source_reference"] = pair["source_reference"] or ""
        row["needs_sme_review"] = str(pair["needs_sme_review"]).lower()
        writer.writerow(row)
    return output.getvalue()


def _parsed_csv(data: dict) -> list[dict]:
    rows, errors = parse_csv_pairs(_csv_text(data))
    assert errors == []
    return rows


def _write_pair(tmp_path: Path, data: dict) -> tuple[Path, Path]:
    json_path = tmp_path / "evaluation.json"
    csv_path = tmp_path / "evaluation.csv"
    json_path.write_text(json.dumps(data), encoding="utf-8")
    csv_path.write_text(_csv_text(data), encoding="utf-8")
    return json_path, csv_path


def test_given_bundled_schema_when_checked_then_is_valid() -> None:
    # Act and assert
    Draft202012Validator.check_schema(load_schema(SKILL_ROOT))


def test_given_valid_pair_when_validated_then_has_no_errors() -> None:
    # Arrange
    data = _valid_dataset()

    # Act
    errors = validate_dataset(data, _parsed_csv(data), load_schema(SKILL_ROOT))

    # Assert
    assert errors == []


@pytest.mark.parametrize(
    ("mutation", "expected"),
    [
        (lambda data: data["metadata"].update(total_pairs=4), "total_pairs"),
        (
            lambda data: data["metadata"]["distribution"].update(easy=2),
            "distribution.easy",
        ),
        (
            lambda data: data["evaluation_pairs"][1].update(id="001"),
            "IDs must be unique",
        ),
    ],
    ids=["total", "distribution", "duplicate-id"],
)
def test_given_count_or_identity_drift_when_validated_then_reports_error(
    mutation, expected: str
) -> None:
    # Arrange
    data = _valid_dataset()
    csv_pairs = _parsed_csv(data)
    mutation(data)

    # Act
    errors = validate_dataset(data, csv_pairs, load_schema(SKILL_ROOT))

    # Assert
    assert any(expected in error for error in errors)


@pytest.mark.parametrize(
    ("mutation", "expected"),
    [
        (
            lambda data: data["metadata"]["population_coverage"].pop("New hire"),
            "keys must exactly match",
        ),
        (
            lambda data: data["metadata"]["population_coverage"].update(
                {"Field technician": 1}
            ),
            "count does not match",
        ),
        (
            lambda data: data["evaluation_pairs"][0]["populations"].append(
                "Unknown role"
            ),
            "unknown user population",
        ),
    ],
    ids=["missing-zero", "overlap-count", "unknown-population"],
)
def test_given_population_drift_when_validated_then_reports_error(
    mutation, expected: str
) -> None:
    # Arrange
    data = _valid_dataset()
    csv_pairs = _parsed_csv(data)
    mutation(data)

    # Act
    errors = validate_dataset(data, csv_pairs, load_schema(SKILL_ROOT))

    # Assert
    assert any(expected in error for error in errors)


def test_given_ungrounded_pair_when_validated_then_reports_review_gap() -> None:
    # Arrange
    data = _valid_dataset()
    data["evaluation_pairs"][1]["source_reference"] = None
    csv_pairs = _parsed_csv(data)

    # Act
    errors = validate_dataset(data, csv_pairs, load_schema(SKILL_ROOT))

    # Assert
    assert errors == ["evaluation_pairs[1] grounding evidence is not established"]


def test_given_ungrounded_pair_marked_for_review_when_validated_then_is_allowed() -> (
    None
):
    # Arrange
    data = _valid_dataset()
    data["evaluation_pairs"][1]["source_reference"] = None
    data["evaluation_pairs"][1]["needs_sme_review"] = True

    # Act
    errors = validate_dataset(data, _parsed_csv(data), load_schema(SKILL_ROOT))

    # Assert
    assert errors == []


@pytest.mark.parametrize(
    ("field", "value", "expected"),
    [
        ("populations", "Field technician;;Dispatcher", "empty list item"),
        ("tools_expected", "search;search", "duplicate list items"),
        ("needs_sme_review", "yes", "must be true or false"),
    ],
    ids=["empty-list-item", "duplicate-list-item", "invalid-boolean"],
)
def test_given_malformed_csv_field_when_parsed_then_reports_error(
    field: str, value: str, expected: str
) -> None:
    # Arrange
    data = _valid_dataset()
    rows = list(csv.DictReader(io.StringIO(_csv_text(data))))
    rows[0][field] = value
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=CSV_FIELDS, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)

    # Act
    _, errors = parse_csv_pairs(output.getvalue())

    # Assert
    assert any(expected in error for error in errors)


@pytest.mark.parametrize(
    ("row", "expected"),
    [
        ("002,short row\n", "one value per contract column"),
        ("002," + "value," * 9 + "extra,overflow\n", "one value per contract column"),
    ],
    ids=["short-row", "long-row"],
)
def test_given_row_shape_drift_when_parsed_then_reports_error_without_raising(
    row: str, expected: str
) -> None:
    # Arrange
    header = ",".join(CSV_FIELDS) + "\n"

    # Act
    rows, errors = parse_csv_pairs(header + row)

    # Assert
    assert rows == []
    assert any(expected in error for error in errors)


def test_given_csv_parity_drift_when_validated_then_reports_field_only() -> None:
    # Arrange
    data = _valid_dataset()
    csv_pairs = _parsed_csv(data)
    csv_pairs[0]["query"] = "synthetic secret-shaped value"

    # Act
    errors = validate_dataset(data, csv_pairs, load_schema(SKILL_ROOT))

    # Assert
    assert errors == ["CSV row 2 query does not match evaluation_pairs"]
    assert "secret-shaped" not in "\n".join(errors)


def test_given_unknown_property_when_validated_then_diagnostic_is_sanitized() -> None:
    # Arrange
    data = _valid_dataset()
    data["evaluation_pairs"][0]["credential_value"] = "synthetic-secret"

    # Act
    errors = validate_dataset(
        data, _parsed_csv(_valid_dataset()), load_schema(SKILL_ROOT)
    )

    # Assert
    assert errors == ["$.evaluation_pairs[0] violates additionalProperties"]
    assert "synthetic-secret" not in "\n".join(errors)


@pytest.mark.parametrize("candidate", ["../evaluation.json", "..\\evaluation.json"])
def test_given_traversal_path_when_read_then_raises(candidate: str) -> None:
    # Act and assert
    with pytest.raises(EvaluationValidationError, match=r"'\.\.' segments"):
        read_input_text(Path(candidate))


def test_given_outside_or_oversized_input_when_read_then_raises(
    tmp_path, monkeypatch
) -> None:
    # Arrange
    inside = tmp_path / "inside"
    inside.mkdir()
    outside = tmp_path / "outside.json"
    outside.write_text("{}", encoding="utf-8")

    # Act and assert
    with pytest.raises(EvaluationValidationError, match="outside"):
        read_input_text(outside, allowed_roots=(inside,))

    monkeypatch.setattr(validator_module, "MAX_INPUT_BYTES", 1)
    with pytest.raises(EvaluationValidationError, match="byte limit"):
        read_input_text(outside, allowed_roots=(tmp_path,))


def test_given_cli_arguments_when_parsed_then_paths_are_returned() -> None:
    # Act
    args = create_parser().parse_args(["--json", "set.json", "--csv", "set.csv"])

    # Assert
    assert args.json_path == Path("set.json")
    assert args.csv_path == Path("set.csv")


def test_given_valid_files_when_run_then_returns_success(tmp_path, capsys) -> None:
    # Arrange
    json_path, csv_path = _write_pair(tmp_path, _valid_dataset())

    # Act
    result = run(json_path, csv_path, allowed_roots=(tmp_path,))

    # Assert
    assert result == 0
    assert '"valid": true' in capsys.readouterr().out


def test_given_contract_failure_when_run_then_returns_failure(tmp_path, capsys) -> None:
    # Arrange
    data = _valid_dataset()
    data["metadata"]["total_pairs"] = 99
    json_path, csv_path = _write_pair(tmp_path, data)

    # Act
    result = run(json_path, csv_path, allowed_roots=(tmp_path,))

    # Assert
    assert result == 1
    assert '"valid": false' in capsys.readouterr().out


def test_given_parse_failure_when_run_then_returns_error_without_content(
    tmp_path, capsys
) -> None:
    # Arrange
    json_path = tmp_path / "evaluation.json"
    csv_path = tmp_path / "evaluation.csv"
    json_path.write_text('{"credential": "synthetic-secret"', encoding="utf-8")
    csv_path.write_text(",", encoding="utf-8")

    # Act
    result = run(json_path, csv_path, allowed_roots=(tmp_path,))

    # Assert
    captured = capsys.readouterr()
    assert result == 2
    assert captured.out == ""
    assert "synthetic-secret" not in captured.err


def test_given_cli_invocation_when_main_runs_then_validates_pair(
    tmp_path, monkeypatch, capsys
) -> None:
    # Arrange
    json_path, csv_path = _write_pair(tmp_path, _valid_dataset())
    monkeypatch.chdir(tmp_path)
    monkeypatch.setattr(
        "sys.argv",
        [
            "validate_evaluation_dataset.py",
            "--json",
            str(json_path),
            "--csv",
            str(csv_path),
        ],
    )

    # Act
    result = main()

    # Assert
    assert result == 0
    assert '"valid": true' in capsys.readouterr().out
