#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Validate an evaluation dataset JSON and CSV pair.

Usage:
    uv run python scripts/validate_evaluation_dataset.py \
        --json evaluation.json --csv evaluation.csv
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import sys
from collections import Counter
from collections.abc import Iterable, Iterator, Sequence
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator, FormatChecker
from jsonschema.exceptions import SchemaError

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2
MAX_INPUT_BYTES = 5 * 1024 * 1024
MAX_PAIRS = 1000
MAX_LIST_ENTRIES = 64
MAX_CONTENT_CHARS = 16384
MAX_IDENTIFIER_CHARS = 256
MAX_CONTAINER_LEVELS = 8
MAX_NODES = 100000
MAX_DIAGNOSTICS = 50
MAX_EVALUATION_MODES = 2
TRUNCATION_DIAGNOSTIC = "diagnostics truncated; additional errors omitted"
LIST_FIELDS = ("user_populations", "populations", "tools_expected")
MAX_CSV_LIST_CHARS = MAX_LIST_ENTRIES * (MAX_IDENTIFIER_CHARS + 1) - 1
CSV_FIELDS = (
    "id",
    "query",
    "expected_response",
    "category",
    "difficulty",
    "populations",
    "tools_expected",
    "source_reference",
    "needs_sme_review",
    "notes",
)
DIFFICULTIES = ("easy", "grounding", "hard", "negative", "safety")


class EvaluationValidationError(ValueError):
    """Raised when evaluation inputs cannot be read or parsed safely."""


def _skill_root() -> Path:
    """Return the skill root that owns the bundled schema."""
    return Path(__file__).resolve().parent.parent


def _resolve_input_path(path: Path, allowed_roots: Sequence[Path]) -> Path:
    """Return a resolved input path contained by one permitted root."""
    segments = str(path).replace("\\", "/").split("/")
    if any(segment == ".." for segment in segments):
        raise EvaluationValidationError("input path cannot contain '..' segments")
    resolved = path.resolve()
    if any(resolved.is_relative_to(root.resolve()) for root in allowed_roots):
        return resolved
    raise EvaluationValidationError("input path resolves outside the permitted roots")


def read_input_text(path: Path, allowed_roots: Sequence[Path] | None = None) -> str:
    """Read a size-bounded input from a permitted root."""
    roots = tuple(allowed_roots) if allowed_roots else (Path.cwd(), _skill_root())
    resolved = _resolve_input_path(path, roots)
    if resolved.stat().st_size > MAX_INPUT_BYTES:
        raise EvaluationValidationError(
            f"input exceeds the {MAX_INPUT_BYTES} byte limit"
        )
    with resolved.open("rb") as source:
        content = source.read(MAX_INPUT_BYTES + 1)
    if len(content) > MAX_INPUT_BYTES:
        raise EvaluationValidationError(
            f"input exceeds the {MAX_INPUT_BYTES} byte limit"
        )
    return content.decode("utf-8")


def load_schema(skill_root: Path) -> dict[str, Any]:
    """Load and check the bundled evaluation dataset schema."""
    schema_path = skill_root / "assets" / "evaluation-dataset-v1.schema.json"
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    Draft202012Validator.check_schema(schema)
    return schema


def _schema_path(error: Any) -> str:
    """Return a stable JSON path without including rejected values."""
    fields = set(CSV_FIELDS) | {
        "metadata",
        "evaluation_pairs",
        "system_name",
        "created_date",
        "version",
        "total_pairs",
        "distribution",
        "user_populations",
        "population_coverage",
        "approach",
        "evaluation_mode",
        "recommended_tooling",
        "review_state",
        "validation_status",
        "generation_method",
        *DIFFICULTIES,
    }
    path = "$"
    previous = None
    for segment in error.absolute_path:
        if isinstance(segment, int):
            path += f"[{segment}]"
        elif segment in fields and previous != "population_coverage":
            path += f".{segment}"
        else:
            path += ".[property]"
        previous = segment
    return path


def _append_error(errors: list[str], message: str) -> bool:
    """Append one diagnostic, returning whether collection must stop."""
    if len(errors) == MAX_DIAGNOSTICS:
        errors[-1] = TRUNCATION_DIAGNOSTIC
        return True
    errors.append(message)
    return False


