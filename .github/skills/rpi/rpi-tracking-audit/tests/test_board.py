# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Task state words and next actions on the board."""

from __future__ import annotations

from builders import (
    DAY,
    T,
    Workspace,
    changes_text,
    critique_text,
    plan_text,
    research_text,
    review_text,
)

PLAN = f"{T}/plans/{DAY}/alpha-plan.md"
OPEN = (("P01-T01", True), ("P01-T02", False))


def _row(ws: Workspace) -> dict:
    audit = ws.audit()
    return next(r for r in audit.board if r["slug"] == "alpha")


def test_given_research_ready_when_boarded_then_researched_and_plan_next(
    ws: Workspace,
) -> None:
    # Arrange
    ws.write(f"{T}/research/{DAY}/alpha-research.md", research_text())

    # Act
    row = _row(ws)

    # Assert
    assert row["state"] == "researched"
    assert (
        row["next"]
        == f"/rpi-plan task=alpha research={T}/research/{DAY}/alpha-research.md"
    )


def test_given_research_not_ready_when_boarded_then_researching(ws: Workspace) -> None:
    # Arrange
    ws.write(
        f"{T}/research/{DAY}/alpha-research.md", research_text(readiness="Not ready")
    )

    # Act
    row = _row(ws)

    # Assert
    assert row["state"] == "researching"
    assert row["next"] == "/rpi-research topic=alpha (readiness Not ready)"


def test_given_ready_plan_when_boarded_then_implement_first_dependency_ready_task(
    ws: Workspace,
) -> None:
    # Arrange
    ws.write(PLAN, plan_text(tasks=(("P01-T01", False), ("P01-T02", False))))
    ws.write(f"{T}/reviews/plans/{DAY}/alpha-plan-critique.md", critique_text())

    # Act
    row = _row(ws)

    # Assert
    assert row["state"] == "planned"
    assert row["next"] == f"/rpi-implement plan={PLAN} task=P01-T01"


def test_given_plan_not_ready_when_boarded_then_planning_and_replan(
    ws: Workspace,
) -> None:
    # Arrange
    ws.write(
        PLAN, plan_text(tasks=(("P01-T01", False),), readiness="Partial and Not ready")
    )

    # Act
    row = _row(ws)

    # Assert
    assert row["state"] == "planning"
    assert row["next"] == "/rpi-plan task=alpha (readiness Not ready)"


def test_given_started_critique_when_boarded_then_critique_in_progress(
    ws: Workspace,
) -> None:
    # Arrange
    ws.write(PLAN, plan_text(tasks=(("P01-T01", False),)))
    ws.write(
        f"{T}/reviews/plans/{DAY}/alpha-plan-critique.md",
        critique_text(execution="started", verdict=""),
    )

    # Act
    row = _row(ws)

    # Assert
    assert row["state"] == "planning, critique in progress"
    assert "was started and not finished" in row["next"]


def test_given_open_decision_when_boarded_then_resolve_before_implement(
    ws: Workspace,
) -> None:
    # Arrange
    ws.write(
        PLAN,
        plan_text(
            tasks=(("P01-T01", False),),
            decisions=(("D2", "Encoding", "input requested"),),
        ),
    )
    ws.write(f"{T}/reviews/plans/{DAY}/alpha-plan-critique.md", critique_text())

    # Act
    row = _row(ws)

    # Assert
    assert row["next"].startswith("resolve 1 open decision in")


def test_given_plan_without_tasks_when_boarded_then_replan(ws: Workspace) -> None:
    # Arrange
    ws.write(PLAN, plan_text(tasks=()))

    # Act
    row = _row(ws)

    # Assert
    assert row["next"] == "/rpi-plan task=alpha (the plan has no tasks)"


def test_given_unmet_dependency_when_boarded_then_first_unchecked_named(
    ws: Workspace,
) -> None:
    # Arrange
    head, tail = plan_text(tasks=(("P01-T01", False),)).rsplit(
        "Dependencies:\n* none", 1
    )
    ws.write(PLAN, head + "Dependencies:\n* P01-T09" + tail)
    ws.write(f"{T}/reviews/plans/{DAY}/alpha-plan-critique.md", critique_text())

    # Act
    row = _row(ws)

    # Assert
    assert row["next"] == (
        f"/rpi-implement plan={PLAN} (first unchecked task P01-T01 (dependencies "
        "unchecked))"
    )


