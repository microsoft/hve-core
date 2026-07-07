# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

from typing import Any

from runtime_a11y.matrix._merge import merge_updates
from runtime_a11y.matrix._model import CandidateUpdate, Cell, Criterion, Matrix, Surface


def _matrix_with_cell(**cell_kwargs: Any) -> Matrix:
    cell = dict(criterionId="1.1.1", surfaceId="web", state="default")
    cell.update(cell_kwargs)
    return Matrix(
        criteria=[Criterion(id="1.1.1", framework="wcag-22", title="Name")],
        surfaces=[Surface(id="web", name="Web", platform="web", states=["default"])],
        cells=[Cell(**cell)],
    )


def _update(**kwargs: Any) -> CandidateUpdate:
    update = dict(
        criterionId="1.1.1",
        surfaceId="web",
        state="default",
        status="pass",
        method="static-source",
    )
    update.update(kwargs)
    return CandidateUpdate(**update)


def test_non_applicable_cell_not_overwritten_by_applicable_update() -> None:
    matrix = _matrix_with_cell(status="not-applicable", isApplicable=False)

    merged = merge_updates(
        matrix, [_update(status="fail", method="runtime-automation")]
    )

    assert merged.cells[0].status == "not-applicable"
    assert merged.cells[0].verifiedByMethod is None


def test_higher_method_rank_replaces_lower() -> None:
    matrix = _matrix_with_cell(
        status="fail", verifiedByMethod="plan-derived", date="2026-01-01"
    )

    merged = merge_updates(
        matrix, [_update(status="fail", method="static-source", date="2026-01-01")]
    )

    assert merged.cells[0].verifiedByMethod == "static-source"


def test_status_priority_breaks_tie_when_method_and_date_match() -> None:
    matrix = _matrix_with_cell(
        status="fail", verifiedByMethod="runtime-automation", date="2026-01-01"
    )

    merged = merge_updates(
        matrix,
        [_update(status="pass", method="runtime-automation", date="2026-01-01")],
    )

    assert merged.cells[0].status == "pass"


def test_lower_method_rank_does_not_replace() -> None:
    matrix = _matrix_with_cell(
        status="pass", verifiedByMethod="static-source", date="2026-01-01"
    )

    merged = merge_updates(
        matrix, [_update(status="fail", method="plan-derived", date="2026-01-01")]
    )

    assert merged.cells[0].verifiedByMethod == "static-source"
    assert merged.cells[0].status == "pass"


def test_non_numeric_dates_fall_through_to_status_priority() -> None:
    matrix = _matrix_with_cell(
        status="fail", verifiedByMethod="runtime-automation", date="unknown"
    )

    merged = merge_updates(
        matrix,
        [_update(status="pass", method="runtime-automation", date="bad-date")],
    )

    assert merged.cells[0].status == "pass"


def test_update_without_matching_cell_is_ignored() -> None:
    matrix = _matrix_with_cell(status="unknown")

    merged = merge_updates(matrix, [_update(surfaceId="other", status="pass")])

    assert merged.cells[0].status == "unknown"
