# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for the evaluation dataset validator."""

from __future__ import annotations

import csv
import io
import json
from copy import deepcopy
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


def _dataset_with_pairs(count: int) -> dict:
    data = _valid_dataset()
    pair = data["evaluation_pairs"][0]
    data["evaluation_pairs"] = [
        dict(deepcopy(pair), id=f"pair-{index}") for index in range(count)
    ]
    data["metadata"]["total_pairs"] = count
    data["metadata"]["distribution"].update(easy=count, grounding=0, safety=0)
    data["metadata"]["population_coverage"].update(
        {"Field technician": count, "Dispatcher": 0}
    )
    return data


def _node_tree(count: int) -> list:
    children, remaining = divmod(count - 1, 1000)
    result = [[None] * 999 for _ in range(children)]
    if remaining:
        result.append([None] * (remaining - 1))
    return result


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


@pytest.mark.parametrize("count", [1000, 1001])
@pytest.mark.parametrize("final_newline", [False, True])
def test_given_pair_limit_when_validated_then_json_and_csv_agree(
    count: int, final_newline: bool
) -> None:
    # Arrange
    data = _dataset_with_pairs(count)
    text = _csv_text(data)
    if not final_newline:
        text = text.rstrip("\n")

    # Act
    rows, csv_errors = parse_csv_pairs(text)
    errors = validate_dataset(data, rows, load_schema(SKILL_ROOT))
    schema_errors = list(
        Draft202012Validator(load_schema(SKILL_ROOT)).iter_errors(data)
    )

    # Assert
    assert bool(errors) == bool(csv_errors) == bool(schema_errors) == (count > 1000)
    assert len(rows) <= 1000


@pytest.mark.parametrize("count", [64, 65])
@pytest.mark.parametrize(
    "field",
    ["user_populations", "populations", "tools_expected", "population_coverage"],
)
def test_given_collection_limit_when_validated_then_schema_and_guard_agree(
    field: str, count: int
) -> None:
    # Arrange
    data = _valid_dataset()
    names = [f"name-{index}" for index in range(count)]
    if field == "population_coverage":
        data["metadata"][field] = dict.fromkeys(names, 0)
    elif field == "user_populations":
        data["metadata"][field] = names
    else:
        data["evaluation_pairs"][0][field] = names

    # Act
    resource_error = validator_module._resource_error(data)
    schema_errors = list(
        Draft202012Validator(load_schema(SKILL_ROOT)).iter_errors(data)
    )

    # Assert
    assert bool(resource_error) == bool(schema_errors) == (count > 64)


@pytest.mark.parametrize("count", [2, 3])
def test_given_mode_limit_when_validated_then_schema_and_guard_agree(
    count: int,
) -> None:
    # Arrange
    data = _valid_dataset()
    data["metadata"]["evaluation_mode"] = ["manual", "batch", "manual"][:count]

    # Act
    errors = validate_dataset(data, _parsed_csv(data), load_schema(SKILL_ROOT))
    schema_errors = list(
        Draft202012Validator(load_schema(SKILL_ROOT)).iter_errors(data)
    )

    # Assert
    assert bool(errors) == bool(schema_errors) == (count > 2)


@pytest.mark.parametrize("extra", [0, 1])
@pytest.mark.parametrize(
    ("field", "limit"),
    [
        ("query", 16384),
        ("expected_response", 16384),
        ("category", 16384),
        ("source_reference", 16384),
        ("notes", 16384),
        ("system_name", 16384),
        ("recommended_tooling", 16384),
        ("generation_method", 16384),
        ("id", 256),
    ],
)
def test_given_string_limit_when_validated_then_schema_and_guard_agree(
    field: str, limit: int, extra: int
) -> None:
    # Arrange
    data = _valid_dataset()
    target = (
        data["metadata"] if field in data["metadata"] else data["evaluation_pairs"][0]
    )
    target[field] = "x" * (limit + extra)

    # Act
    resource_error = validator_module._resource_error(data)
    schema_errors = list(
        Draft202012Validator(load_schema(SKILL_ROOT)).iter_errors(data)
    )

    # Assert
    assert bool(resource_error) == bool(schema_errors) == bool(extra)
    if not extra:
        assert validate_dataset(data, _parsed_csv(data), load_schema(SKILL_ROOT)) == []


