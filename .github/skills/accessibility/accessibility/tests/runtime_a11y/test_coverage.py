# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

from runtime_a11y.matrix._build import build_matrix
from runtime_a11y.matrix._coverage import compute_coverage
from runtime_a11y.matrix._model import Criterion, Surface


def test_two_of_three_adequate_cells_yield_66_7_percent_coverage() -> None:
    criterion = Criterion(
        id="1.1.1",
        framework="wcag-22",
        title="Name",
        adequateMethods={"manual-keyboard"},
    )
    surface = Surface(id="web", name="Web", platform="web", states=["default"])
    matrix = build_matrix([criterion], [surface], ["default", "focus", "hover"])

    matrix.cells[0].status = "pass"
    matrix.cells[0].verifiedByMethod = "manual-keyboard"
    matrix.cells[0].isApplicable = True
    matrix.cells[1].status = "pass"
    matrix.cells[1].verifiedByMethod = "manual-keyboard"
    matrix.cells[1].isApplicable = True
    matrix.cells[2].status = "partial"
    matrix.cells[2].verifiedByMethod = "static-source"
    matrix.cells[2].isApplicable = True

    summary = compute_coverage(matrix)

    assert summary["overall"]["coverage"] == 66.7
    assert summary["overall"]["numerator"] == 2
    assert summary["overall"]["denominator"] == 3
