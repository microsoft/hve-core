# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Regression tests for review findings: input size, redaction, paths, routing."""

from __future__ import annotations

import io
import json
import os
import subprocess
import sys
import time
from pathlib import Path

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
from rpi_tracking_audit._discovery import (
    JUNCTION_TAG,
    file_mtime,
    is_link,
    resolve_ref,
    workspace_file,
)
from rpi_tracking_audit._markdown import (
    Doc,
    bullet_fields,
    labeled_blocks,
    redact,
    redact_obj,
    strip_fences_and_comments,
    vocab_match,
)
from rpi_tracking_audit._rules import VERDICTS

STATE = f"{T}/rpi-sessions/{DAY}/alpha-work/alpha-state.json"
PLAN = f"{T}/plans/{DAY}/alpha-plan.md"


@pytest.mark.parametrize(
    "line",
    [
        "# a" + " " * 50_000 + "x",
        "* a" + " " * 50_000 + "b",
        "[" * 50_000,
        "{{" * 25_000,
        "a" * 50_000,
    ],
)
def test_given_adversarial_line_when_parsed_then_linear_time(line: str) -> None:
    # Arrange
    start = time.perf_counter()

    # Act
    Doc(line + "\n" + line)
    bullet_fields(line)
    vocab_match(line, VERDICTS, strip_paths=True)
    redact(line)

    # Assert: generous for a busy runner; backtracking on these lines took minutes
    assert time.perf_counter() - start < 10.0


def test_given_heading_with_closing_hashes_when_parsed_then_text_trimmed() -> None:
    # Act
    doc = Doc("## Findings ##\n### C# notes\n#not-a-heading")

    # Assert
    assert [(lvl, t) for lvl, t, _ in doc.headings] == [
        (2, "Findings"),
        (3, "C# notes"),
    ]


@pytest.mark.parametrize(
    ("prefix", "secret"),
    [
        ("access_token=", "abc123def456ghi789jkl012mno"),
        ("clientSecret: '", "abcdefghijklmnopqrstuvwxyz0123"),
        ("AccountKey=", "abcdefghijklmnopqrstuvwxyz0123=="),
        ("Authorization: Bearer ", "abcdefghijklmnopqrstuvwxyz.0123"),
        ("", "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abcdefghijklmnopq"),
        ("", "ASIA" + "Q" * 16),
        ("client_secret=", "Yp58Q~Vf1eLs6nB2hUxXrkYmD2a7bM3cQwErTyUi"),
        ("token: ", "abcdefghij-klmnop.qrstuvwxyz0123456789"),
    ],
)
def test_given_credential_shape_when_redacted_then_value_removed(
    prefix: str, secret: str
) -> None:
    # Act
    result = redact(f"{prefix}{secret}'")

    # Assert
    assert "[redacted" in result
    assert secret[4:20] not in result


def test_given_camel_case_keys_when_redacted_then_values_and_keys_cleaned() -> None:
    # Arrange
    obj = {
        "accessToken": "a" * 30,
        "dbPassword": "b" * 12,
        "AKIA" + "E" * 16: 1,
        "path": "c" * 30,
    }

    # Act
    result = redact_obj(obj)

    # Assert
    assert result["accessToken"] == "[redacted value of accessToken]"
    assert result["dbPassword"] == "[redacted value of dbPassword]"
    assert "[redacted AWS access key]" in result
    assert result["path"] == "c" * 30


def test_given_state_with_extra_secrets_when_json_written_then_only_contract_fields(
    ws: Workspace, tmp_path: Path
) -> None:
    # Arrange
    ws.full_task()
    ws.state(STATE, state_obj(accessToken="z" * 36, notes="Bearer " + "y" * 30))
    out = tmp_path / "r.json"

    # Act
    main([str(ws.root), "--json", str(out)])

    # Assert
    text = out.read_text(encoding="utf-8")
    state = json.loads(text)["state_files"][0]["state"]
    assert "accessToken" not in state and "notes" not in state
    assert "z" * 36 not in text and "y" * 30 not in text


def test_given_over_long_link_target_when_audited_then_no_crash(ws: Workspace) -> None:
    # Arrange
    ws.full_task(changes=changes_text(plan_ref="[x](" + "a" * 300 + ".md)"))

    # Act
    audit = ws.audit()

    # Assert
    assert "CH6" in rules_of(audit)


