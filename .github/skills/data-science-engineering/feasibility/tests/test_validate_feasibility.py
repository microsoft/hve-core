# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for the Feasibility Study Interchange Profile validator."""

from __future__ import annotations

import copy
import time
from pathlib import Path

import pytest
import validate_feasibility as validate_feasibility_module
import yaml
from jsonschema import Draft202012Validator, FormatChecker
from validate_feasibility import (
    BEGIN_MARKER,
    END_MARKER,
    NARRATIVE_ANCHOR_PATTERN,
    FeasibilityValidationError,
    _assert_json_compatible,
    _is_rfc3339_date_time,
    _reject_tagged_node,
    _sanitize_yaml_error,
    build_format_checker,
    create_parser,
    extract_profile_yaml,
    load_schema,
    main,
    narrative_text,
    parse_profile,
    read_study_text,
    requirement_allocation_errors,
    run,
    validate_profile,
)

SKILL_ROOT = Path(__file__).resolve().parent.parent
VALID_PATH = SKILL_ROOT / "examples" / "valid-study.md"


def _valid() -> tuple[dict, str]:
    markdown = VALID_PATH.read_text(encoding="utf-8")
    return parse_profile(markdown), markdown


def _block(body: str) -> str:
    """Wrap a YAML body in the one named interchange block."""
    return f"{BEGIN_MARKER}\n```yaml\n{body}```\n{END_MARKER}\n"


def test_given_valid_study_when_validated_then_has_no_errors() -> None:
    # Arrange
    data, markdown = _valid()

    # Act
    errors = validate_profile(data, markdown, load_schema(SKILL_ROOT))

    # Assert
    assert errors == []


def test_given_unsupported_version_when_validated_then_fails() -> None:
    # Arrange
    data, markdown = _valid()
    data["profile_version"] = "2.0.0"

    # Act
    errors = validate_profile(data, markdown, load_schema(SKILL_ROOT))

    # Assert
    assert errors


def test_given_duplicate_concept_id_when_validated_then_fails() -> None:
    # Arrange
    data, markdown = _valid()
    duplicate = copy.deepcopy(data["items"][1])
    duplicate["display_ref"] = "FS-003"
    duplicate["narrative_anchor"] = "fs-003"
    data["items"].append(duplicate)
    markdown += "\n### FS-003: Duplicate concept\n"

    # Act
    errors = validate_profile(data, markdown, load_schema(SKILL_ROOT))

    # Assert
    assert any("conceptual IDs must be unique" in error for error in errors)


def test_given_malformed_uuid_when_validated_then_fails() -> None:
    # Arrange
    data, markdown = _valid()
    data["items"][0]["item_id"] = "not-a-uuid"

    # Act
    errors = validate_profile(data, markdown, load_schema(SKILL_ROOT))

    # Assert
    assert errors


def test_given_broken_relation_when_validated_then_fails() -> None:
    # Arrange
    data, markdown = _valid()
    data["items"][1]["relations"][0]["target"] = (
        "urn:uuid:99999999-0000-4000-8000-000000000001"
    )

    # Act
    errors = validate_profile(data, markdown, load_schema(SKILL_ROOT))

    # Assert
    assert any("unknown target" in error for error in errors)


def test_given_cyclic_revision_when_validated_then_fails() -> None:
    # Arrange
    data, markdown = _valid()
    registry = data["revision_registry"]
    registry[0]["revision_of"] = registry[1]["revision_id"]

    # Act
    errors = validate_profile(data, markdown, load_schema(SKILL_ROOT))

    # Assert
    assert any("cyclic" in error for error in errors)


def test_given_incomplete_tombstone_when_validated_then_fails() -> None:
    # Arrange
    data, markdown = _valid()
    item = data["items"][1]
    item["status"] = "superseded"

    # Act
    errors = validate_profile(data, markdown, load_schema(SKILL_ROOT))

    # Assert
    assert any("incomplete superseded tombstone" in error for error in errors)


def test_given_prohibited_yaml_when_parsed_then_raises() -> None:
    # Arrange
    markdown = _block("profile: &p feasibility-study-interchange\ncopy: *p\n")

    # Act and assert
    with pytest.raises(FeasibilityValidationError, match="not permitted"):
        parse_profile(markdown)


