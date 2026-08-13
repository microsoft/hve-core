# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest
import runtime_a11y.__main__ as cli
from runtime_a11y._errors import EXIT_FAILURE, EXIT_SUCCESS, EXIT_USAGE


@pytest.fixture(autouse=True)
def patch_repo_root(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setattr(cli, "_REPO_ROOT", tmp_path)
    (tmp_path / ".copilot-tracking" / "accessibility" / "local-runs").mkdir(
        parents=True,
        exist_ok=True,
    )


@pytest.fixture()
def canned_probe_document() -> dict[str, object]:
    return {
        "probeId": "probe-axe",
        "results": [
            {
                "criterionId": "1.3.1",
                "surfaceId": "web",
                "state": "default",
                "status": "pass",
                "method": "runtime-automation",
            }
        ],
    }


def _allowed_run_path(tmp_path: Path, name: str) -> Path:
    run_root = (
        tmp_path
        / ".copilot-tracking"
        / "accessibility"
        / "local-runs"
        / "2026-07-22"
        / name
    )
    run_root.mkdir(parents=True, exist_ok=True)
    return run_root


def test_resolve_repo_path_rejects_required_empty_and_uri_inputs() -> None:
    with pytest.raises(cli.ScriptError, match="required"):
        cli._resolve_repo_path(None, kind="--config")

    with pytest.raises(cli.ScriptError, match="empty"):
        cli._resolve_repo_path("   ", kind="--config")

    with pytest.raises(cli.ScriptError, match="URI"):
        cli._resolve_repo_path("file:///tmp/file", kind="--config")


def test_resolve_within_root_rejects_invalid_inputs_and_directory(
    tmp_path: Path,
) -> None:
    allowed_root = tmp_path / ".copilot-tracking" / "accessibility" / "local-runs"
    allowed_root.mkdir(parents=True, exist_ok=True)

    with pytest.raises(cli.ScriptError, match="required"):
        cli._resolve_within_root(None, allowed_root=allowed_root, kind="--out")
    with pytest.raises(cli.ScriptError, match="empty"):
        cli._resolve_within_root(" ", allowed_root=allowed_root, kind="--out")
    with pytest.raises(cli.ScriptError, match="URI"):
        cli._resolve_within_root(
            "https://example.com/file.json",
            allowed_root=allowed_root,
            kind="--out",
        )
    with pytest.raises(cli.ScriptError, match="resolve inside"):
        cli._resolve_within_root(
            tmp_path / "outside.json",
            allowed_root=allowed_root,
            kind="--out",
        )
    with pytest.raises(cli.ScriptError, match="traversal"):
        cli._resolve_within_root(
            "../escape.json",
            base_dir=allowed_root / "run",
            allowed_root=allowed_root,
            kind="--out",
        )
    nested_dir = allowed_root / "run"
    nested_dir.mkdir()
    with pytest.raises(cli.ScriptError, match="file"):
        cli._resolve_within_root(
            nested_dir,
            allowed_root=allowed_root,
            kind="--out",
        )


def test_resolve_repo_path_enforces_allowed_root_defaults_and_traversal(
    tmp_path: Path,
) -> None:
    allowed_root = tmp_path / ".copilot-tracking" / "accessibility" / "local-runs"
    allowed_root.mkdir(parents=True, exist_ok=True)
    inside = allowed_root / "2026-07-22" / "child" / "report.json"

    resolved = cli._resolve_repo_path(
        str(inside),
        kind="--out",
        allowed_root=allowed_root,
    )
    assert resolved == inside.resolve()

    with pytest.raises(cli.ScriptError, match="resolve inside"):
        cli._resolve_repo_path(
            str(tmp_path / "outside" / "report.json"),
            kind="--out",
            allowed_root=allowed_root,
        )

    with pytest.raises(cli.ScriptError):
        cli._resolve_repo_path(
            "..\\outside.json", kind="--out", allowed_root=allowed_root
        )

    local_run_path = cli._local_runs_root() / "2026-07-22" / "custom-run"
    resolved_default = cli._resolve_repo_path(str(local_run_path), kind="--run-root")
    assert resolved_default == local_run_path.resolve()


def test_resolve_output_allowed_root_and_public_path_cover_fallback_branches(
    tmp_path: Path,
) -> None:
    local_runs_root = tmp_path / ".copilot-tracking" / "accessibility" / "local-runs"
    run_root = local_runs_root / "2026-07-22" / "run"
    out_path = run_root / "output.json"
    assert cli._resolve_output_allowed_root(run_root, out_path) == run_root.resolve()
    assert (
        cli._resolve_output_allowed_root(None, None) == cli._local_runs_root().resolve()
    )

    sibling_out = local_runs_root / "2026-07-22" / "output.json"
    assert (
        cli._resolve_output_allowed_root(run_root, sibling_out)
        == (local_runs_root / "2026-07-22").resolve()
    )
    assert cli._public_path(str(tmp_path / "docs" / "readme.md")) == "docs/readme.md"
    # A path outside the repository is returned resolved. Windows binds a
    # root-relative path to the current drive, so derive the expectation
    # instead of hard-coding a drive letter.
    outside_expected = Path("/tmp/outside").resolve(strict=False).as_posix()
    assert cli._public_path("/tmp/outside") == outside_expected
    assert cli._public_path(None) is None


def test_resolve_output_allowed_root_handles_relative_and_outside_paths(
    tmp_path: Path,
) -> None:
    relative_run = Path(
        ".copilot-tracking/accessibility/local-runs/2026-07-22/relative-run"
    )
    relative_out = relative_run / "output.json"
    expected_run = (tmp_path / relative_run).resolve()
    assert cli._resolve_output_allowed_root(relative_run, relative_out) == expected_run

    outside = tmp_path / "outside" / "output.json"
    assert (
        cli._resolve_output_allowed_root(expected_run, outside)
        == cli._local_runs_root()
    )

    with pytest.raises(cli.ScriptError, match="child path"):
        cli._resolve_repo_path(cli._local_runs_root(), kind="--run-root")


def test_resolve_repo_path_accepts_relative_allowed_root_and_rejects_traversal(
    tmp_path: Path,
) -> None:
    allowed_root = Path("nested/allowed")
    resolved = cli._resolve_repo_path(
        str(allowed_root / "child" / "report.json"),
        kind="--out",
        allowed_root=allowed_root,
    )

    assert resolved == (tmp_path / allowed_root / "child" / "report.json").resolve()

    with pytest.raises(cli.ScriptError, match="traversal segments"):
        cli._resolve_repo_path(
            "nested/../nested/allowed/child/report.json",
            kind="--out",
            allowed_root=allowed_root,
        )


def test_given_script_entrypoint_when_invoked_directly_then_module_imports_work(
    tmp_path: Path,
) -> None:
    cli_path = Path(cli.__file__).resolve().parent

    completed = subprocess.run(
        [sys.executable, str(cli_path), "--help"],
        capture_output=True,
        text=True,
        cwd=tmp_path,
        check=False,
    )

    assert completed.returncode == 0, completed.stderr
    assert "usage:" in completed.stdout.lower()


def test_materialize_visual_artifact_copies_and_rejects_escape(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    run_root = tmp_path / "run-root"
    manifest_dir = tmp_path / "manifest"
    run_root.mkdir(parents=True, exist_ok=True)
    manifest_dir.mkdir(parents=True, exist_ok=True)
    artifact_path = run_root / "artifacts" / "screenshot.png"
    artifact_path.parent.mkdir(parents=True, exist_ok=True)
    artifact_path.write_bytes(b"artifact-data")
    monkeypatch.setattr(
        cli.os.path,
        "relpath",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            AssertionError("os.path.relpath must not own contained path conversion")
        ),
    )

    relative_artifact = cli._materialize_visual_review_artifact(
        "artifacts/screenshot.png",
        run_root=run_root,
        manifest_dir=manifest_dir,
    )

    assert relative_artifact == "artifacts/screenshot.png"
    copied = manifest_dir / "artifacts" / "screenshot.png"
    assert copied.read_bytes() == b"artifact-data"

    absolute_artifact = cli._materialize_visual_review_artifact(
        str(artifact_path),
        run_root=run_root,
        manifest_dir=manifest_dir,
    )
    assert absolute_artifact == "artifacts/screenshot.png"
    assert "\\" not in absolute_artifact

    with pytest.raises(cli.ScriptError, match="containment"):
        cli._materialize_visual_review_artifact(
            "../escape.png",
            run_root=run_root,
            manifest_dir=manifest_dir,
        )

    with pytest.raises(cli.ScriptError, match="relative for containment"):
        cli._materialize_visual_review_artifact(
            "https://example.com/screenshot.png",
            run_root=run_root,
            manifest_dir=manifest_dir,
        )


def test_visual_review_server_helpers_probe_and_start_handlers(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    class FakeResponse:
        def __enter__(self) -> "FakeResponse":
            return self

        def __exit__(self, exc_type, exc, tb) -> bool:
            return False

        def getcode(self) -> int:
            return 200

    def fake_urlopen(url: str, timeout: float) -> FakeResponse:
        assert url.startswith("http://127.0.0.1")
        return FakeResponse()

    monkeypatch.setattr(cli, "urlopen", fake_urlopen)
    assert cli._probe_visual_review_server("http://127.0.0.1:3000/") is True
    assert cli._probe_visual_review_server("http://example.com/") is False

    monkeypatch.setattr(cli, "_REPO_ROOT", tmp_path)
    (tmp_path / "docs" / "docusaurus").mkdir(parents=True, exist_ok=True)

    class FakeProcess:
        def poll(self) -> int | None:
            return None

        def terminate(self) -> None:
            return None

        def wait(self, timeout: int | None = None) -> None:
            return None

    # Accepts **kwargs because the caller passes platform-specific process-group
    # arguments. Pinning the signature to one platform's argument set makes this
    # fake pass on Windows and fail on Linux for a reason unrelated to the test.
    def fake_popen(
        command, cwd, stdout, stderr, stdin, text, env, **kwargs
    ) -> FakeProcess:
        assert command[0].lower().endswith("npm") or command[0].lower().endswith(
            "npm.cmd"
        )
        if sys.platform != "win32":
            assert kwargs.get("start_new_session") is True
        return FakeProcess()

    monkeypatch.setattr(cli.subprocess, "Popen", fake_popen)
    monkeypatch.setattr(cli.time, "sleep", lambda *_args, **_kwargs: None)
    monkeypatch.setattr(
        cli, "_probe_visual_review_server", lambda *_args, **_kwargs: True
    )

    process = cli._start_visual_review_server("http://127.0.0.1:3000/")
    assert isinstance(process, FakeProcess)

    monkeypatch.setattr(
        cli, "_probe_visual_review_server", lambda *_args, **_kwargs: False
    )
    monkeypatch.setattr(
        cli, "_start_visual_review_server", lambda *_args, **_kwargs: "started"
    )
    assert cli._ensure_visual_review_server("http://127.0.0.1:3000/") == (
        "started",
        True,
    )


def test_given_run_all_when_subprocess_returns_probe_data_then_aggregates_results(
    mocker, canned_probe_document: dict[str, object], tmp_path: Path
) -> None:
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        return_value=SimpleNamespace(
            returncode=0, stdout=json.dumps(canned_probe_document), stderr=""
        ),
    )
    mocker.patch.object(cli, "_NODE_MODULES", tmp_path)
    config_path = tmp_path / "a11y-runtime.config.json"
    config_path.write_text(
        '{"baseUrl": "http://127.0.0.1:3000", '
        '"surfaces": [{"id": "web", "type": "page"}], '
        '"probeScoping": [{"probe": "probe-axe", '
        '"surfaces": ["web"], "states": ["default"]}]}',
        encoding="utf-8",
    )
    out_path = (
        tmp_path
        / ".copilot-tracking"
        / "accessibility"
        / "local-runs"
        / "2026-07-22"
        / "results.json"
    )

    exit_code = cli.main(
        ["run-all", "--config", str(config_path), "--out", str(out_path)]
    )

    assert exit_code == EXIT_SUCCESS
    document = json.loads(out_path.read_text(encoding="utf-8"))
    assert document["tool"] == "runtime_a11y"
    assert document["results"][0]["criterionId"] == "1.3.1"
    assert document["results"][0]["probeId"] == "probe-axe"
    assert document["runs"][0]["probeId"] == "probe-axe"


def test_given_operational_failure_when_run_all_then_persists_quarantined_evidence(
    mocker,
    tmp_path: Path,
) -> None:
    mocker.patch.object(cli, "load_validated_config", return_value={})
    mocker.patch.object(
        cli,
        "_iter_runs",
        return_value=iter(
            [
                ("probe-axe", "web", "default"),
                ("probe-real-sr", "web", "default"),
                ("probe-contrast", "web", "default"),
            ]
        ),
    )
    run_probe = mocker.patch.object(
        cli,
        "_run_probe",
        side_effect=[
            {
                "probeId": "probe-axe",
                "results": [{"criterionId": "1.3.1", "status": "pass"}],
            },
            {
                "probeId": "probe-real-sr",
                "results": [{"criterionId": "4.1.3", "status": "candidate"}],
                "operationalFailure": {"reason": "driver state is unverified"},
                "cleanup": {"status": "attempted"},
            },
        ],
    )
    out_path = _allowed_run_path(tmp_path, "operational-failure") / "results.json"

    exit_code = cli.main(
        [
            "run-all",
            "--config",
            str(tmp_path / "runtime.json"),
            "--out",
            str(out_path),
        ]
    )

    assert exit_code == EXIT_FAILURE
    document = json.loads(out_path.read_text(encoding="utf-8"))
    assert document["quarantined"] is True
    assert document["operationalFailure"]["cleanup"] == {"status": "attempted"}
    assert [item["probeId"] for item in document["results"]] == [
        "probe-axe",
        "probe-real-sr",
    ]
    assert run_probe.call_count == 2


def test_given_calibration_run_when_run_root_override_is_provided_then_subprocess_receives_it(  # noqa: E501
    mocker,
    tmp_path: Path,
) -> None:
    captured: dict[str, object] = {}
    allowed_run_root = _allowed_run_path(tmp_path, "custom-run-root")

    def fake_run(command, capture_output, text, check, env, cwd):
        captured["env"] = env
        return SimpleNamespace(
            returncode=0,
            stdout=json.dumps(
                {
                    "tool": "runtime_a11y",
                    "command": "run-calibration",
                    "aggregate": {"status": "successful"},
                }
            ),
            stderr="",
        )

    mocker.patch("runtime_a11y.__main__.subprocess.run", side_effect=fake_run)
    mocker.patch.object(
        cli, "resolve_run_root", return_value=tmp_path / "calibration-run"
    )
    config_path = tmp_path / "runtime.json"
    config_path.write_text(
        json.dumps({"baseUrl": "http://127.0.0.1:3000"}),
        encoding="utf-8",
    )
    out_path = (
        tmp_path
        / ".copilot-tracking"
        / "accessibility"
        / "local-runs"
        / "2026-07-22"
        / "calibration.json"
    )

    exit_code = cli.main(
        [
            "run-calibration",
            "--config",
            str(config_path),
            "--out",
            str(out_path),
            "--run-root",
            str(allowed_run_root),
        ]
    )

    assert exit_code == EXIT_SUCCESS
    assert captured["env"]["RUNTIME_A11Y_RUN_ROOT"] == str(allowed_run_root)


def test_calibration_run_passes_base_url_override(
    mocker,
    tmp_path: Path,
) -> None:
    captured: dict[str, object] = {}

    def fake_run(command, capture_output, text, check, env, cwd):
        captured["env"] = env
        return SimpleNamespace(
            returncode=0,
            stdout=json.dumps(
                {
                    "tool": "runtime_a11y",
                    "command": "run-calibration",
                    "aggregate": {"status": "successful"},
                }
            ),
            stderr="",
        )

    mocker.patch("runtime_a11y.__main__.subprocess.run", side_effect=fake_run)
    mocker.patch.object(cli, "_NODE_MODULES", tmp_path)
    config_path = tmp_path / "runtime.json"
    config_path.write_text(
        json.dumps(
            {
                "baseUrl": "http://127.0.0.1:3000",
                "calibration": {"journeys": [{"id": "14399", "bugId": "14399"}]},
            }
        ),
        encoding="utf-8",
    )
    out_path = (
        tmp_path
        / ".copilot-tracking"
        / "accessibility"
        / "local-runs"
        / "2026-07-22"
        / "calibration.json"
    )

    exit_code = cli.main(
        [
            "run-calibration",
            "--config",
            str(config_path),
            "--out",
            str(out_path),
            "--base-url",
            "http://127.0.0.1:3001",
        ]
    )

    assert exit_code == EXIT_SUCCESS
    payload = json.loads(captured["env"]["RUNTIME_A11Y_CONFIG"])
    assert payload["baseUrl"] == "http://127.0.0.1:3001"
    assert captured["env"]["RUNTIME_A11Y_BASE_URL"] == "http://127.0.0.1:3001"


def test_given_calibration_run_when_prerequisite_only_then_reports_readiness(
    mocker,
    tmp_path: Path,
) -> None:
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        return_value=SimpleNamespace(stdout="", stderr=""),
    )
    config_path = tmp_path / "runtime.json"
    config_path.write_text(
        json.dumps(
            {
                "baseUrl": "http://127.0.0.1:3000",
                "calibration": {"journeys": [{"id": "14399", "bugId": "14399"}]},
            }
        ),
        encoding="utf-8",
    )
    out_path = (
        tmp_path
        / ".copilot-tracking"
        / "accessibility"
        / "local-runs"
        / "2026-07-22"
        / "calibration.json"
    )

    exit_code = cli.main(
        [
            "run-calibration",
            "--config",
            str(config_path),
            "--out",
            str(out_path),
            "--prerequisite-only",
        ]
    )

    assert exit_code == EXIT_SUCCESS
    document = json.loads(out_path.read_text(encoding="utf-8"))
    assert document["aggregate"]["status"] == "successful"
    assert document["aggregate"]["reason"] == "Calibration prerequisites are ready."


