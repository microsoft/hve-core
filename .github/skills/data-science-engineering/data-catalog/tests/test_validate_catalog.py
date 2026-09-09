# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for the DS_CATALOG_V1 validator."""

from __future__ import annotations

import copy
from pathlib import Path

import pytest
import validate_catalog as validate_catalog_module
import yaml
from jsonschema import Draft202012Validator, FormatChecker
from validate_catalog import (
    CatalogValidationError,
    _assert_json_compatible,
    _is_rfc3339_date_time,
    _reject_tagged_node,
    _sanitize_yaml_error,
    build_format_checker,
    create_parser,
    extract_frontmatter,
    lineage_cycle_ids,
    load_schema,
    main,
    parse_catalog,
    read_catalog_text,
    run,
    validate_catalog,
)

SKILL_ROOT = Path(__file__).resolve().parent.parent


def _valid_catalog() -> dict:
    markdown = (SKILL_ROOT / "examples" / "northwind-catalog.md").read_text(
        encoding="utf-8"
    )
    return parse_catalog(markdown)


def _frontmatter(body: str) -> str:
    """Build a minimal Markdown catalog around a frontmatter body."""
    return f"---\ncatalog_version: DS_CATALOG_V1\n{body}---\n"


def _entity(entity_id: str, derived_from: list[str]) -> dict:
    """Build the lineage-only entity shape used by cycle detection."""
    return {"id": entity_id, "lineage": {"derived_from": derived_from}}


def test_given_valid_example_when_validated_then_has_no_errors() -> None:
    # Arrange
    data = _valid_catalog()

    # Act
    errors = validate_catalog(data, load_schema(SKILL_ROOT))

    # Assert
    assert errors == []


def test_given_example_when_inspected_then_covers_full_relationship_surface() -> None:
    # Arrange
    data = _valid_catalog()
    relationships = data["relationships"]

    # Act
    confidences = {relationship["confidence"] for relationship in relationships}
    scalar = [
        relationship
        for relationship in relationships
        if isinstance(relationship["join_keys"]["from_field"], str)
    ]
    composite = [
        relationship
        for relationship in relationships
        if isinstance(relationship["join_keys"]["from_field"], list)
    ]
    minimums = {
        (relationship["from_minimum"], relationship["to_minimum"])
        for relationship in relationships
    }

    # Assert
    assert confidences == {"confirmed", "inferred", "assumed"}
    assert scalar and composite
    assert {"zero", "one"} <= {value for pair in minimums for value in pair}


def test_given_scalar_join_keys_when_validated_then_has_no_errors() -> None:
    # Arrange
    data = _valid_catalog()
    relationship = data["relationships"][0]
    relationship["join_keys"] = {
        "from_field": "customer_id",
        "to_field": "customer_id",
    }

    # Act
    errors = validate_catalog(data, load_schema(SKILL_ROOT))

    # Assert
    assert errors == []


def test_given_duplicate_entity_id_when_validated_then_reports_error() -> None:
    # Arrange
    data = _valid_catalog()
    duplicate = copy.deepcopy(data["entities"][0])
    data["entities"].append(duplicate)
    data["coverage"]["entities_catalogued"] += 1
    data["coverage"]["entities_access_confirmed"] += 1
    data["coverage"]["entities_classified"] += 1

    # Act
    errors = validate_catalog(data, load_schema(SKILL_ROOT))

    # Assert
    assert "entity IDs must be unique" in errors


def test_given_unknown_endpoint_when_validated_then_reports_error() -> None:
    # Arrange
    data = _valid_catalog()
    data["relationships"][0]["to"] = "missing"

    # Act
    errors = validate_catalog(data, load_schema(SKILL_ROOT))

    # Assert
    assert any("unknown to endpoint" in error for error in errors)


def test_given_unknown_and_self_lineage_when_validated_then_reports_errors() -> None:
    # Arrange
    data = _valid_catalog()
    data["entities"][0]["lineage"]["derived_from"] = ["missing", "customer"]

    # Act
    errors = validate_catalog(data, load_schema(SKILL_ROOT))

    # Assert
    assert any("unknown lineage source" in error for error in errors)
    assert any("cannot derive from itself" in error for error in errors)


