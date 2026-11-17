# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Regression tests: report paths, session joins, and parsing."""

from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path

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
    state_obj,
)
from rpi_tracking_audit import main
from rpi_tracking_audit._cli import EXIT_ERROR, EXIT_FAILURE, EXIT_SUCCESS
from rpi_tracking_audit._discovery import state_defect
from rpi_tracking_audit._markdown import (
    Doc,
    escape_inline,
    redact,
    strip_fences_and_comments,
    vocab_match,
)
from rpi_tracking_audit._models import decision_kind
from rpi_tracking_audit._rules import OUTCOMES, VERDICTS

PLAN = f"{T}/plans/{DAY}/alpha-plan.md"
REVIEW = f"{T}/reviews/logs/{DAY}/alpha-review.md"
SESSION = f"{T}/rpi-sessions/{DAY}/alpha-work"
STATE = f"{SESSION}/alpha-state.json"
HIGH = (("RV-001", "High", "rpi-implement"),)
POSIX = pytest.mark.skipif(sys.platform == "win32", reason="needs POSIX links")


def _snapshot(ws: Workspace) -> dict[Path, bytes]:
    return {p: p.read_bytes() for p in ws.root.rglob("*") if p.is_file()}


def _board(ws: Workspace) -> dict[str, dict]:
    return {r["slug"]: r for r in ws.audit().board}


# ---- report paths


