# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for catalog-driven ERD rendering."""

from __future__ import annotations

import copy
import re
from pathlib import Path
from typing import Any

import pytest
import render_catalog_erd as render_catalog_erd_module
import yaml
from render_catalog_erd import (
    ASCII_MULTIPLICITY,
    MAX_DISPLAY_TEXT_LENGTH,
    MERMAID_ATTRIBUTE_TOKEN_PATTERN,
    MERMAID_ATTRIBUTE_TYPE,
    CatalogRenderError,
    _node_ids,
    _sanitize_yaml_error,
    create_parser,
    main,
    parse_catalog,
    read_catalog_text,
    render_ascii,
    render_mermaid,
    run,
)

REPO_ROOT = Path(__file__).resolve().parents[5]
CATALOG_FIXTURE = (
    REPO_ROOT
    / ".github"
    / "skills"
    / "data-science"
    / "ds-catalog"
    / "examples"
    / "northwind-catalog.md"
)


def _catalog() -> dict:
    return copy.deepcopy(parse_catalog(CATALOG_FIXTURE.read_text(encoding="utf-8")))


def _to_markdown(data: dict) -> str:
    """Serialize a catalog dictionary into Markdown frontmatter."""
    return f"---\n{yaml.safe_dump(data, sort_keys=False)}---\n"


def _minimal(**overrides: Any) -> dict:
    """Build a two-entity catalog with one overridable relationship."""
    relationship: dict[str, Any] = {
        "id": "rel-a-b",
        "from": "alpha",
        "to": "beta",
        "cardinality": "one-to-many",
        "from_minimum": "one",
        "to_minimum": "zero",
        "join_keys": {"from_field": "alpha_id", "to_field": "alpha_id"},
        "confidence": "confirmed",
        "basis": "Confirmed by the data owner",
    }
    relationship.update(overrides)
    return {
        "catalog_version": "DS_CATALOG_V1",
        "engagement": "demo",
        "entities": [
            {"id": "alpha", "name": "Alpha"},
            {"id": "beta", "name": "Beta"},
        ],
        "relationships": [relationship],
    }


@pytest.mark.parametrize("renderer", [render_mermaid, render_ascii])
def test_given_catalog_when_rendered_then_document_sections_are_present(
    renderer,
) -> None:
    # Arrange
    data = _catalog()

    # Act
    rendered = renderer(data)

    # Assert
    assert rendered.startswith("## northwind-modernization Data Model")
    assert "### Legend" in rendered
    assert "### Key Relationships" in rendered


@pytest.mark.parametrize("renderer", [render_mermaid, render_ascii])
def test_given_catalog_when_rendered_then_every_declared_fact_survives(
    renderer,
) -> None:
    # Arrange
    data = _catalog()

    # Act
    rendered = renderer(data)

    # Assert
    for entity in data["entities"]:
        assert entity["name"] in rendered
    for relationship in data["relationships"]:
        assert relationship["id"] in rendered
        assert relationship["basis"] in rendered


def test_given_catalog_when_rendered_as_mermaid_then_uses_er_diagram() -> None:
    # Arrange
    data = _catalog()

    # Act
    rendered = render_mermaid(data)

    # Assert
    assert "```mermaid" in rendered
    assert "erDiagram" in rendered
    assert "flowchart" not in rendered


def test_given_catalog_when_rendered_as_ascii_then_no_mermaid_block() -> None:
    # Arrange
    data = _catalog()

    # Act
    rendered = render_ascii(data)

    # Assert
    assert "```mermaid" not in rendered
    assert "```text" in rendered