def test_given_deeply_nested_json_when_audited_then_no_crash(ws: Workspace) -> None:
    # Arrange
    ws.full_task()
    ws.write(f"{T}/security-plans/deep.json", "[" * 200_000)
    ws.write(f"{T}/plans/{DAY}/deep.json", "[" * 200_000)

    # Act
    audit = ws.audit()

    # Assert
    assert "HY2" in rules_of(audit)


def test_given_link_outside_workspace_when_resolved_then_not_probed(
    ws: Workspace,
) -> None:
    # Arrange
    outside = ws.root.parent / "outside-plan.md"
    outside.write_text("x", encoding="utf-8")

    # Act
    result = resolve_ref(
        "[p](../../../../outside-plan.md)", ws.root / T / "changes" / DAY, ws.root
    )

    # Assert
    assert result is not None
    assert result[1] is False
    assert result[0].endswith("(outside the workspace, not checked)")


def test_given_path_through_link_when_checked_then_not_a_workspace_file(
    ws: Workspace,
) -> None:
    # Arrange
    target = ws.write("real/a.md", "x")
    (ws.root / "linked").symlink_to(target.parent, target_is_directory=True)

    # Act / Assert
    assert workspace_file(ws.root, "real/a.md") is True
    assert workspace_file(ws.root, "linked/a.md") is False
    assert workspace_file(ws.root, "../x.md") is False


def test_given_work_reusing_research_when_joined_then_newest_kind_wins(
    ws: Workspace,
) -> None:
    # Arrange
    ws.write(f"{T}/research/{DAY}/alpha-research.md", research_text())
    ws.write(
        f"{T}/plans/{DAY}/polish-plan.md",
        plan_text("polish", tasks=(("P01-T01", False),)),
    )
    st = state_obj(status="completed")
    st["artifact_paths"] = {
        "research": f"{T}/research/{DAY}/alpha-research.md",
        "plan": f"{T}/plans/{DAY}/polish-plan.md",
        "critique": None,
        "changes": None,
        "review": None,
    }
    st["documents"] = {k: [v] if v else [] for k, v in st["artifact_paths"].items()}
    ws.state(STATE, st)

    # Act
    audit = ws.audit()

    # Assert
    assert audit.state_slugs[STATE] == "polish"
    assert details(audit, "TK9") == ["status completed; unchecked: P01-T01"]