@pytest.mark.parametrize(
    "command",
    ["run-calibration", "capture-visual-review"],
)
def test_given_non_loopback_base_url_override_when_running_then_rejects(
    tmp_path: Path,
    command: str,
    capsys,
) -> None:
    # The config's own baseUrl is guarded at load time. A --base-url override
    # replaces it afterwards, so the override must re-enter the guard or the
    # single chokepoint is bypassed. Both commands exit with a usage code for
    # unrelated environment reasons, so the assertion is on the reported cause.
    config_path = tmp_path / "runtime.json"
    config_path.write_text(
        json.dumps(
            {
                "baseUrl": "http://127.0.0.1:3000",
                "calibration": {"journeys": [{"id": "search-results"}]},
                "visualReview": {
                    "enabled": True,
                    "operatorConfirmedNoPersonalData": True,
                },
            }
        ),
        encoding="utf-8",
    )

    exit_code = cli.main(
        [
            command,
            "--config",
            str(config_path),
            "--base-url",
            "http://evil.example.net",
        ]
    )

    assert exit_code == EXIT_USAGE
    stderr = capsys.readouterr().err
    assert "Refusing to probe non-loopback host 'evil.example.net'" in stderr


def test_given_no_out_flag_when_running_calibration_then_writes_into_run_root(
    mocker,
    tmp_path: Path,
) -> None:
    # Without --out the command must write the computed, containment-checked
    # run-root output file rather than emitting nothing.
    mocker.patch.object(
        cli,
        "_run_calibration_session",
        return_value={"aggregate": {"status": "successful"}},
    )
    mocker.patch.object(cli, "_emit_live_test_start_notice")
    mocker.patch.object(cli, "_emit_live_test_finish_notice")
    run_root = _allowed_run_path(tmp_path, "default-out")
    config_path = tmp_path / "runtime.json"
    config_path.write_text(
        json.dumps(
            {
                "baseUrl": "http://127.0.0.1:3000",
                "calibration": {"journeys": [{"id": "search-results"}]},
            }
        ),
        encoding="utf-8",
    )

    exit_code = cli.main(
        [
            "run-calibration",
            "--config",
            str(config_path),
            "--run-root",
            str(run_root),
        ]
    )

    assert exit_code == EXIT_SUCCESS
    written = run_root / "calibration-output.json"
    assert written.exists()
    document = json.loads(written.read_text(encoding="utf-8"))
    assert document["command"] == "run-calibration"


