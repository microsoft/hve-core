# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import subprocess
from types import SimpleNamespace

import pytest
import runtime_a11y.__main__ as cli
from runtime_a11y._errors import ScriptError


def test_emit_live_test_start_notice_uses_dot_and_repo_relative_paths(capsys) -> None:
    cli._emit_live_test_start_notice(None, 2)
    first = capsys.readouterr()
    assert first.err.splitlines() == [
        cli._LIVE_TEST_START_NOTICE,
        "Run root: . | Journey count: 2",
    ]

    cli._emit_live_test_start_notice("docs/docusaurus", 1)
    second = capsys.readouterr()
    assert second.err.splitlines() == [
        cli._LIVE_TEST_START_NOTICE,
        "Run root: .github/skills/accessibility/accessibility/docs/docusaurus "
        "| Journey count: 1",
    ]


def test_run_calibration_emits_start_and_finish_notices_for_script_error(
    mocker, capsys, tmp_path
) -> None:
    events: list[tuple[str, object]] = []
    config = {
        "baseUrl": "http://127.0.0.1:3001",
        "calibration": {"journeys": [{"id": "14399"}]},
        "visualReview": {"enabled": True},
    }
    process = SimpleNamespace()
    expected_run_root = tmp_path / "test-run-root"

    mocker.patch.object(cli, "load_validated_config", return_value=config)
    mocker.patch.object(cli, "resolve_run_root", return_value=expected_run_root)
    mocker.patch.object(
        cli, "_ensure_visual_review_server", return_value=(process, True)
    )
    mocker.patch.object(
        cli,
        "_run_calibration_session",
        side_effect=ScriptError("calibration failed", cli.EXIT_USAGE),
    )

    real_start_notice = cli._emit_live_test_start_notice
    real_finish_notice = cli._emit_live_test_finish_notice

    def capture_start(run_root, journey_count):
        events.append(("start", (run_root, journey_count)))
        return real_start_notice(run_root, journey_count)

    def capture_finish():
        events.append(("finish", None))
        return real_finish_notice()

    mocker.patch.object(cli, "_emit_live_test_start_notice", side_effect=capture_start)
    mocker.patch.object(
        cli, "_emit_live_test_finish_notice", side_effect=capture_finish
    )
    mocker.patch.object(
        cli,
        "_stop_visual_review_server",
        side_effect=lambda proc: events.append(("stop", proc)),
    )

    config_path = tmp_path / "runtime.json"
    config_path.write_text("{}", encoding="utf-8")

    exit_code = cli.main(
        [
            "run-calibration",
            "--config",
            str(config_path),
            "--base-url",
            "http://127.0.0.1:3001",
        ]
    )

    assert exit_code == cli.EXIT_USAGE
    assert events == [
        ("start", (expected_run_root, 1)),
        ("stop", process),
        ("finish", None),
    ]
    stderr = capsys.readouterr().err.splitlines()
    assert stderr[0] == cli._LIVE_TEST_START_NOTICE
    assert stderr[1].startswith("Run root: ")
    assert stderr[1].endswith(" | Journey count: 1")
    assert stderr[2] == cli._LIVE_TEST_FINISH_NOTICE
    assert stderr[-1] == "Error: calibration failed"


def test_run_calibration_emits_finish_notice_for_keyboard_interrupt(
    mocker, capsys, tmp_path
) -> None:
    events: list[tuple[str, object]] = []
    config = {
        "baseUrl": "http://127.0.0.1:3001",
        "calibration": {"journeys": [{"id": "14399"}]},
        "visualReview": {"enabled": True},
    }
    process = SimpleNamespace()
    expected_run_root = tmp_path / "test-run-root"

    mocker.patch.object(cli, "load_validated_config", return_value=config)
    mocker.patch.object(cli, "resolve_run_root", return_value=expected_run_root)
    mocker.patch.object(
        cli, "_ensure_visual_review_server", return_value=(process, True)
    )
    mocker.patch.object(
        cli,
        "_run_calibration_session",
        side_effect=KeyboardInterrupt,
    )

    real_start_notice = cli._emit_live_test_start_notice
    real_finish_notice = cli._emit_live_test_finish_notice

    def capture_start(run_root, journey_count):
        events.append(("start", (run_root, journey_count)))
        return real_start_notice(run_root, journey_count)

    def capture_finish():
        events.append(("finish", None))
        return real_finish_notice()

    mocker.patch.object(cli, "_emit_live_test_start_notice", side_effect=capture_start)
    mocker.patch.object(
        cli, "_emit_live_test_finish_notice", side_effect=capture_finish
    )
    mocker.patch.object(
        cli,
        "_stop_visual_review_server",
        side_effect=lambda proc: events.append(("stop", proc)),
    )

    config_path = tmp_path / "runtime.json"
    config_path.write_text("{}", encoding="utf-8")

    with pytest.raises(KeyboardInterrupt):
        cli.main(
            [
                "run-calibration",
                "--config",
                str(config_path),
                "--base-url",
                "http://127.0.0.1:3001",
            ]
        )

    assert events == [
        ("start", (expected_run_root, 1)),
        ("stop", process),
        ("finish", None),
    ]
    assert capsys.readouterr().err.splitlines()[2] == cli._LIVE_TEST_FINISH_NOTICE


