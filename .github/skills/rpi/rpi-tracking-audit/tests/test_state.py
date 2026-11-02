# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Session state rules, the state-to-task join, staleness, and task filtering."""

from __future__ import annotations

import os
from datetime import datetime

import pytest
from builders import (
    DAY,
    T,
    Workspace,
    details,
    plan_text,
    research_text,
    rules_of,
    state_obj,
)
from rpi_tracking_audit._audit import UsageError
from rpi_tracking_audit._rules import STATE_RULES

SESSION = f"{T}/rpi-sessions/{DAY}/alpha-work"
STATE = f"{SESSION}/alpha-state.json"


def test_given_consistent_state_when_audited_then_no_state_findings(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()
    ws.state(STATE, state_obj())

    # Act
    audit = ws.audit()

    # Assert
    assert audit.findings == []
    assert audit.state_slugs == {STATE: "alpha"}


def test_given_no_state_file_when_audited_then_state_rules_not_evaluated(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()

    # Act
    audit = ws.audit()

    # Assert
    assert set(STATE_RULES) <= set(audit.not_evaluated)


def test_given_missing_artifact_path_when_audited_then_tk7(ws: Workspace) -> None:
    # Arrange
    ws.full_task()
    st = state_obj()
    st["artifact_paths"]["plan"] = f"{T}/plans/{DAY}/gone-plan.md"
    st["documents"]["plan"].append(st["artifact_paths"]["plan"])
    st["documents"]["research"].append(f"{T}/research/{DAY}/old-research.md")
    ws.state(STATE, st)

    # Act
    audit = ws.audit()

    # Assert
    found = details(audit, "TK7")
    assert any("artifact_paths.plan" in d for d in found)
    assert any("documents.research" in d for d in found)


def test_given_path_missing_from_documents_when_audited_then_tk13(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()
    st = state_obj()
    st["documents"]["review"] = []
    ws.state(STATE, st)

    # Act
    audit = ws.audit()

    # Assert
    assert details(audit, "TK13") == [
        f"artifact_paths.review = `{T}/reviews/logs/{DAY}/alpha-review.md` "
        "is not in documents.review"
    ]


@pytest.mark.parametrize(
    ("rel", "expected"),
    [
        (STATE, False),
        (f"{T}/alpha-state.json", True),
        (f"{T}/rpi-sessions/latest/alpha-work/alpha-state.json", True),
        (f"{SESSION}/state.json", True),
    ],
)
def test_given_state_location_when_audited_then_tk11_only_outside_session_folder(
    ws: Workspace, rel: str, expected: bool
) -> None:
    # Arrange
    ws.full_task()
    ws.state(rel, state_obj())

    # Act
    audit = ws.audit()

    # Assert
    assert ("TK11" in rules_of(audit)) is expected


@pytest.mark.parametrize(
    ("phase", "remove", "message"),
    [
        ("Implement", f"plans/{DAY}/alpha-plan.md", "no plan for `alpha`"),
        ("Review", f"changes/{DAY}/alpha-changes.md", "no changes record for `alpha`"),
    ],
)
def test_given_phase_without_needed_artifact_when_audited_then_tk8(
    ws: Workspace, phase: str, remove: str, message: str
) -> None:
    # Arrange
    ws.full_task()
    (ws.root / T / remove).unlink()
    st = state_obj(active_phase=phase, status="active", next_action={"phase": phase})
    ws.state(STATE, st)

    # Act
    audit = ws.audit()

    # Assert
    assert any(message in d for d in details(audit, "TK8"))


def test_given_state_for_unknown_task_in_implement_when_audited_then_tk8(
    ws: Workspace,
) -> None:
    # Arrange
    st = state_obj("ghost", active_phase="Implement", status="active", next_action=None)
    ws.state(f"{T}/rpi-sessions/{DAY}/ghost/ghost-state.json", st)

    # Act
    audit = ws.audit()

    # Assert
    assert any(
        "no recognized artifacts for `ghost`" in d for d in details(audit, "TK8")
    )


def test_given_state_in_research_without_artifacts_when_audited_then_no_tk8(
    ws: Workspace,
) -> None:
    # Arrange
    st = state_obj("fresh", active_phase="Research", status="active", next_action=None)
    st["artifact_paths"] = {k: None for k in st["artifact_paths"]}
    st["documents"] = {k: [] for k in st["documents"]}
    ws.state(f"{T}/rpi-sessions/{DAY}/fresh/fresh-state.json", st)

    # Act
    audit = ws.audit()

    # Assert
    assert "TK8" not in rules_of(audit)


def test_given_completed_state_with_unchecked_plan_when_audited_then_tk9(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(plan=plan_text(tasks=(("P01-T01", True), ("P01-T02", False))))
    (ws.root / f"{T}/reviews/logs/{DAY}/alpha-review.md").unlink()
    state = state_obj()
    state["artifact_paths"]["review"] = None
    state["documents"]["review"] = []
    ws.state(STATE, state)

    # Act
    audit = ws.audit()

    # Assert
    assert details(audit, "TK9") == ["status completed; unchecked: P01-T02"]


def test_given_work_named_documents_when_audited_then_state_joins_by_artifact_path(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task("task-board-polish")
    st = state_obj("alpha")
    st["artifact_paths"] = state_obj("task-board-polish")["artifact_paths"]
    st["documents"] = state_obj("task-board-polish")["documents"]
    ws.state(STATE, st)

    # Act
    audit = ws.audit()

    # Assert
    assert audit.state_slugs[STATE] == "task-board-polish"
    assert "TK8" not in rules_of(audit)


def test_given_parent_and_child_linked_when_audited_then_no_tk12(ws: Workspace) -> None:
    # Arrange
    ws.full_task()
    child_rel = f"{SESSION}/alpha-fix-state.json"
    parent = state_obj(
        child_tasks=[
            {"task_id": "alpha-fix", "task_slug": "alpha-fix", "state_path": child_rel}
        ]
    )
    child = state_obj(
        "alpha-fix",
        parent_task={"task_id": "alpha", "task_slug": "alpha", "state_path": STATE},
        artifact_paths={
            k: None for k in ("research", "plan", "critique", "changes", "review")
        },
        documents={
            k: [] for k in ("research", "plan", "critique", "changes", "review")
        },
        active_phase="Research",
        status="active",
        next_action=None,
    )
    ws.state(STATE, parent)
    ws.state(child_rel, child)

    # Act
    audit = ws.audit()

    # Assert
    assert "TK12" not in rules_of(audit)


@pytest.mark.parametrize(
    ("case", "message"),
    [
        ("missing-parent", "does not exist"),
        ("parent-does-not-list", "does not list this state"),
        ("child-points-elsewhere", "names parent"),
    ],
)
def test_given_broken_session_link_when_audited_then_tk12(
    ws: Workspace, case: str, message: str
) -> None:
    # Arrange
    ws.full_task()
    child_rel = f"{SESSION}/alpha-fix-state.json"
    empty = {k: None for k in ("research", "plan", "critique", "changes", "review")}
    child = state_obj(
        "alpha-fix",
        parent_task={"task_id": "alpha", "task_slug": "alpha", "state_path": STATE},
        artifact_paths=empty,
        documents={k: [] for k in empty},
        active_phase="Research",
        status="active",
        next_action=None,
    )
    parent = state_obj(child_tasks=[{"task_id": "alpha-fix", "state_path": child_rel}])
    if case == "missing-parent":
        child["parent_task"]["state_path"] = f"{SESSION}/gone-state.json"
    elif case == "parent-does-not-list":
        parent["child_tasks"] = []
    else:
        child["parent_task"] = None
    ws.state(STATE, parent)
    ws.state(child_rel, child)

    # Act
    audit = ws.audit()

    # Assert
    assert any(message in d for d in details(audit, "TK12"))


def test_given_listed_child_without_state_yet_when_audited_then_no_tk12(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()
    ws.state(
        STATE,
        state_obj(
            child_tasks=[
                {"task_id": "next", "state_path": f"{SESSION}/next-state.json"}
            ]
        ),
    )

    # Act
    audit = ws.audit()

    # Assert
    assert "TK12" not in rules_of(audit)


def test_given_credential_in_state_when_audited_then_hy1_and_value_redacted(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()
    ws.state(STATE, state_obj(api_key="x" * 24))

    # Act
    audit = ws.audit()

    # Assert
    assert "HY1" in rules_of(audit)
    assert audit.state_files[0].state["api_key"] == "[redacted value of api_key]"


def test_given_old_untouched_task_when_audited_then_tk6(ws: Workspace) -> None:
    # Arrange
    ws.write(f"{T}/research/{DAY}/old-research.md", research_text("old"))
    stamp = 1_700_000_000  # 2023-11-14
    os.utime(ws.root / T / "research" / DAY / "old-research.md", (stamp, stamp))

    # Act
    audit = ws.audit()

    # Assert
    local_day = (
        datetime.fromtimestamp(stamp).date().isoformat()
    )  # the report uses local time
    assert any(f"last change {local_day}" in d for d in details(audit, "TK6"))


def test_given_old_accepted_task_when_audited_then_no_tk6(ws: Workspace) -> None:
    # Arrange
    ws.full_task()
    stamp = 1_700_000_000
    for path in (ws.root / T).rglob("*.md"):
        os.utime(path, (stamp, stamp))

    # Act
    audit = ws.audit()

    # Assert
    assert "TK6" not in rules_of(audit)


def test_given_task_filter_when_audited_then_other_tasks_and_states_dropped(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()
    ws.full_task("beta")
    ws.state(STATE, state_obj())
    ws.state(
        f"{T}/rpi-sessions/{DAY}/beta/beta-state.json",
        state_obj("beta", api_key="y" * 30),
    )

    # Act
    audit = ws.audit(task="alpha")

    # Assert
    assert list(audit.tasks) == ["alpha"]
    assert [sf.rel for sf in audit.state_files] == [STATE]
    assert all(f.slug in ("alpha", None) for f in audit.findings)


def test_given_unknown_task_filter_when_audited_then_usage_error(ws: Workspace) -> None:
    # Arrange
    ws.full_task()

    # Act / Assert
    with pytest.raises(UsageError, match="no task `nope`; tasks found: alpha"):
        ws.audit(task="nope")
