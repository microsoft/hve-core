# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""One scenario per artifact rule: start from an accepted task and break one thing."""

from __future__ import annotations

from collections.abc import Callable

import pytest
from builders import (
    DAY,
    T,
    Workspace,
    changes_text,
    critique_text,
    details,
    plan_text,
    research_text,
    review_text,
    rules_of,
)
from rpi_tracking_audit._rules import RULES

PLAN = f"{T}/plans/{DAY}/alpha-plan.md"
CHANGES = f"{T}/changes/{DAY}/alpha-changes.md"
REVIEW = f"{T}/reviews/logs/{DAY}/alpha-review.md"
CRITIQUE = f"{T}/reviews/plans/{DAY}/alpha-plan-critique.md"
RESEARCH = f"{T}/research/{DAY}/alpha-research.md"
MARKERLESS_TASK = "#### [ ] P01-T03: No marker\n\nGoals:\n* g\n"


def _replace(ws: Workspace, rel: str, old: str, new: str) -> None:
    path = ws.root / rel
    text = path.read_text(encoding="utf-8")
    assert old in text, old
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


SCENARIOS: dict[str, Callable[[Workspace], None]] = {
    "LY1": lambda ws: (ws.root / ".gitignore").write_text(
        "node_modules/\n", encoding="utf-8"
    ),
    "LY2": lambda ws: ws.write("pkg/.copilot-tracking/plans/x.md", "x"),
    "LY3": lambda ws: ws.write(f"{T}/plans/beta-plan.md", plan_text("beta")),
    "LY4": lambda ws: ws.write(f"{T}/plans/{DAY}/beta-plan-v2.md", "x"),
    "LY5": lambda ws: ws.write(
        f"{T}/research/{DAY}/Bad_Slug-research.md", research_text("Bad_Slug")
    ),
    "LY6": lambda ws: _replace(
        ws, RESEARCH, "<!-- markdownlint-disable-file -->\n", ""
    ),
    "LY7": lambda ws: _replace(
        ws, RESEARCH, "* Research status: complete", "* See src/a.py:42"
    ),
    "LY8": lambda ws: _replace(
        ws, RESEARCH, "* Research status: complete", "* Use #file:src/a.py"
    ),
    "LY9": lambda ws: ws.write(
        f"{T}/plans/{DAY}/old-plan.instructions.md", "* [x] Step 1.1: a\n"
    ),
    "LY10": lambda ws: ws.write(f"{T}/plans/{DAY}/beta-plan.md", "# nothing here\n"),
    "PL1": lambda ws: _replace(
        ws, PLAN, "<!-- rpi:task id=P01-T02 -->", "<!-- rpi:task id=P01-T09 -->"
    ),
    "PL2": lambda ws: _replace(ws, PLAN, "<!-- rpi:task id=P01-T02 -->\n", ""),
    "PL3": lambda ws: _replace(ws, PLAN, "P01-T02: Task P01-T02", "P01-T01: Task dup"),
    "PL4": lambda ws: _replace(
        ws, PLAN, "id=P01-T02 -->\n#### [x] P01-T02", "id=P02-T02 -->\n#### [x] P02-T02"
    ),
    "PL5": lambda ws: _replace(ws, PLAN, "#### [x] P01-T02", "#### [ ] P01-T02"),
    "PL6": lambda ws: ws.write(
        CHANGES, changes_text(entries=(("P01-T01", "passed"),), completed="P01-T01")
    ),
    "PL7": lambda ws: _replace(ws, PLAN, "Details:\n* Detail.\n", ""),
    "PL8": lambda ws: _replace(
        ws, PLAN, "Dependencies:\n* none\n\nChanges in the map", "Changes in the map"
    ),
    "PL9": lambda ws: _replace(ws, PLAN, "Adds the export.", "{{summary}}"),
    "PL10": lambda ws: _replace(ws, PLAN, "## Handoff", "## Closing"),
    "PL11": lambda ws: _replace(
        ws, PLAN, "## Follow-Up Items", "## Follow-Up Items\n\n## Extra"
    ),
    "PL12": lambda ws: _replace(
        ws, PLAN, "* FR-001: The export", "* FR-002: Unused.\n* FR-001: The export"
    ),
    "PL13": lambda ws: _replace(
        ws, PLAN, "Requirements:\n* FR-001", "Requirements:\n* FR-009"
    ),
    "PL14": lambda ws: (ws.root / CRITIQUE).unlink(),
    "PL15": lambda ws: ws.write(
        PLAN, plan_text(critique_status="not run", critique_latest="not run yet")
    ),
    "PL16": lambda ws: ws.write(
        PLAN, plan_text(decisions=(("D2", "Encoding", "proposed"),))
    ),
    "PL17": lambda ws: ws.write(PLAN, plan_text(meta_slug="other")),
    "PL18": lambda ws: ws.write(PLAN, plan_text(disposed=())),
    "PL19": lambda ws: ws.write(PLAN, plan_text(readiness="Partial and Not ready")),
    "PC1": lambda ws: ws.write(CRITIQUE, critique_text(findings=("PC-001", "PC-001"))),
    "PC2": lambda ws: ws.write(CRITIQUE, critique_text(verdict="maybe")),
    "PC3": lambda ws: ws.write(
        CRITIQUE, critique_text(plan_ref=f"{T}/plans/{DAY}/gone-plan.md")
    ),
    "PC4": lambda ws: ws.write(CRITIQUE, critique_text(critique_type="follow-up")),
    "PC5": lambda ws: ws.write(CRITIQUE, critique_text(execution="sort of")),
    "PC6": lambda ws: ws.write(
        CRITIQUE, critique_text(execution="started", verdict="")
    ),
    "CH1": lambda ws: ws.write(
        CHANGES, changes_text(completed="P01-T01, P01-T02, P03-T01")
    ),
    "CH2": lambda ws: _replace(ws, PLAN, "#### [x] P01-T02", "#### [ ] P01-T02"),
    "CH3": lambda ws: ws.write(CHANGES, changes_text(status="done")),
    "CH4": lambda ws: ws.write(
        PLAN,
        plan_text(tasks=(("P01-T01", True), ("P01-T02", True), ("P01-T03", False))),
    ),
    "CH5": lambda ws: ws.write(
        CHANGES, changes_text(entries=(("P01-T01", "passed"), ("P01-T02", "")))
    ),
    "CH6": lambda ws: ws.write(
        CHANGES, changes_text(plan_ref="[plan](../../plans/2026-01-01/x-plan.md)")
    ),
    "CH7": lambda ws: ws.write(CHANGES, changes_text(alignment="pending-decision")),
    "CH8": lambda ws: ws.write(
        CHANGES, changes_text(blockers=("Waiting on API keys",))
    ),
    "CH9": lambda ws: ws.write(
        CHANGES, changes_text(blockers=("Waiting",), review_readiness="ready")
    ),
    "CH10": lambda ws: ws.write(
        CHANGES, changes_text(validation_rows=(("`npm test`", "Failed"),))
    ),
    "RV1": lambda ws: ws.write(
        REVIEW,
        review_text().replace(
            "<!-- rpi:review id=RV-001 -->", "<!-- rpi:review id=RV-009 -->"
        ),
    ),
    "RV2": lambda ws: ws.write(
        REVIEW, review_text(findings=(("RV-001", "Low", "somewhere"),))
    ),
    "RV3": lambda ws: ws.write(REVIEW, review_text(outcome="fine")),
    "RV4": lambda ws: ws.write(REVIEW, review_text(decisions=())),
    "RV5": lambda ws: ws.write(
        REVIEW, review_text(changes_ref=f"{T}/changes/{DAY}/gone-changes.md")
    ),
    "RV6": lambda ws: ws.write(
        REVIEW,
        review_text(
            findings=(("RV-001", "High", "rpi-implement"),),
            decisions=(("RD-001", "RV-001", "deferred", "rpi-implement"),),
        ),
    ),
    "RV7": lambda ws: ws.write(
        REVIEW, review_text(final_outcome="pending parent decision")
    ),
    "RV8": lambda ws: ws.write(
        REVIEW,
        review_text(execution="{{x}}", outcome="{{y}}", record_execution="started"),
    ),
    "RS1": lambda ws: ws.write(RESEARCH, research_text(readiness="soon")),
    "RS2": lambda ws: ws.write(RESEARCH, research_text(cited="C1 and C7")),
    "RS3": lambda ws: ws.write(RESEARCH, research_text(disposition="done")),
    "RS4": lambda ws: ws.write(RESEARCH, research_text(readiness="Not ready")),
    "TK1": lambda ws: (ws.root / PLAN).unlink(),
    "TK2": lambda ws: (ws.root / CHANGES).unlink(),
    "TK3": lambda ws: (ws.root / PLAN).unlink(),
    "TK4": lambda ws: ws.write(CHANGES, changes_text(task_id="alpha-2")),
    "TK5": lambda ws: ws.write(f"{T}/plans/2026-10-21/alpha-plan.md", plan_text()),
    "TK10": lambda ws: ws.write(
        f"{T}/research/{DAY}/beta-research.md", research_text("beta")
    ),
    "HY1": lambda ws: _replace(
        ws, RESEARCH, "* Research status: complete", "* token: 'ghp_" + "a" * 36 + "'"
    ),
    "HY2": lambda ws: ws.write(f"{T}/plans/{DAY}/notes.txt", "x"),
}


