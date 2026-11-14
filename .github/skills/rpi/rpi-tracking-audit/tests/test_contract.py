# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Fidelity to the RPI skills and the RPI Workflow canvas: markers and routes."""

from __future__ import annotations

import os

import pytest
from builders import (
    DAY,
    T,
    Workspace,
    changes_text,
    details,
    plan_text,
    review_text,
    rules_of,
)

PLAN = f"{T}/plans/{DAY}/alpha-plan.md"
REVIEW = f"{T}/reviews/logs/{DAY}/alpha-review.md"
CHANGES = f"{T}/changes/{DAY}/alpha-changes.md"
MARKER = "<!-- rpi:task id=P01-T02 -->\n"
HIGH = (("RV-001", "High", "rpi-implement"),)


def _row(ws: Workspace) -> dict:
    return next(r for r in ws.audit().board if r["slug"] == "alpha")


def _decision_row(status: str, tail: str = "") -> str:
    return f"| RD-001 | RV-001 | user | {status} | rpi-implement | none |{tail}"


@pytest.mark.parametrize(
    ("replacement", "reason"),
    [
        (MARKER + "\n", "separated from its heading by a blank line"),
        ("<!-- rpi:task id = P01-T02 -->\n", "spaces around `=`"),
        ("See <!-- rpi:task id=P01-T02 --> here\n", "shares its line with other text"),
    ],
)
def test_given_marker_the_canvas_cannot_read_when_audited_then_pl1_names_the_reason(
    ws: Workspace, replacement: str, reason: str
) -> None:
    # Arrange
    ws.full_task(plan=plan_text().replace(MARKER, replacement))

    # Act
    found = details(ws.audit(), "PL1")

    # Assert
    assert len(found) == 1
    assert "marker `P01-T02`" in found[0]
    assert reason in found[0]


