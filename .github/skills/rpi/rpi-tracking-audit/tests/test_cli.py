# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Command-line runs: reports, filters, single-file mode, redaction, and exit codes."""

from __future__ import annotations

import json
import runpy
import subprocess
import sys
from pathlib import Path

import pytest
from builders import DAY, T, Workspace, plan_text, review_text, state_obj
from rpi_tracking_audit import VERSION, create_parser, main
from rpi_tracking_audit._cli import (
    EXIT_ERROR,
    EXIT_FAILURE,
    EXIT_SUCCESS,
    _same_target,
)

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
TOKEN = "ghp_" + "Z" * 36
AS_OF = ["--as-of", "2026-10-25"]


def _busy_workspace(ws: Workspace) -> None:
    """Two tasks, one with defects and a credential, a legacy task, and other areas."""
    ws.full_task()
    ws.full_task(
        "beta",
        plan=plan_text("beta", tasks=(("P01-T01", True), ("P01-T02", False))),
        review=review_text("beta", decisions=(), final_outcome="pending")
        + f"\nkey: '{TOKEN}'\n",
    )
    ws.state(f"{T}/rpi-sessions/{DAY}/alpha/alpha-state.json", state_obj())
    ws.write(f"{T}/plans/{DAY}/old-plan.instructions.md", "* [x] Step 1.1: a\n")
    ws.write(f"{T}/plans/{DAY}/beta-plan-v2.md", "x")
    ws.write(f"{T}/security-plans/a.md", "x")
    ws.write("nested/.copilot-tracking/plans/x.md", "x")