@pytest.mark.parametrize(
    ("cardinality", "from_minimum", "to_minimum", "notation"),
    [
        ("one-to-one", "one", "one", "||--||"),
        ("one-to-one", "zero", "zero", "|o--o|"),
        ("one-to-many", "one", "zero", "||--o{"),
        ("one-to-many", "zero", "one", "|o--|{"),
        ("many-to-many", "one", "one", "}|--|{"),
        ("many-to-many", "zero", "zero", "}o--o{"),
    ],
)
def test_given_multiplicity_when_rendered_as_mermaid_then_notation_matches(
    cardinality: str, from_minimum: str, to_minimum: str, notation: str
) -> None:
    # Arrange
    data = _minimal(
        cardinality=cardinality,
        from_minimum=from_minimum,
        to_minimum=to_minimum,
    )

    # Act
    rendered = render_mermaid(data)

    # Assert
    assert f"entity_alpha {notation} entity_beta" in rendered


@pytest.mark.parametrize(
    ("cardinality", "from_minimum", "to_minimum", "notation"),
    [
        ("one-to-one", "one", "one", "1 --- 1"),
        ("one-to-one", "zero", "zero", "0..1 --- 0..1"),
        ("one-to-many", "one", "zero", "1 --- 0..*"),
        ("many-to-many", "zero", "one", "0..* --- 1..*"),
    ],
)
def test_given_multiplicity_when_rendered_as_ascii_then_notation_matches(
    cardinality: str, from_minimum: str, to_minimum: str, notation: str
) -> None:
    # Arrange
    data = _minimal(
        cardinality=cardinality,
        from_minimum=from_minimum,
        to_minimum=to_minimum,
    )

    # Act
    rendered = render_ascii(data)

    # Assert
    assert notation in rendered


@pytest.mark.parametrize("renderer", [render_mermaid, render_ascii])
def test_given_confirmed_relationship_when_rendered_then_label_is_unmarked(
    renderer,
) -> None:
    # Arrange
    data = _minimal(confidence="confirmed")

    # Act
    rendered = renderer(data)

    # Assert
    assert "(confirmed)" not in rendered
    assert "alpha_id = alpha_id" in rendered


@pytest.mark.parametrize("renderer", [render_mermaid, render_ascii])
@pytest.mark.parametrize("confidence", ["inferred", "assumed"])
def test_given_unconfirmed_relationship_when_rendered_then_label_is_suffixed(
    renderer, confidence: str
) -> None:
    # Arrange
    data = _minimal(confidence=confidence)

    # Act
    rendered = renderer(data)

    # Assert
    assert f"alpha_id = alpha_id ({confidence})" in rendered


def test_given_composite_keys_when_rendered_then_order_is_preserved() -> None:
    # Arrange
    data = _catalog()

    # Act
    rendered = render_mermaid(data)

    # Assert
    assert "tenant_id = tenant_id, customer_id = customer_id" in rendered


def test_given_scalar_keys_when_rendered_then_pairing_is_visible() -> None:
    # Arrange
    data = _catalog()

    # Act
    rendered = render_ascii(data)

    # Assert
    assert "customer_id = account_ref" in rendered


def test_given_catalog_when_rendered_as_mermaid_then_keys_are_role_neutral() -> None:
    # Arrange
    data = _catalog()

    # Act
    rendered = render_mermaid(data)

    # Assert
    assert "catalog_id" not in rendered
    assert " PK" not in rendered
    assert " FK" not in rendered
    assert "        string tenant_id" in rendered


def test_given_repeated_join_key_when_rendered_then_attribute_is_deduplicated() -> None:
    # Arrange
    data = _catalog()

    # Act
    rendered = render_mermaid(data)
    block = rendered.split('entity_sales_2dorder_2dline["Sales Order Line"]')[1]
    block = block.split("    }")[0]

    # Assert
    assert block.count("string tenant_id") == 1


@pytest.mark.parametrize("renderer", [render_mermaid, render_ascii])
def test_given_no_relationships_when_rendered_then_entities_and_notice_appear(
    renderer,
) -> None:
    # Arrange
    data = _minimal()
    data["relationships"] = []

    # Act
    rendered = renderer(data)

    # Assert
    assert "Alpha" in rendered
    assert "Beta" in rendered
    assert "No relationships are declared in this catalog." in rendered


