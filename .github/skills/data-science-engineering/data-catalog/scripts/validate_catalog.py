#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Validate DS_CATALOG_V1 Markdown artifacts.

Usage:
    uv run python scripts/validate_catalog.py examples/northwind-catalog.md
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import re
import sys
from collections.abc import Iterator, Sequence
from pathlib import Path
from typing import Any

import yaml
from jsonschema import Draft202012Validator, FormatChecker

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2

# Operational bound checked before any catalog content is read.
MAX_INPUT_BYTES = 5 * 1024 * 1024
MERGE_TAG = "tag:yaml.org,2002:merge"
RFC3339_DATE_TIME_PATTERN = re.compile(
    r"^\d{4}-\d{2}-\d{2}[Tt]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:[Zz]|[+-]\d{2}:\d{2})$"
)

# Three-colour depth-first search states used for lineage cycle detection.
_WHITE = 0
_GREY = 1
_BLACK = 2


class CatalogValidationError(ValueError):
    """Raised when a catalog violates the DS_CATALOG_V1 contract."""


class UniqueKeyLoader(yaml.SafeLoader):
    """Loader rejecting aliases, anchors, tags, merge keys, and duplicate keys."""

    def compose_node(
        self, parent: yaml.nodes.Node | None, index: Any
    ) -> yaml.nodes.Node:
        """Reject alias, anchor, and explicit-tag events before composition."""
        event = self.peek_event()
        if isinstance(event, yaml.AliasEvent):
            raise CatalogValidationError("YAML aliases are not permitted")
        if getattr(event, "anchor", None) is not None:
            raise CatalogValidationError("YAML anchors are not permitted")
        if getattr(event, "tag", None) is not None:
            raise CatalogValidationError("YAML explicit tags are not permitted")
        return super().compose_node(parent, index)


def _construct_unique_mapping(
    loader: UniqueKeyLoader, node: yaml.MappingNode, deep: bool = False
) -> dict[str, Any]:
    """Construct a mapping while rejecting merge keys and duplicate keys."""
    mapping: dict[str, Any] = {}
    for key_node, value_node in node.value:
        if key_node.tag == MERGE_TAG:
            raise CatalogValidationError("YAML merge keys are not permitted")
        key = loader.construct_object(key_node, deep=deep)
        if not isinstance(key, str):
            raise CatalogValidationError("YAML keys must be strings")
        if key in mapping:
            raise CatalogValidationError(f"duplicate YAML key: {key}")
        mapping[key] = loader.construct_object(value_node, deep=deep)
    return mapping


def _reject_tagged_node(
    loader: UniqueKeyLoader, tag_suffix: str, node: yaml.nodes.Node
) -> Any:
    """Reject any node carrying a tag without a registered safe constructor."""
    raise CatalogValidationError("YAML explicit tags are not permitted")


UniqueKeyLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _construct_unique_mapping
)
UniqueKeyLoader.add_multi_constructor("", _reject_tagged_node)


def _sanitize_yaml_error(error: yaml.YAMLError) -> str:
    """Describe a YAML failure by position only, never by source content."""
    mark = getattr(error, "problem_mark", None) or getattr(error, "context_mark", None)
    if mark is None:
        return f"invalid YAML ({type(error).__name__})"
    return (
        f"invalid YAML ({type(error).__name__}) at line {mark.line + 1} "
        f"column {mark.column + 1}"
    )


def _skill_root() -> Path:
    """Return the skill root that owns the bundled schema."""
    return Path(__file__).resolve().parent.parent


def _resolve_input_path(path: Path, allowed_roots: Sequence[Path]) -> Path:
    """Return a resolved input path contained by one permitted root."""
    segments = str(path).replace("\\", "/").split("/")
    if any(segment == ".." for segment in segments):
        raise CatalogValidationError("input path cannot contain '..' segments")
    resolved = path.resolve()
    for root in allowed_roots:
        if resolved.is_relative_to(root.resolve()):
            return resolved
    raise CatalogValidationError("input path resolves outside the permitted roots")


def read_catalog_text(path: Path, allowed_roots: Sequence[Path] | None = None) -> str:
    """Read a size-bounded catalog file from a permitted root."""
    roots = tuple(allowed_roots) if allowed_roots else (Path.cwd(), _skill_root())
    resolved = _resolve_input_path(path, roots)
    if resolved.stat().st_size > MAX_INPUT_BYTES:
        raise CatalogValidationError(
            f"catalog exceeds the {MAX_INPUT_BYTES} byte input limit"
        )
    return resolved.read_text(encoding="utf-8")