def test_given_review_path_recorded_before_record_when_audited_then_no_tk7(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()
    (ws.root / T / "reviews" / "logs" / DAY / "alpha-review.md").unlink()
    st = state_obj(active_phase="Review", status="active")
    st["documents"]["review"] = []
    ws.state(STATE, st)

    # Act
    audit = ws.audit()

    # Assert
    assert not {"TK7", "TK13"} & rules_of(audit)


def test_given_deferred_finding_when_boarded_then_next_gathers_evidence(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(
        review=review_text(
            outcome="Defects found",
            final_outcome="pending",
            findings=(("RV-001", "Low", "rpi-implement"),),
            decisions=(("RD-001", "RV-001", "deferred", "rpi-research"),),
        )
    )

    # Act
    row = ws.audit().board[0]

    # Assert
    assert "gather the evidence" in row["next"] and "deferred RV-001" in row["next"]
    assert "/rpi-research" not in row["next"]


def test_given_changes_newer_than_review_when_boarded_then_rework_noted(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(
        review=review_text(
            outcome="Defects found",
            final_outcome="Defects found",
            decisions=(("RD-001", "RV-001", "accepted", "rpi-implement"),),
        )
    )
    ws.write(f"{T}/changes/2026-10-22/alpha-changes.md", changes_text())

    # Act
    row = ws.audit().board[0]

    # Assert
    assert "the changes record is newer than the review" in row["next"]


def test_given_execution_and_readiness_both_blocked_when_modeled_then_readiness_read(
    ws: Workspace,
) -> None:
    # Arrange
    ws.write(
        PLAN,
        plan_text(tasks=(("P01-T01", False),), readiness="Blocked and Not ready: gap"),
    )

    # Act
    row = ws.audit().board[0]

    # Assert
    assert row["readiness"] == "Not ready"


def test_given_unrecorded_readiness_when_boarded_then_plan_next(ws: Workspace) -> None:
    # Arrange
    ws.write(PLAN, plan_text(tasks=(("P01-T01", False),), readiness="{{readiness}}"))

    # Act
    row = ws.audit().board[0]

    # Assert
    assert row["next"] == "/rpi-plan task=alpha (readiness not recorded)"


@pytest.mark.parametrize(
    "critique_type", ["initial (not a follow-up)", "{{initial_or_follow_up}}"]
)
def test_given_initial_critique_type_when_audited_then_no_pc4(
    ws: Workspace, critique_type: str
) -> None:
    # Arrange
    ws.full_task(critique=critique_text(critique_type=critique_type))

    # Act
    audit = ws.audit()

    # Assert
    assert "PC4" not in rules_of(audit)


def test_given_prose_mentioning_c4_model_when_audited_then_no_rs2(
    ws: Workspace,
) -> None:
    # Arrange
    text = research_text().replace(
        "### Finding one", "### Finding one\n\nThe C4 model fits."
    )
    ws.full_task(research=text)

    # Act
    audit = ws.audit()

    # Assert
    assert "RS2" not in rules_of(audit)


def test_given_phase_without_change_map_line_when_audited_then_pl8(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(plan=plan_text().replace("Changes in the map: the exporter.\n", ""))

    # Act
    audit = ws.audit()

    # Assert
    assert details(audit, "PL8") == [
        "phase `P01` has no `Changes in the map:` line or block"
    ]


def test_given_task_filter_when_other_task_has_misnamed_file_then_dropped(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()
    ws.write(f"{T}/plans/{DAY}/beta-plan-v2.md", "x")

    # Act
    audit = ws.audit(task="alpha")

    # Assert
    assert "LY4" not in rules_of(audit)
    assert audit.misnamed == []


# ---- second review: findings reproduced on template-filled workspaces


def _board(audit: Audit, slug: str = "alpha") -> dict:
    return next(r for r in audit.board if r["slug"] == slug)


def test_given_root_with_parent_segment_when_audited_then_paths_stay_in_workspace(
    ws: Workspace, tmp_path: Path
) -> None:
    # Arrange
    ws.full_task()
    ws.state(STATE, state_obj())
    (ws.root / "src").mkdir()
    out = tmp_path / "r.json"

    # Act
    main([str(ws.root / "src" / ".."), "--json", str(out)])

    # Assert
    text = out.read_text(encoding="utf-8")
    assert "outside the workspace" not in text
    assert not {"TK7", "RV5", "CH6", "PC3"} & {
        f["rule"] for f in json.loads(text)["findings"]
    }


def test_given_deferred_high_finding_when_final_conformant_then_not_accepted(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(
        review=review_text(
            outcome="Defects found",
            findings=(("RV-001", "High", "rpi-implement"),),
            decisions=(("RD-001", "RV-001", "deferred", "rpi-implement"),),
        )
    )

    # Act
    audit = ws.audit()

    # Assert
    row = _board(audit)
    assert row["state"] != "accepted"
    assert row["next"].startswith("gather the evidence")
    assert any("final outcome Conformant" in d for d in details(audit, "RV6"))


def test_given_rejected_high_finding_when_conformant_then_no_rv6(ws: Workspace) -> None:
    # Arrange
    ws.full_task(
        review=review_text(
            findings=(("RV-001", "High", "rpi-implement"),),
            decisions=(("RD-001", "RV-001", "rejected", "none"),),
        )
    )

    # Act
    audit = ws.audit()

    # Assert
    assert "RV6" not in rules_of(audit)
    assert _board(audit)["state"] == "accepted"


def test_given_negated_pending_when_final_outcome_read_then_accepted(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(review=review_text(final_outcome="Conformant; nothing is pending"))

    # Act
    audit = ws.audit()

    # Assert
    assert "RV7" not in rules_of(audit)
    assert _board(audit)["state"] == "accepted"


def test_given_fenced_comment_in_requirements_when_audited_then_blocks_complete(
    ws: Workspace,
) -> None:
    # Arrange
    plan = plan_text().replace(
        "Requirements:\n", "Requirements:\n```python\n# fixed columns\n```\n"
    )
    ws.full_task(plan=plan)

    # Act
    audit = ws.audit()

    # Assert
    assert not {"PL7", "PL12"} & rules_of(audit)


def test_given_slug_containing_skip_when_critique_unfinished_then_pl15(
    ws: Workspace,
) -> None:
    # Arrange
    slug = "skip-link-a11y"
    ws.write(
        f"{T}/plans/{DAY}/{slug}-plan.md",
        plan_text(
            slug,
            tasks=(("P01-T01", False),),
            readiness="Complete and Ready",
            critique_status="started",
            critique_latest=f"{T}/reviews/plans/{DAY}/{slug}-plan-critique.md",
        ),
    )

    # Act
    audit = ws.audit()

    # Assert
    assert "PL15" in rules_of(audit)


def test_given_started_review_skeleton_when_audited_then_no_placeholder_noise(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(
        review=review_text(
            execution="{{x}}",
            outcome="{{y}}",
            record_execution="started",
            findings=(("RV-001", "Low", "{{destination}}"),),
        )
    )

    # Act
    audit = ws.audit()

    # Assert
    assert "RV8" in rules_of(audit)
    assert not {"PL9", "RV2"} & rules_of(audit)


def test_given_started_critique_listed_late_when_state_audited_then_no_tk13(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task(critique=critique_text(execution="started"))
    state = state_obj()
    state["documents"]["critique"] = []
    ws.state(STATE, state)

    # Act
    audit = ws.audit()

    # Assert
    assert "TK13" not in rules_of(audit)


@pytest.mark.parametrize(
    ("status", "word"), [("completed", "completed"), ("active", "implemented")]
)
def test_given_review_step_skip_when_task_implemented_then_no_review_routing(
    ws: Workspace, status: str, word: str
) -> None:
    # Arrange
    ws.full_task()
    (ws.root / f"{T}/reviews/logs/{DAY}/alpha-review.md").unlink()
    state = state_obj(
        status=status,
        confirmed_decisions=[
            {
                "decision": "Review step",
                "status": "run",
                "evidence": "first task default",
            },
            {"decision": "Review step", "status": "skip", "evidence": "user request"},
        ],
    )
    state["artifact_paths"]["review"] = None
    state["documents"]["review"] = []
    ws.state(STATE, state)
    stamp = 1_700_000_000  # 2023-11-14, far past the stale threshold
    for path in (ws.root / T).rglob("*.md"):
        os.utime(path, (stamp, stamp))

    # Act
    audit = ws.audit()

    # Assert
    row = _board(audit)
    assert row["state"] == f"{word}, review skipped"
    assert "none; the Review step is `skip`" in row["next"]
    # a finished session offers nothing; an unfinished one resumes through /rpi
    assert row["next"].startswith("/rpi task=alpha") is (status != "completed")
    assert "/rpi-review" not in row["next"].split(";")[0]
    assert ("TK6" in rules_of(audit)) is (status != "completed")


def test_given_research_not_applicable_when_board_built_then_no_handoff(
    ws: Workspace,
) -> None:
    # Arrange
    ws.write(
        f"{T}/research/{DAY}/alpha-research.md",
        research_text(readiness="Not applicable: research-only audit mode"),
    )

    # Act
    row = _board(ws.audit())

    # Assert
    assert row["state"] == "researched, no handoff"
    assert row["next"].startswith("none;")


@pytest.mark.skipif(
    sys.platform == "win32" or getattr(os, "geteuid", lambda: 1)() == 0,
    reason="file modes do not block reads here",
)
def test_given_unreadable_plan_when_audited_then_ly10_names_read_error(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()
    plan = ws.root / PLAN
    plan.chmod(0)

    # Act
    try:
        audit = ws.audit()
    finally:
        plan.chmod(0o644)

    # Assert
    assert any("cannot be read" in d for d in details(audit, "LY10"))


@pytest.mark.skipif(not hasattr(os, "mkfifo"), reason="no named pipes on this platform")
def test_given_fifo_in_tracking_folder_when_audited_then_skipped(ws: Workspace) -> None:
    # Arrange
    ws.full_task()
    os.mkfifo(ws.root / f"{T}/plans/{DAY}/other-plan.md")

    # Act
    audit = ws.audit()

    # Assert
    assert audit.other_areas["(special files, not read)"] == 1


def test_given_stdout_without_unicode_when_report_printed_then_no_crash(
    ws: Workspace, monkeypatch: pytest.MonkeyPatch
) -> None:
    # Arrange
    ws.full_task(review=review_text(findings=(("RV-001", "Low", "rpi-implement"),)))
    review = ws.root / f"{T}/reviews/logs/{DAY}/alpha-review.md"
    review.write_text(
        review.read_text(encoding="utf-8").replace(
            "RV-001 [Low]:", "RV-001 [Low]: \u26a0\ufe0f"
        ),
        encoding="utf-8",
    )
    ws.write(
        f"{T}/changes/{DAY}/alpha-changes.md", changes_text(blockers=("\u5f85\u529e",))
    )
    buffer = io.BytesIO()
    monkeypatch.setattr(sys, "stdout", io.TextIOWrapper(buffer, encoding="cp1252"))

    # Act
    code = main([str(ws.root)])
    sys.stdout.flush()

    # Assert
    assert code == 0
    assert b"HVE Core RPI tracking audit" in buffer.getvalue()


def test_given_many_headings_and_findings_when_audited_then_time_stays_linear(
    ws: Workspace,
) -> None:
    # Arrange
    tasks = tuple((f"P01-T{i:02d}", True) for i in range(1, 3000))
    ws.write(PLAN, plan_text(tasks=tasks))
    state = state_obj()
    state["documents"]["research"] = [
        f"{T}/research/{DAY}/gone-{i}.md" for i in range(20_000)
    ]
    ws.state(STATE, state)

    # Act
    start = time.perf_counter()
    audit = ws.audit()
    elapsed = time.perf_counter() - start

    # Assert
    # generous for a busy runner; the quadratic version this guards took minutes
    assert len(details(audit, "TK7")) >= 20_000
    assert elapsed < 30


def test_given_secret_in_quoted_field_when_reports_written_then_both_omit_value(
    ws: Workspace, tmp_path: Path
) -> None:
    # Arrange
    secret = "Yp58Q~Vf1eLs6nB2hUxXrkYmD2a7bM3cQwErTyUi"
    ws.full_task(
        changes=changes_text(
            status="Blocked",
            blockers=(f"Deploy fails until client_secret={secret} rotates",),
        )
    )
    md, js = tmp_path / "r.md", tmp_path / "r.json"

    # Act
    main([str(ws.root), "--md", str(md), "--json", str(js)])

    # Assert
    assert "[redacted token or password assignment]" in js.read_text(encoding="utf-8")
    for out in (md, js):
        assert secret[:12] not in out.read_text(encoding="utf-8")
    assert "HY1" in md.read_text(encoding="utf-8")


SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
NESTED_STATE = (
    '{"task_slug": "alpha", "active_phase": "Plan", "artifact_paths": {}, "blockers": '
    + "[" * 1500
    + "]" * 1500
    + "}"
)


@pytest.mark.parametrize("place", [f"{T}/notes/deep.json", STATE])
def test_given_valid_deeply_nested_json_when_run_then_both_reports_are_produced(
    ws: Workspace, tmp_path: Path, capsys: pytest.CaptureFixture[str], place: str
) -> None:
    # Arrange
    ws.full_task()
    ws.write(place, NESTED_STATE)
    target = tmp_path / "report.json"

    # Act
    brief = main([str(ws.root), "--brief"])
    full = main([str(ws.root), "--json", str(target)])

    # Assert
    assert (brief, full) == (EXIT_SUCCESS, EXIT_SUCCESS)
    assert "Traceback" not in capsys.readouterr().err
    assert json.loads(target.read_text(encoding="utf-8"))["schema_version"] == 1


def test_given_nan_in_state_when_json_report_written_then_it_is_strict_json(
    ws: Workspace, tmp_path: Path
) -> None:
    # Arrange
    ws.full_task()
    text = (
        json.dumps(state_obj())
        .replace('"automatic"', "1e999")
        .replace('"completed"', "NaN")
    )
    ws.write(STATE, text)
    target = tmp_path / "report.json"

    def refuse(name: str) -> None:
        raise AssertionError(f"{name} in the JSON report")

    # Act
    code = main([str(ws.root), "--json", str(target)])

    # Assert
    report = json.loads(target.read_text(encoding="utf-8"), parse_constant=refuse)
    assert code == EXIT_SUCCESS
    assert report["invalid_state_files"] == [
        {"path": STATE, "reason": "is not valid JSON"}
    ]


@pytest.mark.parametrize(
    "work",
    [
        lambda: redact("-----BEGIN PRIVATE KEY-----\n" * 20_000),
        lambda: strip_fences_and_comments("<!-- note\n" * 40_000),
        lambda: labeled_blocks(["Goals:", "<!--" * 40_000]),
        lambda: Doc("<!-- note\n" * 40_000),
    ],
)
def test_given_unterminated_comments_or_key_blocks_when_parsed_then_time_is_linear(
    work: object,
) -> None:
    # Act
    start = time.perf_counter()
    work()  # type: ignore[operator]
    elapsed = time.perf_counter() - start

    # Assert: generous for a busy runner; the quadratic versions took 15 s or more
    assert elapsed < 10.0


@pytest.mark.parametrize(
    "target", [PLAN, STATE, f"{T}/report.md", f"{T}/new-folder/report.md"]
)
@pytest.mark.parametrize("flag", ["--md", "--json"])
def test_given_report_path_in_tracking_folder_when_run_then_refused_and_unchanged(
    ws: Workspace, capsys: pytest.CaptureFixture[str], target: str, flag: str
) -> None:
    # Arrange
    ws.full_task()
    ws.state(STATE, state_obj())
    before = {p: p.read_bytes() for p in (ws.root / T).rglob("*") if p.is_file()}

    # Act
    code = main([str(ws.root), flag, str(ws.root / target)])

    # Assert
    after = {p: p.read_bytes() for p in (ws.root / T).rglob("*") if p.is_file()}
    assert code == EXIT_ERROR
    assert "the audit writes no file there" in capsys.readouterr().err
    assert after == before


@pytest.mark.skipif(
    sys.platform == "win32", reason="symbolic links need privileges on Windows"
)
def test_given_report_path_is_a_symlink_when_run_then_refused_and_target_unchanged(
    ws: Workspace, tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    ws.full_task()
    victim = tmp_path / "victim.txt"
    victim.write_text("keep me", encoding="utf-8")
    link = ws.root / "report.md"
    link.symlink_to(victim)

    # Act
    code = main([str(ws.root), "--md", str(link)])

    # Assert
    assert code == EXIT_ERROR
    assert "symbolic link" in capsys.readouterr().err
    assert victim.read_text(encoding="utf-8") == "keep me"


def test_given_hostile_state_text_when_report_rendered_then_it_stays_inside_its_cell(
    ws: Workspace, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    ws.full_task()
    state = state_obj(
        mode="auto\r\r## INJECTED HEADING\r\r",
        session_name="n" * 100_000,
        blockers=[
            "waiting \x1b]0;TITLE\x07 <img src=https://example.invalid/p.png> A \\| COL"
        ],
    )
    ws.state(STATE, state)

    # Act
    code = main([str(ws.root)])

    # Assert
    out = capsys.readouterr().out
    assert code == EXIT_SUCCESS
    assert "\r" not in out
    assert "\x1b" not in out
    assert not any(line.startswith("## INJECTED") for line in out.split("\n"))
    assert max(len(line) for line in out.split("\n")) < 2_000
    assert "<img" not in out.replace("\\<img", "")


def test_given_credential_in_a_legacy_file_when_audited_then_hy1(ws: Workspace) -> None:
    # Arrange
    token = "ghp_" + "Q" * 36
    ws.write(f"{T}/details/{DAY}/old-details.md", f"* step\n* token: {token}\n")

    # Act
    audit = ws.audit()

    # Assert
    assert details(audit, "HY1") == ["GitHub token pattern at line 2"]


@pytest.mark.skipif(
    sys.platform == "win32" or (hasattr(os, "geteuid") and os.geteuid() == 0),
    reason="needs POSIX permissions enforced for the current user",
)
def test_given_folder_that_cannot_be_listed_when_audited_then_report_says_so(
    ws: Workspace, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    ws.full_task()
    locked = ws.root / T / "plans" / DAY
    locked.chmod(0)

    # Act
    try:
        code = main([str(ws.root), "--brief"])
    finally:
        locked.chmod(0o755)

    # Assert
    out = capsys.readouterr().out
    assert code == EXIT_SUCCESS
    assert f"Folders that could not be listed | {T}/plans/{DAY}" in out
    assert "partly evaluated" in out


def test_given_reader_that_closes_the_pipe_when_run_then_exit_1_without_a_second_error(
    ws: Workspace,
) -> None:
    # Arrange
    env = {**os.environ, "PYTHONPATH": str(SCRIPTS)}
    command = [sys.executable, "-m", "rpi_tracking_audit", str(ws.root), "--brief"]

    # Act
    proc = subprocess.Popen(
        command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env
    )
    assert proc.stdout is not None
    proc.stdout.close()  # the reader goes away before the report is written
    _, err = proc.communicate(timeout=60)

    # Assert
    assert proc.returncode == EXIT_FAILURE
    assert b"Exception ignored" not in err
    assert b"Traceback" not in err


def test_given_timestamp_outside_the_platform_range_when_read_then_no_date(
    tmp_path: Path, mocker: object
) -> None:
    # Arrange
    path = tmp_path / "a.md"
    path.write_text("x", encoding="utf-8")
    clock = mocker.patch("rpi_tracking_audit._discovery.datetime")  # type: ignore[attr-defined]
    clock.fromtimestamp.side_effect = ValueError("year 33658 is out of range")

    # Act
    result = file_mtime(path)

    # Assert
    assert result is None


def test_given_url_or_backslash_reference_when_resolved_then_no_false_missing_file(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()
    art_dir = ws.root / T / "changes" / DAY
    url = f"[plan](https://github.com/org/repo/blob/main/{PLAN})"
    windows = f"..\\..\\plans\\{DAY}\\alpha-plan.md"

    # Act
    from_url = resolve_ref(url, art_dir, ws.root)
    from_windows = resolve_ref(f"[plan]({windows})", art_dir, ws.root)

    # Assert
    assert from_url is None
    assert from_windows is not None and from_windows[1] is True


def test_given_gitignore_pattern_with_trailing_text_when_audited_then_ly1(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()
    (ws.root / ".gitignore").write_text(
        ".copilot-tracking/ # local notes\n", encoding="utf-8"
    )

    # Act
    audit = ws.audit()

    # Assert
    assert "LY1" in rules_of(audit)


def test_given_several_credentials_in_one_file_when_audited_then_each_line_is_named(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()
    lines = [f"* key {n}: AKIA{str(n) * 16}" for n in range(1, 8)]
    path = ws.root / PLAN
    path.write_text(
        path.read_text(encoding="utf-8") + "\n".join(lines) + "\n", encoding="utf-8"
    )
    first = path.read_text(encoding="utf-8").split("\n").index(lines[0]) + 1

    # Act
    found = details(ws.audit(), "HY1")

    # Assert
    assert found[:5] == [
        f"AWS access key pattern at line {first + n}" for n in range(5)
    ]
    assert found[5] == (
        f"2 more lines with a credential pattern, from line {first + 5} to line "
        f"{first + 6}"
    )


def test_given_token_inside_an_assignment_when_audited_then_one_finding_for_the_line(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()
    path = ws.root / PLAN
    path.write_text(
        path.read_text(encoding="utf-8") + f"token: {'ghp_' + 'Z' * 36}\n",
        encoding="utf-8",
    )

    # Act
    found = details(ws.audit(), "HY1")

    # Assert
    assert len(found) == 1
    assert found[0].startswith("GitHub token pattern at line ")


def test_given_directory_junction_when_checked_then_it_is_a_link(
    tmp_path: Path, mocker: object
) -> None:
    # Arrange
    folder = tmp_path / "linked"
    folder.mkdir()
    real = os.lstat(folder)
    junction = mocker.Mock(st_mode=real.st_mode, st_reparse_tag=JUNCTION_TAG)  # type: ignore[attr-defined]
    cloud_file = mocker.Mock(st_mode=real.st_mode, st_reparse_tag=0x9000001A)  # type: ignore[attr-defined]
    lstat = mocker.patch("rpi_tracking_audit._discovery.os.lstat")  # type: ignore[attr-defined]

    # Act
    lstat.return_value = junction
    as_junction = is_link(folder)
    lstat.return_value = cloud_file
    as_cloud_file = is_link(folder)
    lstat.side_effect = OSError("gone")
    as_missing = is_link(folder)

    # Assert
    assert (as_junction, as_cloud_file, as_missing) == (True, False, False)


def test_given_retired_review_path_when_single_file_run_then_refused(
    ws: Workspace, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    old = ws.write(f"{T}/reviews/{DAY}/old-review.md", review_text("old"))

    # Act
    code = main(["--file", str(old)])
    audit = ws.audit()

    # Assert
    assert code == EXIT_ERROR
    assert "retired Task Planner format" in capsys.readouterr().err
    assert [a.rel for a in audit.legacy] == [f"{T}/reviews/{DAY}/old-review.md"]