def test_given_unequal_composite_keys_when_validated_then_reports_error() -> None:
    # Arrange
    data = _valid_catalog()
    data["relationships"][0]["join_keys"]["to_field"].pop()

    # Act
    errors = validate_catalog(data, load_schema(SKILL_ROOT))

    # Assert
    assert any("equal length" in error for error in errors)


def test_given_duplicate_relationship_id_when_validated_then_reports_error() -> None:
    # Arrange
    data = _valid_catalog()
    duplicate = copy.deepcopy(data["relationships"][0])
    data["relationships"].append(duplicate)
    data["coverage"]["relationships_confirmed"] += 1

    # Act
    errors = validate_catalog(data, load_schema(SKILL_ROOT))

    # Assert
    assert "relationship IDs must be unique" in errors


def test_given_unknown_property_when_validated_then_reports_error() -> None:
    # Arrange
    data = _valid_catalog()
    data["relationships"][0]["cardinallity"] = "one-to-many"

    # Act
    errors = validate_catalog(data, load_schema(SKILL_ROOT))

    # Assert
    assert errors


@pytest.mark.parametrize(
    "join_keys",
    [
        {"from_field": "customer_id", "to_field": ["customer_id"]},
        {"from_field": [], "to_field": []},
        {"from_field": [1], "to_field": ["customer_id"]},
        {"from_field": "", "to_field": "customer_id"},
    ],
    ids=["mixed-forms", "empty-arrays", "non-string-value", "empty-string"],
)
def test_given_malformed_join_keys_when_validated_then_reports_error(
    join_keys: dict,
) -> None:
    # Arrange
    data = _valid_catalog()
    data["relationships"][0]["join_keys"] = join_keys

    # Act
    errors = validate_catalog(data, load_schema(SKILL_ROOT))

    # Assert
    assert errors


@pytest.mark.parametrize(
    "mutation",
    [
        {"from_minimum": None},
        {"to_minimum": None},
        {"from_minimum": "zero", "to_minimum": "maybe"},
        {"from_minimum": "0", "to_minimum": "one"},
    ],
    ids=["omitted-from", "omitted-to", "invalid-to", "invalid-from"],
)
def test_given_bad_endpoint_minimum_when_validated_then_reports_error(
    mutation: dict,
) -> None:
    # Arrange
    data = _valid_catalog()
    relationship = data["relationships"][0]
    for field, value in mutation.items():
        if value is None:
            relationship.pop(field)
        else:
            relationship[field] = value

    # Act
    errors = validate_catalog(data, load_schema(SKILL_ROOT))

    # Assert
    assert errors


@pytest.mark.parametrize("confidence", ["confirmed", "inferred", "assumed"])
def test_given_each_confidence_when_validated_then_coverage_must_match(
    confidence: str,
) -> None:
    # Arrange
    data = _valid_catalog()
    for relationship in data["relationships"]:
        relationship["confidence"] = confidence
        relationship["basis"] = "Recorded evidence for this relationship"
    total = len(data["relationships"])
    data["coverage"]["relationships_confirmed"] = (
        total if confidence == "confirmed" else 0
    )
    data["coverage"]["relationships_inferred"] = (
        total if confidence == "inferred" else 0
    )

    # Act
    errors = validate_catalog(data, load_schema(SKILL_ROOT))

    # Assert
    assert errors == []


def test_given_invalid_confidence_when_validated_then_reports_error() -> None:
    # Arrange
    data = _valid_catalog()
    data["relationships"][0]["confidence"] = "likely"

    # Act
    errors = validate_catalog(data, load_schema(SKILL_ROOT))

    # Assert
    assert errors


