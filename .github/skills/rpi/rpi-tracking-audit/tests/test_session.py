# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""The `rpi` session contract: state-driven next actions, links, and bad state."""

from __future__ import annotations

import pytest
from builders import (
    DAY,
    T,
    Workspace,
    changes_text,
    details,
    plan_text,
    research_text,
    rules_of,
    state_obj,
)
from rpi_tracking_audit._rules import STATE_RULES

SESSION = f"{T}/rpi-sessions/{DAY}/alpha-work"
STATE = f"{SESSION}/alpha-state.json"
CHILD = f"{SESSION}/alpha-fix-state.json"
OPEN = (("P01-T01", True), ("P01-T02", False))


def _implementing(ws: Workspace, **state: object) -> dict:
    """A half-implemented task with no review and a session state file."""
    ws.full_task(
        plan=plan_text(tasks=OPEN),
        changes=changes_text(
            status="Partial",
            entries=(("P01-T01", "passed"),),
            completed="P01-T01",
            remaining="P01-T02",
        ),
    )
    (ws.root / f"{T}/reviews/logs/{DAY}/alpha-review.md").unlink()
    obj = state_obj(active_phase="Implement", status="active", session_status="running")
    obj["next_action"] = {"phase": "Implement", "action": "continue P01-T02"}
    obj["artifact_paths"]["review"] = None
    obj["documents"]["review"] = []
    obj.update(state)
    ws.state(STATE, obj)
    return next(r for r in ws.audit().board if r["slug"] == "alpha")


def test_given_manual_session_when_boarded_then_phase_command_leads_and_rpi_is_offered(
    ws: Workspace,
) -> None:
    # Act
    row = _implementing(ws, mode="manual")

    # Assert
    assert row["next"].startswith(f"/rpi-implement plan={T}/plans/{DAY}/alpha-plan.md")
    assert row["next"].endswith(
        f"or /rpi task=alpha to resume the session recorded in {STATE}"
    )
    assert row["session"]["mode"] == "manual"


def test_given_automatic_session_when_boarded_then_rpi_leads(ws: Workspace) -> None:
    # Act
    row = _implementing(ws, mode="automatic")

    # Assert
    assert row["next"].startswith("/rpi task=alpha (")
    assert "the artifacts alone imply: /rpi-implement" in row["next"]


def test_given_blocked_session_when_boarded_then_the_blocker_comes_first(
    ws: Workspace,
) -> None:
    # Act
    row = _implementing(
        ws,
        mode="manual",
        status="blocked",
        blockers=[{"summary": "Destructive migration needs user confirmation"}],
    )

    # Assert
    assert row["next"].startswith(
        "clear the session blocker (Destructive migration needs user confirmation)"
    )


def test_given_completed_task_with_running_child_when_boarded_then_rpi_leads(
    ws: Workspace,
) -> None:
    # Arrange
    child = {"task_id": "alpha-fix", "task_slug": "alpha-fix", "state_path": CHILD}
    ws.state(
        CHILD,
        state_obj(
            "alpha-fix",
            active_phase="Research",
            status="active",
            session_status="running",
            parent_task={"task_id": "alpha", "task_slug": "alpha", "state_path": STATE},
            artifact_paths={},
            documents={},
            next_action={"phase": "Research", "action": "gather evidence"},
        ),
    )

    # Act
    row = _implementing(
        ws, status="completed", active_phase="Follow-up", child_tasks=[child]
    )
    audit = ws.audit()
    board = {r["slug"]: r for r in audit.board}

    # Assert
    assert row["next"].startswith("/rpi task=alpha (")
    assert "1 child task" in row["next"]
    assert board["alpha-fix"]["state"] == "session only"
    assert board["alpha-fix"]["next"].startswith("/rpi task=alpha-fix (")
    assert "TK12" not in rules_of(audit)


def test_given_session_only_task_when_filtered_then_it_is_found(ws: Workspace) -> None:
    # Arrange
    ws.full_task()
    ws.state(
        CHILD, state_obj("alpha-fix", artifact_paths={}, documents={}, status="active")
    )

    # Act
    audit = ws.audit(task="alpha-fix")

    # Assert
    assert [r["slug"] for r in audit.board] == ["alpha-fix"]