def test_run_calibration_emits_start_and_finish_notices_for_live_execution(
    mocker,
    tmp_path: Path,
    capsys,
) -> None:
    mocker.patch.object(
        cli,
        "_run_calibration_session",
        return_value={"aggregate": {"status": "successful"}},
    )
    mocker.patch.object(cli, "_ensure_visual_review_server", return_value=(None, False))
    mocker.patch.object(cli, "_stop_visual_review_server")
    config_path = tmp_path / "runtime.json"
    config_path.write_text(
        json.dumps(
            {
                "baseUrl": "http://127.0.0.1:3000",
                "calibration": {"journeys": [{"id": "14399", "bugId": "14399"}]},
            }
        ),
        encoding="utf-8",
    )
    out_path = _allowed_run_path(tmp_path, "live-notice") / "calibration-output.json"

    exit_code = cli.main(
        [
            "run-calibration",
            "--config",
            str(config_path),
            "--out",
            str(out_path),
        ]
    )

    assert exit_code == EXIT_SUCCESS
    captured = capsys.readouterr()
    assert captured.out == ""
    assert captured.err.splitlines()[0] == cli._LIVE_TEST_START_NOTICE
    assert captured.err.splitlines()[1].startswith("Run root: ")
    assert "Journey count: 1" in captured.err.splitlines()[1]
    assert captured.err.splitlines()[-1] == cli._LIVE_TEST_FINISH_NOTICE


def test_run_calibration_does_not_emit_live_notices_for_prerequisite_only(
    mocker,
    tmp_path: Path,
    capsys,
) -> None:
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        return_value=SimpleNamespace(stdout="", stderr=""),
    )
    config_path = tmp_path / "runtime.json"
    config_path.write_text(
        json.dumps(
            {
                "baseUrl": "http://127.0.0.1:3000",
                "calibration": {"journeys": [{"id": "14399", "bugId": "14399"}]},
            }
        ),
        encoding="utf-8",
    )
    out_path = (
        _allowed_run_path(tmp_path, "prerequisite-notice") / "calibration-output.json"
    )

    exit_code = cli.main(
        [
            "run-calibration",
            "--config",
            str(config_path),
            "--out",
            str(out_path),
            "--prerequisite-only",
        ]
    )

    assert exit_code == EXIT_SUCCESS
    captured = capsys.readouterr()
    assert captured.err == ""


@pytest.mark.parametrize("failure", [cli.ScriptError("failed"), KeyboardInterrupt()])
def test_live_notice_finishes_after_owned_cleanup_on_failure(
    mocker,
    tmp_path: Path,
    capsys,
    failure: BaseException,
) -> None:
    events: list[str] = []
    mocker.patch.object(
        cli,
        "_ensure_visual_review_server",
        return_value=(SimpleNamespace(), True),
    )
    mocker.patch.object(
        cli,
        "_stop_visual_review_server",
        side_effect=lambda _process: events.append("cleanup"),
    )
    mocker.patch.object(
        cli,
        "_emit_live_test_finish_notice",
        side_effect=lambda: events.append("finish"),
    )
    mocker.patch.object(cli, "_run_calibration_session", side_effect=failure)
    config_path = tmp_path / "runtime.json"
    config_path.write_text(
        json.dumps(
            {
                "baseUrl": "http://127.0.0.1:3000",
                "visualReview": {
                    "enabled": True,
                    "operatorConfirmedNoPersonalData": True,
                },
                "calibration": {"journeys": [{"id": "14399"}]},
            }
        ),
        encoding="utf-8",
    )
    out_path = _allowed_run_path(tmp_path, "failure-notice") / "output.json"

    if isinstance(failure, KeyboardInterrupt):
        with pytest.raises(KeyboardInterrupt):
            cli.main(
                [
                    "run-calibration",
                    "--config",
                    str(config_path),
                    "--out",
                    str(out_path),
                ]
            )
    else:
        assert (
            cli.main(
                [
                    "run-calibration",
                    "--config",
                    str(config_path),
                    "--out",
                    str(out_path),
                ]
            )
            == failure.exit_code
        )

    assert events == ["cleanup", "finish"]
    assert cli._LIVE_TEST_START_NOTICE in capsys.readouterr().err


def test_stop_owned_server_kills_after_wait_timeout(mocker) -> None:
    process = SimpleNamespace(
        poll=lambda: None,
        terminate=mocker.Mock(),
        wait=mocker.Mock(side_effect=subprocess.TimeoutExpired("server", 5)),
        kill=mocker.Mock(),
    )

    cli._stop_visual_review_server(process)

    process.terminate.assert_called_once()
    process.kill.assert_called_once()


def test_prerequisite_probe_invalid_json_falls_back_ready(
    mocker,
    tmp_path: Path,
) -> None:
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        return_value=SimpleNamespace(stdout="not-json", stderr=""),
    )
    mocker.patch.object(cli, "_NODE_MODULES", tmp_path)
    mocker.patch.object(
        cli, "resolve_run_root", return_value=tmp_path / "calibration-run"
    )
    config_path = tmp_path / "runtime.json"
    config_path.write_text(
        json.dumps({"baseUrl": "http://127.0.0.1:3000"}),
        encoding="utf-8",
    )
    out_path = (
        tmp_path
        / ".copilot-tracking"
        / "accessibility"
        / "local-runs"
        / "2026-07-22"
        / "calibration.json"
    )

    exit_code = cli.main(
        [
            "run-calibration",
            "--config",
            str(config_path),
            "--out",
            str(out_path),
            "--prerequisite-only",
        ]
    )

    assert exit_code == EXIT_SUCCESS
    document = json.loads(out_path.read_text(encoding="utf-8"))
    assert document["aggregate"]["reason"] == "Calibration prerequisites are ready."


def test_calibration_session_no_output_reports_usage_error(
    mocker,
    tmp_path: Path,
    capsys,
) -> None:
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        return_value=SimpleNamespace(stdout="", stderr=""),
    )
    mocker.patch.object(cli, "_NODE_MODULES", tmp_path)
    config_path = tmp_path / "runtime.json"
    config_path.write_text(
        json.dumps({"baseUrl": "http://127.0.0.1:3000"}),
        encoding="utf-8",
    )

    exit_code = cli.main(["run-calibration", "--config", str(config_path)])

    assert exit_code == EXIT_USAGE
    captured = capsys.readouterr()
    assert "Calibration produced no JSON output" in captured.err


def test_given_calibration_session_when_subprocess_errors_then_reports_failure(
    mocker,
    tmp_path: Path,
    capsys,
) -> None:
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        side_effect=subprocess.CalledProcessError(
            1,
            ["node"],
            stderr="calibration exploded",
        ),
    )
    mocker.patch.object(cli, "_NODE_MODULES", tmp_path)
    mocker.patch.object(
        cli, "resolve_run_root", return_value=tmp_path / "calibration-run"
    )
    config_path = tmp_path / "runtime.json"
    config_path.write_text(
        json.dumps({"baseUrl": "http://127.0.0.1:3000"}),
        encoding="utf-8",
    )

    exit_code = cli.main(["run-calibration", "--config", str(config_path)])

    assert exit_code == 1
    captured = capsys.readouterr()
    assert "calibration exploded" in captured.err


@pytest.mark.parametrize(
    "removed_flag",
    ["--nvda-only", "--retained-preflight", "--checkpoint-path"],
)
def test_run_calibration_rejects_removed_resume_flags(
    tmp_path: Path,
    removed_flag: str,
) -> None:
    config_path = tmp_path / "runtime.json"
    config_path.write_text(
        json.dumps(
            {"baseUrl": "http://127.0.0.1:3000", "calibration": {"journeys": []}}
        ),
        encoding="utf-8",
    )

    with pytest.raises(SystemExit):
        cli.main(
            [
                "run-calibration",
                "--config",
                str(config_path),
                removed_flag,
                "bundle.json",
            ]
        )


def test_main_rejects_unknown_command() -> None:
    with pytest.raises(SystemExit):
        cli.main(["unknown-command"])