def test_given_accepted_task_when_audited_then_no_findings_and_state_accepted(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()

    # Act
    audit = ws.audit()

    # Assert
    assert audit.findings == []
    assert audit.board[0]["state"] == "accepted"


@pytest.mark.parametrize("rule", sorted(SCENARIOS))
def test_given_one_defect_when_audited_then_rule_reported(
    ws: Workspace, rule: str
) -> None:
    # Arrange
    ws.full_task()
    SCENARIOS[rule](ws)

    # Act
    audit = ws.audit()

    # Assert
    assert rule in rules_of(audit), [(f.rule, f.detail) for f in audit.findings]


def test_given_rule_table_when_listed_then_every_artifact_rule_has_a_scenario() -> None:
    # Arrange
    elsewhere = {
        "TK6",
        "TK7",
        "TK8",
        "TK9",
        "TK11",
        "TK12",
        "TK13",
        "TK14",
    }  # see test_state.py

    # Act
    missing = set(RULES) - set(SCENARIOS) - elsewhere

    # Assert
    assert missing == set()


def test_given_slug_over_sixty_characters_when_audited_then_ly5_names_length(
    ws: Workspace,
) -> None:
    # Arrange
    slug = "a" * 61
    ws.write(f"{T}/research/{DAY}/{slug}-research.md", research_text(slug))

    # Act
    audit = ws.audit()

    # Assert
    assert any("61 characters" in d for d in details(audit, "LY5"))


def test_given_started_critique_when_audited_then_pc2_and_pl18_are_not_reported(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(
        critique=critique_text(execution="started", verdict="", findings=("PC-002",))
    )

    # Act
    audit = ws.audit()

    # Assert
    assert {"PC6"} <= rules_of(audit)
    assert not {"PC2", "PL18"} & rules_of(audit)


def test_given_started_review_when_audited_then_undecided_findings_are_not_rv4(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(
        review=review_text(
            execution="", outcome="", decisions=(), record_execution="started"
        )
    )

    # Act
    audit = ws.audit()

    # Assert
    assert "RV8" in rules_of(audit)
    assert not {"RV3", "RV4"} & rules_of(audit)


def test_given_superseded_review_when_audited_then_old_findings_drop_to_info(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(review=review_text(decisions=()))
    ws.write(f"{T}/reviews/logs/{DAY}/alpha-review-2.md", review_text())

    # Act
    audit = ws.audit()

    # Assert
    rv4 = [f for f in audit.findings if f.rule == "RV4"]
    assert rv4 and all(f.severity == "info" and "superseded" in f.detail for f in rv4)


def test_given_credential_in_superseded_review_when_audited_then_hy1_stays_high(
    ws: Workspace,
) -> None:
    # Arrange
    secret = "AKIA" + "B" * 16
    ws.full_task(review=review_text() + f"\nkey {secret}\n")
    ws.write(f"{T}/reviews/logs/{DAY}/alpha-review-2.md", review_text())

    # Act
    audit = ws.audit()

    # Assert
    hy1 = [f for f in audit.findings if f.rule == "HY1"]
    assert hy1 and hy1[0].severity == "high"


def test_given_symlinked_tracking_root_when_audited_then_nothing_is_read(
    ws: Workspace,
) -> None:
    # Arrange
    real = ws.root / "elsewhere"
    real.mkdir()
    (ws.root / T).symlink_to(real, target_is_directory=True)

    # Act
    audit = ws.audit()

    # Assert
    assert T in audit.symlinks
    assert "PL1" in audit.not_evaluated


def test_given_no_tracking_folder_when_audited_then_rules_are_not_evaluated(
    ws: Workspace,
) -> None:
    # Act
    audit = ws.audit(stale_days=0)

    # Assert
    assert audit.not_evaluated["TK6"] == "--stale-days 0"
    assert "no .copilot-tracking/" in audit.not_evaluated["PL1"]


def test_given_missing_gitignore_when_audited_then_ly1_says_so(ws: Workspace) -> None:
    # Arrange
    (ws.root / ".gitignore").unlink()
    ws.full_task()

    # Act
    audit = ws.audit()

    # Assert
    assert any("no .gitignore at the root" in d for d in details(audit, "LY1"))


def test_given_research_in_legacy_format_when_audited_then_listed_as_legacy(
    ws: Workspace,
) -> None:
    # Arrange
    ws.write(f"{T}/research/{DAY}/old-research.md", "# Old\n\n## Objectives\n\n* a\n")

    # Act
    audit = ws.audit()

    # Assert
    assert "old" in audit.legacy_tasks
    assert "LY9" in rules_of(audit)


def test_given_other_areas_when_audited_then_counted_not_audited(ws: Workspace) -> None:
    # Arrange
    ws.write(f"{T}/security-plans/a.md", "x")
    ws.write(f"{T}/reviews/code-reviews/b.md", "x")
    ws.write(f"{T}/loose.md", "x")

    # Act
    audit = ws.audit()

    # Assert
    assert audit.other_areas == {
        "security-plans": 1,
        "reviews/code-reviews": 1,
        "(files at the tracking root)": 1,
    }
