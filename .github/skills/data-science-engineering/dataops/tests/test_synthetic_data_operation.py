# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for synthetic-data operation validation and local commit."""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path

import pytest
import synthetic_data_operation as operation_module
from jsonschema import Draft202012Validator
from synthetic_data_operation import (
    EXIT_ERROR,
    EXIT_FAILURE,
    EXIT_SUCCESS,
    OperationError,
    commit_local,
    create_parser,
    load_schema,
    main,
    read_record,
    run,
    sha256_file,
    validate_operation,
)


def _digest(value: bytes = b"source") -> str:
    return f"sha256:{hashlib.sha256(value).hexdigest()}"


def _decision(*roles: str, applicable: bool = True) -> dict:
    return {
        "decision_id": "decision-1",
        "revision_id": "revision-1",
        "owner_roles": list(roles) or ["data-owner"],
        "provenance_refs": ["decision-record-1"],
        "artifact_digest": _digest(b"decision"),
        "review_state": "approved",
        "review_reasons": [],
        "applicability": "applicable" if applicable else "not-applicable",
        "status": "current",
    }


def _lineage() -> list[dict]:
    return [
        {
            "output_field": "field-a",
            "source_or_generator_ref": "generator-a",
            "disposition": "generated",
            "transformation_ref": None,
        }
    ]


def _preflight(*, replace: bool = False, subgroup: bool = True) -> dict:
    return {
        "contract_version": "SYNTHETIC_DATA_OPERATION_V1",
        "record_type": "preflight",
        "operation_id": "operation-1",
        "record_revision": "preflight-1",
        "purpose": "Bounded synthetic fixture",
        "mode": "replace-local" if replace else "new-output",
        "source": {
            "reference": "source-1",
            "expected_digest": _digest() if replace else None,
            "tier": "unknown",
        },
        "decision_refs": {
            "classification": _decision("data-owner"),
            "protected_attributes": _decision(
                "privacy-owner", "rai-fairness-owner", "domain-owner"
            ),
            "subgroup_evaluation": _decision(
                "rai-fairness-owner", "domain-owner", applicable=subgroup
            ),
            "replacement_authority": _decision("data-owner", applicable=replace),
        },
        "field_lineage": _lineage(),
        "activated_subgroups": ["group-1"] if subgroup else [],
        "gate": {"state": "passed", "reasons": []},
    }


def _result(*, replace: bool = False, subgroup: bool = True) -> dict:
    return {
        "contract_version": "SYNTHETIC_DATA_OPERATION_V1",
        "record_type": "result",
        "operation_id": "operation-1",
        "record_revision": "result-1",
        "previous_result_revision": None,
        "preflight_revision": "preflight-1",
        "mode": "replace-local" if replace else "new-output",
        "source_reference": "source-1",
        "observed_source_digest": _digest() if replace else None,
        "output_digest": _digest(b"candidate"),
        "field_lineage": _lineage(),
        "subgroup_results": (
            [{"reference": "group-1", "state": "passed", "reason_categories": []}]
            if subgroup
            else []
        ),
        "validation_evidence": [
            {"reference": "schema", "state": "passed", "reason_categories": []}
        ],
        "commit": {
            "state": "not-attempted",
            "target_digest": None,
            "predecessor_ref": None,
            "predecessor_digest": None,
            "evidence_state": "unchanged-original" if replace else "not-applicable",
        },
    }


def test_given_valid_new_output_when_validated_then_passes() -> None:
    # Act
    errors = validate_operation(_preflight(), _result())

    # Assert
    assert errors == []


def test_given_valid_replace_local_when_validated_for_commit_then_passes() -> None:
    # Act
    errors = validate_operation(
        _preflight(replace=True), _result(replace=True), for_commit=True
    )

    # Assert
    assert errors == []


