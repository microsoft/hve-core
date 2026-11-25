# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

from pathlib import Path

from runtime_a11y.matrix._ingest_reports import ingest_report_markdown
from runtime_a11y.matrix._model import Surface

FIXTURE = Path(__file__).with_name("fixtures") / "report_findings.md"


def test_report_rows_fan_out_to_each_surface() -> None:
    surfaces = [
        Surface(id="web", name="Web", platform="web", states=["default"]),
        Surface(id="mobile", name="Mobile", platform="mobile", states=["default"]),
    ]

    updates = ingest_report_markdown(FIXTURE, surfaces)

    # 3 fixture rows x 2 surfaces.
    assert len(updates) == 6
    assert {update.surfaceId for update in updates} == {"web", "mobile"}
    assert all(update.method == "static-source" for update in updates)
    assert all(update.state == "default" for update in updates)


def test_report_status_and_evidence_mapping_from_fixture() -> None:
    updates = ingest_report_markdown(FIXTURE, ["web"])

    by_criterion = {update.criterionId: update for update in updates}
    assert by_criterion["1.3.1"].status == "pass"
    assert by_criterion["1.3.1"].evidence == "line 10"
    assert by_criterion["2.4.7"].status == "fail"
    assert by_criterion["2.4.7"].evidence == "button.tsx"
    assert by_criterion["4.1.2"].status == "partial"
    assert by_criterion["4.1.2"].evidence is None


def test_report_empty_surfaces_returns_empty() -> None:
    assert ingest_report_markdown(FIXTURE, []) == []


def test_report_accepts_string_payload_and_skips_rows_without_id() -> None:
    markdown = (
        "| ID | Status | Severity | Location |\n"
        "|----|--------|----------|----------|\n"
        "|  | Pass | minor | ignored |\n"
        "| 1.4.3 | covered | minor | theme.css (contrast) |\n"
    )

    updates = ingest_report_markdown(markdown, ["web"])

    assert len(updates) == 1
    assert updates[0].criterionId == "1.4.3"
    assert updates[0].status == "pass"
    assert updates[0].evidence == "contrast"


def test_report_status_synonyms_map_to_canonical_statuses() -> None:
    cases = {
        "caution": "partial",
        "informational": "partial",
        "risk": "fail",
        "blocked": "fail",
        "not applicable": "not-applicable",
        "totally-unknown": "fail",
    }
    for raw, expected in cases.items():
        markdown = (
            "| ID | Status | Severity | Location |\n"
            "|----|--------|----------|----------|\n"
            f"| 1.1.1 | {raw} | minor | x |\n"
        )

        updates = ingest_report_markdown(markdown, ["web"])

        assert updates[0].status == expected, raw