@pytest.mark.parametrize(
    ("body", "message"),
    [
        ("copy: *undefined\n", "aliases are not permitted"),
        ("base: &anchor value\n", "anchors are not permitted"),
        ("value: !custom scalar\n", "explicit tags are not permitted"),
        ("merged:\n  <<: {a: 1}\n", "merge keys are not permitted"),
        ("profile: one\nprofile: two\n", "duplicate YAML key"),
        ("1: numeric-key\n", "keys must be strings"),
    ],
    ids=["alias", "anchor", "tag", "merge-key", "duplicate-key", "non-string-key"],
)
def test_given_unsafe_yaml_construct_when_parsed_then_raises(
    body: str, message: str
) -> None:
    # Act and assert
    with pytest.raises(FeasibilityValidationError, match=message):
        parse_profile(_block(body))


def test_given_unquoted_date_when_parsed_then_raises() -> None:
    # Act and assert
    with pytest.raises(FeasibilityValidationError, match="must be a quoted string"):
        parse_profile(_block("created_at: 2026-01-01\n"))


def test_given_quoted_timestamp_when_parsed_then_value_is_a_string() -> None:
    # Act
    parsed = parse_profile(_block('created_at: "2026-01-01T00:00:00Z"\n'))

    # Assert
    assert parsed["created_at"] == "2026-01-01T00:00:00Z"


@pytest.mark.parametrize("literal", [".nan", ".inf", "-.inf"])
def test_given_non_finite_number_when_parsed_then_raises(literal: str) -> None:
    # Act and assert
    with pytest.raises(FeasibilityValidationError, match="must be a finite number"):
        parse_profile(_block(f"threshold: {literal}\n"))


def test_given_finite_number_when_parsed_then_value_survives() -> None:
    # Act
    parsed = parse_profile(_block("threshold: 1.5\n"))

    # Assert
    assert parsed["threshold"] == 1.5


def test_given_quoted_markdown_prose_when_parsed_then_value_survives() -> None:
    # Arrange
    prose = "Cites FR-123, uses **bold**, `code`, and the 2026-01-01 baseline"

    # Act
    parsed = parse_profile(_block(f'title: "{prose}"\n'))

    # Assert
    assert parsed["title"] == prose


def test_given_orphaned_item_when_validated_then_fails() -> None:
    # Arrange
    data, markdown = _valid()
    markdown = markdown.replace(
        "### FS-002: Rank recommendation candidates",
        "### Candidate narrative without an alias",
    )

    # Act
    errors = validate_profile(data, markdown, load_schema(SKILL_ROOT))

    # Assert
    assert any("orphaned YAML items" in error for error in errors)


def test_given_prose_requirement_citation_when_validated_then_has_no_errors() -> None:
    # Arrange
    data, markdown = _valid()
    markdown += "\nThis study informs the upstream requirement FR-123.\n"

    # Act
    errors = validate_profile(data, markdown, load_schema(SKILL_ROOT))

    # Assert
    assert errors == []


def test_given_requirement_heading_when_validated_then_fails() -> None:
    # Arrange
    data, markdown = _valid()
    markdown += "\n### FR-123: Allocated downstream requirement\n"

    # Act
    errors = validate_profile(data, markdown, load_schema(SKILL_ROOT))

    # Assert
    assert any("narrative heading cannot allocate" in error for error in errors)


@pytest.mark.parametrize("display_ref", ["FR-123", "NFR-4567"])
def test_given_requirement_display_ref_when_checked_then_reports_error(
    display_ref: str,
) -> None:
    # Arrange
    items = [{"display_ref": display_ref}]

    # Act
    errors = requirement_allocation_errors(items, "")

    # Assert
    assert errors == [
        f"{display_ref} cannot allocate an FR or NFR identifier as its own display_ref"
    ]


def test_given_feasibility_display_ref_when_checked_then_has_no_errors() -> None:
    # Act
    errors = requirement_allocation_errors([{"display_ref": "FS-001"}], "")

    # Assert
    assert errors == []


def test_given_multiple_blocks_when_extracted_then_raises() -> None:
    # Arrange
    block = (
        f"{BEGIN_MARKER}\n```yaml\nprofile: feasibility-study-interchange\n"
        f"```\n{END_MARKER}\n"
    )

    # Act and assert
    with pytest.raises(FeasibilityValidationError, match="exactly one"):
        extract_profile_yaml(block + block)


def test_given_valid_file_when_run_then_returns_success(capsys) -> None:
    # Act
    result = run(VALID_PATH)

    # Assert
    assert result == 0
    assert '"valid": true' in capsys.readouterr().out


def test_given_missing_file_when_run_then_reports_operational_error(
    tmp_path, capsys
) -> None:
    # Act
    result = run(tmp_path / "missing.md", allowed_roots=(tmp_path,))

    # Assert
    captured = capsys.readouterr()
    assert result == 2
    assert captured.out == ""
    assert "validate_feasibility:" in captured.err