@pytest.mark.parametrize(
    ("field", "value", "category"),
    [
        ("review_state", "pending", "decision-not-approved"),
        ("review_state", "rejected", "decision-not-approved"),
        ("status", "superseded", "decision-not-current"),
        ("status", "withdrawn", "decision-not-current"),
        ("applicability", "not-applicable", "decision-not-applicable"),
    ],
)
def test_given_invalid_classification_when_validated_then_blocks(
    field: str, value: str, category: str
) -> None:
    # Arrange
    preflight = _preflight()
    preflight["decision_refs"]["classification"][field] = value
    if field == "review_state":
        preflight["decision_refs"]["classification"]["review_reasons"] = ["review"]

    # Act
    errors = validate_operation(preflight)

    # Assert
    assert category in errors


def test_given_unqualified_protected_branch_when_validated_then_blocks() -> None:
    # Arrange
    preflight = _preflight()
    preflight["decision_refs"]["protected_attributes"]["owner_roles"] = [
        "privacy-owner"
    ]

    # Act
    errors = validate_operation(preflight)

    # Assert
    assert "decision-owner-role-missing" in errors


def test_given_inactive_optional_branches_when_validated_then_passes() -> None:
    # Arrange
    preflight = _preflight(subgroup=False)
    preflight["decision_refs"]["protected_attributes"] = _decision(
        "privacy-owner", applicable=False
    )

    # Act
    errors = validate_operation(preflight, _result(subgroup=False))

    # Assert
    assert errors == []


def test_given_active_subgroup_without_reference_when_validated_then_blocks() -> None:
    # Arrange
    preflight = _preflight()
    preflight["activated_subgroups"] = []

    # Act
    errors = validate_operation(preflight)

    # Assert
    assert "activated-subgroup-missing" in errors


def test_given_inactive_subgroup_with_reference_when_validated_then_blocks() -> None:
    # Arrange
    preflight = _preflight(subgroup=False)
    preflight["activated_subgroups"] = ["group-1"]

    # Act
    errors = validate_operation(preflight)

    # Assert
    assert "inactive-subgroup-declared" in errors


def test_given_duplicate_lineage_when_validated_then_blocks() -> None:
    # Arrange
    preflight = _preflight()
    preflight["field_lineage"].append(copy.deepcopy(preflight["field_lineage"][0]))

    # Act
    errors = validate_operation(preflight)

    # Assert
    assert "lineage-output-field-duplicate" in errors


@pytest.mark.parametrize("disposition", ["transformed", "derived"])
def test_given_missing_transform_reference_when_validated_then_blocks(
    disposition: str,
) -> None:
    # Arrange
    preflight = _preflight()
    preflight["field_lineage"][0]["disposition"] = disposition

    # Act
    errors = validate_operation(preflight)

    # Assert
    assert "lineage-transformation-invalid" in errors


@pytest.mark.parametrize(
    ("field", "value", "category"),
    [
        ("operation_id", "other", "result-operation-mismatch"),
        ("preflight_revision", "other", "result-preflight-mismatch"),
        ("source_reference", "other", "result-source-mismatch"),
        ("observed_source_digest", "sha256:" + "0" * 64, "source-digest-mismatch"),
    ],
)
def test_given_mismatched_result_when_validated_then_blocks(
    field: str, value: str, category: str
) -> None:
    # Arrange
    result = _result(replace=True)
    result[field] = value

    # Act
    errors = validate_operation(_preflight(replace=True), result)

    # Assert
    assert category in errors


@pytest.mark.parametrize("state", ["failed", "insufficient", "not-measured"])
def test_given_explicit_unresolved_subgroup_when_validated_then_remains_honest(
    state: str,
) -> None:
    # Arrange
    result = _result()
    result["subgroup_results"][0]["state"] = state
    result["subgroup_results"][0]["reason_categories"] = ["evidence-state"]

    # Act
    errors = validate_operation(_preflight(), result)

    # Assert
    assert errors == []


def test_given_missing_subgroup_result_when_validated_then_blocks() -> None:
    # Arrange
    result = _result()
    result["subgroup_results"] = []

    # Act
    errors = validate_operation(_preflight(), result)

    # Assert
    assert "subgroup-result-incomplete" in errors