def test_given_calibration_run_when_subprocess_succeeds_then_document_contains_evidence(
    mocker,
    tmp_path: Path,
) -> None:
    _allowed_run_path(tmp_path, "calibration-run")
    payload = {
        "tool": "runtime_a11y",
        "command": "run-calibration",
        "aggregate": {"status": "successful", "reason": "Calibration completed"},
        "journeys": ["14399", "14410"],
        "checkpoints": [{"journeyId": "14399", "ordinal": 0, "classification": "pass"}],
        "state": {"journeys": {}},
    }
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        return_value=SimpleNamespace(stdout=json.dumps(payload), stderr=""),
    )
    mocker.patch.object(
        cli, "resolve_run_root", return_value=tmp_path / "calibration-run"
    )
    config_path = tmp_path / "runtime.json"
    config_path.write_text(
        json.dumps(
            {
                "baseUrl": "http://127.0.0.1:3000",
                "calibration": {
                    "journeys": [
                        {"id": "14399", "bugId": "14399"},
                        {"id": "14410", "bugId": "14410"},
                    ]
                },
            }
        ),
        encoding="utf-8",
    )
    out_path = (
        tmp_path
        / ".copilot-tracking"
        / "accessibility"
        / "local-runs"
        / "2026-07-22"
        / "calibration.json"
    )

    exit_code = cli.main(
        ["run-calibration", "--config", str(config_path), "--out", str(out_path)]
    )

    assert exit_code == EXIT_SUCCESS
    document = json.loads(out_path.read_text(encoding="utf-8"))
    assert document["command"] == "run-calibration"
    assert document["aggregate"]["status"] == "successful"
    assert document["journeys"] == ["14399", "14410"]


def test_given_calibration_run_when_aggregate_is_missing_then_document_reports_unsuccessful(  # noqa: E501
    mocker,
    tmp_path: Path,
) -> None:
    _allowed_run_path(tmp_path, "calibration-run")
    payload = {
        "tool": "runtime_a11y",
        "command": "run-calibration",
        "journeys": ["14399"],
        "checkpoints": [],
        "state": {"journeys": []},
    }
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        return_value=SimpleNamespace(stdout=json.dumps(payload), stderr=""),
    )
    mocker.patch.object(
        cli, "resolve_run_root", return_value=tmp_path / "calibration-run"
    )
    config_path = tmp_path / "runtime.json"
    config_path.write_text(
        json.dumps(
            {
                "baseUrl": "http://127.0.0.1:3000",
                "calibration": {"journeys": [{"id": "14399", "bugId": "14399"}]},
            }
        ),
        encoding="utf-8",
    )
    out_path = (
        tmp_path
        / ".copilot-tracking"
        / "accessibility"
        / "local-runs"
        / "2026-07-22"
        / "calibration.json"
    )

    exit_code = cli.main(
        ["run-calibration", "--config", str(config_path), "--out", str(out_path)]
    )

    assert exit_code == EXIT_SUCCESS
    document = json.loads(out_path.read_text(encoding="utf-8"))
    assert document["aggregate"]["status"] == "unsuccessful"
    assert (
        document["aggregate"]["reason"]
        == "Calibration completed without an aggregate status."
    )


def test_repo_relative_paths_dispatch_as_absolute(
    mocker,
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured: dict[str, object] = {}
    allowed_root = tmp_path / ".copilot-tracking" / "accessibility" / "local-runs"
    allowed_root.mkdir(parents=True, exist_ok=True)
    (tmp_path / "elsewhere").mkdir(parents=True, exist_ok=True)
    monkeypatch.chdir(tmp_path / "elsewhere")

    def fake_run(command, capture_output, text, check, env, cwd):
        captured["env"] = env
        return SimpleNamespace(
            returncode=0,
            stdout=json.dumps(
                {
                    "tool": "runtime_a11y",
                    "command": "run-calibration",
                    "aggregate": {"status": "successful"},
                }
            ),
            stderr="",
        )

    mocker.patch("runtime_a11y.__main__.subprocess.run", side_effect=fake_run)
    mocker.patch.object(cli, "_NODE_MODULES", tmp_path)
    mocker.patch.object(cli, "_REPO_ROOT", tmp_path)
    config_path = tmp_path / "runtime.json"
    config_path.write_text(
        json.dumps({"baseUrl": "http://127.0.0.1:3000"}), encoding="utf-8"
    )
    out_path = (
        tmp_path
        / ".copilot-tracking"
        / "accessibility"
        / "local-runs"
        / "2026-07-22"
        / "report.json"
    )

    exit_code = cli.main(
        [
            "run-calibration",
            "--config",
            str(config_path),
            "--out",
            ".copilot-tracking/accessibility/local-runs/2026-07-22/report.json",
            "--run-root",
            ".copilot-tracking/accessibility/local-runs/2026-07-22/custom-run",
        ]
    )

    assert exit_code == EXIT_SUCCESS
    assert captured["env"]["RUNTIME_A11Y_RUN_ROOT"] == str(
        tmp_path
        / ".copilot-tracking"
        / "accessibility"
        / "local-runs"
        / "2026-07-22"
        / "custom-run"
    )
    assert out_path.exists()


def test_given_calibration_run_when_run_root_is_outside_allowed_tree_then_rejects(
    mocker,
    tmp_path: Path,
) -> None:
    mocker.patch.object(cli, "_REPO_ROOT", tmp_path)
    config_path = tmp_path / "runtime.json"
    config_path.write_text(
        json.dumps({"baseUrl": "http://127.0.0.1:3000"}), encoding="utf-8"
    )

    exit_code = cli.main(
        [
            "run-calibration",
            "--config",
            str(config_path),
            "--run-root",
            "../outside",
        ]
    )

    assert exit_code == EXIT_USAGE


@pytest.mark.skipif(not hasattr(os, "symlink"), reason="symlink support required")
def test_given_calibration_run_when_run_root_uses_symlink_escape_then_rejects(
    mocker,
    tmp_path: Path,
) -> None:
    mocker.patch.object(cli, "_REPO_ROOT", tmp_path)
    allowed_root = tmp_path / ".copilot-tracking" / "accessibility" / "local-runs"
    allowed_root.mkdir(parents=True, exist_ok=True)
    outside_dir = tmp_path / "outside"
    outside_dir.mkdir(parents=True, exist_ok=True)
    link_path = allowed_root / "escaped"
    os.symlink(outside_dir, link_path)
    config_path = tmp_path / "runtime.json"
    config_path.write_text(
        json.dumps({"baseUrl": "http://127.0.0.1:3000"}), encoding="utf-8"
    )

    exit_code = cli.main(
        [
            "run-calibration",
            "--config",
            str(config_path),
            "--run-root",
            str(link_path / "nested-run"),
        ]
    )

    assert exit_code == EXIT_USAGE


def test_given_visual_review_server_when_process_becomes_ready_then_returns_it(
    mocker,
    tmp_path: Path,
) -> None:
    docs_dir = tmp_path / "docs" / "docusaurus"
    docs_dir.mkdir(parents=True, exist_ok=True)
    mocker.patch.object(cli, "_REPO_ROOT", tmp_path)
    mocker.patch("runtime_a11y.__main__._probe_visual_review_server", return_value=True)
    fake_process = SimpleNamespace(
        poll=lambda: None,
        terminate=lambda: None,
        wait=lambda timeout=None: None,
    )
    mocker.patch("runtime_a11y.__main__.subprocess.Popen", return_value=fake_process)

    process = cli._start_visual_review_server("http://127.0.0.1:3000")

    assert process is fake_process


def test_given_visual_review_server_when_stopping_then_terminates_owned_process(
    tmp_path: Path,
) -> None:
    class FakeProcess:
        def __init__(self) -> None:
            self.terminated = False
            self.wait_calls = 0

        def poll(self) -> None:
            return None

        def terminate(self) -> None:
            self.terminated = True

        def wait(self, timeout: int = 5) -> None:
            self.wait_calls += 1

    process = FakeProcess()

    cli._stop_visual_review_server(process)

    assert process.terminated is True
    assert process.wait_calls == 1


def test_given_visual_review_server_when_starting_then_reports_ownership(
    mocker,
    tmp_path: Path,
) -> None:
    docs_dir = tmp_path / "docs" / "docusaurus"
    docs_dir.mkdir(parents=True, exist_ok=True)
    mocker.patch.object(cli, "_REPO_ROOT", tmp_path)
    mocker.patch(
        "runtime_a11y.__main__._probe_visual_review_server",
        side_effect=[False, True],
    )
    fake_process = SimpleNamespace(
        poll=lambda: None,
        terminate=lambda: None,
        wait=lambda timeout=None: None,
    )
    mocker.patch("runtime_a11y.__main__.subprocess.Popen", return_value=fake_process)

    process, owned = cli._ensure_visual_review_server("http://127.0.0.1:3000")

    assert process is fake_process
    assert owned is True


def test_given_prerequisite_probe_when_node_modules_missing_then_returns_usage_error(
    mocker,
    tmp_path: Path,
) -> None:
    mocker.patch.object(cli, "_NODE_MODULES", tmp_path / "missing")

    with pytest.raises(cli.ScriptError, match="Runtime probe dependencies"):
        cli._run_prerequisite_probe(
            {"baseUrl": "http://127.0.0.1:3000"},
            "http://127.0.0.1:3000",
        )


def test_given_calibration_session_when_node_modules_missing_then_returns_usage_error(
    mocker,
    tmp_path: Path,
) -> None:
    mocker.patch.object(cli, "_NODE_MODULES", tmp_path / "missing")

    with pytest.raises(cli.ScriptError, match="Runtime probe dependencies"):
        cli._run_calibration_session(
            {"baseUrl": "http://127.0.0.1:3000"},
            "http://127.0.0.1:3000",
            None,
            None,
        )


def test_given_calibration_session_when_subprocess_returns_invalid_json_then_raises(
    mocker,
    tmp_path: Path,
) -> None:
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        return_value=SimpleNamespace(stdout="not-json", stderr=""),
    )
    mocker.patch.object(cli, "_NODE_MODULES", tmp_path)

    with pytest.raises(cli.ScriptError, match="invalid JSON output"):
        cli._run_calibration_session(
            {"baseUrl": "http://127.0.0.1:3000"},
            "http://127.0.0.1:3000",
            None,
            None,
        )