@pytest.mark.parametrize("extra", [0, 1])
def test_given_identifier_limits_when_validated_then_names_are_bounded(
    extra: int,
) -> None:
    # Arrange
    data = _valid_dataset()
    name = "n" * (256 + extra)
    data["metadata"]["user_populations"] = [name]
    data["metadata"]["population_coverage"] = {name: 3}
    for pair in data["evaluation_pairs"]:
        pair["populations"] = [name]
        pair["tools_expected"] = [name]

    # Act
    schema_errors = list(
        Draft202012Validator(load_schema(SKILL_ROOT)).iter_errors(data)
    )
    resource_error = validator_module._resource_error(data)
    _, csv_errors = parse_csv_pairs(_csv_text(data))
    property_error = validator_module._resource_error({name: None})

    # Assert
    assert bool(schema_errors) == bool(resource_error) == bool(extra)
    assert bool(csv_errors) == bool(extra)
    assert bool(property_error) == bool(extra)
    if not extra:
        assert validate_dataset(data, _parsed_csv(data), load_schema(SKILL_ROOT)) == []


@pytest.mark.parametrize("depth", [8, 9])
def test_given_container_depth_when_guarded_then_counts_containers(depth: int) -> None:
    # Arrange
    value = None
    for _ in range(depth):
        value = [value]

    # Act
    error = validator_module._resource_error(value)

    # Assert
    assert bool(error) == (depth > 8)


@pytest.mark.parametrize("nodes", [100000, 100001])
def test_given_node_limit_when_guarded_then_combined_roots_are_counted(
    nodes: int,
) -> None:
    # Arrange
    left = _node_tree(50000)
    right = _node_tree(nodes - 50000)

    # Act
    error = validator_module._resource_error(left, right)

    # Assert
    assert bool(error) == (nodes > 100000)


@pytest.mark.parametrize(
    "kind",
    ["depth", "cycle", "nodes", "pairs", "list", "string", "property", "key", "type"],
)
@pytest.mark.parametrize("target", ["json", "csv"])
def test_given_unsafe_direct_input_when_validated_then_schema_is_not_called(
    kind: str, target: str, monkeypatch
) -> None:
    # Arrange
    schema = load_schema(SKILL_ROOT)
    bad = []
    if kind == "depth":
        for _ in range(1500):
            bad = [bad]
    elif kind == "cycle":
        bad.append(bad)
    elif kind == "nodes":
        bad = _node_tree(100001)
    elif kind == "pairs":
        bad = [None] * 1001
    elif kind == "list":
        bad = {"populations": [{}] * 65}
    elif kind == "string":
        bad = {"query": "synthetic-secret" * 2000}
    elif kind == "property":
        bad = {"synthetic-secret" * 20: None}
    elif kind == "key":
        bad = {1: None}
    else:
        bad = {"notes": {1, 2}}

    def unexpected_schema(*args, **kwargs):
        pytest.fail("resource guard must short-circuit schema validation")

    monkeypatch.setattr(Draft202012Validator, "iter_errors", unexpected_schema)

    # Act
    errors = validate_dataset(
        bad if target == "json" else _valid_dataset(),
        bad if target == "csv" else [],
        schema,
    )

    # Assert
    assert len(errors) == 1
    assert "synthetic-secret" not in errors[0]


@pytest.mark.parametrize("extra", [0, 1])
@pytest.mark.parametrize("field", ["id", "query", "tools_expected"])
def test_given_csv_field_limit_when_parsed_then_decoded_lengths_are_bounded(
    field: str, extra: int
) -> None:
    # Arrange
    data = _dataset_with_pairs(1)
    pair = data["evaluation_pairs"][0]
    if field == "id":
        pair[field] = "i" * (256 + extra)
    elif field == "query":
        pair[field] = ('"é,\n' * 4096) + "x" * extra
    else:
        pair[field] = [f"{index:03}" + "t" * 253 for index in range(64 + extra)]
    previous_field_limit = csv.field_size_limit()

    # Act
    rows, errors = parse_csv_pairs(_csv_text(data))

    # Assert
    assert bool(errors) == bool(extra)
    assert csv.field_size_limit() == previous_field_limit
    if not extra:
        assert rows == data["evaluation_pairs"]