def test_given_schema_violation_when_run_then_reports_validation_failure(
    tmp_path, capsys
) -> None:
    # Arrange
    path = tmp_path / "study.md"
    path.write_text(
        _block("profile: feasibility-study-interchange\n"), encoding="utf-8"
    )

    # Act
    result = run(path, allowed_roots=(tmp_path,))

    # Assert
    captured = capsys.readouterr()
    assert result == 1
    assert '"valid": false' in captured.out
    assert captured.err == ""


@pytest.mark.parametrize("candidate", ["../evil.md", "..\\evil.md", "a/../../evil.md"])
def test_given_traversal_path_when_read_then_raises(candidate: str) -> None:
    # Act and assert
    with pytest.raises(FeasibilityValidationError, match=r"'\.\.' segments"):
        read_study_text(Path(candidate))


def test_given_traversal_path_when_run_then_returns_operational_error(capsys) -> None:
    # Act
    result = run(Path("../evil.md"))

    # Assert
    assert result == 2
    assert "'..' segments" in capsys.readouterr().err


def test_given_path_outside_root_when_read_then_raises(tmp_path) -> None:
    # Arrange
    inside = tmp_path / "inside"
    inside.mkdir()
    outside = tmp_path / "outside.md"
    outside.write_text(_block("profile: x\n"), encoding="utf-8")

    # Act and assert
    with pytest.raises(FeasibilityValidationError, match="outside the permitted roots"):
        read_study_text(outside, allowed_roots=(inside,))


def test_given_symlink_outside_root_when_read_then_raises(tmp_path) -> None:
    # Arrange
    inside = tmp_path / "inside"
    inside.mkdir()
    outside = tmp_path / "outside.md"
    outside.write_text(_block("profile: x\n"), encoding="utf-8")
    link = inside / "link.md"
    try:
        link.symlink_to(outside)
    except (OSError, NotImplementedError):
        pytest.skip("symlink creation is not permitted in this environment")

    # Act and assert
    with pytest.raises(FeasibilityValidationError, match="outside the permitted roots"):
        read_study_text(link, allowed_roots=(inside,))


def test_given_oversized_file_when_read_then_raises(tmp_path, monkeypatch) -> None:
    # Arrange
    path = tmp_path / "study.md"
    path.write_text(_block("profile: x\n"), encoding="utf-8")
    monkeypatch.setattr(validate_feasibility_module, "MAX_INPUT_BYTES", 4)

    # Act and assert
    with pytest.raises(FeasibilityValidationError, match="byte input limit"):
        read_study_text(path, allowed_roots=(tmp_path,))


def test_given_permitted_file_when_read_then_returns_text(tmp_path) -> None:
    # Arrange
    path = tmp_path / "study.md"
    path.write_text(_block("profile: x\n"), encoding="utf-8")

    # Act
    text = read_study_text(path, allowed_roots=(tmp_path,))

    # Assert
    assert "profile: x" in text


def test_given_malformed_timestamp_when_validated_then_fails() -> None:
    # Arrange
    data, markdown = _valid()
    data["study"]["created_at"] = "2026-13-45T99:99:99Z"

    # Act
    errors = validate_profile(data, markdown, load_schema(SKILL_ROOT))

    # Assert
    assert any("date-time" in error for error in errors)


def test_given_valid_timestamp_when_validated_then_has_no_errors() -> None:
    # Arrange
    data, markdown = _valid()
    data["study"]["created_at"] = "2026-01-01T00:00:00+05:30"

    # Act
    errors = validate_profile(data, markdown, load_schema(SKILL_ROOT))

    # Assert
    assert errors == []


def test_given_unsupported_format_sentinel_then_checker_stays_restricted() -> None:
    # Arrange
    checker = build_format_checker()
    schema = {
        "type": "object",
        "properties": {"contact": {"type": "string", "format": "email"}},
    }
    validator = Draft202012Validator(schema, format_checker=checker)

    # Act
    errors = list(validator.iter_errors({"contact": "not-an-email"}))

    # Assert
    assert errors == []
    assert set(checker.checkers) == {"date-time"}


def test_given_parser_error_when_run_then_output_excludes_source(
    tmp_path, capsys
) -> None:
    # Arrange
    path = tmp_path / "study.md"
    path.write_text(
        _block('profile: "unterminated\ncustomer_secret_value: 42\n'), encoding="utf-8"
    )

    # Act
    result = run(path, allowed_roots=(tmp_path,))

    # Assert
    captured = capsys.readouterr()
    assert result == 2
    assert "invalid YAML" in captured.err
    assert "customer_secret_value" not in captured.err
    assert "unterminated" not in captured.err


