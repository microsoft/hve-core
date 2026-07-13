# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

from runtime_a11y.matrix._model import (
    METHOD_RANK,
    STATUS_PRIORITY,
    CandidateUpdate,
    Cell,
    Matrix,
)


def _normalize_status(status: str) -> str:
    normalized = status.lower().strip()
    if normalized in STATUS_PRIORITY:
        return normalized
    return "unknown"


def _date_rank(date: str | None) -> int | None:
    if not date:
        return None
    try:
        return int(date.replace("-", ""))
    except ValueError:
        return None


def _should_replace(
    current_method: str | None,
    current_status: str,
    current_date: str | None,
    candidate: CandidateUpdate,
) -> bool:
    current_rank = METHOD_RANK.get(current_method or "", 0)
    candidate_rank = METHOD_RANK.get(candidate.method, 0)
    if candidate_rank != current_rank:
        return candidate_rank > current_rank

    current_dt = _date_rank(current_date)
    candidate_dt = _date_rank(candidate.date)
    if candidate_dt and current_dt and candidate_dt != current_dt:
        return candidate_dt > current_dt

    current_priority = STATUS_PRIORITY.get(_normalize_status(current_status), 0)
    candidate_priority = STATUS_PRIORITY.get(_normalize_status(candidate.status), 0)
    if current_priority != candidate_priority:
        return candidate_priority > current_priority

    return False


def merge_updates(matrix: Matrix, updates: list[CandidateUpdate]) -> Matrix:
    """Apply deterministic updates to the matrix cells."""
    cells = list(matrix.cells)
    for update in updates:
        for index, cell in enumerate(cells):
            if (
                cell.criterionId != update.criterionId
                or cell.surfaceId != update.surfaceId
                or cell.state != update.state
            ):
                continue
            if cell.isApplicable is False and update.status != "not-applicable":
                continue
            if cell.verifiedByMethod in {"manual-keyboard", "screen-reader"}:
                continue
            if _should_replace(cell.verifiedByMethod, cell.status, cell.date, update):
                cells[index] = Cell(
                    criterionId=cell.criterionId,
                    surfaceId=cell.surfaceId,
                    state=cell.state,
                    status=_normalize_status(update.status),
                    verifiedByMethod=update.method,
                    date=update.date,
                    evidence=update.evidence,
                    severity=update.severity,
                    rationale=update.rationale or cell.rationale,
                    requiredMethods=set(cell.requiredMethods),
                    adequateMethods=set(cell.adequateMethods),
                    isApplicable=cell.isApplicable,
                    methodProvenance=update.method,
                )
                break
    return Matrix(criteria=matrix.criteria, surfaces=matrix.surfaces, cells=cells)
