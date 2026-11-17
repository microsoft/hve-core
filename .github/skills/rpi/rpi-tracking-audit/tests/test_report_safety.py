# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Report safety: escaping, report paths, time bounds, state, and credentials."""

from __future__ import annotations

import json
import os
import stat
import sys
import time
from datetime import date

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
    state_obj,
)
from rpi_tracking_audit import main
from rpi_tracking_audit._audit import Audit
from rpi_tracking_audit._cli import EXIT_ERROR, EXIT_FAILURE, EXIT_SUCCESS
from rpi_tracking_audit._discovery import classify_file
from rpi_tracking_audit._markdown import (
    _CELL_SEP,
    escape_inline,
    real_bullets,
    redact,
    strip_controls,
    vocab_match,
)
from rpi_tracking_audit._models import decision_kind
from rpi_tracking_audit._render import render_markdown, to_json
from rpi_tracking_audit._rules import PLAN_READINESS

PLAN = f"{T}/plans/{DAY}/alpha-plan.md"
CHANGES = f"{T}/changes/{DAY}/alpha-changes.md"
REVIEW = f"{T}/reviews/logs/{DAY}/alpha-review.md"
HIGH = (("RV-001", "High", "rpi-implement"),)
POSIX = pytest.mark.skipif(sys.platform == "win32", reason="needs POSIX permissions")
# a quadratic pass over these inputs takes many times longer than this
TIME_LIMIT = 5.0


def implemented(ws: Workspace, **changes: object) -> None:
    """A task whose plan is fully checked and whose review has not started."""
    ws.full_task("alpha", changes=changes_text("alpha", **changes))
    (ws.root / REVIEW).unlink()


# ---- report text cannot become markup


@pytest.mark.parametrize(
    "payload",
    [
        "` `` ` <img src=https://example.invalid/p.png onerror=alert(1)> `",
        "` `` ` ![x](https://example.invalid/q.png) `",
        "``` `` <script>alert(1)</script> `",
    ],
)
def test_given_mixed_backtick_runs_when_escaped_then_markup_is_neutralized(
    payload: str,
) -> None:
    # Act
    result = escape_inline(payload)

    # Assert
    assert "``" not in result
    assert "<img" not in result.replace("\\<img", "")
    assert "<script" not in result.replace("\\<script", "")
    assert "![x](" not in result


def test_given_blocker_with_mixed_backticks_when_rendered_then_no_raw_html(
    ws: Workspace,
) -> None:
    # Arrange
    payload = "` `` ` <img src=https://example.invalid/p.png onerror=alert(1)> `"
    ws.write(PLAN, plan_text("alpha", tasks=(("P01-T01", False),)))
    ws.write(
        CHANGES,
        changes_text(
            "alpha", status="Partial", entries=(), completed="none", blockers=(payload,)
        ),
    )

    # Act
    report = render_markdown(ws.audit(), "0")

    # Assert
    assert "<img" not in report.replace("\\<img", "")


def test_given_bidi_overrides_when_controls_stripped_then_none_remain() -> None:
    # Arrange
    text = "plan‮gnp.exe⁦ x⁩ ‏   end"

    # Act
    result = strip_controls(text)

    # Assert
    assert not set(result) & set("‮⁦⁩‏ ")
    assert result.startswith("plan") and result.endswith("end")


# ---- a report is never written into a tracking folder


