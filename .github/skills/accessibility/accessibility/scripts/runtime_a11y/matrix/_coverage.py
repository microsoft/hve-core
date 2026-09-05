# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

from collections import defaultdict

from runtime_a11y.matrix._model import Cell, Matrix


def compute_coverage(matrix: Matrix) -> dict[str, object]:
    """Compute adequate-coverage summaries and residual recommendations."""
    applicable_cells = [cell for cell in matrix.cells if cell.isApplicable]
    if not applicable_cells:
        return {
            "overall": {"coverage": 0.0, "denominator": 0, "numerator": 0},
            "frameworks": {},
            "residual": [],
            "nextActions": [],
        }

    by_framework: dict[str, list[Cell]] = defaultdict(list)
    for cell in applicable_cells:
        criterion = next(
            (item for item in matrix.criteria if item.id == cell.criterionId),
            None,
        )
        if criterion is None:
            continue
        by_framework[criterion.framework].append(cell)

    overall_numerator = sum(
        1
        for cell in applicable_cells
        if cell.status == "pass" and cell.verifiedByMethod in cell.adequateMethods
    )
    overall_denominator = len(applicable_cells)
    overall_percentage = round(
        (overall_numerator / overall_denominator * 100) if overall_denominator else 0.0,
        1,
    )

    frameworks: dict[str, dict[str, object]] = {}
    for framework, cells in by_framework.items():
        numerator = sum(
            1
            for cell in cells
            if cell.status == "pass" and cell.verifiedByMethod in cell.adequateMethods
        )
        denominator = len(cells)
        frameworks[framework] = {
            "coverage": round(
                (numerator / denominator * 100) if denominator else 0.0,
                1,
            ),
            "numerator": numerator,
            "denominator": denominator,
        }

    residual = []
    for cell in applicable_cells:
        if cell.status == "pass" and cell.verifiedByMethod in cell.adequateMethods:
            continue
        residual.append(
            {
                "criterionId": cell.criterionId,
                "surfaceId": cell.surfaceId,
                "state": cell.state,
                "status": cell.status,
                "verifiedByMethod": cell.verifiedByMethod,
                "requiredMethods": sorted(cell.requiredMethods),
            }
        )

    next_actions = [
        {
            "criterionId": item["criterionId"],
            "surfaceId": item["surfaceId"],
            "state": item["state"],
            "priority": "human"
            if item["verifiedByMethod"] in {"manual-keyboard", "screen-reader"}
            else "automation",
        }
        for item in residual[:5]
    ]

    return {
        "overall": {
            "coverage": overall_percentage,
            "denominator": overall_denominator,
            "numerator": overall_numerator,
        },
        "frameworks": frameworks,
        "residual": residual,
        "nextActions": next_actions,
    }