def test_given_unknown_property_when_validated_then_blocks() -> None:
    # Arrange
    preflight = _preflight()
    preflight["unexpected"] = True

    # Act
    errors = validate_operation(preflight)

    # Assert
    assert "schema-invalid" in errors


@pytest.mark.parametrize(
    "fault_at", ["predecessor", "staged-validation", "before-replace"]
)
def test_given_precommit_failure_when_commit_then_original_bytes_are_unchanged(
    tmp_path: Path, fault_at: str
) -> None:
    # Arrange
    target = tmp_path / "source.csv"
    candidate = tmp_path / "candidate.csv"
    target.write_bytes(b"source")
    candidate.write_bytes(b"candidate")
    before = sha256_file(target)

    # Act and assert
    with pytest.raises(OperationError) as captured:
        commit_local(
            _preflight(replace=True),
            _result(replace=True),
            candidate,
            target,
            tmp_path,
            tmp_path / "final-result.json",
            fault_at=fault_at,
        )
    assert sha256_file(target) == before
    assert "unchanged-original" in captured.value.categories
    assert captured.value.digests == {"original": before, "current": before}


def test_given_stale_target_when_commit_then_original_bytes_are_unchanged(
    tmp_path: Path,
) -> None:
    # Arrange
    target = tmp_path / "source.csv"
    candidate = tmp_path / "candidate.csv"
    target.write_bytes(b"stale")
    candidate.write_bytes(b"candidate")
    before = sha256_file(target)

    # Act and assert
    with pytest.raises(OperationError, match="source-digest-mismatch") as captured:
        commit_local(
            _preflight(replace=True),
            _result(replace=True),
            candidate,
            target,
            tmp_path,
            tmp_path / "final-result.json",
        )
    assert sha256_file(target) == before
    assert "unchanged-original" in captured.value.categories
    assert captured.value.digests["current"] == before


def test_given_valid_candidate_when_commit_then_replaces_and_preserves_predecessor(
    tmp_path: Path,
) -> None:
    # Arrange
    target = tmp_path / "source.csv"
    candidate = tmp_path / "candidate.csv"
    target.write_bytes(b"source")
    candidate.write_bytes(b"candidate")

    # Act
    summary = commit_local(
        _preflight(replace=True),
        _result(replace=True),
        candidate,
        target,
        tmp_path,
        tmp_path / "final-result.json",
    )

    # Assert
    predecessor = tmp_path / ".source.csv.operation-1.previous"
    assert target.read_bytes() == b"candidate"
    assert predecessor.read_bytes() == b"source"
    assert summary["digests"]["target"] == _digest(b"candidate")
    final_result = json.loads((tmp_path / "final-result.json").read_text())
    assert final_result["previous_result_revision"] == "result-1"
    assert final_result["commit"]["predecessor_digest"] == _digest(b"source")
    assert final_result["record_revision"] != "result-1"
    assert final_result["preflight_revision"] == "preflight-1"
    assert validate_operation(_preflight(replace=True), final_result) == []


def test_given_candidate_digest_mismatch_when_commit_then_blocks(
    tmp_path: Path,
) -> None:
    # Arrange
    target = tmp_path / "source.csv"
    candidate = tmp_path / "candidate.csv"
    target.write_bytes(b"source")
    candidate.write_bytes(b"different")

    # Act and assert
    with pytest.raises(OperationError, match="candidate-digest-mismatch"):
        commit_local(
            _preflight(replace=True),
            _result(replace=True),
            candidate,
            target,
            tmp_path,
            tmp_path / "final-result.json",
        )


def test_given_target_outside_root_when_commit_then_blocks(tmp_path: Path) -> None:
    # Arrange
    root = tmp_path / "root"
    root.mkdir()
    target = tmp_path / "source.csv"
    candidate = root / "candidate.csv"
    target.write_bytes(b"source")
    candidate.write_bytes(b"candidate")

    # Act and assert
    with pytest.raises(OperationError, match="target-invalid"):
        commit_local(
            _preflight(replace=True),
            _result(replace=True),
            candidate,
            target,
            root,
            root / "final-result.json",
        )


