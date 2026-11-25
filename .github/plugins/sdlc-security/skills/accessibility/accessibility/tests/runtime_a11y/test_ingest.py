# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

from pathlib import Path

from runtime_a11y.matrix._ingest_assessor import ingest_assessor_findings
from runtime_a11y.matrix._ingest_planner import ingest_planner_state
from runtime_a11y.matrix._ingest_probe import ingest_probe_results
from runtime_a11y.matrix._model import Surface


def test_assessor_findings_fan_out_to_surfaces() -> None:
    payload = Path(__file__).with_name("fixtures") / "assessor_findings.md"
    surfaces = [Surface(id="web", name="Web", platform="web", states=["default"])]

    updates = ingest_assessor_findings(payload, surfaces)

    assert len(updates) == 2
    assert updates[0].surfaceId == "web"
    assert updates[0].method == "static-source"
    assert updates[1].status == "fail"


def test_planner_state_matches_by_platform_not_surface_id() -> None:
    payload = Path(__file__).with_name("fixtures") / "planner_state.json"
    surfaces = [
        Surface(id="web", name="Web", platform="web", states=["default"]),
        Surface(id="mobile", name="Mobile", platform="mobile", states=["default"]),
    ]

    updates = ingest_planner_state(payload, surfaces)

    assert [update.surfaceId for update in updates] == ["web", "mobile"]
    assert updates[0].method == "plan-derived"
    assert updates[0].evidence == "https://example.com/plan"


def test_probe_document_maps_direct_to_matrix_updates() -> None:
    payload = Path(__file__).with_name("fixtures") / "probe_results.json"

    updates = ingest_probe_results(payload)

    assert len(updates) == 1
    assert updates[0].criterionId == "1.3.1"
    assert updates[0].method == "runtime-automation"
    assert updates[0].status == "pass"
