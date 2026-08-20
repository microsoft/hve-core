# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for Jira audit logging and token-rotation handling."""

from __future__ import annotations

import json
from pathlib import Path

import jira
import pytest
from pytest_mock import MockerFixture


def _events(path: Path) -> list[dict[str, object]]:
    return [
        json.loads(line)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]


def test_audit_no_op_when_disabled(
    monkeypatch: pytest.MonkeyPatch,
    configured_client: jira.JiraClient,
    response_factory: object,
    mocker: MockerFixture,
) -> None:
    monkeypatch.delenv("JIRA_AUDIT_LOG", raising=False)
    mocker.patch("jira._OPENER.open", return_value=response_factory("{}"))  # type: ignore[operator]

    assert jira._audit_write({"event": "attempt"}) is False
    configured_client.request("GET", "/issue/PROJ-1")


def test_audit_writes_attempt_then_success(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    configured_client: jira.JiraClient,
    response_factory: object,
    mocker: MockerFixture,
) -> None:
    log = tmp_path / "audit.jsonl"
    monkeypatch.setenv("JIRA_AUDIT_LOG", str(log))
    monkeypatch.setattr(jira, "_AUDIT_OP", "get")
    mocker.patch("jira._OPENER.open", return_value=response_factory('{"ok": true}'))  # type: ignore[operator]

    configured_client.request("GET", "/issue/PROJ-1?expand=changelog")

    events = _events(log)
    assert [e["event"] for e in events] == ["attempt", "outcome"]
    assert events[0]["skill"] == "jira"
    assert events[0]["op"] == "get"
    assert events[0]["method"] == "GET"
    assert "resource" not in events[0]
    assert events[0]["actor"] == "jira-pat"
    assert events[0]["origin"] == "https://jira.example.com"
    assert events[0]["auth_mode"] == "data-center-pat"
    assert events[1]["outcome"] == "success"


def test_audit_records_error_outcome_with_status(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    configured_client: jira.JiraClient,
    http_error_factory: object,
    mocker: MockerFixture,
) -> None:
    log = tmp_path / "audit.jsonl"
    monkeypatch.setenv("JIRA_AUDIT_LOG", str(log))
    mocker.patch(
        "jira._OPENER.open",
        side_effect=http_error_factory(
            "boom", 500, "https://jira.example.com/rest/api/2/issue/PROJ-1"
        ),  # type: ignore[operator]
    )

    with pytest.raises(jira.ScriptError):
        configured_client.request("GET", "/issue/PROJ-1")

    events = _events(log)
    assert events[-1]["event"] == "outcome"
    assert events[-1]["outcome"] == "error"
    assert events[-1]["status"] == 500


def test_audit_fail_closed_blocks_request(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    configured_client: jira.JiraClient,
    mocker: MockerFixture,
) -> None:
    log = tmp_path / "missing-dir" / "audit.jsonl"
    monkeypatch.setenv("JIRA_AUDIT_LOG", str(log))
    opener = mocker.patch("jira._OPENER.open")

    with pytest.raises(jira.ScriptError) as exc_info:
        configured_client.request("GET", "/issue/PROJ-1")

    assert "refusing to proceed" in str(exc_info.value)
    opener.assert_not_called()


def test_audit_actor_override(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    response_factory: object,
    mocker: MockerFixture,
) -> None:
    monkeypatch.setenv("JIRA_PAT", "server-token")
    monkeypatch.setenv("JIRA_AUDIT_ACTOR", "ci-service@example.com")
    client = jira.JiraClient.from_environment()
    log = tmp_path / "audit.jsonl"
    monkeypatch.setenv("JIRA_AUDIT_LOG", str(log))
    mocker.patch("jira._OPENER.open", return_value=response_factory("{}"))  # type: ignore[operator]

    client.request("GET", "/issue/PROJ-1")

    assert _events(log)[0]["actor"] == "ci-service@example.com"


def test_scoped_audit_excludes_cloud_id_and_resource_path(
    configured_cloud_environment: None,
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    response_factory: object,
    mocker: MockerFixture,
) -> None:
    cloud_id = "private-cloud-id"
    log = tmp_path / "audit.jsonl"
    monkeypatch.setenv("JIRA_CLOUD_TOKEN_MODE", "scoped")
    monkeypatch.setenv("JIRA_CLOUD_ID", cloud_id)
    monkeypatch.setenv("JIRA_AUDIT_LOG", str(log))
    client = jira.JiraClient.from_environment()
    mocker.patch("jira._OPENER.open", return_value=response_factory("{}"))  # type: ignore[operator]

    client.request("GET", "/issue/PROJ-1?expand=names")

    rendered = log.read_text(encoding="utf-8")
    events = _events(log)
    assert events[0]["origin"] == "https://api.atlassian.com"
    assert events[0]["auth_mode"] == "cloud-scoped-token"
    assert cloud_id not in rendered
    assert "PROJ-1" not in rendered
    assert "expand" not in rendered


def test_audit_outcome_warns_when_unwritable(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    monkeypatch.setenv("JIRA_AUDIT_LOG", str(tmp_path / "audit.jsonl"))

    def boom(_event: dict[str, object]) -> bool:
        raise OSError("disk full")

    monkeypatch.setattr(jira, "_audit_write", boom)
    jira._audit_outcome("actor", "GET", "success")

    assert "audit outcome write failed" in capsys.readouterr().err


def test_audit_write_redacts_unsanitized_fields_and_stays_valid_json(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """The sink redacts fields no call site sanitized, without breaking JSON.

    Redacting the serialized line instead of each value would corrupt the
    record, because the bare form-shape rule consumes the closing quote and
    the comma that follow the matched value.
    """
    log = tmp_path / "audit.jsonl"
    monkeypatch.setenv("JIRA_AUDIT_LOG", str(log))
    secret = "SUPERSECRET123"

    jira._audit_write(
        {
            "ts": "x",
            "future_field": f"api_token={secret}",
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