def test_given_duplicate_json_key_when_read_then_errors(tmp_path: Path) -> None:
    # Arrange
    record = tmp_path / "record.json"
    record.write_text('{"a": 1, "a": 2}', encoding="utf-8")

    # Act and assert
    with pytest.raises(OperationError, match="duplicate-json-key"):
        read_record(record)


def test_given_valid_file_when_cli_validate_then_returns_success(
    tmp_path: Path, capsys
) -> None:
    # Arrange
    preflight_path = tmp_path / "preflight.json"
    preflight_path.write_text(json.dumps(_preflight()), encoding="utf-8")
    arguments = create_parser().parse_args(
        ["validate", "--preflight", str(preflight_path)]
    )

    # Act
    exit_code = run(arguments)

    # Assert
    assert exit_code == EXIT_SUCCESS
    assert json.loads(capsys.readouterr().out)["status"] == "valid"


def test_given_invalid_file_when_cli_validate_then_returns_failure(
    tmp_path: Path, capsys
) -> None:
    # Arrange
    preflight = _preflight()
    preflight["gate"] = {"state": "blocked", "reasons": ["owner-action"]}
    preflight_path = tmp_path / "preflight.json"
    preflight_path.write_text(json.dumps(preflight), encoding="utf-8")
    arguments = create_parser().parse_args(
        ["validate", "--preflight", str(preflight_path)]
    )

    # Act
    exit_code = run(arguments)

    # Assert
    assert exit_code == EXIT_FAILURE
    assert "gate-blocked" in json.loads(capsys.readouterr().out)["categories"]


def test_given_malformed_file_when_cli_validate_then_returns_error(
    tmp_path: Path, capsys
) -> None:
    # Arrange
    preflight_path = tmp_path / "preflight.json"
    preflight_path.write_text("not-json", encoding="utf-8")
    arguments = create_parser().parse_args(
        ["validate", "--preflight", str(preflight_path)]
    )

    # Act
    exit_code = run(arguments)

    # Assert
    assert exit_code == EXIT_ERROR
    assert json.loads(capsys.readouterr().out)["categories"] == ["record-read-error"]


def test_given_stale_target_when_cli_commit_then_reports_unchanged_original(
    tmp_path: Path, capsys
) -> None:
    # Arrange
    preflight_path = tmp_path / "preflight.json"
    result_path = tmp_path / "result.json"
    target = tmp_path / "source.csv"
    candidate = tmp_path / "candidate.csv"
    preflight_path.write_text(json.dumps(_preflight(replace=True)), encoding="utf-8")
    result_path.write_text(json.dumps(_result(replace=True)), encoding="utf-8")
    target.write_bytes(b"stale")
    candidate.write_bytes(b"candidate")
    arguments = create_parser().parse_args(
        [
            "commit-local",
            "--preflight",
            str(preflight_path),
            "--result",
            str(result_path),
            "--candidate",
            str(candidate),
            "--target",
            str(target),
            "--approved-root",
            str(tmp_path),
            "--final-result",
            str(tmp_path / "final-result.json"),
        ]
    )

    # Act
    exit_code = run(arguments)

    # Assert
    summary = json.loads(capsys.readouterr().out)
    assert exit_code == EXIT_FAILURE
    assert "unchanged-original" in summary["categories"]
    assert summary["digests"]["original"] == summary["digests"]["current"]


def test_given_committed_result_without_evidence_when_validated_then_blocks() -> None:
    # Arrange
    result = _result(replace=True)
    result["previous_result_revision"] = "result-0"
    result["commit"]["state"] = "committed"
    result["commit"]["evidence_state"] = "rollback-available"

    # Act
    errors = validate_operation(_preflight(replace=True), result)

    # Assert
    assert "schema-invalid" in errors