@POSIX
@pytest.mark.parametrize("case", ["upper", "linked-parent", "hard-link", "gitignore"])
def test_given_report_path_that_reaches_an_input_when_run_then_refused_and_unchanged(
    ws: Workspace, case: str, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    ws.full_task()
    if case == "upper":
        target = ws.root / T.upper() / "plans" / DAY / "alpha-plan.md"
        if not target.exists():
            pytest.skip("the file system is case-sensitive")
    elif case == "linked-parent":
        (ws.root / "lnk").symlink_to(ws.root / T / "plans" / DAY)
        target = ws.root / "lnk" / "alpha-plan.md"
    elif case == "hard-link":
        target = ws.root / "hard.md"
        os.link(ws.root / PLAN, target)
    else:
        target = ws.root / ".gitignore"
    before = _snapshot(ws)

    # Act
    code = main([str(ws.root), "--md", str(target)])

    # Assert
    assert code == EXIT_ERROR
    assert "report path" in capsys.readouterr().err
    assert _snapshot(ws) == before


def test_given_single_file_run_when_report_names_the_audited_file_then_refused(
    ws: Workspace,
) -> None:
    # Arrange
    loose = ws.write("loose/alpha-plan.md", plan_text())
    before = loose.read_bytes()

    # Act
    code = main(["--file", str(loose), "--md", str(loose)])

    # Assert
    assert code == EXIT_ERROR
    assert loose.read_bytes() == before


def test_given_second_report_that_cannot_be_written_when_run_then_no_partial_pair(
    ws: Workspace, tmp_path: Path
) -> None:
    # Arrange
    ws.full_task()
    out = tmp_path / "out"
    out.mkdir()
    existing = out / "r.md"
    existing.write_text("earlier report", encoding="utf-8")

    # Act
    code = main(
        [str(ws.root), "--md", str(existing), "--json", str(out / "nodir" / "r.json")]
    )

    # Assert
    assert code == EXIT_FAILURE
    assert existing.read_text(encoding="utf-8") == "earlier report"
    assert sorted(p.name for p in out.iterdir()) == ["r.md"]


def test_given_report_names_differing_only_by_case_in_one_folder_then_refused(
    ws: Workspace, tmp_path: Path
) -> None:
    # Act
    code = main(
        [
            str(ws.root),
            "--md",
            str(tmp_path / "Report.md"),
            "--json",
            str(tmp_path / "report.MD"),
        ]
    )

    # Assert
    assert code == EXIT_ERROR
    assert list(tmp_path.glob("*eport*")) == []


def test_given_empty_task_filter_when_run_then_exit_2(ws: Workspace) -> None:
    # Act
    code = main([str(ws.root), "--task", ""])

    # Assert
    assert code == EXIT_ERROR


@pytest.mark.parametrize("value", ['"\\ud800 work"', "1e999", "[-1e999]"])
def test_given_unwritable_value_in_state_when_reports_written_then_both_are_valid(
    ws: Workspace, tmp_path: Path, value: str
) -> None:
    # Arrange
    ws.full_task()
    text = json.dumps(state_obj()).replace('"Alpha work"', value)
    ws.write(STATE, text)
    md, js = tmp_path / "r.md", tmp_path / "r.json"

    # Act
    code = main([str(ws.root), "--md", str(md), "--json", str(js)])

    # Assert
    assert code == EXIT_SUCCESS
    assert md.read_bytes().decode("utf-8").startswith("# HVE Core RPI tracking audit")
    assert "\\ud800" not in js.read_text(encoding="utf-8")
    assert json.loads(js.read_text(encoding="utf-8"))["schema_version"] == 1


@pytest.mark.parametrize("number", ["1e999", "-1e999"])
def test_given_number_too_large_for_json_when_state_loaded_then_refused(
    number: str,
) -> None:
    # Arrange
    text = '{"task_slug": "a", "active_phase": "Plan", "artifact_paths": {}, "n": %s}'

    # Act
    state, defect = state_defect(text % number)

    # Assert
    assert state is None
    assert defect == "is not valid JSON"


def test_given_control_characters_in_a_task_name_when_error_printed_then_removed(
    ws: Workspace, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    ws.full_task()
    ws.state(
        STATE, state_obj(task_slug="be\x1b[31mta\rX", artifact_paths={}, documents={})
    )

    # Act
    code = main([str(ws.root), "--task", "nosuch"])

    # Assert
    err = capsys.readouterr().err
    assert code == EXIT_ERROR
    assert "\x1b" not in err and "\r" not in err
    assert err.count("\n") == 1


# ---- session joins


def test_given_child_state_that_reuses_parent_research_then_it_stays_its_own_task(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()
    (ws.root / REVIEW).unlink()
    parent = state_obj(mode="manual", status="active", active_phase="Implement")
    parent["artifact_paths"]["review"] = None
    parent["documents"]["review"] = []
    ws.state(STATE, parent)
    child = state_obj(
        "alpha-ui",
        status="blocked",
        blockers=[{"summary": "child needs a design decision"}],
        confirmed_decisions=[{"decision": "Review step", "status": "skip"}],
        artifact_paths={"research": f"{T}/research/{DAY}/alpha-research.md"},
        documents={"research": [f"{T}/research/{DAY}/alpha-research.md"]},
    )
    ws.state(f"{SESSION}/alpha-ui-state.json", child)

    # Act
    board = _board(ws)

    # Assert
    assert board["alpha"]["state"] == "implemented, not reviewed"
    assert "/rpi-review task=alpha" in board["alpha"]["next"]
    assert "child needs a design decision" not in board["alpha"]["next"]
    assert board["alpha-ui"]["state"] == "session only"


@pytest.mark.parametrize("folder", ["a-first", "z-last"])
def test_given_two_states_naming_one_task_then_its_own_state_governs_in_any_order(
    ws: Workspace, folder: str
) -> None:
    # Arrange
    ws.full_task()
    ws.write(f"{T}/plans/{DAY}/beta-plan.md", plan_text("beta"))
    other = state_obj("beta", status="blocked", blockers=["beta needs a decision"])
    other["artifact_paths"] = {"plan": f"{T}/plans/{DAY}/beta-plan.md"}
    other["documents"] = {"plan": [PLAN, f"{T}/plans/{DAY}/beta-plan.md"]}
    ws.state(f"{T}/rpi-sessions/{DAY}/m-beta/beta-state.json", other)
    ws.state(f"{T}/rpi-sessions/{DAY}/{folder}/alpha-state.json", state_obj())

    # Act
    audit = ws.audit()

    # Assert
    assert audit.sessions["alpha"].rel.endswith(f"{folder}/alpha-state.json")
    assert "beta needs a decision" not in _board(ws)["alpha"]["next"]


@pytest.mark.parametrize(
    "link",
    [
        {"task_id": None, "task_slug": "alpha-fix", "state_path": None},
        {"task_id": "alpha-fix", "task_slug": "alpha-fix", "state_path": ""},
    ],
)
def test_given_child_link_without_a_path_when_audited_then_matched_by_id_or_slug(
    ws: Workspace, link: dict
) -> None:
    # Arrange
    ws.full_task()
    ws.state(STATE, state_obj(child_tasks=[link]))
    ws.state(
        f"{SESSION}/alpha-fix-state.json",
        state_obj(
            "alpha-fix",
            artifact_paths={},
            documents={},
            status="active",
            parent_task={"task_id": "alpha", "task_slug": "alpha", "state_path": STATE},
        ),
    )

    # Act
    audit = ws.audit()

    # Assert
    assert "TK12" not in rules_of(audit)


def test_given_session_only_task_when_boarded_then_summary_counts_it(
    ws: Workspace, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    ws.full_task()
    ws.state(
        f"{SESSION}/alpha-fix-state.json",
        state_obj("alpha-fix", artifact_paths={}, documents={}, status="active"),
    )

    # Act
    main([str(ws.root), "--brief"])

    # Assert
    out = capsys.readouterr().out
    assert "2 tasks on the board" in out
    assert "the artifacts alone imply: none derivable" not in out


# ---- review decisions


@pytest.mark.parametrize(
    ("status", "kind"),
    [
        ("accepted", "accepted"),
        ("Rejected: duplicate", "rejected"),
        ("Skip", "skipped"),
        ("rejected; user chose Skip", "skipped"),
        ("Defer", "deferred"),
        ("deferral until Q2", "deferred"),
        ("changed", "changed"),
        ("pending acceptance", None),
        ("proposed (accept)", None),
        ("no change yet", None),
        ("not resolved", None),
        ("", None),
    ],
)
def test_given_decision_status_when_classified_then_one_reading(
    status: str, kind: str | None
) -> None:
    # Act
    result = decision_kind(status)

    # Assert
    assert result == kind


@pytest.mark.parametrize("status", ["Skip", "Defer", "skipped", "deferred"])
def test_given_high_finding_skipped_or_deferred_by_stem_when_conformant_then_rv6(
    ws: Workspace, status: str
) -> None:
    # Arrange
    ws.full_task(
        review=review_text(
            findings=HIGH, decisions=(("RD-001", "RV-001", status, "none"),)
        )
    )

    # Act
    audit = ws.audit()

    # Assert
    assert "RV6" in rules_of(audit)
    assert audit.board[0]["state"] != "accepted"


def test_given_rejection_whose_rationale_says_skipped_about_something_else_then_closed(
    ws: Workspace,
) -> None:
    # Arrange
    review = review_text(findings=HIGH).replace(
        "| RD-001 | RV-001 | user | accepted | rpi-implement | rpi-implement |",
        "| RD-001 | RV-001 | user | rejected | rpi-implement | none | user | none "
        "| none | false positive: the test is skipped on Windows by design |",
    )
    ws.full_task(review=review)

    # Act
    audit = ws.audit()

    # Assert
    assert audit.board[0]["state"] == "accepted"
    assert "RV6" not in rules_of(audit)


# ---- parsing


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        ("No findings - Pass", "Pass"),
        ("No blocking findings - Pass", "Pass"),
        ("Critique returned no result - unavailable", "unavailable"),
        ("Did not pass", None),
        ("not yet a Pass", None),
    ],
)
def test_given_clause_separated_by_a_spaced_hyphen_when_matched_then_not_negated(
    value: str, expected: str | None
) -> None:
    # Act
    result = vocab_match(value, VERDICTS)

    # Assert
    assert result == expected


def test_given_non_prefix_on_another_word_when_matched_then_entry_is_kept() -> None:
    # Act
    kept = vocab_match("non-blocking clarification", ("clarification",))
    negated = vocab_match("non conformant", OUTCOMES)

    # Assert
    assert (kept, negated) == ("clarification", None)


@pytest.mark.parametrize(
    "bullet",
    [
        "* Strip everything after `<!--` in the output.",
        "* Place `<!-- rpi:task id=P01-T02 -->` before the heading.",
    ],
)
def test_given_comment_opener_or_marker_in_inline_code_when_audited_then_no_finding(
    ws: Workspace, bullet: str
) -> None:
    # Arrange
    ws.full_task(plan=plan_text().replace("* Detail.", bullet, 1))

    # Act
    audit = ws.audit()

    # Assert
    assert audit.findings == []


def test_given_loose_marker_above_its_heading_when_audited_then_reported_once(
    ws: Workspace,
) -> None:
    # Arrange
    plan = plan_text().replace(
        "<!-- rpi:task id=P01-T02 -->", "<!-- rpi:task id = P01-T02 -->"
    )
    ws.full_task(plan=plan)

    # Act
    found = [f.rule for f in ws.audit().findings]

    # Assert
    assert found == ["PL1"]


def test_given_comment_closing_and_reopening_on_one_line_then_next_is_hidden() -> None:
    # Act
    doc = Doc("## Real\n<!-- a\nb --> <!-- c\n## Hidden\n-->\n## After")

    # Assert
    assert [title for _, title, _ in doc.headings] == ["Real", "After"]


def test_given_multi_line_comment_when_stripped_then_opener_line_is_cut() -> None:
    # Act
    result = strip_fences_and_comments("keep <!-- gone\nhidden\n--> tail\nnext")

    # Assert
    assert result == "keep \nnext"


@pytest.mark.parametrize(
    "text",
    [
        "![x](https://example.invalid/t.png)",
        "[docs](https://example.invalid/)",
        "<img src=//example.invalid/p onerror=alert(1)>",
    ],
)
def test_given_link_image_or_html_in_quoted_text_when_escaped_then_neutralized(
    text: str,
) -> None:
    # Act
    result = escape_inline(text)

    # Assert
    assert "](" not in result.replace("]\\(", "")
    assert "<img" not in result.replace("\\<img", "")


def test_given_backtick_in_a_slug_when_next_action_rendered_then_code_spans_do_not_pair(
    ws: Workspace, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    state = state_obj(
        task_slug="a`b",
        status="blocked",
        artifact_paths={},
        documents={},
        blockers=[{"summary": "`<img src=//example.invalid/p onerror=alert(1)>`"}],
    )
    ws.state(f"{SESSION}/x-state.json", state)

    # Act
    main([str(ws.root)])

    # Assert
    line = next(
        line for line in capsys.readouterr().out.split("\n") if line.startswith("- **a")
    )
    assert line.startswith("- **a'b**: ")


@pytest.mark.parametrize(
    "block",
    [
        "Proc-Type: 4,ENCRYPTED\nDEK-Info: AES-128-CBC,0A\n\nMIIEowIBAAKCAQEAx3vQmZ8s",
        "> MIIEowIBAAKCAQEAx3vQmZ8sJ0kL2pN\n> q8RtYuIoPaSdFgHjKlZxCvBnM1234",
        "MIIEowIBAAKCAQEAx3vQ-Z8sJ0kL_pN",
    ],
)
def test_given_private_key_without_end_in_other_layouts_when_redacted_then_gone(
    block: str,
) -> None:
    # Act
    result = redact("-----BEGIN RSA PRIVATE KEY-----\n" + block + "\n")

    # Assert
    assert "MIIEow" not in result
    assert result.count("\n") == block.count("\n") + 2


def test_given_pgp_private_key_block_when_redacted_then_gone() -> None:
    # Arrange
    text = (
        "-----BEGIN PGP PRIVATE KEY BLOCK-----\n\nlQOYBGXabcdEFGHijklMNOPqrstUVWX\n"
        "-----END PGP PRIVATE KEY BLOCK-----\n"
    )

    # Act
    result = redact(text)

    # Assert
    assert "lQOYBG" not in result


def test_given_quoted_begin_and_end_around_sections_then_sections_stay() -> None:
    # Arrange
    text = "\n".join(
        [
            "The scanner flags `-----BEGIN PRIVATE KEY-----` headers.",
            "## Phase Checklist",
            "### [ ] P01: x",
            "The block ends with `-----END PRIVATE KEY-----`.",
        ]
    )

    # Act
    result = redact(text)

    # Assert
    assert "## Phase Checklist" in result and "### [ ] P01: x" in result


def test_given_many_credential_lines_when_scanned_then_time_grows_linearly(
    ws: Workspace,
) -> None:
    # Arrange
    audit = ws.audit()
    small = "AKIAABCDEFGHIJKLMNOP\n" * 20_000
    large = small * 4

    def scan(text: str, name: str) -> float:
        start = time.perf_counter()
        audit.scan_secrets(text, name, None)
        return time.perf_counter() - start

    # Act: four times the input; a quadratic scan would take sixteen times as long
    first, second = scan(small, "small.md"), scan(large, "large.md")

    # Assert
    assert second < 10 * first + 1.0
    assert len([f for f in audit.findings if f.artifact == "small.md"]) == 6


# ---- plan and changes fields


@pytest.mark.parametrize(
    "readiness", ["`ready`", "Yes, ready", "Review-ready", "READY"]
)
def test_given_ready_written_another_way_when_boarded_then_review_is_offered(
    ws: Workspace, readiness: str
) -> None:
    # Arrange
    ws.full_task(changes=changes_text(review_readiness=readiness))
    (ws.root / REVIEW).unlink()

    # Act
    row = _board(ws)["alpha"]

    # Assert
    assert row["next"].startswith("/rpi-review task=alpha")


@pytest.mark.parametrize(
    "setting",
    ["standard; the user chose not to skip the critique", "not run; never skipped"],
)
def test_given_negated_skip_in_critique_disposition_when_ready_then_pl15(
    ws: Workspace, setting: str
) -> None:
    # Arrange
    plan = plan_text(critique_status=setting, critique_latest="not run yet")
    ws.write(PLAN, plan)

    # Act
    audit = ws.audit()

    # Assert
    assert "PL15" in rules_of(audit)


@pytest.mark.parametrize(
    "cite",
    [
        "PRD-2026-004 FR-012, FR-013 (docs/prd.md)",
        "BRD-7 NFR-002 and NFR-003 (docs/brd.md)",
        "PRD-2026-004: FR-012 (docs/prd.md)",
        "[PRD-2026-004](../../docs/prd.md) FR-014",
        "prd-2026-004 FR-015",
        "PRD 2026-004 FR-016",
    ],
)
def test_given_external_requirement_citation_forms_when_audited_then_no_pl13(
    ws: Workspace, cite: str
) -> None:
    # Arrange
    ws.full_task(plan=plan_text().replace("* FR-001", f"* FR-001\n* {cite}"))

    # Act
    audit = ws.audit()

    # Assert
    assert "PL13" not in rules_of(audit)


@pytest.mark.parametrize(
    ("status", "is_open"),
    [
        ("proposed", True),
        ("needs input", True),
        ("resolved (was proposed)", False),
        ("confirmed; no longer unresolved", False),
        ("not deferred - confirmed", False),
    ],
)
def test_given_planning_decision_status_when_modeled_then_first_real_word_counts(
    ws: Workspace, status: str, is_open: bool
) -> None:
    # Arrange
    ws.write(PLAN, plan_text(decisions=(("D2", "Encoding", status),)))

    # Act
    audit = ws.audit()

    # Assert
    assert (audit.board[0]["open_decisions"] == 1) is is_open


@pytest.mark.parametrize(
    "line", ["````mermaid", "``` mermaid", "**Highlighted work:** x"]
)
def test_given_phase_diagram_written_another_way_when_audited_then_no_pl8(
    ws: Workspace, line: str
) -> None:
    # Arrange
    body = f"{line}\nflowchart LR\n````" if "mermaid" in line else line
    ws.full_task(plan=plan_text().replace("Changes in the map: the exporter.", body))

    # Act
    audit = ws.audit()

    # Assert
    assert "PL8" not in rules_of(audit)


def test_given_file_named_for_another_area_when_single_file_run_then_refused(
    ws: Workspace, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    misplaced = ws.write(f"{T}/plans/{DAY}/alpha-changes.md", changes_text())

    # Act
    code = main(["--file", str(misplaced)])

    # Assert
    assert code == EXIT_ERROR
    assert "(LY4)" in capsys.readouterr().err


def test_given_state_file_with_upper_case_extension_when_broken_then_tk14(
    ws: Workspace,
) -> None:
    # Arrange
    ws.full_task()
    ws.write(f"{SESSION}/h-state.JSON", "{not json")

    # Act
    audit = ws.audit()

    # Assert
    assert details(audit, "TK14") == ["the file is not valid JSON"]
