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
from collections.abc import Sequence
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator, FormatChecker
from jsonschema.exceptions import SchemaError

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2
MAX_INPUT_BYTES = 5 * 1024 * 1024
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
    return resolved.read_text(encoding="utf-8")


def load_schema(skill_root: Path) -> dict[str, Any]:
    """Load and check the bundled evaluation dataset schema."""
    schema_path = skill_root / "assets" / "evaluation-dataset-v1.schema.json"
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    Draft202012Validator.check_schema(schema)
    return schema


def _schema_path(error: Any) -> str:
    """Return a stable JSON path without including rejected values."""
    path = "$"
    for segment in error.absolute_path:
        path += f"[{segment}]" if isinstance(segment, int) else f".{segment}"
    return path


def _schema_errors(data: Any, schema: dict[str, Any]) -> list[str]:
    """Return sanitized schema diagnostics."""
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    return [
        f"{_schema_path(error)} violates {error.validator}"
        for error in sorted(
            validator.iter_errors(data), key=lambda item: list(item.path)
        )
    ]


def _decode_list(
    value: str, field: str, row_number: int
) -> tuple[list[str], list[str]]:
    """Decode one semicolon-delimited CSV list with strict empty-item checks."""
    if value == "":
        return [], []
    items = [item.strip() for item in value.split(";")]
    errors: list[str] = []
    if any(not item for item in items):
        errors.append(f"CSV row {row_number} {field} contains an empty list item")
    if len(items) != len(set(items)):
        errors.append(f"CSV row {row_number} {field} contains duplicate list items")
    return items, errors


def parse_csv_pairs(text: str) -> tuple[list[dict[str, Any]], list[str]]:
    """Parse CSV pair rows and return contract diagnostics separately."""
    try:
        reader = csv.DictReader(io.StringIO(text), strict=True)
        if tuple(reader.fieldnames or ()) != CSV_FIELDS:
            return [], ["CSV header does not match the evaluation pair contract"]
        rows: list[dict[str, Any]] = []
        errors: list[str] = []
        for row_number, raw in enumerate(reader, start=2):
            if None in raw or any(raw[field] is None for field in CSV_FIELDS):
                errors.append(
                    f"CSV row {row_number} does not have one value per contract column"
                )
                continue
            populations, population_errors = _decode_list(
                raw["populations"], "populations", row_number
            )
            tools, tool_errors = _decode_list(
                raw["tools_expected"], "tools_expected", row_number
            )
            errors.extend(population_errors)
            errors.extend(tool_errors)
            review_literal = raw["needs_sme_review"].lower()
            if review_literal not in {"true", "false"}:
                errors.append(
                    f"CSV row {row_number} needs_sme_review must be true or false"
                )
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


def validate_dataset(
    data: Any, csv_pairs: list[dict[str, Any]], schema: dict[str, Any]
) -> list[str]:
    """Return structural, semantic, and JSON-to-CSV parity errors."""
    errors = _schema_errors(data, schema)
    if errors:
        return errors

    metadata = data["metadata"]
    pairs = data["evaluation_pairs"]
    pair_ids = [pair["id"] for pair in pairs]
    if len(pair_ids) != len(set(pair_ids)):
        errors.append("evaluation pair IDs must be unique")

    if metadata["total_pairs"] != len(pairs):
        errors.append("metadata.total_pairs does not match evaluation_pairs")

    actual_distribution = Counter(pair["difficulty"] for pair in pairs)
    for difficulty in DIFFICULTIES:
        if metadata["distribution"][difficulty] != actual_distribution[difficulty]:
            errors.append(
                f"metadata.distribution.{difficulty} does not match evaluation_pairs"
            )

    populations = metadata["user_populations"]
    population_set = set(populations)
    coverage = metadata["population_coverage"]
    if set(coverage) != population_set:
        errors.append(
            "metadata.population_coverage keys must exactly match user_populations"
        )
    actual_coverage = Counter(
        population for pair in pairs for population in pair["populations"]
    )
    for population in populations:
        if coverage.get(population) != actual_coverage[population]:
            errors.append(
                "metadata.population_coverage count does not match evaluation_pairs"
            )
    if any(
        population not in population_set
        for pair in pairs
        for population in pair["populations"]
    ):
        errors.append("evaluation pair references an unknown user population")

    for index, pair in enumerate(pairs):
        if (
            pair["difficulty"] == "grounding"
            and pair["source_reference"] is None
            and not pair["needs_sme_review"]
        ):
            errors.append(
                f"evaluation_pairs[{index}] grounding evidence is not established"
            )

    if len(csv_pairs) != len(pairs):
        errors.append("CSV row count does not match evaluation_pairs")
    else:
        for index, (json_pair, csv_pair) in enumerate(
            zip(pairs, csv_pairs, strict=True)
        ):
            for field in CSV_FIELDS:
                if json_pair[field] != csv_pair[field]:
                    errors.append(
                        f"CSV row {index + 2} {field} does not match evaluation_pairs"
                    )
    return errors


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
        json.JSONDecodeError,
        EvaluationValidationError,
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