def test_given_unknown_endpoint_when_parsed_then_raises() -> None:
    # Arrange
    markdown = CATALOG_FIXTURE.read_text(encoding="utf-8").replace(
        "to: sales-order-line", "to: missing-entity"
    )

    # Act and assert
    with pytest.raises(CatalogRenderError, match="endpoints"):
        parse_catalog(markdown)


def test_given_unsupported_version_when_parsed_then_raises() -> None:
    # Arrange
    markdown = CATALOG_FIXTURE.read_text(encoding="utf-8").replace(
        "catalog_version: DS_CATALOG_V1", "catalog_version: DS_CATALOG_V2"
    )

    # Act and assert
    with pytest.raises(CatalogRenderError, match="unsupported catalog_version"):
        parse_catalog(markdown)


def test_given_missing_frontmatter_when_parsed_then_raises() -> None:
    # Act and assert
    with pytest.raises(CatalogRenderError, match="must start"):
        parse_catalog("# Catalog\n")


def test_given_unclosed_frontmatter_when_parsed_then_raises() -> None:
    # Act and assert
    with pytest.raises(CatalogRenderError, match="not closed"):
        parse_catalog("---\ncatalog_version: DS_CATALOG_V1\n")


def test_given_duplicate_yaml_key_when_parsed_then_raises() -> None:
    # Act and assert
    with pytest.raises(CatalogRenderError, match="duplicate catalog YAML key"):
        parse_catalog("---\ncatalog_version: DS_CATALOG_V1\ncatalog_version: other\n---\n")


@pytest.mark.parametrize(
    ("overrides", "message"),
    [
        ({"cardinality": "one-to-some"}, "cardinality is unsupported"),
        ({"confidence": "likely"}, "confidence is unsupported"),
        ({"basis": "  "}, "basis must be a non-empty string"),
        ({"id": ""}, "relationship id must be a non-empty string"),
        ({"from_minimum": "maybe"}, "from_minimum must be"),
        ({"to_minimum": 0}, "to_minimum must be"),
    ],
)
def test_given_malformed_relationship_when_parsed_then_raises(
    overrides: dict, message: str
) -> None:
    # Arrange
    data = _minimal(**overrides)

    # Act and assert
    with pytest.raises(CatalogRenderError, match=message):
        parse_catalog(_to_markdown(data))


@pytest.mark.parametrize(
    ("join_keys", "message"),
    [
        ({"from_field": "a", "to_field": ["a"]}, "must both be strings"),
        ({"from_field": [], "to_field": []}, "non-empty"),
        ({"from_field": ["a", "b"], "to_field": ["a"]}, "equal length"),
        ({"from_field": ["a", ""], "to_field": ["a", "b"]}, r"from_field\[1\]"),
        ({"from_field": ["a"], "to_field": [5]}, r"to_field\[0\]"),
        ("not-an-object", "join_keys must be an object"),
    ],
)
def test_given_malformed_join_keys_when_parsed_then_raises(join_keys: Any, message: str) -> None:
    # Arrange
    data = _minimal(join_keys=join_keys)

    # Act and assert
    with pytest.raises(CatalogRenderError, match=message):
        parse_catalog(_to_markdown(data))


def test_given_missing_endpoint_minimum_when_parsed_then_raises() -> None:
    # Arrange
    data = _minimal()
    del data["relationships"][0]["to_minimum"]

    # Act and assert
    with pytest.raises(CatalogRenderError, match="to_minimum must be"):
        parse_catalog(_to_markdown(data))


def test_given_duplicate_entity_id_when_parsed_then_raises() -> None:
    # Arrange
    data = _minimal()
    data["entities"].append({"id": "alpha", "name": "Alpha Again"})

    # Act and assert
    with pytest.raises(CatalogRenderError, match="duplicate catalog entity id"):
        parse_catalog(_to_markdown(data))


