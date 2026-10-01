# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Load the reviewed criteria catalog that governs method adequacy.

Adequacy is the control that stops an automated observation becoming a
conformance pass: coverage counts a cell only when the winning method is in the
criterion's adequate set, and the EARL renderer downgrades anything else to
undetermined. That set is therefore refused rather than defaulted when the
catalog is absent or malformed, so a permissive or missing file cannot silently
authorize a pass.
"""

from __future__ import annotations

import json
from dataclasses import replace
from pathlib import Path
from typing import Any

import jsonschema

from runtime_a11y._errors import EXIT_USAGE, ScriptError
from runtime_a11y.matrix._model import METHOD_VOCABULARY, Criterion, Matrix

_PACKAGE_DIR = Path(__file__).resolve().parent.parent
_SCHEMA_PATH = _PACKAGE_DIR / "criteria-catalog.schema.json"
_PARTITION_FRAMEWORKS = ("wcag-22", "aria-apg", "defect-scan")


def partition_path(framework: str, base_dir: Path | None = None) -> Path:
    root = base_dir if base_dir is not None else _PACKAGE_DIR
    return root / f"criteria-catalog.{framework}.json"


def _schema() -> dict[str, Any]:
    return json.loads(_SCHEMA_PATH.read_text(encoding="utf-8"))


def _load_partition(
    path: Path, validator: jsonschema.Draft202012Validator
) -> dict[str, Any]:
    if not path.exists():
        raise ScriptError(
            f"Criteria catalog partition is missing: {path.name}. "
            "The harness cannot decide method adequacy without it and will not "
            "render coverage or EARL output.",
            EXIT_USAGE,
        )
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ScriptError(
            f"Criteria catalog partition is not valid JSON: {path.name}: {exc}",
            EXIT_USAGE,
        ) from exc

    errors = sorted(validator.iter_errors(payload), key=lambda err: list(err.path))
    if errors:
        first = errors[0]
        location = "/".join(str(part) for part in first.path) or "(root)"
        raise ScriptError(
            f"Criteria catalog partition failed validation: {path.name} at "
            f"{location}: {first.message}",
            EXIT_USAGE,
        )
    return payload


def _assert_known_methods(payload: dict[str, Any], path: Path) -> None:
    """Reject a method the shared vocabulary does not define.

    The schema enumerates methods independently, so this check catches a
    partition that drifts ahead of methods.json rather than letting an unknown
    method rank zero during merge.
    """
    for entry in payload["criteria"]:
        for method in entry["adequateMethods"]:
            if method not in METHOD_VOCABULARY:
                raise ScriptError(
                    f"Criteria catalog partition {path.name} names an unknown "
                    f"evidence method '{method}' for criterion {entry['id']}.",
                    EXIT_USAGE,
                )


def load_criteria_catalog(base_dir: str | Path | None = None) -> list[Criterion]:
    """Load, validate, and merge every catalog partition."""
    root = Path(base_dir) if base_dir is not None else _PACKAGE_DIR
    validator = jsonschema.Draft202012Validator(
        _schema(),
        format_checker=jsonschema.FormatChecker(),
    )

    criteria: list[Criterion] = []
    seen: set[tuple[str, str]] = set()
    for framework in _PARTITION_FRAMEWORKS:
        path = partition_path(framework, root)
        payload = _load_partition(path, validator)
        if payload["framework"] != framework:
            raise ScriptError(
                f"Criteria catalog partition {path.name} declares framework "
                f"'{payload['framework']}' but is loaded as '{framework}'.",
                EXIT_USAGE,
            )
        _assert_known_methods(payload, path)

        for entry in payload["criteria"]:
            key = (framework, entry["id"])
            if key in seen:
                raise ScriptError(
                    f"Criteria catalog declares {entry['id']} more than once for "
                    f"framework {framework}.",
                    EXIT_USAGE,
                )
            seen.add(key)
            criteria.append(
                Criterion(
                    id=entry["id"],
                    framework=framework,
                    title=entry["title"],
                    adequateMethods=set(entry["adequateMethods"]),
                )
            )

    return criteria


def apply_criteria_catalog(
    matrix: Matrix, base_dir: str | Path | None = None
) -> Matrix:
    """Replace caller-supplied adequacy with the reviewed catalog's.

    A matrix document arrives from outside the package and carries its own
    adequate-method sets. Those sets decide whether a result renders as a pass,
    so they are taken from the reviewed catalog instead of trusted as supplied.
    A criterion the catalog does not cover is refused rather than defaulted,
    because an unlisted criterion has no reviewed adequacy rule behind it.
    """
    catalog = {
        (entry.framework, entry.id): entry for entry in load_criteria_catalog(base_dir)
    }

    criteria: list[Criterion] = []
    for criterion in matrix.criteria:
        reviewed = catalog.get((criterion.framework, criterion.id))
        if reviewed is None:
            raise ScriptError(
                f"Matrix references criterion {criterion.id} for framework "
                f"{criterion.framework}, which the reviewed criteria catalog does "
                "not cover. Add it to the catalog before rendering.",
                EXIT_USAGE,
            )
        criteria.append(
            Criterion(
                id=criterion.id,
                framework=criterion.framework,
                title=criterion.title or reviewed.title,
                adequateMethods=set(reviewed.adequateMethods),
            )
        )

    adequacy = {
        (entry.framework, entry.id): entry.adequateMethods for entry in criteria
    }
    frameworks = {criterion.id: criterion.framework for criterion in criteria}
    cells = []
    for cell in matrix.cells:
        framework = frameworks.get(cell.criterionId)
        reviewed_methods = adequacy.get((framework, cell.criterionId))
        cells.append(
            replace(cell, adequateMethods=set(reviewed_methods))
            if reviewed_methods is not None
            else cell
        )

    return replace(matrix, criteria=criteria, cells=cells)


def catalog_provenance(base_dir: str | Path | None = None) -> dict[str, Any]:
    """Return catalog identity for rendered artifacts.

    Rendered output records which adequacy rules produced its verdicts, so a
    reader can tell whether a pass rests on reviewed judgments.
    """
    root = Path(base_dir) if base_dir is not None else _PACKAGE_DIR
    partitions: dict[str, Any] = {}
    for framework in _PARTITION_FRAMEWORKS:
        raw = partition_path(framework, root).read_text(encoding="utf-8")
        payload = json.loads(raw)
        partitions[framework] = {
            "catalogVersion": payload["catalogVersion"],
            "classification": payload.get("classification", "standards"),
            "reviewedBy": payload["provenance"].get("reviewedBy"),
        }
    return {
        "partitions": partitions,
        "reviewed": all(entry["reviewedBy"] for entry in partitions.values()),
    }