def test_given_partial_changes_when_boarded_then_implementing(ws: Workspace) -> None:
    # Arrange
    ws.full_task(
        plan=plan_text(tasks=OPEN),
        changes=changes_text(
            status="Partial", entries=(("P01-T01", "passed"),), completed="P01-T01"
        ),
        review="",
    )
    (ws.root / T / "reviews" / "logs" / DAY / "alpha-review.md").unlink()

    # Act
    row = _row(ws)

    # Assert
    assert row["state"] == "implementing"
    assert row["next"] == f"/rpi-implement plan={PLAN} task=P01-T02"


def test_given_blocked_changes_when_boarded_then_blocked_and_clear_blocker(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(
        plan=plan_text(tasks=OPEN),
        changes=changes_text(
            status="Blocked",
            blockers=("Need credentials",),
            completed="P01-T01",
            entries=(("P01-T01", "passed"),),
        ),
    )
    (ws.root / T / "reviews" / "logs" / DAY / "alpha-review.md").unlink()

    # Act
    row = _row(ws)

    # Assert
    assert row["state"] == "blocked in implementation"
    assert row["next"] == (
        f"clear the blocker (Need credentials), then /rpi-implement plan={PLAN} "
        "task=P01-T02"
    )


def test_given_blocker_with_partial_status_when_boarded_then_next_notes_blocker(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(
        plan=plan_text(tasks=OPEN),
        changes=changes_text(
            status="Partial",
            blockers=("Flaky test",),
            completed="P01-T01",
            entries=(("P01-T01", "passed"),),
        ),
    )
    (ws.root / T / "reviews" / "logs" / DAY / "alpha-review.md").unlink()

    # Act
    row = _row(ws)

    # Assert
    assert row["next"].endswith(
        f"(a blocker is recorded in {T}/changes/{DAY}/alpha-changes.md)"
    )


def test_given_all_checked_without_review_when_boarded_then_review_next(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()
    (ws.root / T / "reviews" / "logs" / DAY / "alpha-review.md").unlink()

    # Act
    row = _row(ws)

    # Assert
    assert row["state"] == "implemented, not reviewed"
    assert row["next"] == (
        f"/rpi-review task=alpha plan={PLAN} changes={T}/changes/{DAY}/alpha-changes.md"
    )


def test_given_undecided_finding_when_boarded_then_decide_first(ws: Workspace) -> None:
    # Arrange
    ws.full_task(review=review_text(decisions=(), final_outcome="pending"))

    # Act
    row = _row(ws)

    # Assert
    assert row["state"] == "reviewed, findings open"
    assert row["next"].startswith("decide RV-001 in the Parent Decision Record")


def test_given_decided_but_final_pending_when_boarded_then_record_outcome_and_route(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(
        review=review_text(
            outcome="Defects found",
            final_outcome="pending",
            findings=(
                ("RV-001", "High", "rpi-implement"),
                ("RV-002", "Low", "rpi-plan"),
            ),
            decisions=(
                ("RD-001", "RV-001", "accepted", "rpi-research"),
                ("RD-002", "RV-002", "rejected", "none"),
            ),
        )
    )

    # Act
    row = _row(ws)

    # Assert
    assert row["state"] == "reviewed, findings open"
    assert row["next"] == (
        "record the final outcome in Current Disposition of "
        f"{T}/reviews/logs/{DAY}/alpha-review.md; "
        "/rpi-research topic=alpha"
    )
    assert row["routes"] == {"rpi-research": 1, "none": 1}


def test_given_conformant_assessed_but_final_pending_when_boarded_then_decision_pending(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(review=review_text(final_outcome="pending"))

    # Act
    row = _row(ws)

    # Assert
    assert row["state"] == "reviewed, decision pending"


def test_given_routes_to_every_destination_when_boarded_then_all_commands_listed(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(
        review=review_text(
            outcome="Defects found",
            final_outcome="Defects found",
            findings=(
                ("RV-001", "Low", "rpi-implement"),
                ("RV-002", "Low", "rpi-plan"),
                ("RV-003", "Low", "follow-up"),
            ),
            decisions=(
                ("RD-001", "RV-001", "accepted", "{{x}}"),
                ("RD-002", "RV-002", "accepted", "{{x}}"),
                ("RD-003", "RV-003", "accepted", "{{x}}"),
            ),
        )
    )

    # Act
    row = _row(ws)

    # Assert
    assert row["next"] == (
        f"/rpi-implement plan={PLAN}; /rpi-plan task=alpha; "
        "plan the follow-up items as a separate task"
    )


def test_given_review_partial_when_boarded_then_decided_route_comes_first(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(review=review_text(execution="Partial", final_outcome="pending"))

    # Act
    row = _row(ws)

    # Assert
    assert row["state"] == "review partial"
    assert row["next"].startswith(f"/rpi-implement plan={T}/plans/{DAY}/alpha-plan.md")
    assert "only if a new review of the unassessed scope is wanted" in row["next"]


def test_given_review_complete_not_conformant_when_boarded_then_review_complete(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(
        review=review_text(
            outcome="Conformant",
            final_outcome="Not accepted",
            findings=(),
            decisions=(),
        )
    )

    # Act
    row = _row(ws)

    # Assert
    assert row["state"] == "review complete"
    assert row["next"] == "none recorded"


def test_given_started_review_when_boarded_then_review_in_progress(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(
        review=review_text(
            execution="", outcome="", decisions=(), record_execution="started"
        )
    )

    # Act
    row = _row(ws)

    # Assert
    assert row["state"] == "review in progress"
    assert "was started and not finished" in row["next"]
    assert row["review"].startswith("started /")


def test_given_review_without_changes_when_boarded_then_evidence_missing(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()
    (ws.root / T / "changes" / DAY / "alpha-changes.md").unlink()

    # Act
    row = _row(ws)

    # Assert
    assert row["state"] == "reviewed, evidence missing"
    assert row["next"].startswith("restore the changes record")


def test_given_bounded_review_when_boarded_then_not_accepted(ws: Workspace) -> None:
    # Arrange
    ws.full_task(review=review_text(scope="P01-T01"))

    # Act
    row = _row(ws)

    # Assert
    assert row["state"] == "implemented, not reviewed"
    assert row["review_scope"] == "bounded"


def test_given_high_finding_when_boarded_then_repair_prefix(ws: Workspace) -> None:
    # Arrange
    ws.full_task()
    path = ws.root / PLAN
    path.write_text(
        path.read_text().replace("id=P01-T02 -->", "id=P01-T07 -->"), encoding="utf-8"
    )

    # Act
    row = _row(ws)

    # Assert
    assert row["next"].startswith(f"repair the high findings on {PLAN} first, then:")


def test_given_legacy_plan_when_boarded_then_replan_with_draft(ws: Workspace) -> None:
    # Arrange
    rel = f"{T}/plans/{DAY}/old-plan.instructions.md"
    ws.write(
        rel,
        "# Plan\n\n## Implementation Checklist\n\n* [x] Step 1.1: a\n* [ ] Step 1.2: "
        "b\n",
    )
    ws.write(f"{T}/details/{DAY}/old-details.md", "details")

    # Act
    audit = ws.audit()

    # Assert
    row = audit.legacy_board[0]
    assert row["progress"] == "1/2 steps"
    assert row["next"] == f"re-plan with `/rpi-plan task=old draft={rel}`"


def test_given_legacy_without_plan_when_boarded_then_replan_citing_files(
    ws: Workspace,
) -> None:
    # Arrange
    ws.write(f"{T}/details/{DAY}/old-details.md", "details")

    # Act
    audit = ws.audit()

    # Assert
    assert audit.legacy_board[0]["progress"] == "no plan file"