def test_given_busy_workspace_when_full_report_then_every_section_rendered(
    ws: Workspace, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    _busy_workspace(ws)

    # Act
    code = main([str(ws.root), *AS_OF])

    # Assert
    out = capsys.readouterr().out
    assert code == EXIT_SUCCESS
    for heading in (
        "## Task board",
        "### Next action per task",
        "### Legacy tasks",
        "## Artifacts needing attention",
        "### High (",
        "## Remediation plan",
        "### Secrets",
        "## Inventory",
        "### Session state files",
        "### Files in RPI areas not matching the naming convention",
        "### Other tracking areas (not audited)",
        "### Nested tracking folders",
        "## Method and limits",
    ):
        assert heading in out, heading
    assert TOKEN not in out


def test_given_busy_workspace_when_brief_report_then_low_findings_rolled_up(
    ws: Workspace, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    _busy_workspace(ws)

    # Act
    main([str(ws.root), "--brief", *AS_OF])

    # Assert
    out = capsys.readouterr().out
    assert "## Inventory" not in out
    assert "| Task | State | Plan | Next action |" in out
    assert "- **LY4 File name does not match" in out


def test_given_small_max_rows_when_report_then_tables_truncated(
    ws: Workspace, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    _busy_workspace(ws)

    # Act
    main([str(ws.root), "--max-rows", "1", *AS_OF])

    # Assert
    out = capsys.readouterr().out
    assert "Use --max-rows to show more" in out
    assert "- ... and 1 more tasks" in out


def test_given_output_files_when_run_then_reports_written_and_redacted(
    ws: Workspace, tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    _busy_workspace(ws)
    md, js = tmp_path / "out" / "r.md", tmp_path / "out" / "r.json"
    md.parent.mkdir()

    # Act
    code = main([str(ws.root), "--md", str(md), "--json", str(js), *AS_OF])

    # Assert
    data = json.loads(js.read_text(encoding="utf-8"))
    assert code == EXIT_SUCCESS
    assert "Wrote" in capsys.readouterr().out
    assert TOKEN not in md.read_text(encoding="utf-8") + js.read_text(encoding="utf-8")
    assert {"board", "findings", "artifacts", "state_files", "rules"} <= set(data)
    assert data["state_files"][0]["task"] == "alpha"


def test_given_task_filter_when_run_then_only_that_task_reported(
    ws: Workspace, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    _busy_workspace(ws)
    ws.state(f"{T}/rpi-sessions/{DAY}/beta/beta-state.json", state_obj("beta"))

    # Act
    main([str(ws.root), "--task", "alpha", *AS_OF])

    # Assert
    out = capsys.readouterr().out
    board = out.split("## Task board")[1].split("## Artifacts needing attention")[0]
    assert "**alpha**" in board
    assert "beta" not in board
    assert "beta-state.json" not in out


def test_given_single_plan_file_when_run_then_cross_artifact_rules_not_evaluated(
    ws: Workspace, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    path = ws.write(f"{T}/plans/{DAY}/alpha-plan.md", plan_text())

    # Act
    code = main(["--file", str(path), *AS_OF])

    # Assert
    out = capsys.readouterr().out
    assert code == EXIT_SUCCESS
    assert "| File |" in out
    assert "single-file run; needs the other artifacts of the task" in out


def test_given_single_legacy_research_when_run_then_listed_as_legacy(
    ws: Workspace, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    path = ws.write(f"{T}/research/{DAY}/old-research.md", "# Old\n\n## Objectives\n")

    # Act
    main(["--file", str(path), *AS_OF])

    # Assert
    assert "LY9" in capsys.readouterr().out


@pytest.mark.parametrize(
    ("argv", "message"),
    [
        (["--as-of", "yesterday"], "--as-of expects YYYY-MM-DD"),
        (["--max-rows", "0"], "--max-rows must be at least 1"),
        (["--stale-days", "-1"], "--stale-days must be 0 or more"),
        (["--task", "a", "--file", "x.md"], "--task cannot be combined with --file"),
        (["--file", "missing-plan.md"], "not a file"),
        (["/definitely/not/here"], "not a folder"),
    ],
)
def test_given_invalid_arguments_when_run_then_exit_error(
    argv: list[str], message: str, capsys: pytest.CaptureFixture[str]
) -> None:
    # Act
    code = main(argv)

    # Assert
    assert code == EXIT_ERROR
    assert message in capsys.readouterr().err


@pytest.mark.parametrize(
    ("name", "message"),
    [
        ("notes.md", "--file expects a file named"),
        ("old-plan.instructions.md", "retired Task Planner format"),
    ],
)
def test_given_unsupported_file_when_run_then_exit_error(
    ws: Workspace, name: str, message: str, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    path = ws.write(f"{T}/plans/{DAY}/{name}", "x")

    # Act
    code = main(["--file", str(path)])

    # Assert
    assert code == EXIT_ERROR
    assert message in capsys.readouterr().err


def test_given_file_through_symlinked_folder_when_run_then_refused(
    ws: Workspace, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    real = ws.root / "real"
    (real / DAY).mkdir(parents=True)
    (real / DAY / "alpha-plan.md").write_text(plan_text(), encoding="utf-8")
    (ws.root / T).mkdir()
    (ws.root / T / "plans").symlink_to(real, target_is_directory=True)

    # Act
    code = main(["--file", str(ws.root / T / "plans" / DAY / "alpha-plan.md")])

    # Assert
    assert code == EXIT_ERROR
    assert "refuses a path through a symbolic link" in capsys.readouterr().err


def test_given_symlinked_file_when_run_then_refused(
    ws: Workspace, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    target = ws.write("elsewhere/alpha-plan.md", plan_text())
    link = ws.root / T / "plans" / DAY / "alpha-plan.md"
    link.parent.mkdir(parents=True)
    link.symlink_to(target)

    # Act
    code = main(["--file", str(link)])

    # Assert
    assert code == EXIT_ERROR
    assert "refuses a symbolic link" in capsys.readouterr().err


def test_given_unwritable_output_when_run_then_exit_failure(
    ws: Workspace, tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    ws.full_task()

    # Act
    code = main([str(ws.root), "--md", str(tmp_path / "no" / "such" / "dir" / "r.md")])

    # Assert
    assert code == EXIT_FAILURE
    assert "Error:" in capsys.readouterr().err


@pytest.mark.parametrize(
    ("exc", "code"), [(KeyboardInterrupt, 130), (BrokenPipeError, 1)]
)
def test_given_interrupt_when_run_then_conventional_exit_code(
    mocker, exc: type[BaseException], code: int
) -> None:
    # Arrange
    mocker.patch("rpi_tracking_audit._cli.run", side_effect=exc)
    mocker.patch("rpi_tracking_audit._cli.sys.stderr")

    # Act
    result = main(["."])

    # Assert
    assert result == code


def test_given_parser_when_created_then_version_and_defaults() -> None:
    # Act
    args = create_parser().parse_args([])

    # Assert
    assert (args.root, args.stale_days, args.max_rows, args.brief) == (
        None,
        None,
        25,
        False,
    )
    assert VERSION.count(".") == 2


def test_given_module_entry_when_run_as_path_then_main_runs(
    ws: Workspace, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    # Arrange
    monkeypatch.setattr(sys, "argv", ["rpi_tracking_audit", str(ws.root), "--brief"])

    # Act
    with pytest.raises(SystemExit) as exc:
        runpy.run_path(str(SCRIPTS / "rpi_tracking_audit"), run_name="__main__")

    # Assert
    assert exc.value.code == EXIT_SUCCESS
    assert "# HVE Core RPI tracking audit" in capsys.readouterr().out


def test_given_directory_path_when_run_in_subprocess_then_report_printed(
    ws: Workspace,
) -> None:
    # Act
    result = subprocess.run(
        [sys.executable, str(SCRIPTS / "rpi_tracking_audit"), str(ws.root), "--brief"],
        capture_output=True,
        text=True,
        check=False,
    )

    # Assert
    assert result.returncode == EXIT_SUCCESS
    assert "No RPI tasks found." in result.stdout


@pytest.mark.parametrize(
    "argv",
    [
        ["--as-of", "2026-1-5"],
        ["--as-of", ""],
        ["--md", "report.md", "--json", "./report.md"],
    ],
)
def test_given_invalid_arguments_when_run_then_exit_2(
    ws: Workspace, monkeypatch: pytest.MonkeyPatch, argv: list[str]
) -> None:
    # Arrange
    monkeypatch.chdir(ws.root)

    # Act
    code = main([str(ws.root), *argv])

    # Assert
    assert code == EXIT_ERROR
    assert not (ws.root / "report.md").exists()


@pytest.mark.parametrize("extra", [["--stale-days", "5"], ["ROOT"]])
def test_given_file_mode_with_workspace_arguments_when_run_then_exit_2(
    ws: Workspace, capsys: pytest.CaptureFixture[str], extra: list[str]
) -> None:
    # Arrange
    ws.full_task()
    plan = ws.root / T / "plans" / DAY / "alpha-plan.md"
    extra = [str(ws.root) if a == "ROOT" else a for a in extra]

    # Act
    code = main(["--file", str(plan), *extra])

    # Assert
    assert code == EXIT_ERROR
    assert "cannot be combined with" in capsys.readouterr().err


def test_given_json_report_when_written_then_schema_version_and_all_severities(
    ws: Workspace, tmp_path: Path
) -> None:
    # Arrange
    ws.full_task()
    target = tmp_path / "out" / "report.json"
    target.parent.mkdir()

    # Act
    code = main([str(ws.root), "--json", str(target), *AS_OF])

    # Assert
    report = json.loads(target.read_text(encoding="utf-8"))
    assert code == EXIT_SUCCESS
    assert report["schema_version"] == 1
    assert report["summary"] == {"high": 0, "medium": 0, "low": 0, "info": 0}


def test_given_version_flag_when_run_then_prints_the_tool_version(
    capsys: pytest.CaptureFixture[str],
) -> None:
    # Act
    with pytest.raises(SystemExit) as exc:
        main(["--version"])

    # Assert
    assert exc.value.code == 0
    assert capsys.readouterr().out.strip() == f"rpi_tracking_audit {VERSION}"


@pytest.mark.parametrize(
    ("threshold", "expected"),
    [
        (None, EXIT_SUCCESS),
        ("high", EXIT_SUCCESS),
        ("medium", EXIT_FAILURE),
        ("info", EXIT_FAILURE),
    ],
)
def test_given_fail_on_when_findings_reach_it_then_exit_1_and_report_written(
    ws: Workspace,
    tmp_path: Path,
    capsys: pytest.CaptureFixture[str],
    threshold: str | None,
    expected: int,
) -> None:
    # Arrange: one medium finding (LY1) and nothing higher
    ws.full_task()
    (ws.root / ".gitignore").write_text("node_modules/\n", encoding="utf-8")
    target = tmp_path / "report.md"
    gate = ["--fail-on", threshold] if threshold else []

    # Act
    code = main([str(ws.root), "--md", str(target), *gate, *AS_OF])

    # Assert
    assert code == expected
    assert target.read_text(encoding="utf-8").startswith(
        "# HVE Core RPI tracking audit"
    )
    assert ("--fail-on" in capsys.readouterr().err) is (expected == EXIT_FAILURE)


@pytest.mark.parametrize(
    ("first", "second"),
    [("r.md", "R.MD"), ("r.md", "r.md."), ("r.md", "r.md "), ("r.md", "r.md")],
)
def test_given_two_spellings_of_one_report_name_when_compared_then_same_target(
    tmp_path: Path, first: str, second: str
) -> None:
    # Act
    result = _same_target(tmp_path / first, tmp_path / second)

    # Assert
    assert result is True


def test_given_two_report_names_when_compared_then_different_targets(
    tmp_path: Path,
) -> None:
    # Act
    result = _same_target(tmp_path / "r.md", tmp_path / "r.json")

    # Assert
    assert result is False


def test_given_locale_without_utf8_when_output_is_piped_then_report_is_utf8(
    ws: Workspace,
) -> None:
    # Arrange
    ws.write(f"{T}/plans/{DAY}/alpha-plan.md", plan_text("alpha"))
    state = state_obj("alpha")
    state["session_name"] = "\u4efb\u52a1 alpha"
    ws.state(f"{T}/rpi-sessions/{DAY}/alpha-work/alpha-state.json", state)
    env = {
        "LC_ALL": "C",
        "PYTHONCOERCECLOCALE": "0",
        "PYTHONUTF8": "0",
        "PYTHONPATH": str(Path(__file__).parents[1] / "scripts"),
        "PYTHONDONTWRITEBYTECODE": "1",
    }

    # Act
    result = subprocess.run(
        [sys.executable, "-m", "rpi_tracking_audit", str(ws.root)],
        capture_output=True,
        env=env,
        check=False,
    )

    # Assert
    assert result.returncode == EXIT_SUCCESS
    assert "\u4efb\u52a1" in result.stdout.decode("utf-8")


def test_given_caller_chose_an_encoding_when_output_is_piped_then_it_is_kept(
    ws: Workspace,
) -> None:
    # Arrange
    ws.write(f"{T}/plans/{DAY}/alpha-plan.md", plan_text("alpha"))
    state = state_obj("alpha")
    state["session_name"] = "\u4efb\u52a1 alpha"
    ws.state(f"{T}/rpi-sessions/{DAY}/alpha-work/alpha-state.json", state)
    env = {
        "PYTHONIOENCODING": "ascii",
        "PYTHONPATH": str(Path(__file__).parents[1] / "scripts"),
        "PYTHONDONTWRITEBYTECODE": "1",
    }

    # Act
    result = subprocess.run(
        [sys.executable, "-m", "rpi_tracking_audit", str(ws.root)],
        capture_output=True,
        env=env,
        check=False,
    )

    # Assert
    assert result.returncode == EXIT_SUCCESS
    assert result.stdout.isascii()
