#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Validate an OWASP Threat Dragon v2.6.2 model.

The model is checked against the vendored Threat Dragon v2.6.2 JSON Schema and
against the semantic graph rules the generator guarantees. The schema check is
implemented in this module so the skill needs no extra runtime dependency, and it
fails closed on any schema keyword it does not implement.

Usage:
    python scripts/validate_threat_dragon.py model.json

Exit codes: 0 valid, 1 invalid model, 2 usage or read error.
"""

from __future__ import annotations

import argparse
import json
import sys
import uuid
from pathlib import Path
from typing import Any

from tm7_threat_contract import MAX_MODEL_BYTES, InputTooLargeError, read_bounded_bytes

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2

THREAT_DRAGON_VERSION = "2.6.2"
SCHEMA_PATH = (
    Path(__file__).resolve().parent.parent
    / "assets"
    / "threat-dragon"
    / "threat-dragon-v2.6.2.schema.json"
)
MAX_SCHEMA_ERRORS = 50
EXPECTED_THUMBNAIL = "./public/content/images/thumbnail.stride.jpg"

ALLOWED_SHAPES = {"actor", "process", "store", "trust-boundary-box", "flow"}
SHAPE_DATA_TYPES = {
    "actor": "tm.Actor",
    "process": "tm.Process",
    "store": "tm.Store",
    "trust-boundary-box": "tm.BoundaryBox",
    "flow": "tm.Flow",
}
ALLOWED_STATUSES = {"NotApplicable", "Open", "Mitigated"}
ALLOWED_SEVERITIES = {"TBD", "Low", "Medium", "High", "Critical"}
ALLOWED_THREAT_TYPES = {
    "Spoofing",
    "Tampering",
    "Repudiation",
    "Information disclosure",
    "Denial of service",
    "Elevation of privilege",
}

_ANNOTATION_KEYWORDS = {"$id", "$schema", "title", "description"}
_IMPLEMENTED_KEYWORDS = _ANNOTATION_KEYWORDS | {
    "type",
    "properties",
    "required",
    "items",
    "minimum",
    "minLength",
    "maxLength",
    "nullable",
}


class SchemaError(ValueError):
    """Raised when the schema uses a keyword this validator does not implement."""


def _check_schema_keywords(schema: Any, path: str = "#") -> None:
    if not isinstance(schema, dict):
        raise SchemaError(f"{path}: schema node must be an object")
    unsupported = sorted(set(schema) - _IMPLEMENTED_KEYWORDS)
    if unsupported:
        raise SchemaError(f"{path}: unsupported schema keyword(s) {unsupported}")
    for name, child in (schema.get("properties") or {}).items():
        _check_schema_keywords(child, f"{path}/properties/{name}")
    if "items" in schema:
        _check_schema_keywords(schema["items"], f"{path}/items")


def load_schema(path: Path = SCHEMA_PATH) -> dict[str, Any]:
    """Load the vendored schema and confirm every keyword is implemented.

    Args:
        path: Schema file to load.

    Returns:
        Parsed schema.

    Raises:
        SchemaError: If the schema uses an unimplemented keyword.
    """
    schema = json.loads(path.read_text(encoding="utf-8"))
    _check_schema_keywords(schema)
    return schema


def _matches_type(value: Any, expected: str) -> bool:
    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if expected == "null":
        return value is None
    raise SchemaError(f"unsupported schema type {expected!r}")


def _validate_node(
    value: Any, schema: dict[str, Any], path: str, errors: list[str]
) -> None:
    if len(errors) >= MAX_SCHEMA_ERRORS:
        return
    if value is None and schema.get("nullable") is True:
        return
    if "type" in schema:
        expected = schema["type"]
        types = expected if isinstance(expected, list) else [expected]
        if not any(_matches_type(value, item) for item in types):
            errors.append(f"{path}: expected {' or '.join(types)}")
            return
    if isinstance(value, str):
        if "minLength" in schema and len(value) < schema["minLength"]:
            errors.append(f"{path}: shorter than {schema['minLength']} characters")
        if "maxLength" in schema and len(value) > schema["maxLength"]:
            errors.append(f"{path}: longer than {schema['maxLength']} characters")
    if (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and "minimum" in schema
        and value < schema["minimum"]
    ):
        errors.append(f"{path}: less than minimum {schema['minimum']}")
    if isinstance(value, dict):
        for name in schema.get("required") or []:
            if name not in value:
                errors.append(f"{path}: missing required property {name!r}")
        for name, child in (schema.get("properties") or {}).items():
            if name in value:
                _validate_node(value[name], child, f"{path}.{name}", errors)
    if isinstance(value, list) and "items" in schema:
        for index, item in enumerate(value):
            _validate_node(item, schema["items"], f"{path}[{index}]", errors)


def validate_schema(model: Any, schema: dict[str, Any] | None = None) -> list[str]:
    """Return schema errors for a model, capped at ``MAX_SCHEMA_ERRORS``."""
    errors: list[str] = []
    _validate_node(model, schema if schema is not None else load_schema(), "$", errors)
    return errors


def _is_uuid5(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    try:
        return uuid.UUID(value).version == 5
    except ValueError:
        return False


def _cell_label(diagram: dict[str, Any], cell: dict[str, Any]) -> str:
    name = (cell.get("data") or {}).get("name") or cell.get("id")
    return f"cell {name!r} in diagram {diagram.get('title')!r}"


def _semantic_error(model: dict[str, Any]) -> str | None:
    """Return the first semantic rule violation, or ``None`` when the model holds."""
    if model.get("version") != THREAT_DRAGON_VERSION:
        return f"$.version: expected {THREAT_DRAGON_VERSION!r}"
    summary = model.get("summary") or {}
    if not _is_uuid5(summary.get("id")):
        return "$.summary.id: expected a UUID version 5 identifier"
    detail = model.get("detail") or {}
    diagrams = detail.get("diagrams") or []
    if detail.get("diagramTop") != len(diagrams):
        return (
            f"$.detail.diagramTop: {detail.get('diagramTop')!r} does not match "
            f"{len(diagrams)} diagram(s)"
        )

    seen_ids: set[str] = set()
    threat_numbers: list[int] = []
    for index, diagram in enumerate(diagrams):
        where = f"$.detail.diagrams[{index}]"
        if diagram.get("id") != index:
            return f"{where}.id: expected {index}"
        if diagram.get("version") != THREAT_DRAGON_VERSION:
            return f"{where}.version: expected {THREAT_DRAGON_VERSION!r}"
        if diagram.get("diagramType") != "STRIDE":
            return f"{where}.diagramType: expected 'STRIDE'"
        if diagram.get("thumbnail") != EXPECTED_THUMBNAIL:
            return f"{where}.thumbnail: expected {EXPECTED_THUMBNAIL!r}"

        cells = diagram.get("cells") or []
        node_ids: set[str] = set()
        boundary_ids: set[str] = set()
        for cell in cells:
            cell_id = cell.get("id")
            label = _cell_label(diagram, cell)
            if not _is_uuid5(cell_id):
                return f"{label}: id is not a UUID version 5 identifier"
            if cell_id in seen_ids:
                return f"{label}: duplicate id {cell_id}"
            seen_ids.add(cell_id)
            shape = cell.get("shape")
            if shape not in ALLOWED_SHAPES:
                return f"{label}: unsupported shape {shape!r}"
            data = cell.get("data") or {}
            if data.get("type") != SHAPE_DATA_TYPES[shape]:
                return f"{label}: data.type must be {SHAPE_DATA_TYPES[shape]!r}"
            if shape == "trust-boundary-box":
                boundary_ids.add(cell_id)
                if data.get("isTrustBoundary") is not True:
                    return f"{label}: data.isTrustBoundary must be true"
            elif shape != "flow":
                node_ids.add(cell_id)
                if data.get("isTrustBoundary"):
                    return f"{label}: a node cannot be a trust boundary"

        for cell in cells:
            label = _cell_label(diagram, cell)
            data = cell.get("data") or {}
            threats = data.get("threats") or []
            if cell.get("shape") == "trust-boundary-box" and threats:
                return f"{label}: trust boundaries cannot carry threats"
            for threat in threats:
                threat_label = f"threat {threat.get('threatId')!r} on {label}"
                if not _is_uuid5(threat.get("id")):
                    return f"{threat_label}: id is not a UUID version 5 identifier"
                if threat.get("id") in seen_ids:
                    return f"{threat_label}: duplicate id {threat.get('id')}"
                seen_ids.add(threat["id"])
                if threat.get("status") not in ALLOWED_STATUSES:
                    return (
                        f"{threat_label}: unsupported status {threat.get('status')!r}"
                    )
                if threat.get("severity") not in ALLOWED_SEVERITIES:
                    return (
                        f"{threat_label}: unsupported severity "
                        f"{threat.get('severity')!r}"
                    )
                if threat.get("type") not in ALLOWED_THREAT_TYPES:
                    return f"{threat_label}: unsupported type {threat.get('type')!r}"
                if threat.get("modelType") != "STRIDE":
                    return f"{threat_label}: modelType must be 'STRIDE'"
                number = threat.get("number")
                if not isinstance(number, int) or isinstance(number, bool):
                    return f"{threat_label}: number must be an integer"
                threat_numbers.append(number)
            has_open = any(threat.get("status") == "Open" for threat in threats)
            if bool(data.get("hasOpenThreats")) != has_open:
                return f"{label}: data.hasOpenThreats does not match its threats"
            if cell.get("shape") == "flow":
                for end in ("source", "target"):
                    endpoint = (cell.get(end) or {}).get("cell")
                    if endpoint not in node_ids:
                        return (
                            f"{label}: {end} {endpoint!r} is not a node in the diagram"
                        )
                for boundary_id in data.get("trustBoundaryIds") or []:
                    if boundary_id not in boundary_ids:
                        return f"{label}: unknown trust boundary {boundary_id!r}"

    expected_top = max(threat_numbers) if threat_numbers else 0
    if detail.get("threatTop") != expected_top:
        return (
            f"$.detail.threatTop: {detail.get('threatTop')!r} does not match the "
            f"highest threat number {expected_top}"
        )
    if sorted(threat_numbers) != list(range(len(threat_numbers))):
        return "threat numbers must be unique and contiguous from 0"
    return None


def validate_model(model: Any, schema: dict[str, Any] | None = None) -> list[str]:
    """Validate a parsed Threat Dragon model.

    Args:
        model: Parsed model.
        schema: Optional pre-loaded schema; the vendored schema is used otherwise.

    Returns:
        Every schema error found (capped), followed by the first semantic error.
        An empty list means the model is valid.
    """
    errors = validate_schema(model, schema)
    if not isinstance(model, dict):
        return errors or ["$: expected object"]
    try:
        semantic = _semantic_error(model)
    except (AttributeError, KeyError, TypeError) as exc:
        semantic = None if errors else f"model structure is not traversable: {exc}"
    if semantic:
        errors.append(semantic)
    return errors


def validate_file(path: Path) -> list[str]:
    """Read a model through a bounded read and validate it.

    Raises:
        OSError: If the file cannot be read.
        InputTooLargeError: If the file exceeds the model size ceiling.
        ValueError: If the file is not valid UTF-8 JSON.
    """
    data = read_bounded_bytes(path, MAX_MODEL_BYTES)
    model = json.loads(data.decode("utf-8"))
    return validate_model(model)


def create_parser() -> argparse.ArgumentParser:
    """Create the CLI parser for Threat Dragon validation."""
    parser = argparse.ArgumentParser(
        description="Validate an OWASP Threat Dragon v2.6.2 model"
    )
    parser.add_argument("model", type=Path, help="Path to the Threat Dragon JSON model")
    return parser


def main() -> int:
    """CLI entry point."""
    args = create_parser().parse_args()
    try:
        errors = validate_file(args.model)
    except (OSError, InputTooLargeError, ValueError, SchemaError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return EXIT_ERROR
    if errors:
        for error in errors:
            print(f"Invalid: {error}", file=sys.stderr)
        return EXIT_FAILURE
    print(f"Valid Threat Dragon {THREAT_DRAGON_VERSION} model: {args.model}")
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
