# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

from runtime_a11y.matrix._merge import merge_updates
from runtime_a11y.matrix._model import CandidateUpdate, Cell, Criterion, Matrix, Surface


def test_human_cell_preserved_when_automated_update_arrives() -> None:
    matrix = Matrix(
        criteria=[Criterion(id="1.1.1", framework="wcag-22", title="Name")],
        surfaces=[Surface(id="web", name="Web", platform="web", states=["default"])],
        cells=[
            Cell(
                criterionId="1.1.1",
                surfaceId="web",
                state="default",
                status="pass",
                verifiedByMethod="manual-keyboard",
                date="2024-01-02",
                rationale="human review",
            )
        ],
    )
    update = CandidateUpdate(
        criterionId="1.1.1",
        surfaceId="web",
        state="default",
        status="fail",
        method="runtime-automation",
        date="2024-01-01",
        evidence="probe",
    )

    merged = merge_updates(matrix, [update])

    assert merged.cells[0].status == "pass"
    assert merged.cells[0].verifiedByMethod == "manual-keyboard"


def test_probe_failure_replaces_stale_automated_pass() -> None:
    matrix = Matrix(
        criteria=[Criterion(id="1.1.1", framework="wcag-22", title="Name")],
        surfaces=[Surface(id="web", name="Web", platform="web", states=["default"])],
        cells=[
            Cell(
                criterionId="1.1.1",
                surfaceId="web",
                state="default",
                status="pass",
                verifiedByMethod="runtime-automation",
                date="2024-01-01",
            )
        ],
    )
    update = CandidateUpdate(
        criterionId="1.1.1",
        surfaceId="web",
        state="default",
        status="fail",
        method="runtime-automation",
        date="2024-01-02",
        evidence="probe",
    )

    merged = merge_updates(matrix, [update])

    assert merged.cells[0].status == "fail"
    assert merged.cells[0].verifiedByMethod == "runtime-automation"