def test_given_non_json_value_when_asserted_then_raises() -> None:
    # Act and assert
    with pytest.raises(FeasibilityValidationError, match="non-JSON YAML value"):
        _assert_json_compatible({"field": {"a", "b"}})


def test_given_non_string_mapping_key_when_asserted_then_raises() -> None:
    # Act and assert
    with pytest.raises(FeasibilityValidationError, match="non-string key"):
        _assert_json_compatible({1: "value"})


def test_given_tagged_node_when_constructed_then_raises() -> None:
    # Act and assert
    with pytest.raises(FeasibilityValidationError, match="explicit tags"):
        _reject_tagged_node(None, "custom", yaml.ScalarNode("!custom", "value"))


def test_given_unmarked_yaml_error_when_sanitized_then_reports_type_only() -> None:
    # Act
    message = _sanitize_yaml_error(yaml.YAMLError("customer secret detail"))

    # Assert
    assert message == "invalid YAML (YAMLError)"


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        ("2026-01-01T00:00:00Z", True),
        ("2026-01-01T00:00:00.123+05:30", True),
        ("2026-13-45T99:99:99Z", False),
        ("2026-01-01", False),
        (42, True),
    ],
    ids=["utc", "offset", "out-of-range", "date-only", "non-string"],
)
def test_given_value_when_checked_against_rfc3339_then_matches_expectation(
    value: object, expected: bool
) -> None:
    # Act and assert
    assert _is_rfc3339_date_time(value) is expected


def test_given_absent_registered_format_when_built_then_uses_local_checker(
    monkeypatch,
) -> None:
    # Arrange
    monkeypatch.setattr(FormatChecker, "checkers", {})

    # Act
    checker = build_format_checker()

    # Assert
    assert set(checker.checkers) == {"date-time"}
    assert checker.conforms("2026-01-01T00:00:00Z", "date-time")
    assert not checker.conforms("2026-13-45T99:99:99Z", "date-time")


def test_given_cli_arguments_when_parsed_then_study_path_is_returned() -> None:
    # Act
    args = create_parser().parse_args(["study.md"])

    # Assert
    assert args.study == Path("study.md")


def test_given_cli_invocation_when_main_runs_then_validates_the_example(
    monkeypatch, capsys
) -> None:
    # Arrange
    monkeypatch.setattr("sys.argv", ["validate_feasibility.py", str(VALID_PATH)])

    # Act
    result = main()

    # Assert
    assert result == 0
    assert '"valid": true' in capsys.readouterr().out


def test_given_many_unterminated_begin_markers_when_extracted_then_fails_quickly() -> (
    None
):
    # Arrange
    hostile = (f"{BEGIN_MARKER}\n```yaml\n" * 20000) + "never closed\n"

    # Act
    started = time.monotonic()
    with pytest.raises(FeasibilityValidationError):
        extract_profile_yaml(hostile)
    elapsed = time.monotonic() - started

    # Assert
    assert elapsed < 5.0


def test_given_deeply_nested_yaml_when_parsed_then_raises_feasibility_error() -> None:
    # Arrange
    study = _block("deep: " + "[" * 5000 + "]" * 5000 + "\n")

    # Act / Assert
    with pytest.raises(FeasibilityValidationError):
        parse_profile(study)


@pytest.mark.parametrize("timestamp", ["2026-02-31", "2026-13-01", "2026-01-32"])
def test_given_out_of_range_timestamp_when_parsed_then_raises_feasibility_error(
    timestamp: str,
) -> None:
    # Arrange
    study = _block(f"timestamp: {timestamp}\n")

    # Act / Assert
    with pytest.raises(FeasibilityValidationError, match="invalid scalar value"):
        parse_profile(study)


def test_given_requirement_heading_in_fence_when_checked_then_not_allocated() -> None:
    # Arrange
    markdown = "```text\n### FR-101: fenced sample\n```\n"

    # Act
    errors = requirement_allocation_errors([], markdown)

    # Assert
    assert errors == []


def test_given_anchor_inside_fence_when_narrative_read_then_anchor_is_ignored() -> None:
    # Arrange
    markdown = "```text\n### FS-001: fenced anchor\n```\n### FS-002: real anchor\n"

    # Act
    anchors = NARRATIVE_ANCHOR_PATTERN.findall(narrative_text(markdown))

    # Assert
    assert anchors == ["FS-002"]