def _assert_json_compatible(value: Any, path: str = "$") -> None:
    """Reject YAML-native values outside the JSON data model."""
    if value is None or isinstance(value, (str, bool, int)):
        return
    if isinstance(value, float):
        if math.isnan(value) or math.isinf(value):
            raise CatalogValidationError(f"{path} must be a finite number")
        return
    if isinstance(value, list):
        for index, item in enumerate(value):
            _assert_json_compatible(item, f"{path}[{index}]")
        return
    if isinstance(value, dict):
        for key, item in value.items():
            if not isinstance(key, str):
                raise CatalogValidationError(f"{path} has a non-string key")
            _assert_json_compatible(item, f"{path}.{key}")
        return
    if isinstance(value, dt.date):
        raise CatalogValidationError(f"{path} timestamp must be a quoted string")
    raise CatalogValidationError(
        f"{path} contains non-JSON YAML value {type(value).__name__}"
    )


def _is_rfc3339_date_time(value: Any) -> bool:
    """Return True when a string value is a strict RFC 3339 timestamp."""
    if not isinstance(value, str):
        return True
    if RFC3339_DATE_TIME_PATTERN.match(value) is None:
        return False
    normalized = f"{value[:-1]}+00:00" if value[-1] in "Zz" else value
    try:
        dt.datetime.fromisoformat(normalized)
    except ValueError:
        return False
    return True


def build_format_checker() -> FormatChecker:
    """Return a format checker restricted to RFC 3339 date-time."""
    if "date-time" in FormatChecker.checkers:
        return FormatChecker(formats=["date-time"])
    checker = FormatChecker(formats=[])
    checker.checks("date-time")(_is_rfc3339_date_time)
    return checker


def extract_frontmatter(markdown: str) -> str:
    """Extract YAML frontmatter from a Markdown catalog."""
    lines = markdown.splitlines()
    if not lines or lines[0] != "---":
        raise CatalogValidationError("catalog must start with YAML frontmatter")
    try:
        closing = lines.index("---", 1)
    except ValueError as error:
        raise CatalogValidationError("catalog frontmatter is not closed") from error
    return "\n".join(lines[1:closing])


def parse_catalog(markdown: str) -> dict[str, Any]:
    """Parse catalog frontmatter under the constrained loader."""
    try:
        parsed = yaml.load(extract_frontmatter(markdown), Loader=UniqueKeyLoader)
    except CatalogValidationError:
        raise
    except yaml.YAMLError as error:
        raise CatalogValidationError(_sanitize_yaml_error(error)) from error
    except RecursionError as error:
        raise CatalogValidationError(
            "catalog frontmatter is nested too deeply"
        ) from error
    except ValueError as error:
        raise CatalogValidationError(
            "catalog frontmatter has an invalid scalar value"
        ) from error
    if not isinstance(parsed, dict):
        raise CatalogValidationError("catalog frontmatter must be an object")
    try:
        _assert_json_compatible(parsed)
    except RecursionError as error:
        raise CatalogValidationError(
            "catalog frontmatter is nested too deeply"
        ) from error
    return parsed


def load_schema(skill_root: Path) -> dict[str, Any]:
    """Load the bundled DS_CATALOG_V1 schema."""
    schema_path = skill_root / "assets" / "ds-catalog-v1.schema.json"
    return json.loads(schema_path.read_text(encoding="utf-8"))


def lineage_cycle_ids(entities: list[dict[str, Any]]) -> list[str]:
    """Return entity IDs on a lineage cycle using a three-colour search.

    Runs in O(V+E). A grey node reached again is a back edge, so every entity
    on the current path from that node onward participates in a cycle.
    """
    graph = {
        entity["id"]: list(entity["lineage"]["derived_from"]) for entity in entities
    }
    colour = dict.fromkeys(graph, _WHITE)
    on_cycle: set[str] = set()

    for root in graph:
        if colour[root] != _WHITE:
            continue
        colour[root] = _GREY
        path = [root]
        stack: list[tuple[str, Iterator[str]]] = [(root, iter(graph[root]))]
        while stack:
            node, children = stack[-1]
            descended = False
            for child in children:
                if child not in colour:
                    continue
                if colour[child] == _GREY:
                    on_cycle.update(path[path.index(child) :])
                elif colour[child] == _WHITE:
                    colour[child] = _GREY
                    path.append(child)
                    stack.append((child, iter(graph[child])))
                    descended = True
                    break
            if not descended:
                colour[node] = _BLACK
                path.pop()
                stack.pop()
    return sorted(on_cycle)