def test_given_committed_result_without_evidence_when_schema_validated_then_fails() -> (
    None
):
    # Arrange
    result = _result(replace=True)
    result["previous_result_revision"] = "result-0"
    result["commit"]["state"] = "committed"
    result["commit"]["evidence_state"] = "rollback-available"

    # Act
    errors = list(Draft202012Validator(load_schema()).iter_errors(result))

    # Assert
    assert errors


def test_given_target_changes_before_replace_when_commit_then_change_is_preserved(
    tmp_path: Path,
) -> None:
    # Arrange
    target = tmp_path / "source.csv"
    candidate = tmp_path / "candidate.csv"
    target.write_bytes(b"source")
    candidate.write_bytes(b"candidate")

    # Act and assert
    with pytest.raises(OperationError) as captured:
        commit_local(
            _preflight(replace=True),
            _result(replace=True),
            candidate,
            target,
            tmp_path,
            tmp_path / "final-result.json",
            fault_at="target-change",
        )
    assert target.read_bytes() == b"external-change"
    assert "external-change-preserved" in captured.value.categories


@pytest.mark.parametrize("target_kind", ["directory", "symlink"])
def test_given_unsupported_target_when_commit_then_blocks(
    tmp_path: Path, target_kind: str
) -> None:
    # Arrange
    target = tmp_path / "source.csv"
    candidate = tmp_path / "candidate.csv"
    candidate.write_bytes(b"candidate")
    if target_kind == "directory":
        target.mkdir()
    else:
        source = tmp_path / "linked.csv"
        source.write_bytes(b"source")
        try:
            target.symlink_to(source)
        except OSError:
            pytest.skip("symbolic-link creation is unavailable")

    # Act and assert
    with pytest.raises(OperationError, match="target-invalid"):
        commit_local(
            _preflight(replace=True),
            _result(replace=True),
            candidate,
            target,
            tmp_path,
            tmp_path / "final-result.json",
        )


def test_given_illegal_commit_transition_when_validated_then_blocks() -> None:
    # Arrange
    result = _result(replace=True)
    result["commit"]["state"] = "committed"

    # Act
    errors = validate_operation(_preflight(replace=True), result)

    # Assert
    assert "schema-invalid" in errors


def test_given_missing_decision_object_when_validated_then_blocks() -> None:
    # Arrange
    preflight = _preflight()
    del preflight["decision_refs"]["classification"]

    # Act
    errors = validate_operation(preflight)

    # Assert
    assert "schema-invalid" in errors


def test_given_sensitive_marker_when_cli_fails_then_diagnostic_omits_value(
    tmp_path: Path, capsys
) -> None:
    # Arrange
    marker = "synthetic-secret-marker"
    preflight_path = tmp_path / "preflight.json"
    preflight = _preflight()
    preflight[marker] = True
    preflight_path.write_text(json.dumps(preflight), encoding="utf-8")

    # Act
    exit_code = run(
        create_parser().parse_args(["validate", "--preflight", str(preflight_path)])
    )

    # Assert
    captured = capsys.readouterr()
    assert exit_code == EXIT_FAILURE
    assert marker not in captured.out + captured.err
    assert marker not in json.loads(captured.out)["categories"]


def test_given_missing_arguments_when_main_then_returns_sanitized_json(
    monkeypatch, capsys
) -> None:
    # Arrange
    monkeypatch.setattr("sys.argv", ["synthetic_data_operation.py", "validate"])

    # Act
    exit_code = main()

    # Assert
    summary = json.loads(capsys.readouterr().out)
    assert exit_code == EXIT_ERROR
    assert set(summary) == {
        "status",
        "record_identity",
        "categories",
        "counts",
        "digests",
    }


def test_given_missing_schema_when_loaded_then_returns_configuration_error(
    tmp_path: Path,
) -> None:
    # Act and assert
    with pytest.raises(OperationError, match="schema-configuration-error"):
        load_schema(tmp_path)