def test_given_review_skip_when_later_work_has_its_own_slug_then_both_follow_it(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()
    (ws.root / f"{T}/reviews/logs/{DAY}/alpha-review.md").unlink()
    ws.write(
        f"{T}/plans/{DAY}/task-board-polish-plan.md", plan_text("task-board-polish")
    )
    ws.write(
        f"{T}/changes/{DAY}/task-board-polish-changes.md",
        changes_text("task-board-polish"),
    )
    state = state_obj(
        confirmed_decisions=[
            {"decision": "Review step", "status": "skip", "evidence": "user"}
        ],
        status="active",
    )
    later = {k: f"{T}/{k}s/{DAY}/task-board-polish-{k}.md" for k in ("plan",)}
    later["changes"] = f"{T}/changes/{DAY}/task-board-polish-changes.md"
    state["artifact_paths"] = {
        **later,
        "research": None,
        "critique": None,
        "review": None,
    }
    state["documents"]["plan"].append(later["plan"])
    state["documents"]["changes"].append(later["changes"])
    state["documents"]["review"] = []
    ws.state(STATE, state)

    # Act
    board = {r["slug"]: r["state"] for r in ws.audit().board}

    # Assert
    assert board == {
        "alpha": "implemented, review skipped",
        "task-board-polish": "implemented, review skipped",
    }


def test_given_dot_slash_and_backslash_paths_when_audited_then_state_joins_its_task(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()
    state = state_obj()
    state["artifact_paths"] = {k: "./" + v for k, v in state["artifact_paths"].items()}
    state["documents"] = {
        k: [v[0].replace("/", "\\")] for k, v in state["documents"].items()
    }
    ws.state(STATE, state)

    # Act
    audit = ws.audit()

    # Assert
    assert audit.state_slugs == {STATE: "alpha"}
    assert audit.findings == []


@pytest.mark.parametrize("child_path", [None, "./" + CHILD])
def test_given_link_by_task_id_or_unnormalized_path_when_audited_then_no_tk12(
    ws: Workspace, child_path: str | None
) -> None:
    # Arrange
    ws.full_task()
    child = {"task_id": "alpha-fix", "task_slug": "alpha-fix", "state_path": child_path}
    ws.state(STATE, state_obj(child_tasks=[child]))
    ws.state(
        CHILD,
        state_obj(
            "alpha-fix",
            artifact_paths={},
            documents={},
            status="active",
            parent_task={
                "task_id": "alpha",
                "task_slug": "alpha",
                "state_path": "./" + STATE,
            },
        ),
    )

    # Act
    audit = ws.audit()

    # Assert
    assert "TK12" not in rules_of(audit)


@pytest.mark.parametrize(
    ("content", "reason"),
    [
        (
            '{"task_slug": "alpha", "active_phase": "Plan", "artifact_',
            "is not valid JSON",
        ),
        ('{"task_slug": "alpha", "active_phase": "Plan"}', "lacks `artifact_paths`"),
        (
            '{"task_slug": "a", "active_phase": "Plan", "artifact_paths": NaN}',
            "is not valid JSON",
        ),
        (
            '{"task_slug": "a", "active_phase": "Plan", "artifact_paths": {}, '
            '"blockers": ' + "[" * 1500 + "]" * 1500 + "}",
            "is nested deeper than 64 levels",
        ),
    ],
)
def test_given_state_file_that_cannot_be_loaded_when_audited_then_tk14(
    ws: Workspace, content: str, reason: str
) -> None:
    # Arrange
    ws.full_task()
    ws.write(STATE, content)

    # Act
    audit = ws.audit()

    # Assert
    assert details(audit, "TK14") == [f"the file {reason}"]
    assert audit.other_areas == {}


def test_given_lower_case_state_enums_when_audited_then_they_are_read(
    ws: Workspace,
) -> None:
    # Arrange
    ws.write(f"{T}/research/{DAY}/alpha-research.md", research_text())
    state = state_obj(active_phase="implement", status="Completed")
    state["next_action"] = {"phase": "review", "action": "review"}
    ws.state(STATE, state)

    # Act
    audit = ws.audit()

    # Assert
    assert details(audit, "TK8") == ["phase `Review` recorded, no plan for `alpha`"]


def test_given_complete_review_when_state_is_completed_then_unchecked_tasks_are_not_tk9(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(plan=plan_text(tasks=OPEN))
    ws.state(STATE, state_obj())

    # Act
    audit = ws.audit()

    # Assert
    assert "TK9" not in rules_of(audit)


def test_given_task_filter_without_state_when_run_then_state_rules_not_evaluated(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()
    ws.full_task("beta")
    ws.state(f"{T}/rpi-sessions/{DAY}/beta-work/beta-state.json", state_obj("beta"))

    # Act
    audit = ws.audit(task="alpha")

    # Assert
    assert set(STATE_RULES) <= set(audit.not_evaluated)