@pytest.mark.parametrize("extra", [0, 1])
def test_given_csv_node_limit_when_parsed_then_rows_stop_at_budget(extra: int) -> None:
    # Arrange
    data = _dataset_with_pairs(720)
    names = [f"name-{index}" for index in range(64)]
    for pair in data["evaluation_pairs"][:-1]:
        pair["populations"] = names
        pair["tools_expected"] = names
    data["evaluation_pairs"][-1]["populations"] = names[: 47 + extra]
    data["evaluation_pairs"][-1]["tools_expected"] = []

    # Act
    rows, errors = parse_csv_pairs(_csv_text(data))

    # Assert
    assert bool(errors) == bool(extra)
    assert len(rows) == 720 - extra


@pytest.mark.parametrize("kind", ["rows", "width", "field", "header"])
def test_given_oversized_csv_when_parsed_then_reader_is_not_called(
    kind: str, monkeypatch
) -> None:
    # Arrange
    header = ",".join(CSV_FIELDS) + "\n"
    text = {
        "rows": header + "id,short\n" * 1001,
        "width": header + "id," + "x," * 100000,
        "field": header + "id," + "synthetic-secret" * 2000,
        "header": "id," + "x," * 100000,
    }[kind]

    def unexpected_reader(*args, **kwargs):
        pytest.fail("CSV guard must short-circuit row allocation")

    monkeypatch.setattr(csv, "DictReader", unexpected_reader)

    # Act
    rows, errors = parse_csv_pairs(text)

    # Assert
    assert rows == []
    assert len(errors) == 1
    assert "synthetic-secret" not in errors[0]


@pytest.mark.parametrize("count", [50, 51])
@pytest.mark.parametrize("stage", ["schema", "csv", "parity"])
def test_given_diagnostic_limit_when_validated_then_truncation_stays_inside_cap(
    count: int, stage: str
) -> None:
    # Arrange
    data = _dataset_with_pairs(count)
    rows = _parsed_csv(data)
    if stage == "schema":
        for pair in data["evaluation_pairs"]:
            pair["query"] = ""
    elif stage == "parity":
        for row in rows:
            row["query"] = "synthetic-secret"

    # Act
    if stage == "csv":
        _, errors = parse_csv_pairs(",".join(CSV_FIELDS) + "\n" + "short,row\n" * count)
    else:
        errors = validate_dataset(data, rows, load_schema(SKILL_ROOT))

    # Assert
    assert len(errors) == 50
    assert (errors[-1] == validator_module.TRUNCATION_DIAGNOSTIC) == (count > 50)
    assert "synthetic-secret" not in "\n".join(errors)


def test_given_many_schema_errors_when_validated_then_iteration_stops(
    monkeypatch,
) -> None:
    # Arrange
    data = _dataset_with_pairs(1000)
    for pair in data["evaluation_pairs"]:
        pair["query"] = ""
    schema = load_schema(SKILL_ROOT)
    original = Draft202012Validator.iter_errors
    seen = []

    def bounded_iteration(self, instance, *args, **kwargs):
        for error in original(self, instance, *args, **kwargs):
            seen.append(error)
            assert len(seen) <= 51
            yield error

    monkeypatch.setattr(Draft202012Validator, "iter_errors", bounded_iteration)

    # Act
    errors = validate_dataset(data, [], schema)

    # Assert
    assert len(seen) == 51
    assert len(errors) == 50
    assert errors[-1] == validator_module.TRUNCATION_DIAGNOSTIC