def _bounded_errors(messages: Iterable[str]) -> list[str]:
    """Consume at most one diagnostic beyond the reporting limit."""
    errors: list[str] = []
    for message in messages:
        if _append_error(errors, message):
            break
    return errors


def _children(
    value: dict | list, field: str, depth: int
) -> Iterator[tuple[str, Any, int]]:
    """Keep each traversal frame's depth and field independent of its siblings."""
    if isinstance(value, dict):
        for key, child in value.items():
            yield key, child, depth
    else:
        for child in value:
            yield field, child, depth


def _resource_error(*values: Any) -> str | None:
    """Bound JSON-like trees before schema traversal, equality, or hashing.

    Count containers and scalar values, including each supplied root, but not
    property names. Iterator frames keep traversal storage bounded by depth.
    Repeated references count again; cycles exhaust the container-depth budget.
    """
    stack = [iter(("", value, 0) for value in values)]
    visited = 0
    while stack:
        item = next(stack[-1], None)
        if item is None:
            stack.pop()
            continue
        field, value, depth = item
        visited += 1
        if visited > MAX_NODES:
            return f"input exceeds the {MAX_NODES} node limit"
        if isinstance(value, (dict, list)):
            depth += 1
            if depth > MAX_CONTAINER_LEVELS:
                return f"input exceeds the {MAX_CONTAINER_LEVELS} container level limit"
            if isinstance(value, dict):
                if len(value) > MAX_LIST_ENTRIES:
                    return f"object exceeds the {MAX_LIST_ENTRIES} property limit"
                for key in value:
                    if not isinstance(key, str) or len(key) > MAX_IDENTIFIER_CHARS:
                        return (
                            "property names must be strings of at most "
                            f"{MAX_IDENTIFIER_CHARS} characters"
                        )
            else:
                limit = (
                    MAX_LIST_ENTRIES
                    if field in LIST_FIELDS
                    else MAX_EVALUATION_MODES
                    if field == "evaluation_mode"
                    else MAX_PAIRS
                )
                if len(value) > limit:
                    return f"array exceeds the {limit} entry limit"
            stack.append(_children(value, field, depth))
        elif isinstance(value, str):
            limit = (
                MAX_IDENTIFIER_CHARS
                if field in (*LIST_FIELDS, "id")
                else MAX_CONTENT_CHARS
            )
            if len(value) > limit:
                return f"string exceeds the {limit} character limit"
        elif value is not None and not isinstance(value, (bool, int, float)):
            return "input contains an unsupported JSON value"
    return None


def _schema_errors(data: Any, schema: dict[str, Any]) -> list[str]:
    """Return sanitized schema diagnostics."""
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    return _bounded_errors(
        f"{_schema_path(error)} violates {error.validator}"
        for error in validator.iter_errors(data)
    )


def _csv_resource_error(text: str) -> str | None:
    """Bound decoded field sizes and record width before CSV allocates fields."""
    column, records, size = 0, 0, 0
    quoted, started = False, False
    index = 0
    while index < len(text):
        char = text[index]
        if quoted:
            if char == '"':
                if index + 1 < len(text) and text[index + 1] == '"':
                    index += 1
                    size += 1
                else:
                    quoted = False
            else:
                size += 1
        elif char == '"' and not started:
            quoted = True
            started = True
        elif char == ",":
            column += 1
            if column == len(CSV_FIELDS):
                return (
                    "CSV header does not match the evaluation pair contract"
                    if records == 0
                    else (
                        f"CSV row {records + 1} "
                        "does not have one value per contract column"
                    )
                )
            size, started = 0, False
        elif char in "\r\n":
            if started or column:
                records += 1
            if records > MAX_PAIRS + 1:
                return f"CSV exceeds the {MAX_PAIRS} data row limit"
            column, size, started = 0, 0, False
            if char == "\r" and index + 1 < len(text) and text[index + 1] == "\n":
                index += 1
        else:
            size += 1
            started = True
        field = CSV_FIELDS[column]
        limit = (
            MAX_IDENTIFIER_CHARS
            if records == 0 or field == "id"
            else MAX_CSV_LIST_CHARS
            if field in LIST_FIELDS
            else MAX_CONTENT_CHARS
        )
        if size > limit:
            return f"CSV field exceeds the {limit} character limit"
        index += 1
    if records + bool(started or column) > MAX_PAIRS + 1:
        return f"CSV exceeds the {MAX_PAIRS} data row limit"
    return None