def validate_catalog(data: dict[str, Any], schema: dict[str, Any]) -> list[str]:
    """Return structural and semantic catalog errors."""
    validator = Draft202012Validator(schema, format_checker=build_format_checker())
    errors = [error.message for error in sorted(validator.iter_errors(data), key=str)]
    if errors:
        return errors

    entities = data["entities"]
    relationships = data["relationships"]
    entity_ids = [entity["id"] for entity in entities]
    relationship_ids = [relationship["id"] for relationship in relationships]

    if len(entity_ids) != len(set(entity_ids)):
        errors.append("entity IDs must be unique")
    if len(relationship_ids) != len(set(relationship_ids)):
        errors.append("relationship IDs must be unique")

    known_entities = set(entity_ids)
    for entity in entities:
        for source_id in entity["lineage"]["derived_from"]:
            if source_id not in known_entities:
                errors.append(
                    f"entity {entity['id']} has unknown lineage source {source_id}"
                )
        if entity["id"] in entity["lineage"]["derived_from"]:
            errors.append(f"entity {entity['id']} cannot derive from itself")

    cycles = lineage_cycle_ids(entities)
    if cycles:
        errors.append("entity lineage is cyclic: " + ", ".join(cycles))

    for relationship in relationships:
        for endpoint in ("from", "to"):
            if relationship[endpoint] not in known_entities:
                errors.append(
                    f"relationship {relationship['id']} has unknown {endpoint} endpoint"
                )
        join_keys = relationship["join_keys"]
        if isinstance(join_keys["from_field"], list) and len(
            join_keys["from_field"]
        ) != len(join_keys["to_field"]):
            errors.append(
                f"relationship {relationship['id']} composite join keys "
                "must have equal length"
            )

    coverage = data["coverage"]
    classified = sum(
        entity["classification"]["sensitivity"] != "none"
        or any(
            entity["classification"][field] is not None
            for field in (
                "gdpr_article",
                "ccpa_section",
                "nist_pf_category",
                "nistir8062_objective",
                "owasp_privacy_id",
            )
        )
        for entity in entities
    )
    expected = {
        "entities_catalogued": len(entities),
        "entities_access_confirmed": sum(
            entity["source"]["access_confirmed"] for entity in entities
        ),
        "entities_classified": classified,
        "relationships_confirmed": sum(
            relationship["confidence"] == "confirmed" for relationship in relationships
        ),
        "relationships_inferred": sum(
            relationship["confidence"] == "inferred" for relationship in relationships
        ),
    }
    for field, expected_value in expected.items():
        if coverage[field] != expected_value:
            errors.append(
                f"coverage.{field} is {coverage[field]}, expected {expected_value}"
            )
    return errors


def create_parser() -> argparse.ArgumentParser:
    """Create the command-line parser."""
    parser = argparse.ArgumentParser(description="Validate a DS_CATALOG_V1 catalog")
    parser.add_argument("catalog", type=Path, help="Markdown catalog to validate")
    return parser


def run(catalog_path: Path, allowed_roots: Sequence[Path] | None = None) -> int:
    """Validate one catalog and print a JSON result.

    Operational failures report on stderr with EXIT_ERROR. Validation failures
    report on stdout with EXIT_FAILURE.
    """
    try:
        markdown = read_catalog_text(catalog_path, allowed_roots)
        data = parse_catalog(markdown)
        schema = load_schema(_skill_root())
    except (OSError, CatalogValidationError, json.JSONDecodeError) as error:
        print(f"validate_catalog: {error}", file=sys.stderr)
        return EXIT_ERROR

    errors = validate_catalog(data, schema)
    print(json.dumps({"valid": not errors, "errors": errors}, indent=2))
    return EXIT_FAILURE if errors else EXIT_SUCCESS


def main() -> int:
    """Run the catalog validator CLI."""
    return run(create_parser().parse_args().catalog)


if __name__ == "__main__":
    sys.exit(main())