def test_run_calibration_skips_notices_for_prerequisite_only(
    mocker, capsys, tmp_path
) -> None:
    config = {
        "baseUrl": "http://127.0.0.1:3001",
        "calibration": {"journeys": [{"id": "14399"}]},
    }
    start_calls: list[tuple[str | None, int]] = []
    finish_calls: list[tuple[()]] = []

    expected_run_root = tmp_path / "test-run-root"

    mocker.patch.object(cli, "load_validated_config", return_value=config)
    mocker.patch.object(cli, "resolve_run_root", return_value=expected_run_root)
    mocker.patch.object(
        cli,
        "_run_prerequisite_probe",
        return_value={"ok": True, "reason": "ready"},
    )
    mocker.patch.object(
        cli,
        "_emit_live_test_start_notice",
        side_effect=lambda run_root, count: start_calls.append((run_root, count)),
    )
    mocker.patch.object(
        cli,
        "_emit_live_test_finish_notice",
        side_effect=lambda: finish_calls.append(()),
    )

    config_path = tmp_path / "runtime.json"
    config_path.write_text("{}", encoding="utf-8")

    exit_code = cli.main(
        [
            "run-calibration",
            "--config",
            str(config_path),
            "--prerequisite-only",
            "--base-url",
            "http://127.0.0.1:3001",
        ]
    )

    assert exit_code == cli.EXIT_SUCCESS
    assert start_calls == []
    assert finish_calls == []
    captured = capsys.readouterr()
    assert captured.out == ""
    assert captured.err == ""


def test_run_calibration_keeps_server_reuse_without_stopping_it(
    mocker, tmp_path
) -> None:
    config = {
        "baseUrl": "http://127.0.0.1:3001",
        "calibration": {"journeys": [{"id": "14399"}]},
        "visualReview": {"enabled": True},
    }
    expected_run_root = tmp_path / "test-run-root"
    stop_calls: list[object] = []

    mocker.patch.object(cli, "load_validated_config", return_value=config)
    mocker.patch.object(cli, "resolve_run_root", return_value=expected_run_root)
    mocker.patch.object(
        cli,
        "_ensure_visual_review_server",
        return_value=(SimpleNamespace(), False),
    )
    mocker.patch.object(
        cli,
        "_run_calibration_session",
        return_value={"aggregate": {"status": "successful"}, "journeys": []},
    )
    mocker.patch.object(
        cli,
        "_stop_visual_review_server",
        side_effect=lambda proc: stop_calls.append(proc),
    )
    mocker.patch.object(cli, "_emit_live_test_start_notice")
    mocker.patch.object(cli, "_emit_live_test_finish_notice")

    config_path = tmp_path / "runtime.json"
    config_path.write_text("{}", encoding="utf-8")

    exit_code = cli.main(
        [
            "run-calibration",
            "--config",
            str(config_path),
            "--base-url",
            "http://127.0.0.1:3001",
        ]
    )

    assert exit_code == cli.EXIT_SUCCESS
    assert stop_calls == []


def test_stop_visual_review_server_uses_kill_after_timeout() -> None:
    class _Process:
        def __init__(self) -> None:
            self.terminations = 0
            self.kills = 0

        def poll(self) -> int | None:
            return None

        def terminate(self) -> None:
            self.terminations += 1

        def wait(self, timeout: float) -> None:
            raise subprocess.TimeoutExpired(cmd="npm", timeout=timeout)

        def kill(self) -> None:
            self.kills += 1

    process = _Process()

    cli._stop_visual_review_server(process)

    assert process.terminations == 1
    assert process.kills == 1


def test_visual_review_server_lease_eq_matches_tuples_and_values() -> None:
    lease = cli._VisualReviewServerLease(None, False)

    assert lease == (None, False)
    assert lease != "other"
