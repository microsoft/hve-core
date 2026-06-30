# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Targeted tests for previously uncovered Jira helper branches."""

from __future__ import annotations

import argparse

import jira
import pytest
from test_constants import TEST_ISSUE_KEY


def test_no_redirect_handler_raises() -> None:
    handler = jira._NoRedirect()
    request = jira.urllib.request.Request("https://jira.example.com/x")

    with pytest.raises(jira.urllib.error.HTTPError):
        handler.redirect_request(
            request, None, 302, "Found", {"Location": "https://evil"}, "https://evil"
        )


def test_validate_base_url_requires_host() -> None:
    with pytest.raises(jira.ScriptError):
        jira._validate_base_url("https://")


def test_validate_ascii_no_newlines_rejects_empty() -> None:
    with pytest.raises(jira.ScriptError):
        jira._validate_ascii_no_newlines("", name="JIRA_PAT")


def test_validate_ascii_no_newlines_rejects_control_characters() -> None:
    with pytest.raises(jira.ScriptError):
        jira._validate_ascii_no_newlines("abc\x01def", name="JIRA_PAT")


def test_validate_ascii_no_newlines_rejects_non_ascii() -> None:
    with pytest.raises(jira.ScriptError):
        jira._validate_ascii_no_newlines("caf\u00e9", name="JIRA_PAT")


def test_get_response_content_type_without_headers_attribute() -> None:
    assert jira._get_response_content_type(object()) == ""


def test_from_environment_rejects_partial_cloud_credentials(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.delenv("JIRA_PAT", raising=False)
    monkeypatch.setenv("JIRA_USER_EMAIL", "user@example.com")
    monkeypatch.delenv("JIRA_API_TOKEN", raising=False)

    with pytest.raises(jira.ScriptError):
        jira.JiraClient.from_environment()


def test_read_stdin_without_read_attribute(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("sys.stdin", object())

    assert jira._read_stdin(16) == ""


def test_read_json_argument_handles_none_stdin(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(jira, "_read_stdin", lambda _limit: None)

    with pytest.raises(jira.ScriptError):
        jira._read_json_argument(None, "usage message")


def test_handle_comment_handles_none_stdin_body(
    handler_client: jira.JiraClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(jira, "_read_stdin", lambda _limit: None)
    args = argparse.Namespace(issue_key=TEST_ISSUE_KEY, body=None)

    with pytest.raises(jira.ScriptError):
        jira.handle_comment(handler_client, args)


def test_validate_base_url_rejects_insecure_remote_host(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.delenv("JIRA_ALLOW_INSECURE", raising=False)

    with pytest.raises(jira.ScriptError):
        jira._validate_base_url("http://jira.example.com")


def test_validate_base_url_rejects_unknown_scheme() -> None:
    with pytest.raises(jira.ScriptError):
        jira._validate_base_url("ftp://jira.example.com")


def test_read_response_body_without_read_attribute() -> None:
    assert jira._read_response_body(object()) == b""


def test_read_response_body_handles_none_body() -> None:
    class _NoneBody:
        def read(self, _size: int | None = None) -> None:
            return None

    assert jira._read_response_body(_NoneBody()) == b""


def test_read_response_body_encodes_string_body() -> None:
    class _StrBody:
        def read(self, _size: int | None = None) -> str:
            return "text"

    assert jira._read_response_body(_StrBody()) == b"text"


def test_get_response_content_type_coerces_non_string() -> None:
    class _Headers:
        def get(self, _key: str, default: object = None) -> object:
            return 123

    class _Response:
        headers = _Headers()

    assert jira._get_response_content_type(_Response()) == "123"


def test_get_response_content_type_without_get_returns_empty() -> None:
    class _Response:
        headers = object()

    assert jira._get_response_content_type(_Response()) == ""


def test_read_json_argument_rejects_oversized_payload() -> None:
    with pytest.raises(jira.ScriptError):
        jira._read_json_argument("x" * (jira.MAX_BODY_BYTES + 1), "usage")


def test_read_json_argument_requires_content_when_stdin_empty(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    class _Stdin:
        def read(self) -> None:
            return None

    monkeypatch.setattr("sys.stdin", _Stdin())

    with pytest.raises(jira.ScriptError):
        jira._read_json_argument(None, "usage message")


def test_create_response_with_body_roundtrips() -> None:
    response = jira._create_response_with_body("payload", content_type="text/plain")

    with response as handle:
        assert handle.read() == b"payload"
        assert handle.read(3) == b"pay"
    assert response.headers["Content-Type"] == "text/plain"


def test_request_rejects_non_json_content_type(
    configured_client: jira.JiraClient,
    mocker: object,
) -> None:
    response = jira._create_response_with_body("<html>", content_type="text/html")
    mocker.patch("jira._OPENER.open", return_value=response)  # type: ignore[attr-defined]

    with pytest.raises(jira.ScriptError) as exc_info:
        configured_client.request("GET", "/issue/PROJ-1")

    assert "content type" in str(exc_info.value).lower()


def test_handle_comment_rejects_oversized_body(
    handler_client: jira.JiraClient,
) -> None:
    args = argparse.Namespace(
        issue_key=TEST_ISSUE_KEY,
        body="x" * (jira.MAX_BODY_BYTES + 1),
    )

    with pytest.raises(jira.ScriptError) as exc_info:
        jira.handle_comment(handler_client, args)

    assert "exceeds size limit" in str(exc_info.value)


def test_handle_comment_requires_body_when_stdin_empty(
    handler_client: jira.JiraClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    class _Stdin:
        def read(self) -> None:
            return None

    monkeypatch.setattr("sys.stdin", _Stdin())
    args = argparse.Namespace(issue_key=TEST_ISSUE_KEY, body=None)

    with pytest.raises(jira.ScriptError) as exc_info:
        jira.handle_comment(handler_client, args)

    assert "comment body" in str(exc_info.value).lower()


def test_handle_fields_rejects_invalid_issue_type_id(
    handler_client: jira.JiraClient,
) -> None:
    args = argparse.Namespace(project_key="PROJ", issue_type_id="not-a-number")

    with pytest.raises(jira.ScriptError):
        jira.handle_fields(handler_client, args)


def test_handle_fields_fetches_issue_type_metadata(
    handler_client: jira.JiraClient,
) -> None:
    args = argparse.Namespace(project_key="PROJ", issue_type_id="5")

    jira.handle_fields(handler_client, args)

    recorded = handler_client.calls[-1]  # type: ignore[attr-defined]
    assert recorded.path.endswith("/issuetypes/5")
