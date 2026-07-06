# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

from runtime_a11y.matrix._ingest_assessor import ingest_assessor_findings
from runtime_a11y.matrix._ingest_planner import ingest_planner_state
from runtime_a11y.matrix._ingest_probe import ingest_probe_results
from runtime_a11y.matrix._model import Surface

# --- probe results ---------------------------------------------------------


def test_probe_non_list_results_returns_empty() -> None:
    assert ingest_probe_results({"results": "nope"}) == []


def test_probe_skips_non_dict_items_and_missing_criterion() -> None:
    document = {
        "results": [
            42,
            {"surfaceId": "web"},
            {"criterionId": "1.1.1", "status": "pass"},
        ]
    }

    updates = ingest_probe_results(document)

    assert len(updates) == 1
    assert updates[0].criterionId == "1.1.1"
    assert updates[0].surfaceId == "default"


def test_probe_accepts_json_string_bytes_and_missing_path() -> None:
    payload = '{"results": [{"criterionId": "1.4.3", "status": "candidate"}]}'

    assert ingest_probe_results(payload)[0].status == "partial"
    assert ingest_probe_results(payload.encode("utf-8"))[0].criterionId == "1.4.3"
    assert ingest_probe_results("does-not-exist.json") == []


def test_probe_unknown_status_normalizes_to_unknown() -> None:
    document = {"results": [{"criterionId": "1.1.1", "status": "weird"}]}

    assert ingest_probe_results(document)[0].status == "unknown"


# --- planner state ---------------------------------------------------------


def test_planner_non_list_control_mappings_returns_empty() -> None:
    assert ingest_planner_state({"controlMappings": "x"}, ["web"]) == []


def test_planner_inline_evidence_takes_precedence() -> None:
    state = {
        "controlMappings": [
            {
                "controlId": "1.1.1",
                "surfaces": ["web"],
                "status": "covered",
                "evidence": "inline-uri",
            }
        ]
    }
    surfaces = [Surface(id="web", name="Web", platform="web", states=["default"])]

    updates = ingest_planner_state(state, surfaces)

    assert updates[0].status == "pass"
    assert updates[0].evidence == "inline-uri"


def test_planner_evidence_register_fallback_by_control_id() -> None:
    state = {
        "controlMappings": [
            {"controlId": "1.1.1", "surfaces": ["web"], "status": "gap"}
        ],
        "evidenceRegister": [{"controlId": "1.1.1", "sourceUri": "https://ev/1"}],
    }
    surfaces = [Surface(id="web", name="Web", platform="web", states=["default"])]

    updates = ingest_planner_state(state, surfaces)

    assert updates[0].status == "fail"
    assert updates[0].evidence == "https://ev/1"


def test_planner_matches_by_platform_with_project_surfaces_fallback() -> None:
    state = {
        "controlMappings": [{"controlId": "1.1.1", "status": "partial"}],
        "project": {"surfaces": ["web"]},
    }
    surfaces = [Surface(id="web-main", name="Web", platform="web", states=["default"])]

    updates = ingest_planner_state(state, surfaces)

    assert [update.surfaceId for update in updates] == ["web-main"]
    assert updates[0].status == "partial"


def test_planner_skips_mapping_without_control_id() -> None:
    state = {
        "controlMappings": [
            {"surfaces": ["web"]},
            {"controlId": "1.1.1", "surfaces": ["web"], "status": "covered"},
        ]
    }
    surfaces = [Surface(id="web", name="Web", platform="web", states=["default"])]

    updates = ingest_planner_state(state, surfaces)

    assert len(updates) == 1
    assert updates[0].criterionId == "1.1.1"


# --- assessor findings -----------------------------------------------------


def test_assessor_empty_surfaces_returns_empty() -> None:
    markdown = (
        "| ID | Title | Status | Severity |\n"
        "|----|-------|--------|----------|\n"
        "| 1.1.1 | Name | fail | serious |\n"
    )

    assert ingest_assessor_findings(markdown, []) == []


def test_assessor_skips_rows_without_id_and_resets_between_tables() -> None:
    markdown = (
        "intro prose\n"
        "| ID | Title | Status | Severity |\n"
        "|----|-------|--------|----------|\n"
        "|  | Missing | fail | serious |\n"
        "| 1.4.3 | Contrast | caution | moderate |\n"
        "trailing prose\n"
    )

    updates = ingest_assessor_findings(markdown, ["web"])

    assert len(updates) == 1
    assert updates[0].criterionId == "1.4.3"
    assert updates[0].status == "partial"


def test_assessor_status_synonyms_map_to_canonical_statuses() -> None:
    cases = {
        "covered": "pass",
        "not_assessed": "fail",
        "not applicable": "not-applicable",
        "mystery": "fail",
    }
    for raw, expected in cases.items():
        markdown = (
            "| ID | Title | Status | Severity |\n"
            "|----|-------|--------|----------|\n"
            f"| 1.1.1 | Name | {raw} | x |\n"
        )

        assert ingest_assessor_findings(markdown, ["web"])[0].status == expected, raw