def test_given_empty_basis_when_validated_then_reports_error() -> None:
    # Arrange
    data = _valid_catalog()
    data["relationships"][0]["basis"] = ""

    # Act
    errors = validate_catalog(data, load_schema(SKILL_ROOT))

    # Assert
    assert errors


def test_given_bad_coverage_when_validated_then_reports_error() -> None:
    # Arrange
    data = _valid_catalog()
    data["coverage"]["entities_catalogued"] = 99

    # Act
    errors = validate_catalog(data, load_schema(SKILL_ROOT))

    # Assert
    assert any("entities_catalogued" in error for error in errors)


def test_given_mixed_confidence_coverage_when_validated_then_reports_error() -> None:
    # Arrange
    data = _valid_catalog()
    data["coverage"]["relationships_inferred"] = 0

    # Act
    errors = validate_catalog(data, load_schema(SKILL_ROOT))

    # Assert
    assert any("relationships_inferred" in error for error in errors)


def test_given_duplicate_yaml_key_when_parsed_then_raises() -> None:
    # Arrange
    markdown = "---\ncatalog_version: DS_CATALOG_V1\ncatalog_version: bad\n---\n"

    # Act and assert
    with pytest.raises(CatalogValidationError, match="duplicate YAML key"):
        parse_catalog(markdown)


def test_given_missing_frontmatter_when_extracted_then_raises() -> None:
    # Act and assert
    with pytest.raises(CatalogValidationError, match="must start"):
        extract_frontmatter("# Catalog\n")


def test_given_unclosed_frontmatter_when_extracted_then_raises() -> None:
    # Act and assert
    with pytest.raises(CatalogValidationError, match="not closed"):
        extract_frontmatter("---\ncatalog_version: DS_CATALOG_V1\n")


def test_given_schema_violation_when_validated_then_returns_error() -> None:
    # Arrange
    data = _valid_catalog()
    data["catalog_version"] = "DS_CATALOG_V2"

    # Act
    errors = validate_catalog(data, load_schema(SKILL_ROOT))

    # Assert
    assert errors


def test_given_valid_file_when_run_then_returns_success(capsys) -> None:
    # Arrange
    path = SKILL_ROOT / "examples" / "northwind-catalog.md"

    # Act
    result = run(path)

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
    assert "validate_catalog:" in captured.err


def test_given_schema_violation_when_run_then_reports_validation_failure(
    tmp_path, capsys
) -> None:
    # Arrange
    path = tmp_path / "catalog.md"
    path.write_text(_frontmatter("engagement: demo\n"), encoding="utf-8")

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
    with pytest.raises(CatalogValidationError, match=r"'\.\.' segments"):
        read_catalog_text(Path(candidate))


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
    outside.write_text(_frontmatter("engagement: demo\n"), encoding="utf-8")

    # Act and assert
    with pytest.raises(CatalogValidationError, match="outside the permitted roots"):
        read_catalog_text(outside, allowed_roots=(inside,))


def test_given_symlink_outside_root_when_read_then_raises(tmp_path) -> None:
    # Arrange
    inside = tmp_path / "inside"
    inside.mkdir()
    outside = tmp_path / "outside.md"
    outside.write_text(_frontmatter("engagement: demo\n"), encoding="utf-8")
    link = inside / "link.md"
    try:
        link.symlink_to(outside)
    except (OSError, NotImplementedError):
        pytest.skip("symlink creation is not permitted in this environment")

    # Act and assert
    with pytest.raises(CatalogValidationError, match="outside the permitted roots"):
        read_catalog_text(link, allowed_roots=(inside,))


def test_given_oversized_file_when_read_then_raises(tmp_path, monkeypatch) -> None:
    # Arrange
    path = tmp_path / "catalog.md"
    path.write_text(_frontmatter("engagement: demo\n"), encoding="utf-8")
    monkeypatch.setattr(validate_catalog_module, "MAX_INPUT_BYTES", 4)

    # Act and assert
    with pytest.raises(CatalogValidationError, match="byte input limit"):
        read_catalog_text(path, allowed_roots=(tmp_path,))