def test_given_visual_review_artifact_when_remote_path_then_rejects(
    tmp_path: Path,
) -> None:
    with pytest.raises(cli.ScriptError, match="relative for containment"):
        cli._materialize_visual_review_artifact(
            "https://example.com/artifact.png",
            run_root=tmp_path,
            manifest_dir=tmp_path / "manifest",
        )


def test_given_visual_review_server_when_probe_parsing_fails_then_returns_false(
    mocker,
) -> None:
    mocker.patch("runtime_a11y.__main__.urlparse", side_effect=ValueError("bad"))

    assert cli._probe_visual_review_server("http://127.0.0.1:3000") is False


def test_given_visual_review_server_when_startup_times_out_then_terminates_and_raises(
    mocker,
    tmp_path: Path,
) -> None:
    docs_dir = tmp_path / "docs" / "docusaurus"
    docs_dir.mkdir(parents=True, exist_ok=True)
    mocker.patch.object(cli, "_REPO_ROOT", tmp_path)
    mocker.patch(
        "runtime_a11y.__main__._probe_visual_review_server", return_value=False
    )
    values = iter([0.0, 0.0, 901.0, 901.0])
    mocker.patch(
        "runtime_a11y.__main__.time.monotonic", side_effect=lambda: next(values)
    )

    class FakeProcess:
        def __init__(self) -> None:
            self.terminated = False
            self.wait_calls = 0

        def poll(self) -> int | None:
            return None

        def terminate(self) -> None:
            self.terminated = True

        def wait(self, timeout: int = 5) -> None:
            self.wait_calls += 1

    process = FakeProcess()
    mocker.patch("runtime_a11y.__main__.subprocess.Popen", return_value=process)

    with pytest.raises(cli.ScriptError, match="did not become ready"):
        cli._start_visual_review_server("http://127.0.0.1:3000")

    assert process.terminated is True


def test_given_visual_review_capture_when_subprocess_succeeds_then_manifest_is_written(
    mocker,
    tmp_path: Path,
) -> None:
    payload = {
        "runs": [
            {
                "route": "/",
                "surface": "home",
                "state": "default",
                "viewport": {"width": 1440, "height": 900},
                "screenshotPath": "artifacts/screenshot.png",
                "measurementPath": "artifacts/measurements.json",
                "tracePath": "artifacts/trace.json",
                "deterministicMetrics": {"rootHorizontalOverflow": False},
                "probeOutcomes": [{"id": "clock", "status": "pass"}],
                "browser": {"name": "chrome", "version": "126.0"},
            }
        ]
    }
    run_root = tmp_path / "run-root"
    run_root.mkdir(parents=True, exist_ok=True)
    (run_root / "artifacts").mkdir(parents=True, exist_ok=True)
    (run_root / "artifacts" / "screenshot.png").write_bytes(b"image")
    (run_root / "artifacts" / "measurements.json").write_bytes(b"{}")
    (run_root / "artifacts" / "trace.json").write_bytes(b"{}")
    mocker.patch.object(cli, "resolve_run_root", return_value=run_root)
    mocker.patch(
        "runtime_a11y.__main__._probe_visual_review_server",
        return_value=True,
    )
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        return_value=SimpleNamespace(stdout=json.dumps(payload), stderr=""),
    )
    config_path = tmp_path / "runtime.json"
    config_path.write_text(
        json.dumps(
            {
                "baseUrl": "http://127.0.0.1:3000",
                "visualReview": {
                    "enabled": True,
                    "operatorConfirmedNoPersonalData": True,
                    "evidenceRoot": str(tmp_path / "evidence"),
                },
            }
        ),
        encoding="utf-8",
    )
    out_path = (
        tmp_path
        / ".copilot-tracking"
        / "accessibility"
        / "local-runs"
        / "2026-07-22"
        / "visual-review.json"
    )

    exit_code = cli.main(
        ["capture-visual-review", "--config", str(config_path), "--out", str(out_path)]
    )

    assert exit_code == EXIT_SUCCESS
    document = json.loads(out_path.read_text(encoding="utf-8"))
    assert document["command"] == "capture-visual-review"
    assert document["manifestPaths"]
    assert document["runs"][0]["surface"] == "home"


def test_given_server_startup_failure_when_ensuring_then_surfaces_cause(
    mocker,
    tmp_path: Path,
) -> None:
    # A startup failure must not be reported as an unowned lease, which is
    # indistinguishable from reusing a healthy server.
    mocker.patch.object(cli, "_REPO_ROOT", tmp_path)
    mocker.patch(
        "runtime_a11y.__main__._probe_visual_review_server",
        return_value=False,
    )

    with pytest.raises(cli.ScriptError, match="docs/docusaurus"):
        cli._ensure_visual_review_server("http://127.0.0.1:3000")