def test_given_marker_after_blank_line_when_audited_then_heading_not_reported_twice(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(plan=plan_text().replace(MARKER, MARKER + "\n"))

    # Act
    audit = ws.audit()

    # Assert
    assert "PL2" not in rules_of(audit)


def test_given_pending_decision_row_when_audited_then_finding_stays_undecided(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(
        review=review_text(
            decisions=(("RD-001", "RV-001", "pending", "rpi-implement"),)
        )
    )

    # Act
    audit = ws.audit()

    # Assert
    assert details(audit, "RV4") == [
        "`RV-001` [Low] has no deciding RD event in Decision History"
    ]
    assert audit.board[0]["undecided"] == ["RV-001"]


def test_given_high_finding_skipped_in_walkthrough_when_conformant_then_not_accepted(
    ws: Workspace,
) -> None:
    # Arrange
    review = review_text(findings=HIGH).replace(
        "| RD-001 | RV-001 | user | accepted | rpi-implement | rpi-implement |",
        _decision_row("rejected", " user | none | none | Skip in the walkthrough |"),
    )
    ws.full_task(review=review)

    # Act
    audit = ws.audit()

    # Assert
    assert audit.board[0]["state"] != "accepted"
    assert any("rejected (skipped)" in d for d in details(audit, "RV6"))


def test_given_high_finding_rejected_with_a_reason_when_conformant_then_accepted(
    ws: Workspace,
) -> None:
    # Arrange
    review = review_text(findings=HIGH).replace(
        "| RD-001 | RV-001 | user | accepted | rpi-implement | rpi-implement |",
        _decision_row(
            "rejected", " user | none | none | The finding misreads the plan |"
        ),
    )
    ws.full_task(review=review)

    # Act
    audit = ws.audit()

    # Assert
    assert audit.board[0]["state"] == "accepted"
    assert "RV6" not in rules_of(audit)


def test_given_escaped_pipe_in_decision_row_when_modeled_then_columns_do_not_shift(
    ws: Workspace,
) -> None:
    # Arrange
    review = review_text(final_outcome="pending").replace(
        "| RD-001 | RV-001 | user | accepted | rpi-implement | rpi-implement |",
        "| RD-001 | RV-001 (auth \\| session) | user | deferred | rpi-implement | "
        "rpi-plan |",
    )
    ws.full_task(review=review)

    # Act
    audit = ws.audit()

    # Assert
    model = next(a for a in audit.artifacts if a.kind == "review").model
    assert model["decisions"] == {"RV-001": "deferred"}
    assert model["findings"][0]["final_destination"] == "rpi-plan"


@pytest.mark.parametrize("destination", ["rpi_implement", "follow up item", "RPI Plan"])
def test_given_destination_variant_when_audited_then_it_is_a_route(
    ws: Workspace, destination: str
) -> None:
    # Arrange
    ws.full_task(review=review_text(findings=(("RV-001", "Low", destination),)))

    # Act
    audit = ws.audit()

    # Assert
    assert "RV2" not in rules_of(audit)


@pytest.mark.parametrize(
    ("outcome", "rule"), [("Not conformant", "RV3"), ("Non-conformant", "RV3")]
)
def test_given_negated_outcome_when_audited_then_never_accepted(
    ws: Workspace, outcome: str, rule: str
) -> None:
    # Arrange
    ws.full_task(review=review_text(outcome=outcome, final_outcome=outcome))

    # Act
    audit = ws.audit()

    # Assert
    assert audit.board[0]["state"] != "accepted"
    assert rule in rules_of(audit)


def test_given_requirement_cited_from_a_prd_when_audited_then_no_pl13(
    ws: Workspace,
) -> None:
    # Arrange
    plan = plan_text().replace(
        "* FR-001",
        "* FR-001\n* PRD-2026-004 FR-012 (docs/planning/prds/expense-app.md)",
    )
    ws.full_task(plan=plan)

    # Act
    audit = ws.audit()

    # Assert
    assert "PL13" not in rules_of(audit)


def test_given_phase_diagram_instead_of_changes_line_when_audited_then_no_pl8(
    ws: Workspace,
) -> None:
    # Arrange
    diagram = "```mermaid\nflowchart LR\n  a --> b\n```"
    ws.full_task(plan=plan_text().replace("Changes in the map: the exporter.", diagram))

    # Act
    audit = ws.audit()

    # Assert
    assert "PL8" not in rules_of(audit)


def test_given_review_readiness_not_ready_when_boarded_then_review_is_not_offered_first(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(
        changes=changes_text(review_readiness="not ready: a decision is pending")
    )
    (ws.root / REVIEW).unlink()

    # Act
    row = _row(ws)

    # Assert
    assert row["next"].startswith(f"clear Review readiness in {CHANGES}")
    assert row["next"].endswith(
        f"then /rpi-review task=alpha plan={PLAN} changes={CHANGES}"
    )


def test_given_changes_edited_after_the_review_when_boarded_then_rework_is_noted(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(
        review=review_text(outcome="Defects found", final_outcome="Defects found")
    )
    old = 1_700_000_000
    os.utime(ws.root / REVIEW, (old, old))

    # Act
    row = _row(ws)

    # Assert
    assert "the changes record is newer than the review" in row["next"]


def test_given_ledger_named_for_the_plan_when_grouped_then_it_joins_that_task(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()
    ledger = "<!-- markdownlint-disable-file -->\n# Decisions\n\n## Ledger\n\n* None\n"
    ws.write(f"{T}/walkthroughs/{DAY}/alpha-plan-decisions.md", ledger)

    # Act
    audit = ws.audit()

    # Assert
    assert [r["slug"] for r in audit.board] == ["alpha"]
    assert len(audit.tasks["alpha"]["walkthrough"]) == 1


@pytest.mark.parametrize(
    ("rel", "key"),
    [
        (f"{T}/research/expense-app-research-topic.md", "research/*-research-topic.md"),
        (
            f"{T}/research/subagents/{DAY}/storage-account-mcsb.md",
            "research/subagents/*-mcsb.md",
        ),
        (
            f"{T}/plans/{DAY}-network-isa95-assessment.md",
            "plans/*-network-isa95-assessment.md",
        ),
    ],
)
def test_given_other_workflow_file_in_rpi_area_when_audited_then_listed_not_flagged(
    ws: Workspace, rel: str, key: str
) -> None:
    # Arrange
    ws.full_task()
    ws.write(rel, "# Notes from another workflow\n")

    # Act
    audit = ws.audit()

    # Assert
    assert audit.findings == []
    assert audit.other_areas == {key: 1}
    assert audit.legacy_tasks == {}


def test_given_deferred_planning_decision_when_boarded_then_listed_and_not_blocking(
    ws: Workspace,
) -> None:
    # Arrange
    plan = plan_text(
        tasks=(("P01-T01", True), ("P01-T02", False)),
        decisions=(("D2", "Encoding", "deferred"),),
    )
    ws.write(PLAN, plan)

    # Act
    audit = ws.audit()

    # Assert
    assert details(audit, "PL16") == ["D2 `Encoding` is deferred; it does not block"]
    assert audit.board[0]["open_decisions"] == 0
    assert audit.board[0]["next"] == f"/rpi-implement plan={PLAN} task=P01-T02"
