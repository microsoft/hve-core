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
    assert "resource" not in events[0]
    assert events[0]["origin"] == "https://gitlab.example.com"
    assert events[0]["auth_mode"] == "legacy-token"
    assert "projects/1" not in log.read_text(encoding="utf-8")
    assert "per_page" not in log.read_text(encoding="utf-8")
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

    with pytest.raises(gitlab.GitLabAPIError):
        gitlab.request("GET", f"{TEST_API_URL}/projects/1/pipelines/3")

    events = _events(log)
    assert events[-1]["outcome"] == "error"
    assert events[-1]["status"] == 500


def test_oauth_audit_excludes_resource_and_profile_identifiers(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    log = tmp_path / "audit.jsonl"
    monkeypatch.setenv("GITLAB_AUDIT_LOG", str(log))
    gitlab.auth_context = gitlab.AuthContext(
        mode="oauth",
        issuer="https://gitlab.example.com",
        profile_name="private-profile",
        store_path=tmp_path / "private-store.json",
        client_id="client",
    )

    gitlab._audit_attempt(
        "oauth",
        "GET",
        "https://gitlab.example.com/api/v4/projects/42?private_token=secret",
    )

    rendered = log.read_text(encoding="utf-8")
    event = _events(log)[0]
    assert event["origin"] == "https://gitlab.example.com"
    assert event["auth_mode"] == "oauth"
    assert "projects/42" not in rendered
    assert "private-profile" not in rendered
    assert "private-store" not in rendered
    assert "secret" not in rendered


def test_audit_fail_closed_blocks_request(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    configured_gitlab: object,
    mocker: MockerFixture,
) -> None:
    log = tmp_path / "missing-dir" / "audit.jsonl"
    _enable_audit(monkeypatch, log)
    opener = mocker.patch("gitlab._OPENER.open")

    with pytest.raises(gitlab.GitLabError):
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

    with pytest.raises(gitlab.GitLabAPIError) as exc_info:
        gitlab.request("GET", f"{TEST_API_URL}/projects/1/merge_requests/2")

    rendered = str(exc_info.value)
    assert "expired or revoked" in rendered
    assert "GITLAB_TOKEN" in rendered
    assert capsys.readouterr().err == ""


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


def test_oauth_audit_uses_bounded_schema(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    log = tmp_path / "audit.jsonl"
    monkeypatch.setenv("GITLAB_AUDIT_LOG", str(log))

    gitlab._oauth_audit_attempt("oauth.refresh")
    gitlab._oauth_audit_outcome("oauth.refresh", "error", 503, "http")

    events = _events(log)
    assert events == [
        {
            "ts": events[0]["ts"],
            "skill": "gitlab",
            "transport": "oauth",
            "auth_mode": "oauth",
            "operation": "oauth.refresh",
            "event": "attempt",
        },
        {
            "ts": events[1]["ts"],
            "skill": "gitlab",
            "transport": "oauth",
            "auth_mode": "oauth",
            "operation": "oauth.refresh",
            "event": "outcome",
            "outcome": "error",
            "status": 503,
            "failure_kind": "http",
        },
    ]


def test_oauth_attempt_failure_blocks_egress(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    mocker: MockerFixture,
) -> None:
    monkeypatch.setenv("GITLAB_AUDIT_LOG", str(tmp_path / "missing" / "audit.jsonl"))
    opener = mocker.MagicMock()

    with pytest.raises(gitlab.GitLabError):
        gitlab.oauth.post_form(
            "https://gitlab.example.com",
            "/oauth/token",
            {"grant_type": "refresh_token"},
            opener=opener,
            timeout=30,
            operation="oauth.refresh",
            audit_attempt=gitlab._oauth_audit_attempt,
            audit_outcome=gitlab._oauth_audit_outcome,
        )

    opener.assert_not_called()


def test_audit_write_redacts_unsanitized_fields_and_stays_valid_json(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """The sink redacts fields no call site sanitized, without breaking JSON.

    Redacting the serialized line instead of each value would corrupt the
    record, because the bare form-shape rule consumes the closing quote and
    the comma that follow the matched value.
    """
    log = tmp_path / "audit.jsonl"
    monkeypatch.setenv("GITLAB_AUDIT_LOG", str(log))
    secret = "SUPERSECRET123"

    gitlab._audit_write(
        {
            "ts": "x",
            "future_field": f"access_token={secret}",
            "password": secret,
            "note": "after",
            "status": 403,
        }
    )

    line = log.read_text(encoding="utf-8").strip()
    record = json.loads(line)

    assert secret not in line
    assert record["note"] == "after"
    assert record["status"] == 403