def _decode_list(
    value: str, field: str, row_number: int
) -> tuple[list[str], list[str]]:
    """Decode one semicolon-delimited CSV list with strict empty-item checks."""
    if value == "":
        return [], []
    if value.count(";") >= MAX_LIST_ENTRIES:
        return [], [
            f"CSV row {row_number} {field} exceeds the {MAX_LIST_ENTRIES} entry limit"
        ]
    items = [item.strip() for item in value.split(";")]
    errors: list[str] = []
    if any(len(item) > MAX_IDENTIFIER_CHARS for item in items):
        errors.append(
            f"CSV row {row_number} {field} exceeds the "
            f"{MAX_IDENTIFIER_CHARS} character item limit"
        )
    if any(not item for item in items):
        errors.append(f"CSV row {row_number} {field} contains an empty list item")
    if len(items) != len(set(items)):
        errors.append(f"CSV row {row_number} {field} contains duplicate list items")
    return items, errors


def parse_csv_pairs(text: str) -> tuple[list[dict[str, Any]], list[str]]:
    """Parse CSV pair rows and return contract diagnostics separately."""
    if len(text) > MAX_INPUT_BYTES or len(text.encode("utf-8")) > MAX_INPUT_BYTES:
        raise EvaluationValidationError(
            f"input exceeds the {MAX_INPUT_BYTES} byte limit"
        )
    resource_error = _csv_resource_error(text)
    if resource_error:
        return [], [resource_error]
    previous_field_limit = csv.field_size_limit(MAX_CSV_LIST_CHARS)
    try:
        reader = csv.DictReader(io.StringIO(text), strict=True)
        if tuple(reader.fieldnames or ()) != CSV_FIELDS:
            return [], ["CSV header does not match the evaluation pair contract"]
        rows: list[dict[str, Any]] = []
        errors: list[str] = []
        nodes = 1
        for row_number, raw in enumerate(reader, start=2):
            if None in raw or any(raw[field] is None for field in CSV_FIELDS):
                if _append_error(
                    errors,
                    f"CSV row {row_number} does not have one value per contract column",
                ):
                    break
                continue
            populations, population_errors = _decode_list(
                raw["populations"], "populations", row_number
            )
            tools, tool_errors = _decode_list(
                raw["tools_expected"], "tools_expected", row_number
            )
            row_errors = population_errors + tool_errors
            review_literal = raw["needs_sme_review"].lower()
            if review_literal not in {"true", "false"}:
                row_errors.append(
                    f"CSV row {row_number} needs_sme_review must be true or false"
                )
            if any(_append_error(errors, message) for message in row_errors):
                break
            nodes += 1 + len(CSV_FIELDS) + len(populations) + len(tools)
            if nodes > MAX_NODES:
                _append_error(errors, f"CSV exceeds the {MAX_NODES} node limit")
                break
            rows.append(
                {
                    "id": raw["id"],
                    "query": raw["query"],
                    "expected_response": raw["expected_response"],
                    "category": raw["category"],
                    "difficulty": raw["difficulty"],
                    "populations": populations,
                    "tools_expected": tools,
                    "source_reference": raw["source_reference"] or None,
                    "needs_sme_review": review_literal == "true",
                    "notes": raw["notes"],
                }
            )
        return rows, errors
    except (csv.Error, KeyError, TypeError) as error:
        raise EvaluationValidationError("CSV cannot be parsed") from error
    finally:
        csv.field_size_limit(previous_field_limit)


