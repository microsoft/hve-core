# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

from runtime_a11y.matrix._build import build_matrix
from runtime_a11y.matrix._coverage import compute_coverage
from runtime_a11y.matrix._model import Cell, Criterion, Matrix, Surface


def test_build_marks_mobile_hover_state_not_applicable() -> None:
    criteria = [
        Criterion(
            id="2.5.5",
            framework="wcag-22",
            title="Target Size",
            adequateMethods={"axe-auto"},
        )
    ]
    surfaces = [
        Surface(id="m", name="Mobile", platform="mobile", states=["default", "hover"]),
        Surface(id="w", name="Web", platform="web", states=["default", "hover"]),
    ]

    matrix = build_matrix(criteria, surfaces, ["default", "hover"])

    mobile_hover = next(
        cell for cell in matrix.cells if cell.surfaceId == "m" and cell.state == "hover"
    )
    assert mobile_hover.isApplicable is False
    assert mobile_hover.status == "not-applicable"

    web_hover = next(
        cell for cell in matrix.cells if cell.surfaceId == "w" and cell.state == "hover"
    )
    assert web_hover.isApplicable is True
    assert web_hover.status == "unknown"


def test_coverage_empty_when_no_applicable_cells() -> None:
    matrix = Matrix(
        criteria=[Criterion(id="1.1.1", framework="wcag-22", title="Name")],
        surfaces=[Surface(id="web", name="Web", platform="web", states=["default"])],
        cells=[
            Cell(
                criterionId="1.1.1",
                surfaceId="web",
                state="default",
                status="not-applicable",
                isApplicable=False,
            )
        ],
    )

    coverage = compute_coverage(matrix)

    assert coverage["overall"] == {"coverage": 0.0, "denominator": 0, "numerator": 0}
    assert coverage["frameworks"] == {}
    assert coverage["residual"] == []
    assert coverage["nextActions"] == []


def test_coverage_skips_cells_referencing_unknown_criterion() -> None:
    matrix = Matrix(
        criteria=[],
        surfaces=[Surface(id="web", name="Web", platform="web", states=["default"])],
        cells=[
            Cell(
                criterionId="ghost",
                surfaceId="web",
                state="default",
                status="unknown",
                isApplicable=True,
            )
        ],
    )

    coverage = compute_coverage(matrix)

    # The orphaned cell counts toward the denominator but contributes no framework.
    assert coverage["frameworks"] == {}
    assert coverage["overall"]["denominator"] == 1
    assert coverage["overall"]["numerator"] == 0