def test_given_file_outside_tracking_when_report_names_tracking_file_then_refused(
    ws: Workspace, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    plan = ws.write(PLAN, plan_text("alpha"))
    before = plan.read_text(encoding="utf-8")
    copy = ws.root / "copies" / "alpha-plan.md"
    copy.parent.mkdir()
    copy.write_text(before, encoding="utf-8")
    monkeypatch.chdir(ws.root)

    # Act
    code = main(["--file", "copies/alpha-plan.md", "--md", PLAN])

    # Assert
    assert code == EXIT_ERROR
    assert "inside a .copilot-tracking/ folder" in capsys.readouterr().err
    assert plan.read_text(encoding="utf-8") == before


@pytest.mark.parametrize(
    "target",
    [
        f"packages/app/{T}/plans/{DAY}/beta-plan.md",
        ".COPILOT-TRACKING/report.md",
        f"../other/{T}/report.md",
    ],
)
def test_given_any_tracking_folder_in_report_path_when_run_then_refused(
    ws: Workspace, monkeypatch: pytest.MonkeyPatch, target: str
) -> None:
    # Arrange
    ws.write(PLAN, plan_text("alpha"))
    nested = ws.write(f"packages/app/{T}/plans/{DAY}/beta-plan.md", plan_text("beta"))
    before = nested.read_text(encoding="utf-8")
    monkeypatch.chdir(ws.root)

    # Act
    code = main([".", "--json", target])

    # Assert
    assert code == EXIT_ERROR
    assert nested.read_text(encoding="utf-8") == before
    assert not (ws.root / ".COPILOT-TRACKING" / "report.md").exists()
    assert not (ws.root.parent / "other").exists()


def test_given_leftover_temporary_file_when_report_written_then_it_is_kept(
    ws: Workspace, tmp_path_factory: pytest.TempPathFactory
) -> None:
    # Arrange
    ws.write(PLAN, plan_text("alpha"))
    out = tmp_path_factory.mktemp("out") / "report.md"
    leftover = out.with_name(f".{out.name}.{os.getpid()}.tmp")
    leftover.write_text("not this run's file", encoding="utf-8")

    # Act
    code = main([str(ws.root), "--md", str(out)])

    # Assert
    assert code == EXIT_FAILURE
    assert leftover.read_text(encoding="utf-8") == "not this run's file"
    assert not out.exists()


@POSIX
def test_given_private_report_file_when_replaced_then_permissions_are_kept(
    ws: Workspace, tmp_path_factory: pytest.TempPathFactory
) -> None:
    # Arrange
    ws.write(PLAN, plan_text("alpha"))
    out = tmp_path_factory.mktemp("out") / "report.md"
    out.write_text("old", encoding="utf-8")
    out.chmod(0o600)

    # Act
    code = main([str(ws.root), "--md", str(out)])

    # Assert
    assert code == EXIT_SUCCESS
    assert stat.S_IMODE(out.stat().st_mode) == 0o600
    assert out.read_text(encoding="utf-8").startswith("# HVE Core RPI tracking audit")


def test_given_closed_stdout_when_run_then_no_traceback(
    ws: Workspace, monkeypatch: pytest.MonkeyPatch
) -> None:
    # Arrange
    ws.write(PLAN, plan_text("alpha"))
    monkeypatch.setattr(sys, "stdout", None)

    # Act
    code = main([str(ws.root), "--brief"])
    replacement = sys.stdout

    # Assert
    assert code == EXIT_SUCCESS
    assert replacement is not None
    replacement.close()


# ---- time grows with the input, not with its square


def timed_audit(ws: Workspace) -> float:
    start = time.perf_counter()
    render_markdown(ws.audit(), "0")
    return time.perf_counter() - start


@pytest.mark.parametrize(
    ("rel", "text"),
    [
        (
            f"{T}/plans/alpha-plan.instructions.md",
            "# Legacy\n- [x] step\n" + "\n" * 40_000 + "end\n",
        ),
        (
            PLAN,
            plan_text("alpha").replace(
                "## Functional Requirements\n",
                "## Functional Requirements\n" + "\n" * 40_000 + "text\n",
            ),
        ),
        (
            f"{T}/research/{DAY}/alpha-research.md",
            research_text("alpha") + "\n" * 40_000,
        ),
        (
            f"{T}/research/{DAY}/alpha-research.md",
            research_text("alpha") + "\n" + "password=" * 20_000 + "\n",
        ),
        (
            f"{T}/research/{DAY}/alpha-research.md",
            research_text("alpha") + "\n" + "eyJ-" * 40_000 + "\n",
        ),
        (PLAN, plan_text("alpha", critique_latest="x" * 80_000)),
    ],
    ids=[
        "blank-lines-legacy",
        "blank-lines-requirements",
        "blank-lines-evidence",
        "password-run",
        "token-run",
        "long-cell",
    ],
)
def test_given_adversarial_text_when_audited_then_time_stays_bounded(
    ws: Workspace, rel: str, text: str
) -> None:
    # Arrange
    ws.write(rel, text)

    # Act
    elapsed = timed_audit(ws)

    # Assert
    assert elapsed < TIME_LIMIT


def test_given_repeated_phase_id_when_inventory_rendered_then_task_listed_once(
    ws: Workspace,
) -> None:
    # Arrange
    second = "\n".join(
        [
            "<!-- rpi:phase id=P01 -->",
            "### [ ] P01: Build it again",
            "",
            "<!-- rpi:task id=P01-T09 -->",
            "#### [ ] P01-T09: Task P01-T09",
            "",
        ]
    )
    ws.write(PLAN, plan_text("alpha", extra_phase=second))

    # Act
    audit = ws.audit()
    report = render_markdown(audit, "0", max_rows=100)

    # Assert
    assert "PL3" in rules_of(audit)
    assert report.count("| [ ] P01-T09 |") == 1
    assert report.count("| [x] P01-T01 |") == 1


# ---- state and next action


@pytest.mark.parametrize(
    "readiness", ["ready; no blockers and nothing pending", "ready - not blocked"]
)
def test_given_negated_blocker_words_in_readiness_when_audited_then_review_is_next(
    ws: Workspace, readiness: str
) -> None:
    # Arrange
    implemented(ws, review_readiness=readiness)

    # Act
    row = ws.audit().board[0]

    # Assert
    assert row["next"].startswith("/rpi-review task=alpha")


def test_given_blocked_readiness_when_audited_then_readiness_is_cleared_first(
    ws: Workspace,
) -> None:
    # Arrange
    implemented(ws, review_readiness="not ready: blocked on the staging data")

    # Act
    row = ws.audit().board[0]

    # Assert
    assert row["next"].startswith("clear Review readiness")


def test_given_empty_and_real_bullets_when_read_then_only_real_ones_count() -> None:
    # Arrange
    section = "\n".join(
        [
            "* None",
            "* No blockers.",
            "* No open follow-up items",
            "* Not applicable",
            "* N/A",
            "* Nothing yet",
            "* None - cleared in P02",
            "* No access to the staging database",
            "* None of the integration tests can run until the credential is issued",
            "* No reviewer decisions yet",
        ]
    )

    # Act
    result = real_bullets(section)

    # Assert
    assert result == [
        "No access to the staging database",
        "None of the integration tests can run until the credential is issued",
        "No reviewer decisions yet",
    ]


def test_given_no_blockers_bullet_when_audited_then_no_blocker_is_reported(
    ws: Workspace,
) -> None:
    # Arrange
    implemented(ws, blockers=("No blockers.",))

    # Act
    audit = ws.audit()

    # Assert
    assert not {"CH8", "CH9"} & rules_of(audit)
    assert "blocker" not in audit.board[0]["next"]


@pytest.mark.parametrize("rel", [PLAN, CHANGES, REVIEW])
def test_given_single_file_run_when_board_built_then_state_is_not_derived(
    ws: Workspace, rel: str
) -> None:
    # Arrange
    ws.full_task("alpha")
    audit = Audit((ws.root / rel).parent, date(2026, 10, 25), 0, single=True)

    # Act
    audit.run_single(ws.root / rel)
    audit.finalize()
    row = audit.board[0]

    # Assert
    assert row["state"] == "not derived"
    assert "run the audit on the workspace" in row["next"]


def test_given_session_reaching_task_by_documents_when_filtered_then_state_kept(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task("alpha")
    beta_plan = f"{T}/plans/{DAY}/beta-plan.md"
    ws.write(beta_plan, plan_text("beta", tasks=(("P01-T01", False),)))
    state = state_obj("alpha", mode="manual", active_phase="Implement")
    state["documents"]["plan"].append(beta_plan)
    state_rel = f"{T}/rpi-sessions/{DAY}/alpha-work/alpha-state.json"
    ws.state(state_rel, state)

    # Act
    audit = ws.audit(task="beta")
    report = render_markdown(audit, "0")

    # Assert
    assert [sf.rel for sf in audit.state_files] == [state_rel]
    assert audit.board[0]["session"]["state_file"] == state_rel
    assert "| Session state files | 1 file |" in report


@POSIX
def test_given_folder_listed_but_not_entered_when_audited_then_report_names_it(
    ws: Workspace, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    if os.geteuid() == 0:
        pytest.skip("permissions do not bind the superuser")
    ws.write(PLAN, plan_text("alpha"))
    folder = ws.write(CHANGES, changes_text("alpha")).parent
    folder.chmod(0o600)

    # Act
    try:
        code = main([str(ws.root), "--brief"])
    finally:
        folder.chmod(0o700)
    out = capsys.readouterr().out

    # Assert
    assert code == EXIT_SUCCESS
    assert f"{T}/changes/{DAY}" in out
    assert "could not be listed" in out


def test_given_pgp_private_key_block_when_audited_then_hy1_reports_it(
    ws: Workspace,
) -> None:
    # Arrange
    block = "\n".join(
        [
            "-----BEGIN PGP PRIVATE KEY BLOCK-----",
            "",
            "lQOYBGR0" + "a" * 56,
            "=AbCd",
            "-----END PGP PRIVATE KEY BLOCK-----",
        ]
    )
    ws.write(
        f"{T}/research/{DAY}/alpha-research.md", research_text("alpha") + "\n" + block
    )

    # Act
    audit = ws.audit()

    # Assert
    assert any("private key block" in d for d in details(audit, "HY1"))
    assert "lQOYBGR0" not in render_markdown(audit, "0")


@pytest.mark.parametrize(
    ("status", "kind"),
    [
        ("accepted (was deferred in RD-001)", "accepted"),
        ("accepted; previously deferred", "accepted"),
        ("accepted; no longer deferred", "accepted"),
        ("accepted; deferred to follow-up", "deferred"),
        ("accepted deferral to the next release", "deferred"),
        ("accepted, but skipped for now", "skipped"),
        ("rejected; user chose Skip", "skipped"),
        ("rejected - skipped", "skipped"),
        ("deferred until the load test runs", "deferred"),
        ("not accepted yet", None),
    ],
)
def test_given_status_with_two_decision_words_when_read_then_open_one_decides(
    status: str, kind: str | None
) -> None:
    # Act
    result = decision_kind(status)

    # Assert
    assert result == kind


def test_given_skipped_finding_when_routed_then_a_route_is_asked_for(
    ws: Workspace,
) -> None:
    # Arrange
    review = review_text(
        "alpha",
        outcome="Defects found",
        final_outcome="Defects found",
        findings=HIGH,
        decisions=(("RD-001", "RV-001", "rejected; user chose Skip", ""),),
    )
    ws.full_task("alpha", review=review)

    # Act
    row = ws.audit().board[0]

    # Assert
    assert row["next"].startswith("choose a route for skipped RV-001")
    assert "/rpi-implement" not in row["next"]


# ---- reading what the RPI skills and the retired agents wrote


def test_given_retired_validation_file_when_classified_then_plan_suffix_dropped() -> (
    None
):
    # Act
    info = classify_file("reviews/rpi/2026-01-05/old-task-plan-001-validation.md")

    # Assert
    assert info is not None
    assert info[0] == "legacy"
    assert info[3] == "old-task"


@pytest.mark.parametrize(
    ("cell", "state"),
    [
        ("Complete, Ready - research and plan agree", "planned"),
        ("Complete and Ready", "planned"),
        ("Complete; Not ready", "planning"),
    ],
)
def test_given_readiness_cell_without_and_when_modelled_then_readiness_is_read(
    ws: Workspace, cell: str, state: str
) -> None:
    # Arrange
    ws.write(PLAN, plan_text("alpha", tasks=(("P01-T01", False),), readiness=cell))

    # Act
    row = ws.audit().board[0]

    # Assert
    assert row["state"] == state


# ---- found when the fixes above were reviewed


def tags_outside_code(text: str) -> list[str]:
    """Tag, image, and link starts a renderer could act on, inside or outside code."""
    return [
        needle
        for needle in ("<img", "<script", "<a ", "](")
        for i in range(len(text))
        if text.startswith(needle, i) and (i == 0 or text[i - 1] != "\\")
    ]


@pytest.mark.parametrize(
    "value",
    [
        "`<img src=x onerror=alert(1)>`",
        "[ `<img src=x onerror=alert(3)>` `",
        "`![i](https://example.invalid/i.png)`",
        "a ` b <script>alert(1)</script>",
        "x`y <a href=https://example.invalid>z</a>",
    ],
)
def test_given_markup_in_or_near_code_when_escaped_then_inert_everywhere(
    value: str,
) -> None:
    # Act
    result = escape_inline(value)

    # Assert
    assert tags_outside_code(result) == []
    assert result.count("`") % 2 == 0


def test_given_marker_comment_in_code_when_escaped_then_it_can_be_copied() -> None:
    # Arrange
    text = "phase `P01` heading has no `<!-- rpi:phase id=P01 -->` marker before it"

    # Act
    result = escape_inline(text)

    # Assert
    assert result == text


def test_given_slug_with_backticks_when_board_rendered_then_no_raw_tag(
    ws: Workspace,
) -> None:
    # Arrange
    slug = "`<img src=x onerror=alert(1)>`"
    state = state_obj("alpha", active_phase="Research")
    state["task_slug"] = slug
    ws.state(f"{T}/rpi-sessions/{DAY}/s/x-state.json", state)

    # Act
    report = render_markdown(ws.audit(), "0")

    # Assert
    assert tags_outside_code(report) == []


def test_given_password_beside_report_backtick_when_redacted_then_backtick_kept(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(
        "alpha",
        plan=plan_text("alpha", task_id="password=aaaaaaa"),
        changes=changes_text("alpha", task_id="<img src=x onerror=alert(1)>"),
    )

    # Act
    report = render_markdown(ws.audit(), "0")

    # Assert
    assert "TK4" in report
    assert tags_outside_code(report) == []
    assert all(line.count("`") % 2 == 0 for line in report.splitlines())


@pytest.mark.parametrize(
    ("text", "secret"),
    [
        ("Server=db;User=sa;Password=Sup3rS3cretValue", "Sup3rS3cretValue"),
        ("Server=db;Password=Sup3rS3cretValue;Encrypt=true", "Sup3rS3cretValue"),
        ("password=" + "Ab1" * 100 + ";", "Ab1Ab1Ab1"),
        ("postgres://app:Sup3rS3cretValue@db.example:5432/app", "Sup3rS3cretValue"),
        ("redis://:Sup3rS3cretValue@cache.example:6379/0", "Sup3rS3cretValue"),
        ("Data Source=db;Pwd=Sup3rS3cretValue;", "Sup3rS3cretValue"),
        (
            "cookie: x-auth-eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3In0"
            ".c2lnbmF0dXJlMTIz",
            "eyJzdWIiOiIxMjM0NTY3In0",
        ),
    ],
)
def test_given_credential_at_an_edge_when_redacted_then_value_is_gone(
    text: str, secret: str
) -> None:
    # Act
    result = redact(text)

    # Assert
    assert secret not in result
    assert "[redacted" in result


@pytest.mark.parametrize(
    "readiness",
    [
        "no blockers but pending user decision on D2",
        "not blocked but pending legal sign-off",
        "cannot proceed while blocked",
    ],
)
def test_given_contrast_after_negation_when_audited_then_readiness_blocks(
    ws: Workspace, readiness: str
) -> None:
    # Arrange
    implemented(ws, review_readiness=readiness)

    # Act
    row = ws.audit().board[0]

    # Assert
    assert row["next"].startswith("clear Review readiness")


def test_given_blocked_with_none_of_reason_when_matched_then_blocked() -> None:
    # Act
    result = vocab_match("Blocked: none of the sources exist", PLAN_READINESS)

    # Assert
    assert result == "Blocked"
    assert vocab_match("Blocked: none", PLAN_READINESS) is None


def test_given_joined_state_with_findings_when_filtered_then_findings_kept(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task("alpha")
    beta_plan = f"{T}/plans/{DAY}/beta-plan.md"
    ws.write(beta_plan, plan_text("beta", tasks=(("P01-T01", False),)))
    state = state_obj("alpha", mode="manual", active_phase="Implement")
    state["documents"]["plan"].append(beta_plan)
    state["artifact_paths"]["plan"] = f"{T}/plans/{DAY}/missing-plan.md"
    state_rel = f"{T}/rpi-sessions/{DAY}/alpha-work/alpha-state.json"
    ws.state(state_rel, state)
    full = {f.rule for f in ws.audit().findings if f.artifact == state_rel}

    # Act
    filtered = ws.audit(task="beta")
    kept = {f.rule for f in filtered.findings if f.artifact == state_rel}

    # Assert
    assert full
    assert kept == full


@pytest.mark.skipif(
    sys.platform != "darwin", reason="file ID paths are a macOS feature"
)
def test_given_file_id_path_into_tracking_when_report_written_then_refused(
    ws: Workspace,
) -> None:
    # Arrange
    folder = ws.write(PLAN, plan_text("alpha")).parent
    info = folder.stat()
    target = f"/.vol/{info.st_dev}/{info.st_ino}/report.md"

    # Act
    code = main([str(ws.root), "--md", target])

    # Assert
    assert code == EXIT_ERROR
    assert not (folder / "report.md").exists()


@pytest.mark.parametrize(
    "text",
    [
        "see https://example.invalid:8443/path@v2 for the API",
        "clone ssh://git@example.invalid:22/org/repo.git",
        "use postgres://app:<password>@db.example/app",
        "use postgres://app:$DB_PASSWORD@db.example/app",
        "postgresql://user:password@localhost:5432/mydb",
        "mysql://root:********@db:3306/app",
        "Server=x;User Id=u;Password={your_password};",
        "set ;password=required in the form; then submit",
    ],
)
def test_given_url_without_a_password_when_redacted_then_text_is_unchanged(
    text: str,
) -> None:
    # Act
    result = redact(text)

    # Assert
    assert result == text


# ---- nothing rewrites the report after its values are escaped


def test_given_credential_formed_by_a_control_character_when_rendered_then_inert(
    ws: Workspace,
) -> None:
    # Arrange
    image = "!Bearer\x01abcdefghijklmnopqrstuv42(https://example.invalid/p1.png)"
    link = "see Bearer\x01abcdefghijklmnopqrstuv42(https://example.invalid/p1-link)"
    ws.write(PLAN, plan_text("alpha", tasks=(("P01-T01", False),)))
    ws.write(
        CHANGES,
        changes_text(
            "alpha",
            status="Partial",
            entries=(),
            completed="none",
            blockers=(image, link),
        ),
    )

    # Act
    report = render_markdown(ws.audit(), "0")

    # Assert
    assert "abcdefghijklmnopqrstuv42" not in report
    assert "](https://example.invalid" not in report
    assert "[redacted bearer token" in report


def test_given_key_block_split_across_tasks_when_rendered_then_no_rows_lost(
    ws: Workspace,
) -> None:
    # Arrange
    texts = {
        "alpha": "-----BEGIN\x01PRIVATE KEY-----",
        "beta": "an ordinary blocker",
        "gamma": "-----END PRIVATE KEY-----# Injected heading",
    }
    for slug, blocker in texts.items():
        ws.write(
            f"{T}/plans/{DAY}/{slug}-plan.md",
            plan_text(slug, tasks=(("P01-T01", False),)),
        )
        ws.write(
            f"{T}/changes/{DAY}/{slug}-changes.md",
            changes_text(
                slug,
                status="Partial",
                entries=(),
                completed="none",
                blockers=(blocker,),
            ),
        )

    # Act
    report = render_markdown(ws.audit(), "0", brief=True)

    # Assert
    assert all(f"| {slug} |" in report for slug in texts)
    assert [line for line in report.splitlines() if line.startswith("# ")] == [
        "# HVE Core RPI tracking audit"
    ]


def test_given_password_before_a_pipe_when_rendered_then_cell_count_is_kept(
    ws: Workspace,
) -> None:
    # Arrange
    ws.write(PLAN, plan_text("alpha", tasks=(("P01-T01", False),)))
    ws.write(
        CHANGES,
        changes_text(
            "alpha",
            status="Partial",
            entries=(),
            completed="none",
            blockers=("note;password=aaaaaaaa1234| INJECTED CELL",),
        ),
    )

    # Act
    report = render_markdown(ws.audit(), "0")
    rows = [line for line in report.splitlines() if "INJECTED CELL" in line]

    # Assert
    assert rows
    assert all(len(_CELL_SEP.split(row)) == 7 for row in rows)
    assert "aaaaaaaa1234" not in report


def test_given_hostile_values_everywhere_when_rendered_then_nothing_left_to_redact(
    ws: Workspace,
) -> None:
    # Arrange
    token = "ghp_" + "A1b2" * 10
    ws.full_task(
        "alpha",
        plan=plan_text("alpha", task_id=f"token={token}"),
        changes=changes_text("alpha", blockers=(f"waiting on {token}",)),
        review=review_text(
            "alpha",
            findings=HIGH,
            decisions=(("RD-001", "RV-001", f"accepted by {token}", "rpi-implement"),),
        ),
    )
    state = state_obj("alpha", active_phase="Implement")
    state["session_name"] = f"Bearer\x01{token}"
    state["blockers"] = [{"id": "B1", "summary": f"key {token}", "resolution": None}]
    ws.state(f"{T}/rpi-sessions/{DAY}/alpha-work/alpha-state.json", state)

    # Act
    audit = ws.audit()
    full = render_markdown(audit, "0")
    brief = render_markdown(audit, "0", brief=True)

    # Assert
    assert token not in full + brief
    assert redact(full) == full
    assert redact(brief) == brief


@pytest.mark.parametrize(
    ("status", "kind"),
    [
        ("rejected; was skipped in the walkthrough", "skipped"),
        ("accepted by reviewer; was deferred by user", "deferred"),
        ("was accepted by the user", "accepted"),
        ("accepted - originally deferred", "accepted"),
    ],
)
def test_given_passive_was_in_status_when_read_then_it_is_not_an_earlier_state(
    status: str, kind: str
) -> None:
    # Act
    result = decision_kind(status)

    # Assert
    assert result == kind


def test_given_none_with_a_caveat_when_read_then_bullet_is_real() -> None:
    # Arrange
    section = "\n".join(
        [
            "* None, except the staging credential is missing",
            "* None - but P03 is blocked by the missing credential",
            "* None; waiting on legal sign-off for D2",
            "* None - all cleared in P02",
            "* None.",
        ]
    )

    # Act
    result = real_bullets(section)

    # Assert
    assert result == [
        "None, except the staging credential is missing",
        "None - but P03 is blocked by the missing credential",
        "None; waiting on legal sign-off for D2",
    ]


def test_given_readiness_that_names_what_is_pending_when_audited_then_blocked(
    ws: Workspace,
) -> None:
    # Arrange
    implemented(
        ws, review_readiness="cannot be ready without the pending decision on D2"
    )

    # Act
    row = ws.audit().board[0]

    # Assert
    assert row["next"].startswith("clear Review readiness")


def test_given_token_split_by_invisible_character_when_redacted_then_gone() -> None:
    # Arrange
    token = "ghp_" + "A1b2C3d4E5f6" * 3
    split = token[:4] + "\u200e" + token[4:20] + "\u200b" + token[20:]

    # Act
    result = escape_inline(f"waiting on {split}")

    # Assert
    assert token[4:] not in result
    assert "[redacted GitHub token]" in result


# ---- found by the independent pass on the fixes above


def test_given_nested_folder_named_like_markup_when_rendered_then_no_new_block(
    ws: Workspace,
) -> None:
    # Arrange
    ws.write(PLAN, plan_text("alpha"))
    for name in ("# Injected heading", "[x]: http:", "> quote", "1. item"):
        ws.write(f"{name}/evil.example/{T}/plans/{DAY}/beta-plan.md", plan_text("beta"))

    # Act
    report = render_markdown(ws.audit(), "0")
    lines = report.splitlines()

    # Assert
    assert [line for line in lines if line.startswith("# ")] == [
        "# HVE Core RPI tracking audit"
    ]
    assert not [line for line in lines if line.startswith(("- [x]:", "- >", "- 1."))]
    assert "| Folder |" in report


@pytest.mark.parametrize(
    ("text", "secret"),
    [
        ("postgres://app:S3cr3t$Pass99@db.example/app", "S3cr3t$Pass99"),
        ("postgres://app:S3cr3t:Pass99@db.example/app", "S3cr3t:Pass99"),
        ("Server=db;Password=Zx9K|q7Lm2Vt4;", "q7Lm2Vt4"),
        ("Server=db;Password=$Zx9Kq7Lm2Vt4;", "Zx9Kq7Lm2Vt4"),
        ("host=db user=app password=Zx9Kq7Lm2Vt4Rb8 dbname=x", "Zx9Kq7Lm2Vt4Rb8"),
        ("Server=db; Password = Zx9Kq7Lm2Vt4Rb8;", "Zx9Kq7Lm2Vt4Rb8"),
        ("* DB password: Sup3rS3cretPw!x", "Sup3rS3cretPw"),
        ("[Server=db;Pwd=a1I2wgGc8uiEedMV](other)", "a1I2wgGc8uiEedMV"),
        (
            "https://Zx9Kq7Lm2Vt4Rb8Zx9Kq7Lm2Vt4Rb8@github.com/o/r.git",
            "Zx9Kq7Lm2Vt4Rb8",
        ),
        ("postgres:__app:Zx9Kq7Lm2Vt4Rb8@db.example", "Zx9Kq7Lm2Vt4Rb8"),
        ("ghp_" + "A1b2C3d4E5f6" * 3 + "_backup", "A1b2C3d4E5f6A1b2"),
        ("GITHUB_ghp_" + "A1b2C3d4E5f6" * 3, "A1b2C3d4E5f6A1b2"),
        (
            "Bearer Zx9Kq7Lm2Vt4Rb8Zx9Kq7Lm2V/Bearer Qw8Er7Ty6Ui5Op4As3Df2Gh1",
            "Qw8Er7Ty6Ui5Op4As3Df2Gh1",
        ),
        (
            "eyJhbGciOiJub25lIn0.eyJzdWIiOiIxMjM0NTY3ODkwIn0.",
            "eyJzdWIiOiIxMjM0NTY3ODkwIn0",
        ),
        (
            "Bearer Zx9Kq7Lm2Vt4Rb8Zx9Kq7Lm2VBearer Qw8Er7Ty6Ui5Op4As3Df2Gh1",
            "Qw8Er7Ty6Ui5Op4As3Df2Gh1",
        ),
        (
            "AKIAIOSFODNN7EXAMPLEBearer Qw8Er7Ty6Ui5Op4As3Df2Gh1",
            "AKIAIOSFODNN7EXAMPLE",
        ),
    ],
)
def test_given_real_credential_in_an_uncommon_form_when_redacted_then_gone(
    text: str, secret: str
) -> None:
    # Act
    result = redact(text)

    # Assert
    assert secret not in result
    assert "[redacted" in result


@pytest.mark.parametrize(
    "text",
    [
        "https://USERNAME:PERSONAL_ACCESS_TOKEN@github.com/org/repo.git",
        "http://localhost:8080?email=test@example.com",
        "user=input(); password=getpass.getpass()",
        "return;password=hash(password);",
        "cd src; PWD=/home/runner/work node x.js",
        "Password=@Microsoft.KeyVault(SecretUri=https://kv.example/s/x);",
        "postgres://postgres:postgres@localhost:5432/app",
        "Authorization: Bearer YOUR_ACCESS_TOKEN_GOES_HERE",
        "Bearer authentication-scheme-is-required",
        "the Bearer /api/v1/users/list/all/items endpoint",
        "see docs/eyJhbGciOiJIUzI1NiJ9.example-file-name.another-part-here",
        "Password: must be at least twelve characters",
    ],
)
def test_given_ordinary_text_near_a_credential_word_when_redacted_then_unchanged(
    text: str,
) -> None:
    # Act
    result = redact(text)

    # Assert
    assert result == text


@pytest.mark.parametrize(
    "final",
    [
        "Awaiting parent decision (assessed: Conformant)",
        "Not yet decided (assessed Conformant)",
        "TBD - reviewer proposes Conformant",
        "Conformant proposed; no parent decision yet, still pending",
        "Conformant (reviewer's proposal, not yet confirmed by the user)",
        "Not Conformant",
    ],
)
def test_given_final_outcome_that_quotes_a_proposal_when_audited_then_pending(
    ws: Workspace, final: str
) -> None:
    # Arrange
    ws.full_task("alpha", review=review_text("alpha", final_outcome=final))

    # Act
    audit = ws.audit()

    # Assert
    assert audit.board[0]["state"] != "accepted"
    assert "RV7" in rules_of(audit)


@pytest.mark.parametrize(
    "final", ["Conformant", "**Conformant**", "Conformant with justified divergence"]
)
def test_given_final_outcome_that_leads_the_value_when_audited_then_accepted(
    ws: Workspace, final: str
) -> None:
    # Arrange
    ws.full_task("alpha", review=review_text("alpha", final_outcome=final))

    # Act
    row = ws.audit().board[0]

    # Assert
    assert row["state"] == "accepted"


def test_given_token_split_in_a_state_key_when_json_written_then_gone(
    ws: Workspace,
) -> None:
    # Arrange
    token = "ghp_" + "A1b2C3d4E5f6" * 3
    ws.full_task("alpha")
    state = state_obj("alpha")
    state["artifact_paths"][token[:10] + "\u200b" + token[10:]] = "x"
    state["session_name"] = "Bearer\u00a0Zx81kLmQ9pR7sT2vW4yB6nD8"
    ws.state(f"{T}/rpi-sessions/{DAY}/alpha-work/alpha-state.json", state)
    ws.write(
        f"{T}/reviews/plans/{DAY}/alpha-plan-critique.md",
        critique_text("alpha").replace(
            "## Recommended Next Action",
            "## Recommended Next Action\n\n* api_key: 9f8e7d6c5b4a3f2e1d0c",
        ),
    )

    # Act
    audit = ws.audit()
    payload = json.dumps(to_json(audit, "0"), ensure_ascii=False)
    report = render_markdown(audit, "0")

    # Assert
    assert token[4:] not in payload + report
    assert "Zx81kLmQ9pR7sT2vW4yB6nD8" not in payload + report
    assert "9f8e7d6c5b4a3f2e1d0c" not in payload + report


def test_given_clean_workspace_when_json_written_then_nothing_is_redacted(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task("alpha")
    ws.state(f"{T}/rpi-sessions/{DAY}/alpha-work/alpha-state.json", state_obj("alpha"))

    # Act
    payload = json.dumps(to_json(ws.audit(), "0"))

    # Assert
    assert "[redacted" not in payload


def test_given_caveat_after_none_when_read_then_bullet_is_real() -> None:
    # Arrange
    real = [
        "None - awaiting DBA approval of the migration",
        "None, apart from the failing integration test",
        "None - requires production credentials",
        "No sign-off on changes yet",
        "No tests for changes",
    ]
    empty = ["None - all cleared in P02", "None; resolved in RD-003", "No open issues"]

    # Act
    result = real_bullets("\n".join(f"* {item}" for item in real + empty))

    # Assert
    assert result == real


@pytest.mark.parametrize(
    ("status", "expected"),
    [
        ("Unable to complete - Blocked on staging access", "Blocked"),
        ("Failed to complete", None),
        ("Partially complete", None),
        ("Complete", "Complete"),
    ],
)
def test_given_qualified_status_word_when_matched_then_not_read_as_complete(
    status: str, expected: str | None
) -> None:
    # Act
    result = vocab_match(status, ("Complete", "Partial", "Blocked"))

    # Assert
    assert result == expected


@pytest.mark.parametrize(
    "readiness",
    [
        "No staging access so blocked",
        "Do not review yet pending legal sign-off",
        "Ready once P01-T02 is re-validated",
    ],
)
def test_given_reason_or_condition_in_readiness_when_audited_then_not_ready(
    ws: Workspace, readiness: str
) -> None:
    # Arrange
    implemented(ws, review_readiness=readiness)

    # Act
    row = ws.audit().board[0]

    # Assert
    assert row["next"].startswith("clear Review readiness")


SPLIT_TOKEN = "ghp_" + "A1b2C3d4E5f6" * 3


@pytest.mark.parametrize(
    ("text", "secret"),
    [
        (f"x {SPLIT_TOKEN[:10]}\x01{SPLIT_TOKEN[10:]} y", SPLIT_TOKEN[10:]),
        (
            f"{SPLIT_TOKEN[:8]}\x1b{SPLIT_TOKEN[8:20]}\x7f{SPLIT_TOKEN[20:]}",
            SPLIT_TOKEN[20:],
        ),
        ("DB password: hunt\x02er2hunter2 (rotate)", "er2hunter2"),
        ("Server=db;Password=Abc\x0112345xyz;Port=1", "12345xyz"),
        ("Bearer\x01Zx81kLmQ9pR7sT2vW4yB6nD8 end", "Zx81kLmQ9pR7sT2vW4yB6nD8"),
    ],
)
def test_given_credential_split_by_control_character_when_redacted_then_gone(
    text: str, secret: str
) -> None:
    # Act
    result = redact(strip_controls(text))

    # Assert
    assert secret not in result
    assert "[redacted" in result


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("alpha\x01beta \x1b[31mred\x07 done", "alpha beta  red  done"),
        ("first\x00line\nsecond\x9fline", "first line\nsecond line"),
    ],
)
def test_given_control_characters_in_ordinary_text_when_stripped_then_spaces(
    text: str, expected: str
) -> None:
    # Act
    result = strip_controls(text)

    # Assert
    assert result == expected


def test_given_token_split_by_control_character_in_files_when_audited_then_reported(
    ws: Workspace,
) -> None:
    # Arrange
    split = SPLIT_TOKEN[:12] + "\x01" + SPLIT_TOKEN[12:]
    ws.full_task("alpha")
    state = state_obj("alpha")
    state["session_name"] = f"deploy with {split}"
    ws.state(f"{T}/rpi-sessions/{DAY}/alpha-work/alpha-state.json", state)
    rel = f"{T}/reviews/plans/{DAY}/alpha-plan-critique.md"
    ws.write(
        rel,
        critique_text("alpha").replace(
            "## Recommended Next Action",
            f"## Recommended Next Action\n\n* use {split} for the deploy",
        ),
    )

    # Act
    audit = ws.audit()
    payload = json.dumps(to_json(audit, "0"), ensure_ascii=False)
    report = render_markdown(audit, "0")

    # Assert
    assert SPLIT_TOKEN[12:] not in payload + report
    assert any(f.rule == "HY1" and f.artifact == rel for f in audit.findings)
