# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for GitLab audit logging and token-rotation handling."""

from __future__ import annotations

import json
from pathlib import Path

import gitlab
import pytest
from pytest_mock import MockerFixture
from test_constants import TEST_API_URL


def _events(path: Path) -> list[dict[str, object]]:
    return [
        json.loads(line)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]


def _enable_audit(
    monkeypatch: pytest.MonkeyPatch, log: Path, op: str = "mr-get"
) -> None:
    gitlab.require_environment()
    monkeypatch.setenv("GITLAB_AUDIT_LOG", str(log))
    monkeypatch.setattr(gitlab, "_AUDIT_OP", op)


def test_audit_no_op_when_disabled(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("GITLAB_AUDIT_LOG", raising=False)

    assert gitlab._audit_write({"event": "attempt"}) is False


def test_audit_writes_attempt_then_success(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    configured_gitlab: object,
    response_factory: object,
    mocker: MockerFixture,
) -> None:
    log = tmp_path / "audit.jsonl"
    _enable_audit(monkeypatch, log)
    mocker.patch("gitlab._OPENER.open", return_value=response_factory("{}"))  # type: ignore[operator]

    gitlab.request("GET", f"{TEST_API_URL}/projects/1/merge_requests/2?per_page=20")

    events = _events(log)
    assert [e["event"] for e in events] == ["attempt", "outcome"]
    assert events[0]["skill"] == "gitlab"
    assert events[0]["op"] == "mr-get"
    assert events[0]["actor"] == "gitlab-token"
    assert events[0]["resource"] == "/api/v4/projects/1/merge_requests/2"
    assert events[1]["outcome"] == "success"


def test_audit_records_error_outcome_with_status(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    configured_gitlab: object,
    http_error_factory: object,
    mocker: MockerFixture,
) -> None:
    log = tmp_path / "audit.jsonl"
    _enable_audit(monkeypatch, log)
    mocker.patch(
        "gitlab._OPENER.open",
        side_effect=http_error_factory("boom", 500, TEST_API_URL),  # type: ignore[operator]
    )

    with pytest.raises(SystemExit):
        gitlab.request("GET", f"{TEST_API_URL}/projects/1/pipelines/3")

    events = _events(log)
    assert events[-1]["outcome"] == "error"
    assert events[-1]["status"] == 500


def test_audit_fail_closed_blocks_request(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    configured_gitlab: object,
    mocker: MockerFixture,
) -> None:
    log = tmp_path / "missing-dir" / "audit.jsonl"
    _enable_audit(monkeypatch, log)
    opener = mocker.patch("gitlab._OPENER.open")

    with pytest.raises(SystemExit):
        gitlab.request("GET", f"{TEST_API_URL}/projects/1/merge_requests/2")

    opener.assert_not_called()


def test_audit_actor_override(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("GITLAB_AUDIT_ACTOR", "ci-service")
    gitlab.require_environment()

    assert gitlab.audit_actor == "ci-service"


def test_auth_error_adds_rotation_hint(
    configured_gitlab: object,
    http_error_factory: object,
    capsys: pytest.CaptureFixture[str],
    mocker: MockerFixture,
) -> None:
    mocker.patch(
        "gitlab._OPENER.open",
        side_effect=http_error_factory("denied", 401, TEST_API_URL),  # type: ignore[operator]
    )

    with pytest.raises(SystemExit):
        gitlab.request("GET", f"{TEST_API_URL}/projects/1/merge_requests/2")

    err = capsys.readouterr().err
    assert "expired or revoked" in err
    assert "GITLAB_TOKEN" in err


def test_audit_outcome_warns_when_unwritable(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    monkeypatch.setenv("GITLAB_AUDIT_LOG", str(tmp_path / "audit.jsonl"))

    def boom(_event: dict[str, object]) -> bool:
        raise OSError("disk full")

    monkeypatch.setattr(gitlab, "_audit_write", boom)
    gitlab._audit_outcome("actor", "GET", "/projects/1", "success")

    assert "audit outcome write failed" in capsys.readouterr().err