def test_given_duplicate_relationship_id_when_parsed_then_raises() -> None:
    # Arrange
    data = _minimal()
    data["relationships"].append(copy.deepcopy(data["relationships"][0]))

    # Act and assert
    with pytest.raises(CatalogRenderError, match="duplicate catalog relationship id"):
        parse_catalog(_to_markdown(data))


def test_given_colliding_entity_ids_when_parsed_then_identifiers_stay_distinct() -> None:
    # Arrange
    data = _minimal()
    data["entities"].append({"id": "Alpha", "name": "Upper Alpha"})

    # Act
    rendered = render_mermaid(parse_catalog(_to_markdown(data)))

    # Assert
    assert 'entity_alpha["Alpha"]' in rendered
    assert 'entity_alpha_2["Upper Alpha"]' in rendered


def test_given_entity_without_name_when_parsed_then_raises() -> None:
    # Arrange
    data = _minimal()
    data["entities"][0].pop("name")

    # Act and assert
    with pytest.raises(CatalogRenderError, match="entity alpha name"):
        parse_catalog(_to_markdown(data))


def test_given_non_object_frontmatter_when_parsed_then_raises() -> None:
    # Act and assert
    with pytest.raises(CatalogRenderError, match="must be an object"):
        parse_catalog("---\n- one\n- two\n---\n")


def test_given_non_array_entities_when_parsed_then_raises() -> None:
    # Act and assert
    with pytest.raises(CatalogRenderError, match="must be arrays"):
        parse_catalog("---\ncatalog_version: DS_CATALOG_V1\nentities: {}\nrelationships: []\n---\n")


@pytest.mark.parametrize("output_format", ["mermaid", "ascii"])
def test_given_valid_fixture_when_run_then_returns_success(
    output_format: str, capsys: pytest.CaptureFixture[str]
) -> None:
    # Act
    result = run(CATALOG_FIXTURE, output_format, allowed_roots=(REPO_ROOT,))

    # Assert
    assert result == 0
    assert "Data Model" in capsys.readouterr().out