def test_given_permitted_file_when_read_then_returns_text(tmp_path) -> None:
    # Arrange
    path = tmp_path / "catalog.md"
    path.write_text(_frontmatter("engagement: demo\n"), encoding="utf-8")

    # Act
    text = read_catalog_text(path, allowed_roots=(tmp_path,))

    # Assert
    assert "engagement: demo" in text


@pytest.mark.parametrize(
    ("body", "message"),
    [
        ("copy: *undefined\n", "aliases are not permitted"),
        ("base: &anchor value\n", "anchors are not permitted"),
        ("base: &anchor value\ncopy: *anchor\n", "not permitted"),
        ("value: !custom scalar\n", "explicit tags are not permitted"),
        ("merged:\n  <<: {a: 1}\n", "merge keys are not permitted"),
    ],
    ids=["alias", "anchor", "alias-graph", "tag", "merge-key"],
)
def test_given_unsafe_yaml_construct_when_parsed_then_raises(
    body: str, message: str
) -> None:
    # Act and assert
    with pytest.raises(CatalogValidationError, match=message):
        parse_catalog(_frontmatter(body))


def test_given_unquoted_date_when_parsed_then_raises() -> None:
    # Act and assert
    with pytest.raises(CatalogValidationError, match="must be a quoted string"):
        parse_catalog(_frontmatter("generated_at: 2026-01-01\n"))


def test_given_quoted_timestamp_when_parsed_then_value_is_a_string() -> None:
    # Act
    parsed = parse_catalog(_frontmatter('generated_at: "2026-01-01T00:00:00Z"\n'))

    # Assert
    assert parsed["generated_at"] == "2026-01-01T00:00:00Z"


@pytest.mark.parametrize("literal", [".nan", ".inf", "-.inf"])
def test_given_non_finite_number_when_parsed_then_raises(literal: str) -> None:
    # Act and assert
    with pytest.raises(CatalogValidationError, match="must be a finite number"):
        parse_catalog(_frontmatter(f"threshold: {literal}\n"))


def test_given_finite_number_when_parsed_then_value_survives() -> None:
    # Act
    parsed = parse_catalog(_frontmatter("threshold: 1.5\n"))

    # Assert
    assert parsed["threshold"] == 1.5


def test_given_quoted_markdown_prose_when_parsed_then_value_survives() -> None:
    # Arrange
    prose = "## Heading with **bold**, `code`, and 2026-01-01 notes"

    # Act
    parsed = parse_catalog(_frontmatter(f'engagement: "{prose}"\n'))

    # Assert
    assert parsed["engagement"] == prose


def test_given_malformed_timestamp_when_validated_then_reports_error() -> None:
    # Arrange
    data = _valid_catalog()
    data["generated_at"] = "2026-13-45T99:99:99Z"

    # Act
    errors = validate_catalog(data, load_schema(SKILL_ROOT))

    # Assert
    assert any("date-time" in error for error in errors)


def test_given_valid_timestamp_when_validated_then_has_no_errors() -> None:
    # Arrange
    data = _valid_catalog()
    data["generated_at"] = "2026-08-01T09:00:00+02:00"

    # Act
    errors = validate_catalog(data, load_schema(SKILL_ROOT))

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
    path = tmp_path / "catalog.md"
    path.write_text(
        '---\ncatalog_version: "unterminated\ncustomer_secret_value: 42\n---\n',
        encoding="utf-8",
    )

    # Act
    result = run(path, allowed_roots=(tmp_path,))

    # Assert
    captured = capsys.readouterr()
    assert result == 2
    assert "invalid YAML" in captured.err
    assert "customer_secret_value" not in captured.err
    assert "unterminated" not in captured.err