def test_given_help_when_main_then_returns_json_without_usage(
    monkeypatch, capsys
) -> None:
    # Arrange
    monkeypatch.setattr("sys.argv", ["synthetic_data_operation.py", "--help"])

    # Act
    exit_code = main()

    # Assert
    captured = capsys.readouterr()
    assert exit_code == EXIT_SUCCESS
    assert json.loads(captured.out)["categories"] == ["help-requested"]
    assert captured.err == ""


def test_given_unexpected_error_when_main_then_returns_sanitized_json(
    monkeypatch, capsys
) -> None:
    # Arrange
    monkeypatch.setattr(
        "sys.argv", ["synthetic_data_operation.py", "validate", "--preflight", "x"]
    )

    def raise_unexpected_error(arguments) -> int:
        raise RuntimeError("private-path")

    monkeypatch.setattr(operation_module, "run", raise_unexpected_error)

    # Act
    exit_code = main()

    # Assert
    captured = capsys.readouterr()
    assert exit_code == EXIT_ERROR
    assert json.loads(captured.out)["categories"] == ["unexpected-error"]
    assert "private-path" not in captured.out + captured.err


def test_given_existing_final_result_when_commit_then_target_is_unchanged(
    tmp_path: Path,
) -> None:
    # Arrange
    target = tmp_path / "source.csv"
    candidate = tmp_path / "candidate.csv"
    final_result = tmp_path / "final-result.json"
    target.write_bytes(b"source")
    candidate.write_bytes(b"candidate")
    final_result.write_text("existing", encoding="utf-8")

    # Act and assert
    with pytest.raises(OperationError, match="final-result-invalid"):
        commit_local(
            _preflight(replace=True),
            _result(replace=True),
            candidate,
            target,
            tmp_path,
            final_result,
        )
    assert target.read_bytes() == b"source"


def test_given_final_result_publication_failure_when_commit_then_reports_recovery(
    tmp_path: Path, monkeypatch
) -> None:
    # Arrange
    target = tmp_path / "source.csv"
    candidate = tmp_path / "candidate.csv"
    target.write_bytes(b"source")
    candidate.write_bytes(b"candidate")
    original_replace = operation_module.os.replace
    replace_calls = 0

    def fail_second_replace(source: Path, destination: Path) -> None:
        nonlocal replace_calls
        replace_calls += 1
        if replace_calls == 2:
            raise OSError("publication failed")
        original_replace(source, destination)

    monkeypatch.setattr(operation_module.os, "replace", fail_second_replace)

    # Act and assert
    with pytest.raises(OperationError) as captured:
        commit_local(
            _preflight(replace=True),
            _result(replace=True),
            candidate,
            target,
            tmp_path,
            tmp_path / "final-result.json",
        )
    assert target.read_bytes() == b"candidate"
    assert "rollback-available" in captured.value.categories
    assert captured.value.digests["predecessor"] == _digest(b"source")


def test_given_invalid_successor_when_commit_then_reports_recovery(
    tmp_path: Path, monkeypatch
) -> None:
    # Arrange
    target = tmp_path / "source.csv"
    candidate = tmp_path / "candidate.csv"
    target.write_bytes(b"source")
    candidate.write_bytes(b"candidate")
    validation_calls = 0

    def fail_final_validation(preflight, result, **kwargs) -> list[str]:
        nonlocal validation_calls
        validation_calls += 1
        return [] if validation_calls == 1 else ["forced-final-result-error"]

    monkeypatch.setattr(operation_module, "validate_operation", fail_final_validation)

    # Act and assert
    with pytest.raises(OperationError) as captured:
        commit_local(
            _preflight(replace=True),
            _result(replace=True),
            candidate,
            target,
            tmp_path,
            tmp_path / "final-result.json",
        )
    assert "rollback-available" in captured.value.categories


def test_schema_is_draft_2020_12_valid() -> None:
    # Act
    schema = load_schema()

    # Assert
    assert schema["$schema"].endswith("2020-12/schema")