def test_given_missing_file_when_run_then_returns_error(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # Act
    result = run(tmp_path / "missing.md", "mermaid", allowed_roots=(tmp_path,))

    # Assert
    assert result == 2
    assert "render_catalog_erd:" in capsys.readouterr().err


def test_given_malformed_catalog_when_run_then_errors_without_output(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    path = tmp_path / "catalog.md"
    path.write_text(_to_markdown(_minimal(from_minimum="maybe")), encoding="utf-8")

    # Act
    result = run(path, "mermaid", allowed_roots=(tmp_path,))

    # Assert
    captured = capsys.readouterr()
    assert result == 2
    assert captured.out == ""
    assert "from_minimum must be" in captured.err


@pytest.mark.parametrize("candidate", ["../evil.md", "..\\evil.md", "a/../../evil.md"])
def test_given_traversal_path_when_read_then_raises(candidate: str) -> None:
    # Act and assert
    with pytest.raises(CatalogRenderError, match=r"'\.\.' segments"):
        read_catalog_text(Path(candidate))


def test_given_traversal_path_when_run_then_returns_operational_error(
    capsys: pytest.CaptureFixture[str],
) -> None:
    # Act
    result = run(Path("../evil.md"), "mermaid")

    # Assert
    assert result == 2
    assert "'..' segments" in capsys.readouterr().err


def test_given_path_outside_root_when_read_then_raises(tmp_path: Path) -> None:
    # Arrange
    inside = tmp_path / "inside"
    inside.mkdir()
    outside = tmp_path / "outside.md"
    outside.write_text(_to_markdown(_minimal()), encoding="utf-8")

    # Act and assert
    with pytest.raises(CatalogRenderError, match="outside the permitted roots"):
        read_catalog_text(outside, allowed_roots=(inside,))


def test_given_symlink_outside_root_when_read_then_raises(tmp_path: Path) -> None:
    # Arrange
    inside = tmp_path / "inside"
    inside.mkdir()
    outside = tmp_path / "outside.md"
    outside.write_text(_to_markdown(_minimal()), encoding="utf-8")
    link = inside / "link.md"
    try:
        link.symlink_to(outside)
    except (OSError, NotImplementedError):
        pytest.skip("symlink creation is not permitted in this environment")

    # Act and assert
    with pytest.raises(CatalogRenderError, match="outside the permitted roots"):
        read_catalog_text(link, allowed_roots=(inside,))


def test_given_oversized_file_when_read_then_raises(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    # Arrange
    path = tmp_path / "catalog.md"
    path.write_text(_to_markdown(_minimal()), encoding="utf-8")
    monkeypatch.setattr(render_catalog_erd_module, "MAX_INPUT_BYTES", 4)

    # Act and assert
    with pytest.raises(CatalogRenderError, match="byte input limit"):
        read_catalog_text(path, allowed_roots=(tmp_path,))


@pytest.mark.parametrize(
    ("body", "message"),
    [
        ("copy: *undefined\n", "aliases are not permitted"),
        ("base: &anchor value\n", "anchors are not permitted"),
        ("base: &anchor value\ncopy: *anchor\n", "not permitted"),
        ("value: !custom scalar\n", "explicit tags are not permitted"),
        ("merged:\n  <<: {a: 1}\n", "merge keys are not permitted"),
        ("catalog_version: DS_CATALOG_V2\n", "duplicate catalog YAML key"),
    ],
    ids=["alias", "anchor", "alias-graph", "tag", "merge-key", "duplicate-key"],
)
def test_given_unsafe_yaml_construct_when_parsed_then_raises(body: str, message: str) -> None:
    # Act and assert
    with pytest.raises(CatalogRenderError, match=message):
        parse_catalog(f"---\ncatalog_version: DS_CATALOG_V1\n{body}---\n")


def test_given_unquoted_date_when_parsed_then_raises() -> None:
    # Act and assert
    with pytest.raises(CatalogRenderError, match="must be a quoted string"):
        parse_catalog("---\ncatalog_version: DS_CATALOG_V1\ngenerated_at: 2026-01-01\n---\n")


@pytest.mark.parametrize("timestamp", ["2026-02-31", "2026-13-01", "2026-01-32"])
def test_given_out_of_range_timestamp_when_parsed_then_raises(timestamp: str) -> None:
    # Act and assert
    with pytest.raises(CatalogRenderError, match="invalid scalar value"):
        parse_catalog(f"---\ncatalog_version: DS_CATALOG_V1\ngenerated_at: {timestamp}\n---\n")


def test_given_non_finite_number_when_parsed_then_raises() -> None:
    # Act and assert
    with pytest.raises(CatalogRenderError, match="must be a finite number"):
        parse_catalog("---\ncatalog_version: DS_CATALOG_V1\nthreshold: .nan\n---\n")


def test_given_quoted_markdown_prose_when_parsed_then_value_survives() -> None:
    # Arrange
    data = _minimal()
    data["entities"][0]["name"] = "Alpha ledger, revised 2026-01-01 (see notes)"

    # Act
    parsed = parse_catalog(_to_markdown(data))

    # Assert
    assert parsed["entities"][0]["name"] == "Alpha ledger, revised 2026-01-01 (see notes)"


def test_given_parser_error_when_run_then_output_excludes_source(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    path = tmp_path / "catalog.md"
    path.write_text(
        '---\ncatalog_version: "unterminated\ncustomer_secret_value: 42\n---\n',
        encoding="utf-8",
    )

    # Act
    result = run(path, "mermaid", allowed_roots=(tmp_path,))

    # Assert
    captured = capsys.readouterr()
    assert result == 2
    assert "invalid catalog YAML" in captured.err
    assert "customer_secret_value" not in captured.err


def test_given_unmarked_yaml_error_when_sanitized_then_reports_type_only() -> None:
    # Act
    message = _sanitize_yaml_error(yaml.YAMLError("customer secret detail"))

    # Assert
    assert message == "invalid catalog YAML (YAMLError)"


def test_given_newline_in_display_text_when_parsed_then_raises() -> None:
    # Arrange
    data = _minimal()
    data["entities"][0]["name"] = "Alpha\n## Injected heading"

    # Act and assert
    with pytest.raises(CatalogRenderError, match="must be a single line"):
        parse_catalog(_to_markdown(data))


def test_given_code_fence_in_display_text_when_parsed_then_raises() -> None:
    # Arrange
    data = _minimal()
    data["entities"][0]["name"] = "Alpha ``` injected"

    # Act and assert
    with pytest.raises(CatalogRenderError, match="cannot contain the sequence"):
        parse_catalog(_to_markdown(data))


def test_given_mermaid_directive_in_display_text_when_parsed_then_raises() -> None:
    # Arrange
    data = _minimal()
    data["entities"][0]["name"] = "%%{init: {'theme':'dark'}}%%"

    # Act and assert
    with pytest.raises(CatalogRenderError, match="cannot contain the sequence"):
        parse_catalog(_to_markdown(data))


def test_given_script_tag_in_display_text_when_parsed_then_raises() -> None:
    # Arrange
    data = _minimal()
    data["entities"][0]["name"] = "Alpha <script>alert(1)</script>"

    # Act and assert
    with pytest.raises(CatalogRenderError, match="cannot contain the sequence"):
        parse_catalog(_to_markdown(data))


def test_given_mdx_expression_in_display_text_when_parsed_then_raises() -> None:
    # Arrange
    data = _minimal()
    data["engagement"] = "demo {process.env.SECRET}"

    # Act and assert
    with pytest.raises(CatalogRenderError, match="cannot contain the sequence"):
        parse_catalog(_to_markdown(data))


def test_given_quote_in_display_text_when_parsed_then_raises() -> None:
    # Arrange
    data = _minimal()
    data["entities"][0]["name"] = 'Alpha" : "escaped'

    # Act and assert
    with pytest.raises(CatalogRenderError, match="cannot contain the sequence"):
        parse_catalog(_to_markdown(data))


def test_given_over_length_display_text_when_parsed_then_raises() -> None:
    # Arrange
    data = _minimal()
    data["entities"][0]["name"] = "A" * (MAX_DISPLAY_TEXT_LENGTH + 1)

    # Act and assert
    with pytest.raises(CatalogRenderError, match="display characters"):
        parse_catalog(_to_markdown(data))


def test_given_bounded_display_text_when_parsed_then_accepted() -> None:
    # Arrange
    data = _minimal()
    data["entities"][0]["name"] = "A" * MAX_DISPLAY_TEXT_LENGTH

    # Act
    parsed = parse_catalog(_to_markdown(data))

    # Assert
    assert parsed["entities"][0]["name"] == "A" * MAX_DISPLAY_TEXT_LENGTH


@pytest.mark.parametrize("field", ["from_field", "to_field"])
def test_given_malformed_attribute_token_when_parsed_then_raises(field: str) -> None:
    # Arrange
    join_keys = {"from_field": "alpha_id", "to_field": "alpha_id"}
    join_keys[field] = "alpha id; DROP"

    # Act and assert
    with pytest.raises(CatalogRenderError, match="Mermaid attribute token"):
        parse_catalog(_to_markdown(_minimal(join_keys=join_keys)))


def test_given_declared_attributes_when_rendered_then_tokens_are_safe() -> None:
    # Arrange
    data = _catalog()

    # Act
    rendered = render_mermaid(data)

    # Assert
    assert MERMAID_ATTRIBUTE_TOKEN_PATTERN.match(MERMAID_ATTRIBUTE_TYPE)
    for line in rendered.splitlines():
        if line.startswith(f"        {MERMAID_ATTRIBUTE_TYPE} "):
            assert MERMAID_ATTRIBUTE_TOKEN_PATTERN.match(line.split()[1])


def test_given_entities_when_identifiers_derived_then_pattern_is_enforced() -> None:
    # Arrange
    entities = [{"id": "a-b"}, {"id": "a_b"}, {"id": "A B"}]

    # Act
    assigned = _node_ids(entities)

    # Assert
    assert len(set(assigned.values())) == len(entities)
    for token in assigned.values():
        assert MERMAID_ATTRIBUTE_TOKEN_PATTERN.match(token)


@pytest.mark.parametrize("renderer", [render_mermaid, render_ascii])
def test_given_catalog_when_rendered_then_fence_count_is_fixed(renderer) -> None:
    # Arrange
    data = _catalog()

    # Act
    rendered = renderer(data)

    # Assert
    assert rendered.count("```") == 2


def test_given_catalog_when_rendered_as_mermaid_then_accessibility_is_declared() -> None:
    # Arrange
    data = _catalog()

    # Act
    rendered = render_mermaid(data)

    # Assert
    assert "    accTitle: northwind-modernization Data Model" in rendered
    assert re.search(r"^    accDescr: \S.*\.$", rendered, re.MULTILINE)


def test_given_catalog_when_rendered_then_both_formats_carry_the_same_facts() -> None:
    # Arrange
    data = _catalog()
    facts: list[str] = []
    for entity in data["entities"]:
        facts.extend([entity["id"], entity["name"]])
    for relationship in data["relationships"]:
        facts.extend(
            [
                relationship["id"],
                relationship["from"],
                relationship["to"],
                relationship["cardinality"],
                relationship["from_minimum"],
                relationship["to_minimum"],
                relationship["confidence"],
                relationship["basis"],
            ]
        )
        for side in ("from_field", "to_field"):
            value = relationship["join_keys"][side]
            facts.extend(value if isinstance(value, list) else [value])

    # Act
    mermaid = render_mermaid(data)
    ascii_text = render_ascii(data)

    # Assert
    for fact in facts:
        assert fact in mermaid
        assert fact in ascii_text
    for multiplicity in ASCII_MULTIPLICITY.values():
        assert (multiplicity in mermaid) == (multiplicity in ascii_text)


@pytest.mark.parametrize("renderer", [render_mermaid, render_ascii])
def test_given_heading_level_when_rendered_then_headings_shift(renderer) -> None:
    # Arrange
    data = _catalog()

    # Act
    rendered = renderer(data, 3)

    # Assert
    assert rendered.startswith("### northwind-modernization Data Model")
    assert "#### Entities" in rendered
    assert "#### Legend" in rendered
    assert "#### Key Relationships" in rendered


@pytest.mark.parametrize("level", [0, 6, "2", True])
def test_given_unsupported_heading_level_when_rendered_then_raises(level: Any) -> None:
    # Arrange
    data = _minimal()

    # Act and assert
    with pytest.raises(CatalogRenderError, match="heading level must be"):
        render_mermaid(data, level)


def test_given_cli_arguments_when_parsed_then_defaults_are_applied() -> None:
    # Act
    args = create_parser().parse_args(["catalog.md", "--format", "ascii"])

    # Assert
    assert args.catalog == Path("catalog.md")
    assert args.format == "ascii"
    assert args.heading_level == 2


def test_given_cli_invocation_when_main_runs_then_renders_the_fixture(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    monkeypatch.chdir(REPO_ROOT)
    monkeypatch.setattr(
        "sys.argv",
        ["render_catalog_erd.py", str(CATALOG_FIXTURE), "--format", "mermaid"],
    )

    # Act
    result = main()

    # Assert
    assert result == 0
    assert "erDiagram" in capsys.readouterr().out