@pytest.mark.parametrize(
    "text",
    ["[" * 10000 + '"synthetic-secret"' + "]" * 10000, "9" * 5000],
    ids=["parser-depth", "integer-digits"],
)
def test_given_parser_resource_failure_when_run_then_returns_sanitized_error(
    text: str, tmp_path, capsys
) -> None:
    # Arrange
    json_path, csv_path = _write_pair(tmp_path, _valid_dataset())
    json_path.write_text(text, encoding="utf-8")

    # Act
    result = run(json_path, csv_path, allowed_roots=(tmp_path,))

    # Assert
    captured = capsys.readouterr()
    assert result == 2
    assert captured.out == ""
    assert captured.err.startswith("validate_evaluation_dataset: ")
    assert "synthetic-secret" not in captured.err


def test_given_dynamic_property_when_invalid_then_path_does_not_echo_name() -> None:
    # Arrange
    data = _valid_dataset()
    data["metadata"]["population_coverage"] = {"synthetic-secret\npath": "bad"}

    # Act
    errors = validate_dataset(data, _parsed_csv(data), load_schema(SKILL_ROOT))

    # Assert
    assert errors == ["$.metadata.population_coverage.[property] violates type"]


@pytest.mark.parametrize("count", [64, 65])
@pytest.mark.parametrize("field", ["populations", "tools_expected"])
def test_given_short_csv_list_when_parsed_then_item_count_is_bounded(
    count: int, field: str
) -> None:
    # Arrange
    data = _dataset_with_pairs(1)
    data["evaluation_pairs"][0][field] = [f"item-{index}" for index in range(count)]

    # Act
    _, errors = parse_csv_pairs(_csv_text(data))

    # Assert
    assert bool(errors) == (count > 64)
    if errors:
        assert "64 entry limit" in errors[0]


def test_given_maximum_lists_when_validated_then_matching_artifacts_pass() -> None:
    # Arrange
    data = _valid_dataset()
    names = [f"{index:03}" + "n" * 253 for index in range(64)]
    data["metadata"]["user_populations"] = names
    data["metadata"]["population_coverage"] = dict.fromkeys(names, 3)
    for pair in data["evaluation_pairs"]:
        pair["populations"] = names
        pair["tools_expected"] = names

    # Act
    errors = validate_dataset(data, _parsed_csv(data), load_schema(SKILL_ROOT))

    # Assert
    assert errors == []


@pytest.mark.parametrize("rows", [None, [None], [{}], [{"query": []}]])
def test_given_malformed_direct_csv_when_validated_then_returns_diagnostics(
    rows,
) -> None:
    # Act
    errors = validate_dataset(_valid_dataset(), rows, load_schema(SKILL_ROOT))

    # Assert
    assert 1 <= len(errors) <= 50


def test_given_csv_parse_failure_when_parsed_then_restores_field_limit() -> None:
    # Arrange
    text = ",".join(CSV_FIELDS) + '\nid,"unterminated'
    previous_field_limit = csv.field_size_limit()

    # Act and assert
    with pytest.raises(EvaluationValidationError, match="CSV cannot be parsed"):
        parse_csv_pairs(text)
    assert csv.field_size_limit() == previous_field_limit


@pytest.mark.parametrize("stage", ["json", "csv", "parity"])
def test_given_capped_failures_when_run_then_preserves_result_shape_and_exit(
    stage: str, tmp_path, capsys
) -> None:
    # Arrange
    data = _dataset_with_pairs(51)
    json_path, csv_path = _write_pair(tmp_path, data)
    if stage == "json":
        for pair in data["evaluation_pairs"]:
            pair["query"] = ""
        json_path.write_text(json.dumps(data), encoding="utf-8")
    elif stage == "csv":
        csv_path.write_text(
            ",".join(CSV_FIELDS) + "\n" + "short,row\n" * 51, encoding="utf-8"
        )
    else:
        for pair in data["evaluation_pairs"]:
            pair["query"] = "synthetic-secret"
        csv_path.write_text(_csv_text(data), encoding="utf-8")

    # Act
    result = run(json_path, csv_path, allowed_roots=(tmp_path,))

    # Assert
    captured = capsys.readouterr()
    output = json.loads(captured.out)
    assert result == 1
    assert set(output) == {"valid", "errors"}
    assert output["valid"] is False
    assert len(output["errors"]) == 50
    assert output["errors"][-1] == validator_module.TRUNCATION_DIAGNOSTIC
    assert "synthetic-secret" not in captured.out
    assert captured.err == ""
