# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

from runtime_a11y.matrix._model import Cell, Criterion, Matrix, Surface


def build_matrix(
    criteria: list[Criterion],
    surfaces: list[Surface],
    states: list[str],
) -> Matrix:
    """Expand the criterion x surface x state grid into cells."""
    cells: list[Cell] = []
    for criterion in criteria:
        for surface in surfaces:
            for state in states:
                if surface.platform == "mobile" and state == "hover":
                    cells.append(
                        Cell(
                            criterionId=criterion.id,
                            surfaceId=surface.id,
                            state=state,
                            status="not-applicable",
                            rationale="State unavailable for mobile surfaces",
                            isApplicable=False,
                            requiredMethods=set(),
                            adequateMethods=set(criterion.adequateMethods),
                        )
                    )
                    continue
                cells.append(
                    Cell(
                        criterionId=criterion.id,
                        surfaceId=surface.id,
                        state=state,
                        status="unknown",
                        requiredMethods=set(),
                        adequateMethods=set(criterion.adequateMethods),
                    )
                )
    return Matrix(criteria=criteria, surfaces=surfaces, cells=cells)