def test_given_surface_and_state_filters_when_running_then_only_selected_runs_execute(
    mocker, tmp_path: Path
) -> None:
    collected: list[tuple[str, str, str]] = []

    def fake_run(command, capture_output, text, check, env, cwd):
        surface_id = env["RUNTIME_A11Y_SURFACE_ID"]
        state = env["RUNTIME_A11Y_STATE"]
        collected.append((surface_id, state, env["RUNTIME_A11Y_PROBE_ID"]))
        return SimpleNamespace(
            returncode=0,
            stdout=json.dumps({"probeId": env["RUNTIME_A11Y_PROBE_ID"], "results": []}),
            stderr="",
        )

    mocker.patch("runtime_a11y.__main__.subprocess.run", side_effect=fake_run)
    mocker.patch.object(cli, "_NODE_MODULES", tmp_path)
    config_path = tmp_path / "a11y-runtime.config.json"
    config_path.write_text(
        json.dumps(
            {
                "baseUrl": "http://127.0.0.1:3000",
                "surfaces": [
                    {"id": "web", "route": "/", "states": [{"state": "default"}]},
                    {"id": "search", "route": "/search", "states": [{"state": "open"}]},
                ],
                "probeScoping": [
                    {
                        "probe": "probe-axe",
                        "surfaces": ["web", "search"],
                        "states": ["default", "open"],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )

    exit_code = cli.main(
        [
            "run-all",
            "--config",
            str(config_path),
            "--surface",
            "search",
            "--state",
            "open",
        ]
    )

    assert exit_code == EXIT_SUCCESS
    assert collected == [("search", "open", "probe-axe")]


def test_given_visual_review_capture_when_disabled_then_returns_usage_error(
    tmp_path: Path,
) -> None:
    config_path = tmp_path / "runtime.json"
    config_path.write_text(
        json.dumps(
            {"baseUrl": "http://127.0.0.1:3000", "visualReview": {"enabled": False}}
        ),
        encoding="utf-8",
    )

    exit_code = cli.main(["capture-visual-review", "--config", str(config_path)])

    assert exit_code == EXIT_USAGE


def test_given_absolute_visual_review_artifact_path_when_materializing_then_rejects(
    tmp_path: Path,
) -> None:
    with pytest.raises(cli.ScriptError, match="containment"):
        cli._materialize_visual_review_artifact(
            "/tmp/escape.png",
            run_root=tmp_path,
            manifest_dir=tmp_path / "manifest",
        )


def test_given_absolute_artifact_under_run_root_when_materializing_then_copies(
    tmp_path: Path,
) -> None:
    run_root = tmp_path / "run-root"
    manifest_dir = tmp_path / "manifest"
    source_path = run_root / "artifacts" / "screenshot.png"
    source_path.parent.mkdir(parents=True, exist_ok=True)
    source_path.write_bytes(b"image")

    relative_path = cli._materialize_visual_review_artifact(
        str(source_path),
        run_root=run_root,
        manifest_dir=manifest_dir,
    )

    assert relative_path == "artifacts/screenshot.png"
    assert (manifest_dir / "artifacts" / "screenshot.png").exists()


def test_given_visual_review_selection_with_unknown_values_when_validating_then_rejects(
    tmp_path: Path,
) -> None:
    config = {
        "baseUrl": "http://127.0.0.1:3000",
        "visualReview": {
            "enabled": True,
            "operatorConfirmedNoPersonalData": True,
            "routes": [{"path": "/", "surfaceId": "home"}],
            "states": ["desktop", "reflow-320"],
        },
    }

    with pytest.raises(cli.ScriptError, match="surface"):
        cli._select_visual_review_plan(config, surfaces=["missing"], states=["desktop"])

    with pytest.raises(cli.ScriptError, match="state"):
        cli._select_visual_review_plan(config, surfaces=["home"], states=["unknown"])

    selected = cli._select_visual_review_plan(
        config, surfaces=["home"], states=["desktop"]
    )
    assert selected["surfaces"] == ["home"]
    assert selected["states"] == ["desktop"]


def test_given_existing_healthy_server_when_enforcing_then_leaves_it_untouched(
    mocker,
) -> None:
    probe = mocker.patch(
        "runtime_a11y.__main__._probe_visual_review_server", return_value=True
    )
    start = mocker.patch("runtime_a11y.__main__._start_visual_review_server")

    process, owned = cli._ensure_visual_review_server("http://127.0.0.1:3000")

    assert process is None
    assert owned is False
    probe.assert_called_once()
    start.assert_not_called()


def test_given_capture_when_subprocess_is_unavailable_then_returns_usage_error(
    mocker,
    tmp_path: Path,
) -> None:
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        side_effect=FileNotFoundError("node"),
    )
    config_path = tmp_path / "runtime.json"
    config_path.write_text(
        json.dumps(
            {
                "baseUrl": "http://127.0.0.1:3000",
                "visualReview": {
                    "enabled": True,
                    "operatorConfirmedNoPersonalData": True,
                    "evidenceRoot": str(tmp_path / "evidence"),
                },
            }
        ),
        encoding="utf-8",
    )

    exit_code = cli.main(["capture-visual-review", "--config", str(config_path)])

    assert exit_code == EXIT_USAGE


def test_given_visual_review_server_probe_when_host_is_invalid_then_returns_false() -> (
    None
):
    assert cli._probe_visual_review_server("ftp://example.com") is False
    assert cli._probe_visual_review_server("http://example.com") is False


def test_given_visual_review_server_start_when_docs_dir_is_missing_then_raises(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.setattr(cli, "_REPO_ROOT", tmp_path)

    with pytest.raises(cli.ScriptError, match="docs/docusaurus"):
        cli._start_visual_review_server("http://127.0.0.1:3000")


def test_given_visual_review_server_start_when_process_exits_before_ready_then_raises(
    mocker, tmp_path: Path
) -> None:
    docs_dir = tmp_path / "docs" / "docusaurus"
    docs_dir.mkdir(parents=True, exist_ok=True)
    mocker.patch.object(cli, "_REPO_ROOT", tmp_path)
    mocker.patch(
        "runtime_a11y.__main__._probe_visual_review_server", return_value=False
    )
    mocker.patch(
        "runtime_a11y.__main__.subprocess.Popen",
        return_value=SimpleNamespace(poll=lambda: 1),
    )

    with pytest.raises(cli.ScriptError, match="exited before"):
        cli._start_visual_review_server("http://127.0.0.1:3000")


def test_given_capture_failure_run_when_writing_manifests_then_raises(
    tmp_path: Path,
) -> None:
    payload = {
        "runs": [
            {
                "route": "/",
                "surface": "home",
                "state": "default",
                "probeOutcomes": [{"status": "capture-failure"}],
            }
        ]
    }

    with pytest.raises(cli.ScriptError, match=r"run 1 \(home/default\)"):
        cli._write_visual_review_manifests(payload, tmp_path)

    assert not (tmp_path / "runs").exists()


def test_given_malformed_probe_outcome_when_writing_manifests_then_raises(
    tmp_path: Path,
) -> None:
    payload = {
        "runs": [
            {
                "route": "/",
                "surface": "home",
                "state": "default",
                "probeOutcomes": ["capture-failure"],
            }
        ]
    }

    with pytest.raises(cli.ScriptError, match="not an object"):
        cli._write_visual_review_manifests(payload, tmp_path)


def test_given_colliding_run_labels_when_writing_manifests_then_uses_distinct_dirs(
    tmp_path: Path,
) -> None:
    run_root = tmp_path / "run-root"
    artifacts_dir = run_root / "artifacts"
    artifacts_dir.mkdir(parents=True, exist_ok=True)
    (artifacts_dir / "screenshot.png").write_bytes(b"abc")
    (artifacts_dir / "measurements.json").write_bytes(b"{}")
    (artifacts_dir / "trace.json").write_bytes(b"{}")

    def _run(surface: str, state: str) -> dict[str, object]:
        return {
            "route": "/",
            "surface": surface,
            "state": state,
            "screenshotPath": "artifacts/screenshot.png",
            "measurementPath": "artifacts/measurements.json",
            "tracePath": "artifacts/trace.json",
            "probeOutcomes": [],
            "viewport": {"width": 1440, "height": 900},
            "browser": {"name": "chrome", "version": "126"},
            "deterministicMetrics": {},
        }

    # Both runs sanitize to the same "home-search-default" label.
    payload = {"runs": [_run("home-search", "default"), _run("home", "search-default")]}

    manifest_paths = cli._write_visual_review_manifests(payload, run_root)

    assert len(manifest_paths) == 2
    parents = {Path(path).parent for path in manifest_paths}
    assert len(parents) == 2

    surfaces = sorted(
        json.loads(Path(path).read_text(encoding="utf-8"))["surface"]
        for path in manifest_paths
    )
    assert surfaces == ["home", "home-search"]


def test_given_artifact_bytes_ceiling_when_writing_manifests_then_raises(
    tmp_path: Path,
) -> None:
    run_root = tmp_path / "run-root"
    artifacts_dir = run_root / "artifacts"
    artifacts_dir.mkdir(parents=True, exist_ok=True)
    (artifacts_dir / "screenshot.png").write_bytes(b"abc")
    (artifacts_dir / "measurements.json").write_bytes(b"{}")
    (artifacts_dir / "trace.json").write_bytes(b"{}")
    payload = {
        "runs": [
            {
                "route": "/",
                "surface": "home",
                "state": "default",
                "screenshotPath": "artifacts/screenshot.png",
                "measurementPath": "artifacts/measurements.json",
                "tracePath": "artifacts/trace.json",
                "probeOutcomes": [],
                "viewport": {"width": 1440, "height": 900},
                "browser": {"name": "chrome", "version": "126"},
                "deterministicMetrics": {},
            }
        ]
    }

    with pytest.raises(cli.ScriptError, match="byte ceiling"):
        cli._write_visual_review_manifests(payload, run_root, max_artifact_bytes=1)


def test_given_case_navigation_triggers_when_asserting_urls_then_accepts_them() -> None:
    cli._assert_case_urls_allowed(
        {"baseUrl": "http://127.0.0.1:3000"},
        {"route": "/home"},
        {"action": "navigate", "value": "/next"},
        allow_external=False,
    )
    cli._assert_case_urls_allowed(
        {"baseUrl": "http://127.0.0.1:3000"},
        None,
        {"action": "visit", "target": {"value": "/visit"}},
        allow_external=False,
    )


def test_given_run_at_plan_without_eligible_variants_when_forcing_then_executes(
    mocker,
    tmp_path: Path,
) -> None:
    matrix_path = tmp_path / "matrix.json"
    matrix_path.write_text(
        json.dumps(
            {
                "criteria": [
                    {
                        "id": "4.1.2",
                        "framework": "wcag-22",
                        "title": "Name, Role, Value",
                    }
                ],
                "surfaces": [
                    {
                        "id": "dialog",
                        "name": "Dialog",
                        "platform": "web",
                        "widgetPattern": "dialog-modal",
                        "states": ["open"],
                    }
                ],
                "cells": [
                    {
                        "criterionId": "4.1.2",
                        "surfaceId": "dialog",
                        "state": "open",
                        "status": "partial",
                        "adequateMethods": ["screen-reader"],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    mocker.patch(
        "runtime_a11y.__main__._run_at_plan_case",
        return_value={"caseId": "manual-4-1-2-dialog-open", "status": "ok"},
    )

    exit_code = cli.main(
        ["run-at-plan", "--matrix", str(matrix_path), "--driver", "synthetic"]
    )

    assert exit_code == EXIT_SUCCESS


def test_given_runtime_config_when_deriving_cases_then_context_is_sanitized(
    tmp_path: Path,
) -> None:
    matrix_path = tmp_path / "matrix.json"
    matrix_path.write_text(
        (
            Path(__file__).parent / "fixtures" / "aria-at-modal-dialog-matrix.json"
        ).read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    runtime_config_path = tmp_path / "runtime.json"
    runtime_config_path.write_text(
        json.dumps(
            {
                "baseUrl": "http://127.0.0.1:3000",
                "privateKey": "shh",
                "realScreenReader": {"token": "do-not-forward"},
                "surfaces": [
                    {
                        "id": "dialog",
                        "route": "/dialog",
                        "selector": {"kind": "css", "value": "#dialog"},
                        "states": [
                            {
                                "state": "open",
                                "trigger": {
                                    "action": "click",
                                    "target": {"kind": "css", "value": "#open"},
                                },
                            }
                        ],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )

    cases = cli._derive_at_plan_cases(matrix_path, runtime_config_path)

    assert cases
    case = next(item for item in cases if item["surfaceId"] == "dialog")
    assert case["baseUrl"] == "http://127.0.0.1:3000"
    assert case["surface"]["id"] == "dialog"
    assert case["surface"]["route"] == "/dialog"
    assert case["surface"]["selector"] == {"kind": "css", "value": "#dialog"}
    assert case["trigger"]["action"] == "click"
    assert case["trigger"]["target"] == {"kind": "css", "value": "#open"}
    assert "privateKey" not in case["runtimeConfig"]
    assert case["runtimeConfig"] == {"baseUrl": "http://127.0.0.1:3000"}


def test_given_external_surface_route_when_deriving_cases_then_target_is_blocked(
    tmp_path: Path,
) -> None:
    # Arrange
    matrix_path = tmp_path / "matrix.json"
    matrix_path.write_text(
        (
            Path(__file__).parent / "fixtures" / "aria-at-modal-dialog-matrix.json"
        ).read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    runtime_config_path = tmp_path / "runtime.json"
    runtime_config_path.write_text(
        json.dumps(
            {
                "baseUrl": "http://127.0.0.1:3000",
                "surfaces": [
                    {
                        "id": "dialog",
                        "route": "https://example.com/dialog",
                        "states": [{"state": "open"}],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )

    # Act & Assert
    with pytest.raises(cli.ScriptError, match="Refusing to probe"):
        cli._derive_at_plan_cases(matrix_path, runtime_config_path)

    cases = cli._derive_at_plan_cases(
        matrix_path,
        runtime_config_path,
        allow_external=True,
    )
    case = cases[0]
    assert case["surface"]["route"] == "https://example.com/dialog"
    assert case["sourceMatrixRef"] == matrix_path.name
    assert case["sourceMatrixMetadata"]["path"] == matrix_path.name


def test_given_quarantined_matrix_when_deriving_cases_then_each_case_is_marked(
    tmp_path: Path,
) -> None:
    # Arrange
    payload = json.loads(
        (
            Path(__file__).parent / "fixtures" / "aria-at-modal-dialog-matrix.json"
        ).read_text(encoding="utf-8")
    )
    payload["quarantined"] = True
    payload["operationalFailure"] = {"reason": "screen reader driver never started"}
    matrix_path = tmp_path / "matrix.json"
    matrix_path.write_text(json.dumps(payload), encoding="utf-8")
    runtime_config_path = tmp_path / "runtime.json"
    runtime_config_path.write_text(
        json.dumps({"baseUrl": "http://127.0.0.1:3000"}),
        encoding="utf-8",
    )

    # Act
    cases = cli._derive_at_plan_cases(matrix_path, runtime_config_path)

    # Assert
    assert cases
    for case in cases:
        metadata = case["sourceMatrixMetadata"]
        assert metadata["quarantined"] is True
        assert metadata["quarantineReason"] == "screen reader driver never started"
        assert metadata["humanReviewCompleted"] is False
        assert metadata["path"] == matrix_path.name


def test_given_clean_matrix_when_deriving_cases_then_no_quarantine_marker(
    tmp_path: Path,
) -> None:
    # Arrange
    matrix_path = tmp_path / "matrix.json"
    matrix_path.write_text(
        (
            Path(__file__).parent / "fixtures" / "aria-at-modal-dialog-matrix.json"
        ).read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    runtime_config_path = tmp_path / "runtime.json"
    runtime_config_path.write_text(
        json.dumps({"baseUrl": "http://127.0.0.1:3000"}),
        encoding="utf-8",
    )

    # Act
    cases = cli._derive_at_plan_cases(matrix_path, runtime_config_path)

    # Assert
    assert cases
    metadata = cases[0]["sourceMatrixMetadata"]
    assert metadata["quarantined"] is False
    assert "quarantineReason" not in metadata


def test_given_probe_command_when_subprocess_fails_then_returns_usage_error(
    mocker, tmp_path: Path
) -> None:
    mocker.patch(
        "runtime_a11y.__main__.subprocess.run",
        side_effect=FileNotFoundError("node"),
    )
    mocker.patch.object(cli, "_NODE_MODULES", tmp_path)
    config_path = tmp_path / "a11y-runtime.config.json"
    config_path.write_text(
        '{"baseUrl": "http://127.0.0.1:3000", "surfaces": '
        '[{"id": "web", "type": "page"}]}',
        encoding="utf-8",
    )

    exit_code = cli.main(["probe", "probe-axe", "--config", str(config_path)])

    assert exit_code == EXIT_USAGE


def test_given_external_target_without_allowlist_when_run_all_then_returns_usage_error(
    tmp_path: Path,
) -> None:
    config_path = tmp_path / "a11y-runtime.config.json"
    config_path.write_text(
        '{"baseUrl": "https://example.com", '
        '"surfaces": [{"id": "web", "type": "page"}]}',
        encoding="utf-8",
    )

    exit_code = cli.main(["run-all", "--config", str(config_path)])

    assert exit_code == EXIT_USAGE


def test_given_matrix_document_when_rendering_artifacts_then_bundle_is_written(
    tmp_path: Path, capsys
) -> None:
    # Arrange
    matrix_path = tmp_path / "matrix.json"
    matrix_path.write_text(
        json.dumps(
            {
                "criteria": [
                    {
                        "id": "4.1.2",
                        "framework": "wcag-22",
                        "title": "Name, Role, Value",
                        "adequateMethods": ["screen-reader"],
                    }
                ],
                "surfaces": [
                    {
                        "id": "search",
                        "name": "Search",
                        "platform": "web",
                        "states": ["open"],
                    }
                ],
                "cells": [
                    {
                        "criterionId": "4.1.2",
                        "surfaceId": "search",
                        "state": "open",
                        "status": "partial",
                        "adequateMethods": ["screen-reader"],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    output_dir = tmp_path / "artifacts"

    # Act
    exit_code = cli.main(
        [
            "render-artifacts",
            "--matrix",
            str(matrix_path),
            "--output-dir",
            str(output_dir),
            "--repo-slug",
            "octo/repo",
        ]
    )

    # Assert
    summary = json.loads(capsys.readouterr().out)
    assert exit_code == EXIT_SUCCESS
    assert summary["command"] == "render-artifacts"
    assert (output_dir / "accessibility-artifacts-octo-repo.json").exists()
    assert (output_dir / "accessibility-results-octo-repo.earl.jsonld").exists()


def test_given_runtime_config_file_when_rendering_artifacts_then_it_is_used(
    tmp_path: Path, capsys
) -> None:
    # Arrange
    matrix_path = tmp_path / "matrix.json"
    matrix_path.write_text(
        json.dumps(
            {
                "criteria": [
                    {
                        "id": "4.1.2",
                        "framework": "wcag-22",
                        "title": "Name, Role, Value",
                    }
                ],
                "surfaces": [
                    {
                        "id": "dialog",
                        "name": "Dialog",
                        "platform": "web",
                        "states": ["open"],
                        "widgetPattern": "dialog-modal",
                    }
                ],
                "cells": [
                    {
                        "criterionId": "4.1.2",
                        "surfaceId": "dialog",
                        "state": "open",
                        "status": "unknown",
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    runtime_config_path = tmp_path / "runtime.json"
    runtime_config_path.write_text(
        json.dumps(
            {
                "surfaces": [
                    {
                        "id": "dialog",
                        "widgetPattern": "dialog-modal",
                        "states": [{"state": "open"}],
                    }
                ]
            }
        ),
        encoding="utf-8",
    )
    output_dir = tmp_path / "artifacts"

    # Act
    exit_code = cli.main(
        [
            "render-artifacts",
            "--matrix",
            str(matrix_path),
            "--output-dir",
            str(output_dir),
            "--repo-slug",
            "octo/repo",
            "--runtime-config",
            str(runtime_config_path),
        ]
    )

    # Assert
    assert exit_code == EXIT_SUCCESS
    summary = json.loads(capsys.readouterr().out)
    assert summary["artifacts"]["manualTestPlanMarkdown"].endswith(
        "manual-at-testplan-octo-repo.md"
    )


@pytest.mark.parametrize(
    "payload",
    [
        "not-json",
        '{"criteria": [], "surfaces": [], "cells": []}',
    ],
)
def test_given_invalid_matrix_when_rendering_artifacts_then_returns_usage_error(
    tmp_path: Path, payload: str
) -> None:
    # Arrange
    matrix_path = tmp_path / "matrix.json"
    matrix_path.write_text(payload, encoding="utf-8")

    # Act
    exit_code = cli.main(
        [
            "render-artifacts",
            "--matrix",
            str(matrix_path),
            "--output-dir",
            str(tmp_path / "out"),
            "--repo-slug",
            "octo/repo",
        ]
    )

    # Assert
    assert exit_code == EXIT_USAGE


def test_given_run_at_plan_when_listing_cases_then_uses_matrix_without_runtime_config(
    tmp_path: Path,
) -> None:
    matrix_path = tmp_path / "matrix.json"
    matrix_path.write_text(
        json.dumps(
            {
                "criteria": [
                    {
                        "id": "4.1.2",
                        "framework": "wcag-22",
                        "title": "Name, Role, Value",
                    }
                ],
                "surfaces": [
                    {
                        "id": "dialog",
                        "name": "Dialog",
                        "platform": "web",
                        "widgetPattern": "dialog-modal",
                        "states": ["open"],
                    }
                ],
                "cells": [
                    {
                        "criterionId": "4.1.2",
                        "surfaceId": "dialog",
                        "state": "open",
                        "status": "partial",
                        "adequateMethods": ["screen-reader"],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )

    exit_code = cli.main(["run-at-plan", "--matrix", str(matrix_path), "--list"])

    assert exit_code == EXIT_SUCCESS


def test_given_run_at_plan_when_case_is_unknown_then_returns_usage_error(
    tmp_path: Path,
) -> None:
    matrix_path = tmp_path / "matrix.json"
    matrix_path.write_text(
        json.dumps(
            {
                "criteria": [
                    {
                        "id": "4.1.2",
                        "framework": "wcag-22",
                        "title": "Name, Role, Value",
                    }
                ],
                "surfaces": [
                    {
                        "id": "dialog",
                        "name": "Dialog",
                        "platform": "web",
                        "widgetPattern": "dialog-modal",
                        "states": ["open"],
                    }
                ],
                "cells": [
                    {
                        "criterionId": "4.1.2",
                        "surfaceId": "dialog",
                        "state": "open",
                        "status": "partial",
                        "adequateMethods": ["screen-reader"],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )

    exit_code = cli.main(
        ["run-at-plan", "--matrix", str(matrix_path), "--case-id", "missing"]
    )

    assert exit_code == EXIT_USAGE


def test_given_run_at_plan_when_target_is_external_then_requires_allow_external(
    tmp_path: Path,
) -> None:
    matrix_path = tmp_path / "matrix.json"
    matrix_path.write_text(
        json.dumps(
            {
                "criteria": [
                    {
                        "id": "4.1.2",
                        "framework": "wcag-22",
                        "title": "Name, Role, Value",
                    }
                ],
                "surfaces": [
                    {
                        "id": "dialog",
                        "name": "Dialog",
                        "platform": "web",
                        "widgetPattern": "dialog-modal",
                        "states": ["open"],
                    }
                ],
                "cells": [
                    {
                        "criterionId": "4.1.2",
                        "surfaceId": "dialog",
                        "state": "open",
                        "status": "partial",
                        "adequateMethods": ["screen-reader"],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    config_path = tmp_path / "config.json"
    config_path.write_text(
        json.dumps({"baseUrl": "https://example.com", "surfaces": []}),
        encoding="utf-8",
    )

    exit_code = cli.main(
        [
            "run-at-plan",
            "--matrix",
            str(matrix_path),
            "--config",
            str(config_path),
            "--case-id",
            "manual-4-1-2-dialog-open",
        ]
    )

    assert exit_code == EXIT_USAGE


def _visual_review_config(tmp_path: Path, **overrides: object) -> Path:
    """Write a minimal visual-review config and return its path."""
    payload: dict[str, object] = {
        "baseUrl": "http://127.0.0.1:3001",
        "serveMode": "auto",
        "visualReview": {"enabled": True, "evidenceRoot": str(tmp_path / "evidence")},
    }
    payload.update(overrides)
    config_path = tmp_path / "visual-review.config.json"
    config_path.write_text(json.dumps(payload), encoding="utf-8")
    return config_path


def test_given_missing_node_modules_when_capturing_then_fails_before_touching_server(
    mocker, tmp_path: Path
) -> None:
    # Arrange
    mocker.patch.object(cli, "_NODE_MODULES", tmp_path / "absent-node-modules")
    ensure_server = mocker.patch.object(
        cli, "_ensure_visual_review_server", return_value=(None, False)
    )
    start_server = mocker.patch.object(cli, "_start_visual_review_server")
    probe_server = mocker.patch.object(cli, "_probe_visual_review_server")
    config_path = _visual_review_config(tmp_path)

    # Act
    exit_code = cli.main(["capture-visual-review", "--config", str(config_path)])

    # Assert
    assert exit_code == EXIT_USAGE
    ensure_server.assert_not_called()
    start_server.assert_not_called()
    probe_server.assert_not_called()


def test_given_missing_node_modules_when_requiring_then_names_the_install_step(
    mocker, tmp_path: Path
) -> None:
    # Arrange
    mocker.patch.object(cli, "_NODE_MODULES", tmp_path / "absent-node-modules")

    # Act & Assert
    with pytest.raises(cli.ScriptError, match="npm ci") as excinfo:
        cli._require_harness_dependencies("running visual review capture")

    assert excinfo.value.exit_code == EXIT_USAGE


def test_given_installed_node_modules_when_requiring_then_allows_execution(
    mocker, tmp_path: Path
) -> None:
    # Arrange
    installed = tmp_path / "node_modules"
    installed.mkdir()
    mocker.patch.object(cli, "_NODE_MODULES", installed)

    # Act & Assert
    cli._require_harness_dependencies("running visual review capture")


@pytest.mark.parametrize("serve_mode", ["external", "off"])
def test_given_unmanaged_serve_mode_when_ensuring_then_never_probes_or_starts(
    mocker, serve_mode: str
) -> None:
    # Arrange
    probe = mocker.patch.object(cli, "_probe_visual_review_server")
    start = mocker.patch.object(cli, "_start_visual_review_server")

    # Act
    process, owned = cli._ensure_visual_review_server(
        "http://127.0.0.1:3001", serve_mode
    )

    # Assert
    assert (process, owned) == (None, False)
    probe.assert_not_called()
    start.assert_not_called()


def test_given_served_mode_without_running_server_when_ensuring_then_fails_actionably(
    mocker,
) -> None:
    # Arrange
    mocker.patch.object(cli, "_probe_visual_review_server", return_value=False)
    start = mocker.patch.object(cli, "_start_visual_review_server")

    # Act & Assert
    with pytest.raises(cli.ScriptError, match="serve:preview"):
        cli._ensure_visual_review_server("http://127.0.0.1:3001", "served")

    start.assert_not_called()


def test_given_served_mode_with_running_server_when_ensuring_then_reuses_it(
    mocker,
) -> None:
    # Arrange
    mocker.patch.object(cli, "_probe_visual_review_server", return_value=True)
    start = mocker.patch.object(cli, "_start_visual_review_server")

    # Act
    process, owned = cli._ensure_visual_review_server("http://127.0.0.1:3001", "served")

    # Assert
    assert (process, owned) == (None, False)
    start.assert_not_called()


@pytest.mark.parametrize("serve_mode", ["auto", "served"])
def test_given_managed_serve_mode_with_external_host_when_ensuring_then_fails_closed(
    mocker, serve_mode: str
) -> None:
    # Arrange
    start = mocker.patch.object(cli, "_start_visual_review_server")

    # Act & Assert
    with pytest.raises(cli.ScriptError, match="loopback"):
        cli._ensure_visual_review_server("https://docs.example.com", serve_mode)

    start.assert_not_called()


def test_given_unknown_serve_mode_when_ensuring_then_rejects_it(mocker) -> None:
    # Arrange
    start = mocker.patch.object(cli, "_start_visual_review_server")

    # Act & Assert
    with pytest.raises(cli.ScriptError, match="Unsupported serveMode"):
        cli._ensure_visual_review_server("http://127.0.0.1:3001", "sometimes")

    start.assert_not_called()


def test_given_auto_mode_when_starting_then_runs_production_preview_on_parsed_target(
    mocker, tmp_path: Path
) -> None:
    # Arrange
    (tmp_path / "docs" / "docusaurus").mkdir(parents=True, exist_ok=True)
    mocker.patch.object(cli, "_probe_visual_review_server", return_value=True)
    mocker.patch.object(cli.shutil, "which", return_value="/usr/bin/npm")
    popen = mocker.patch.object(
        cli.subprocess, "Popen", return_value=SimpleNamespace(poll=lambda: None)
    )

    # Act
    cli._start_visual_review_server("http://127.0.0.1:3001/")

    # Assert
    assert popen.call_args.args[0] == ["/usr/bin/npm", "run", "serve:preview"]
    assert popen.call_args.kwargs["cwd"] == str(tmp_path / "docs" / "docusaurus")
    assert popen.call_args.kwargs["env"]["HOST"] == "127.0.0.1"
    assert popen.call_args.kwargs["env"]["PORT"] == "3001"


def test_given_windows_npm_shim_when_starting_then_launches_resolved_executable(
    mocker, tmp_path: Path
) -> None:
    # A bare "npm" argument does not launch on Windows, where the executable is
    # npm.cmd, so the resolved PATH entry must reach Popen.
    # Arrange
    (tmp_path / "docs" / "docusaurus").mkdir(parents=True, exist_ok=True)
    mocker.patch.object(cli, "_probe_visual_review_server", return_value=True)
    mocker.patch.object(
        cli.shutil, "which", return_value="C:\\Program Files\\nodejs\\npm.cmd"
    )
    popen = mocker.patch.object(
        cli.subprocess, "Popen", return_value=SimpleNamespace(poll=lambda: None)
    )

    # Act
    cli._start_visual_review_server("http://127.0.0.1:3001/")

    # Assert
    assert popen.call_args.args[0][0] == "C:\\Program Files\\nodejs\\npm.cmd"


def test_given_owned_server_on_windows_when_stopping_then_terminates_the_tree(
    mocker,
) -> None:
    # npm runs the server in a child process, so stopping only the npm wrapper
    # orphans a listener that keeps holding the port.
    # Arrange
    mocker.patch.object(cli.sys, "platform", "win32")
    run = mocker.patch.object(cli.subprocess, "run")
    process = mocker.MagicMock()
    process.pid = 4321
    process.poll.return_value = None

    # Act
    cli._stop_visual_review_server(process)

    # Assert
    assert run.call_args.args[0] == ["taskkill", "/T", "/F", "/PID", "4321"]
    process.terminate.assert_not_called()


def test_given_owned_server_on_posix_when_stopping_then_signals_the_process_group(
    mocker,
) -> None:
    # Arrange
    mocker.patch.object(cli.sys, "platform", "linux")
    mocker.patch.object(cli.os, "getpgid", return_value=9100, create=True)
    killpg = mocker.patch.object(cli.os, "killpg", create=True)
    process = mocker.MagicMock()
    process.pid = 9100
    process.poll.return_value = None

    # Act
    cli._stop_visual_review_server(process)

    # Assert
    killpg.assert_called_once_with(9100, cli.signal.SIGTERM)
    process.terminate.assert_not_called()

    # Arrange
    repo_root = Path(__file__).resolve().parents[6]
    config = json.loads(
        (repo_root / "docs" / "docusaurus" / "a11y-runtime.config.json").read_text(
            encoding="utf-8"
        )
    )
    static_server = (
        repo_root / "docs" / "docusaurus" / "e2e" / "static-server.mjs"
    ).read_text(encoding="utf-8")
    playwright_config = (
        repo_root / "docs" / "docusaurus" / "playwright.config.ts"
    ).read_text(encoding="utf-8")

    # Assert
    assert config["serveMode"] == "auto"
    assert config["baseUrl"] == "http://127.0.0.1:3001"
    assert "http://127.0.0.1:3001" in config["allowlist"]
    assert "process.env.PORT ?? 3001" in static_server
    assert "http://127.0.0.1:3001/" in playwright_config
