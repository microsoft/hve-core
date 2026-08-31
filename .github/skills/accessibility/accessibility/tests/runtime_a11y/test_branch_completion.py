# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest
from runtime_a11y._config import assert_target_allowed
from runtime_a11y._errors import ScriptError
from runtime_a11y.matrix._ingest_assessor import ingest_assessor_findings
from runtime_a11y.matrix._ingest_planner import ingest_planner_state
from runtime_a11y.matrix._ingest_probe import ingest_probe_results
from runtime_a11y.matrix._merge import merge_updates
from runtime_a11y.matrix._model import CandidateUpdate, Cell, Criterion, Matrix, Surface


def _cell(**kwargs: Any) -> Cell:
    base = dict(criterionId="1.1.1", surfaceId="web", state="default")
    base.update(kwargs)
    return Cell(**base)


def _matrix(cell: Cell) -> Matrix:
    return Matrix(
        criteria=[Criterion(id="1.1.1", framework="wcag-22", title="Name")],
        surfaces=[Surface(id="web", name="Web", platform="web", states=["default"])],
        cells=[cell],
    )


# --- planner load + matching + evidence fallbacks --------------------------


def test_planner_loads_state_from_bytes_path_str_and_missing(tmp_path: Path) -> None:
    document = {
        "controlMappings": [
            {"controlId": "1.1.1", "surfaces": ["web"], "status": "covered"}
        ]
    }
    path = tmp_path / "plan.json"
    path.write_text(json.dumps(document), encoding="utf-8")

    assert ingest_planner_state(path, ["web"])[0].criterionId == "1.1.1"
    assert ingest_planner_state(str(path), ["web"])[0].criterionId == "1.1.1"
    assert (
        ingest_planner_state(json.dumps(document).encode("utf-8"), ["web"])[0].status
        == "pass"
    )
    assert ingest_planner_state("missing-plan.json", ["web"]) == []


def test_planner_skips_non_dict_entries_and_unmatched_surfaces() -> None:
    state = {
        "controlMappings": [
            "not-a-dict",
            {"controlId": "1.1.1", "surfaces": ["nope"], "status": "covered"},
        ],
        "evidenceRegister": ["not-a-dict", {"controlId": "1.1.1", "sourceUri": "u"}],
    }
    surfaces = [Surface(id="web", name="Web", platform="web", states=["default"])]

    assert ingest_planner_state(state, surfaces) == []


def test_planner_matches_string_surfaces_and_control_id_only_evidence() -> None:
    state = {
        "controlMappings": [
            {"controlId": "1.1.1", "surfaces": ["web"], "status": "pending"}
        ],
        "evidenceRegister": [
            {"frameworkId": "other", "controlId": "1.1.1", "sourceUri": "https://ev/x"}
        ],
    }

    updates = ingest_planner_state(state, ["web"])

    assert updates[0].status == "fail"
    assert updates[0].evidence == "https://ev/x"


def test_planner_maps_not_applicable_status() -> None:
    state = {
        "controlMappings": [
            {"controlId": "1.1.1", "surfaces": ["web"], "status": "not applicable"}
        ]
    }

    assert ingest_planner_state(state, ["web"])[0].status == "not-applicable"


# --- probe path loading ----------------------------------------------------


def test_probe_reads_from_str_path_and_path_object(tmp_path: Path) -> None:
    document = {"results": [{"criterionId": "1.1.1", "status": "pass"}]}
    path = tmp_path / "probe.json"
    path.write_text(json.dumps(document), encoding="utf-8")

    assert ingest_probe_results(str(path))[0].criterionId == "1.1.1"
    assert ingest_probe_results(path)[0].criterionId == "1.1.1"


# --- merge normalization / no-op path --------------------------------------


def test_merge_unknown_status_and_missing_dates_do_not_replace() -> None:
    matrix = _matrix(_cell(status="bogus", verifiedByMethod="static-source"))

    merged = merge_updates(
        matrix,
        [
            CandidateUpdate(
                criterionId="1.1.1",
                surfaceId="web",
                state="default",
                status="bogus",
                method="static-source",
            )
        ],
    )

    assert merged.cells[0].status == "bogus"
    assert merged.cells[0].verifiedByMethod == "static-source"


# --- assessor plain-text evidence ------------------------------------------


def test_assessor_extracts_plain_text_evidence() -> None:
    markdown = (
        "| ID | Title | Status | Severity | File + Evidence |\n"
        "|----|-------|--------|----------|-----------------|\n"
        "| 1.1.1 | Name | fail | high | button.tsx |\n"
    )

    updates = ingest_assessor_findings(markdown, ["web"])

    assert updates[0].evidence == "button.tsx"


# --- model serialization ---------------------------------------------------


def test_model_to_dict_serializes_matrix() -> None:
    matrix = Matrix(
        criteria=[
            Criterion(
                id="1.1.1",
                framework="wcag-22",
                title="Name",
                adequateMethods={"axe-auto"},
            )
        ],
        surfaces=[Surface(id="web", name="Web", platform="web", states=["default"])],
        cells=[
            _cell(
                status="pass",
                requiredMethods={"axe-auto"},
                adequateMethods={"axe-auto"},
            )
        ],
    )

    payload = matrix.to_dict()

    assert payload["criteria"][0]["adequateMethods"] == ["axe-auto"]
    assert payload["surfaces"][0]["states"] == ["default"]
    assert payload["cells"][0]["requiredMethods"] == ["axe-auto"]


# --- config route-glob allowlist entries -----------------------------------


def test_assert_target_allowed_ignores_route_glob_allowlist_entries() -> None:
    # A "/path" allowlist entry authorizes a route, not a host, so it is skipped.
    with pytest.raises(ScriptError):
        assert_target_allowed(
            {"baseUrl": "https://evil.example.net", "allowlist": ["/docs/*"]}
        )