@pytest.mark.parametrize(
    ("entities", "expected"),
    [
        ([_entity("a", ["b"]), _entity("b", ["a"])], ["a", "b"]),
        (
            [
                _entity("a", ["b"]),
                _entity("b", ["c"]),
                _entity("c", ["d"]),
                _entity("d", ["a"]),
            ],
            ["a", "b", "c", "d"],
        ),
        ([_entity("a", ["a"])], ["a"]),
        ([_entity("a", ["b"]), _entity("b", ["c"]), _entity("c", [])], []),
        (
            [
                _entity("a", ["b"]),
                _entity("b", ["a"]),
                _entity("c", ["d"]),
                _entity("d", []),
            ],
            ["a", "b"],
        ),
    ],
    ids=["two-node", "long-cycle", "self-cycle", "acyclic", "disconnected-with-cycle"],
)
def test_given_lineage_graph_when_searched_then_cycle_members_are_reported(
    entities: list[dict], expected: list[str]
) -> None:
    # Act
    cycles = lineage_cycle_ids(entities)

    # Assert
    assert cycles == expected


def test_given_cyclic_lineage_when_validated_then_reports_error() -> None:
    # Arrange
    data = _valid_catalog()
    data["entities"][0]["lineage"]["derived_from"] = ["product"]
    data["entities"][2]["lineage"]["derived_from"] = ["customer"]

    # Act
    errors = validate_catalog(data, load_schema(SKILL_ROOT))

    # Assert
    assert any("lineage is cyclic" in error for error in errors)


def test_given_non_string_yaml_key_when_parsed_then_raises() -> None:
    # Act and assert
    with pytest.raises(CatalogValidationError, match="keys must be strings"):
        parse_catalog(_frontmatter("1: numeric-key\n"))


def test_given_non_json_value_when_asserted_then_raises() -> None:
    # Act and assert
    with pytest.raises(CatalogValidationError, match="non-JSON YAML value"):
        _assert_json_compatible({"field": {"a", "b"}})


def test_given_non_string_mapping_key_when_asserted_then_raises() -> None:
    # Act and assert
    with pytest.raises(CatalogValidationError, match="non-string key"):
        _assert_json_compatible({1: "value"})


def test_given_tagged_node_when_constructed_then_raises() -> None:
    # Act and assert
    with pytest.raises(CatalogValidationError, match="explicit tags"):
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


def test_given_cli_arguments_when_parsed_then_catalog_path_is_returned() -> None:
    # Act
    args = create_parser().parse_args(["catalog.md"])

    # Assert
    assert args.catalog == Path("catalog.md")


def test_given_cli_invocation_when_main_runs_then_validates_the_example(
    monkeypatch, capsys
) -> None:
    # Arrange
    example = SKILL_ROOT / "examples" / "northwind-catalog.md"
    monkeypatch.setattr("sys.argv", ["validate_catalog.py", str(example)])

    # Act
    result = main()

    # Assert
    assert result == 0
    assert '"valid": true' in capsys.readouterr().out


def test_given_deeply_nested_yaml_when_parsed_then_raises_catalog_error() -> None:
    # Arrange
    frontmatter = _frontmatter("deep: " + "[" * 5000 + "]" * 5000 + "\n")

    # Act / Assert
    with pytest.raises(CatalogValidationError):
        parse_catalog(frontmatter)


@pytest.mark.parametrize("timestamp", ["2026-02-31", "2026-13-01", "2026-01-32"])
def test_given_out_of_range_timestamp_when_parsed_then_raises_catalog_error(
    timestamp: str,
) -> None:
    # Arrange
    frontmatter = _frontmatter(f"generated_at: {timestamp}\n")

    # Act / Assert
    with pytest.raises(CatalogValidationError, match="invalid scalar value"):
        parse_catalog(frontmatter)


def test_given_deeply_nested_yaml_when_run_then_reports_operational_error(
    tmp_path, capsys
) -> None:
    # Arrange
    catalog = tmp_path / "deep-catalog.md"
    catalog.write_text(
        _frontmatter("deep: " + "[" * 5000 + "]" * 5000 + "\n"), encoding="utf-8"
    )

    # Act
    result = run(catalog, allowed_roots=[tmp_path])

    # Assert
    assert result == 2
    assert "validate_catalog:" in capsys.readouterr().err