def validate_dataset(
    data: Any, csv_pairs: list[dict[str, Any]], schema: dict[str, Any]
) -> list[str]:
    """Return structural, semantic, and JSON-to-CSV parity errors."""
    resource_error = _resource_error(data, csv_pairs)
    if resource_error:
        return [resource_error]
    errors = _schema_errors(data, schema)
    if errors:
        return errors
    csv_schema = {
        "type": "array",
        "items": {"$ref": "#/$defs/pair"},
        "$defs": schema["$defs"],
    }
    errors = _schema_errors(csv_pairs, csv_schema)
    if errors:
        return errors
    return _bounded_errors(_semantic_errors(data, csv_pairs))


def _semantic_errors(
    data: dict[str, Any], csv_pairs: list[dict[str, Any]]
) -> Iterator[str]:
    """Yield parity and metadata diagnostics without materializing all failures."""
    metadata = data["metadata"]
    pairs = data["evaluation_pairs"]
    pair_ids = [pair["id"] for pair in pairs]
    if len(pair_ids) != len(set(pair_ids)):
        yield "evaluation pair IDs must be unique"

    if metadata["total_pairs"] != len(pairs):
        yield "metadata.total_pairs does not match evaluation_pairs"

    actual_distribution = Counter(pair["difficulty"] for pair in pairs)
    for difficulty in DIFFICULTIES:
        if metadata["distribution"][difficulty] != actual_distribution[difficulty]:
            yield (
                f"metadata.distribution.{difficulty} does not match evaluation_pairs"
            )

    populations = metadata["user_populations"]
    population_set = set(populations)
    coverage = metadata["population_coverage"]
    if set(coverage) != population_set:
        yield ("metadata.population_coverage keys must exactly match user_populations")
    actual_coverage = Counter(
        population for pair in pairs for population in pair["populations"]
    )
    for population in populations:
        if coverage.get(population) != actual_coverage[population]:
            yield ("metadata.population_coverage count does not match evaluation_pairs")
    if any(
        population not in population_set
        for pair in pairs
        for population in pair["populations"]
    ):
        yield "evaluation pair references an unknown user population"

    for index, pair in enumerate(pairs):
        if (
            pair["difficulty"] == "grounding"
            and pair["source_reference"] is None
            and not pair["needs_sme_review"]
        ):
            yield (f"evaluation_pairs[{index}] grounding evidence is not established")

    if len(csv_pairs) != len(pairs):
        yield "CSV row count does not match evaluation_pairs"
    else:
        for index, (json_pair, csv_pair) in enumerate(
            zip(pairs, csv_pairs, strict=True)
        ):
            for field in CSV_FIELDS:
                if json_pair[field] != csv_pair[field]:
                    yield (
                        f"CSV row {index + 2} {field} does not match evaluation_pairs"
                    )


def create_parser() -> argparse.ArgumentParser:
    """Create the command-line parser."""
    parser = argparse.ArgumentParser(
        description="Validate an evaluation dataset JSON and CSV pair"
    )
    parser.add_argument("--json", required=True, type=Path, dest="json_path")
    parser.add_argument("--csv", required=True, type=Path, dest="csv_path")
    return parser


def run(
    json_path: Path,
    csv_path: Path,
    allowed_roots: Sequence[Path] | None = None,
) -> int:
    """Validate one JSON and CSV pair and emit a sanitized JSON result."""
    try:
        data = json.loads(read_input_text(json_path, allowed_roots))
        csv_pairs, csv_errors = parse_csv_pairs(
            read_input_text(csv_path, allowed_roots)
        )
        schema = load_schema(_skill_root())
    except (
        OSError,
        UnicodeError,
        ValueError,
        RecursionError,
        SchemaError,
    ) as error:
        print(f"validate_evaluation_dataset: {type(error).__name__}", file=sys.stderr)
        return EXIT_ERROR

    errors = csv_errors or validate_dataset(data, csv_pairs, schema)
    print(json.dumps({"valid": not errors, "errors": errors}, indent=2))
    return EXIT_FAILURE if errors else EXIT_SUCCESS


def main() -> int:
    """Run the evaluation dataset validator CLI."""
    args = create_parser().parse_args()
    return run(args.json_path, args.csv_path)


if __name__ == "__main__":
    sys.exit(main())
