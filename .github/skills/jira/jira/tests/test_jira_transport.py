# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Transport and environment tests for jira.py."""

from __future__ import annotations

import base64
import io
import json
import urllib.error
import urllib.request
from types import SimpleNamespace
from typing import cast

import jira
import pytest
from conftest import ClientRecorder, HttpErrorFactory, ResponseFactory
from pytest_mock import MockerFixture
from test_constants import (
    ERROR_AUTH_MISSING,
    ERROR_BASE_URL_INVALID,
    ERROR_BASE_URL_MISSING,
    TEST_API_TOKEN,
    TEST_API_URL,
    TEST_PAT,
    TEST_USER_EMAIL,
)

REQUEST_PATH = "/issue/PROJ-123"
REQUEST_URL = f"{TEST_API_URL}{REQUEST_PATH}"


def _request_headers(request: urllib.request.Request) -> dict[str, str]:
    return {key.lower(): value for key, value in request.header_items()}


def test_from_environment_builds_pat_client(
    configured_server_environment: None,
) -> None:
    client = jira.JiraClient.from_environment()

    assert client.api_url == TEST_API_URL
    assert client.auth_header == f"Bearer {TEST_PAT}"
    assert client.use_legacy_search is True


def test_from_environment_builds_basic_auth_client(
    configured_cloud_environment: None,
) -> None:
    client = jira.JiraClient.from_environment()
    encoded = base64.b64encode(f"{TEST_USER_EMAIL}:{TEST_API_TOKEN}".encode()).decode()

    assert client.api_url == TEST_API_URL
    assert client.auth_header == f"Basic {encoded}"
    assert client.use_legacy_search is False


@pytest.mark.parametrize(
    ("env_name", "env_value", "expected_message"),
    [
        ("JIRA_BASE_URL", "", ERROR_BASE_URL_MISSING),
        ("JIRA_BASE_URL", "jira.example.com", ERROR_BASE_URL_INVALID),
    ],
)
def test_from_environment_validates_base_url(
    monkeypatch: pytest.MonkeyPatch,
    env_name: str,
    env_value: str,
    expected_message: str,
) -> None:
    monkeypatch.setenv(env_name, env_value)

    with pytest.raises(jira.ScriptError) as exc_info:
        jira.JiraClient.from_environment()

    assert exc_info.value.exit_code == jira.EXIT_USAGE
    assert str(exc_info.value) == expected_message


def test_from_environment_requires_auth_credentials() -> None:
    with pytest.raises(jira.ScriptError) as exc_info:
        jira.JiraClient.from_environment()

    assert exc_info.value.exit_code == jira.EXIT_USAGE
    assert str(exc_info.value) == ERROR_AUTH_MISSING


@pytest.mark.parametrize(
    ("base_url", "expected"),
    [
        ("https://jira.example.com", "https://jira.example.com"),
        ("https://jira.example.com/", "https://jira.example.com"),
        ("https://jira.example.com:8443", "https://jira.example.com:8443"),
    ],
)
def test_canonicalize_base_url_accepts_origin_only_values(
    base_url: str,
    expected: str,
) -> None:
    assert jira._canonicalize_base_url(base_url) == expected


@pytest.mark.parametrize(
    "base_url",
    [
        "https://jira.example.com/path",
        "https://jira.example.com?x=1",
        "https://jira.example.com#frag",
        "https://user:pass@jira.example.com",
        "https://jira.example.com\n",
    ],
)
def test_canonicalize_base_url_rejects_unsafe_values(base_url: str) -> None:
    with pytest.raises(jira.ScriptError) as exc_info:
        jira._canonicalize_base_url(base_url)

    assert exc_info.value.exit_code == jira.EXIT_USAGE


def test_from_environment_rejects_invalid_base_url_at_construction(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("JIRA_BASE_URL", "https://jira.example.com/path")

    with pytest.raises(jira.ScriptError) as exc_info:
        jira.JiraClient.from_environment()

    assert exc_info.value.exit_code == jira.EXIT_USAGE


@pytest.mark.parametrize(
    ("email", "token"),
    [
        ("user@example.com\n", "cloud-token"),
        ("user@example.com", "cloud-token\n"),
        ("user@example.comé", "cloud-token"),
    ],
)
def test_from_environment_rejects_invalid_basic_auth_credentials(
    monkeypatch: pytest.MonkeyPatch,
    email: str,
    token: str,
) -> None:
    monkeypatch.setenv("JIRA_BASE_URL", TEST_API_URL)
    monkeypatch.setenv("JIRA_USER_EMAIL", email)
    monkeypatch.setenv("JIRA_API_TOKEN", token)

    with pytest.raises(jira.ScriptError) as exc_info:
        jira.JiraClient.from_environment()

    assert exc_info.value.exit_code == jira.EXIT_USAGE


def test_open_url_uses_opener_directly(mocker: MockerFixture) -> None:
    request = urllib.request.Request("https://jira.example.com")
    opener = mocker.patch("jira._OPENER.open", return_value=object())

    assert jira._open_url(request, timeout=7) is opener.return_value
    opener.assert_called_once_with(request, timeout=7)


def test_request_returns_parsed_json(
    configured_client: jira.JiraClient,
    response_factory: ResponseFactory,
    mocker: MockerFixture,
) -> None:
    captured_request: dict[str, urllib.request.Request] = {}

    def fake_urlopen(request: urllib.request.Request, timeout: int) -> object:
        captured_request["request"] = request
        return response_factory('{"key": "PROJ-123"}')

    mocker.patch("jira._OPENER.open", side_effect=fake_urlopen)
    result = configured_client.request(
        "POST",
        REQUEST_PATH,
        {"fields": {"summary": "x"}},
    )

    request = cast(urllib.request.Request, captured_request["request"])
    assert result == {"key": "PROJ-123"}
    assert request.full_url == REQUEST_URL
    assert request.get_method() == "POST"
    assert json.loads(cast(bytes, request.data).decode()) == {
        "fields": {"summary": "x"}
    }
    assert _request_headers(request)["authorization"] == f"Bearer {TEST_PAT}"


def test_request_returns_none_for_empty_body(
    configured_client: jira.JiraClient,
    response_factory: ResponseFactory,
    mocker: MockerFixture,
) -> None:
    mocker.patch("jira._OPENER.open", return_value=response_factory("   "))
    assert configured_client.request("GET", REQUEST_PATH) is None


def test_request_returns_plain_text_for_non_json_response(
    configured_client: jira.JiraClient,
    response_factory: ResponseFactory,
    mocker: MockerFixture,
) -> None:
    mocker.patch("jira._OPENER.open", return_value=response_factory("plain text"))
    assert configured_client.request("GET", REQUEST_PATH) == "plain text"


@pytest.mark.parametrize(
    ("body", "expected_detail"),
    [
        ('{"errorMessages": ["not allowed"]}', "not allowed"),
        ('{"errors": {"summary": "required"}}', "summary: required"),
        ("raw failure", "raw failure"),
    ],
)
def test_request_translates_http_error_details(
    configured_client: jira.JiraClient,
    http_error_factory: HttpErrorFactory,
    mocker: MockerFixture,
    body: str,
    expected_detail: str,
) -> None:
    error = http_error_factory(body, code=400, url=REQUEST_URL)

    mocker.patch("jira._OPENER.open", side_effect=error)
    with pytest.raises(jira.ScriptError) as exc_info:
        configured_client.request("GET", REQUEST_PATH)

    assert str(exc_info.value) == f"HTTP 400 from GET {REQUEST_URL}: {expected_detail}"


@pytest.mark.parametrize("code", [401, 403])
def test_request_adds_rotation_hint_on_auth_error(
    configured_client: jira.JiraClient,
    http_error_factory: HttpErrorFactory,
    mocker: MockerFixture,
    code: int,
) -> None:
    error = http_error_factory("denied", code=code, url=REQUEST_URL)

    mocker.patch("jira._OPENER.open", side_effect=error)
    with pytest.raises(jira.ScriptError) as exc_info:
        configured_client.request("GET", REQUEST_PATH)

    message = str(exc_info.value)
    assert f"HTTP {code}" in message
    assert "expired or revoked" in message
    assert "JIRA_API_TOKEN" in message


def test_request_rejects_missing_content_type(
    configured_client: jira.JiraClient,
    mocker: MockerFixture,
) -> None:
    mocker.patch(
        "jira._OPENER.open",
        return_value=jira._create_response_with_body('{"ok": true}', content_type=""),
    )

    with pytest.raises(jira.ScriptError) as exc_info:
        configured_client.request("GET", REQUEST_PATH)

    assert exc_info.value.exit_code == jira.EXIT_FAILURE
    assert "Missing Content-Type" in str(exc_info.value)


def test_request_allows_empty_body_without_content_type(
    configured_client: jira.JiraClient,
    mocker: MockerFixture,
) -> None:
    mocker.patch(
        "jira._OPENER.open",
        return_value=jira._create_response_with_body("", content_type=""),
    )

    assert configured_client.request("POST", REQUEST_PATH) is None


def test_request_rejects_non_json_content_type(
    configured_client: jira.JiraClient,
    mocker: MockerFixture,
) -> None:
    mocker.patch(
        "jira._OPENER.open",
        return_value=jira._create_response_with_body(
            '{"ok": true}',
            content_type="text/plain",
        ),
    )

    with pytest.raises(jira.ScriptError) as exc_info:
        configured_client.request("GET", REQUEST_PATH)

    assert exc_info.value.exit_code == jira.EXIT_FAILURE
    assert "Unexpected content type" in str(exc_info.value)


def test_request_allows_json_content_type(
    configured_client: jira.JiraClient,
    mocker: MockerFixture,
) -> None:
    mocker.patch(
        "jira._OPENER.open",
        return_value=jira._create_response_with_body(
            '{"ok": true}',
            content_type="application/json",
        ),
    )

    assert configured_client.request("GET", REQUEST_PATH) == {"ok": True}


def test_request_translates_url_error(
    configured_client: jira.JiraClient,
    mocker: MockerFixture,
) -> None:
    mocker.patch(
        "jira._OPENER.open",
        side_effect=urllib.error.URLError("network down"),
    )
    with pytest.raises(jira.ScriptError) as exc_info:
        configured_client.request("GET", REQUEST_PATH)

    assert str(exc_info.value) == (
        f"Could not reach Jira API at {REQUEST_URL}: network down"
    )


def test_request_blocks_redirects(
    configured_client: jira.JiraClient,
    mocker: MockerFixture,
) -> None:
    def fake_open(request: urllib.request.Request, timeout: int) -> object:
        raise urllib.error.HTTPError(
            url=request.full_url,
            code=302,
            msg="Found",
            hdrs={"Location": "https://evil.example"},
            fp=io.BytesIO(b""),
        )

    mocker.patch("jira._OPENER.open", side_effect=fake_open)

    with pytest.raises(jira.ScriptError) as exc_info:
        configured_client.request("GET", REQUEST_PATH)

    assert "redirect" in str(exc_info.value).lower()


def test_from_environment_rejects_insecure_http_urls(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("JIRA_BASE_URL", "http://jira.example.com")

    with pytest.raises(jira.ScriptError) as exc_info:
        jira.JiraClient.from_environment()

    assert exc_info.value.exit_code == jira.EXIT_USAGE
    assert "https" in str(exc_info.value)


def test_request_passes_timeout_to_opener(
    configured_client: jira.JiraClient,
    mocker: MockerFixture,
) -> None:
    captured: dict[str, object] = {}

    def fake_open(request: urllib.request.Request, timeout: int) -> object:
        captured["timeout"] = timeout
        return jira._create_response_with_body(
            '{"ok": true}',
            content_type="application/json",
        )

    mocker.patch("jira._OPENER.open", side_effect=fake_open)

    configured_client.request("GET", REQUEST_PATH)

    assert captured["timeout"] == jira.REQUEST_TIMEOUT_SECONDS


def test_request_rejects_oversize_responses(
    configured_client: jira.JiraClient,
    mocker: MockerFixture,
) -> None:
    body = b"x" * (jira.MAX_BODY_BYTES + 1)
    response = jira._create_response_with_body(body, content_type="application/json")
    mocker.patch("jira._OPENER.open", return_value=response)

    with pytest.raises(jira.ScriptError) as exc_info:
        configured_client.request("GET", REQUEST_PATH)

    assert "too large" in str(exc_info.value).lower()


def test_handle_fields_quotes_project_key() -> None:
    client = ClientRecorder()
    args = SimpleNamespace(project_key="PROJ/ABC", issue_type_id=None)

    jira.handle_fields(client, args)

    assert client.calls[0].path == "/issue/createmeta/PROJ%2FABC/issuetypes"


def test_handle_search_clamps_max_results() -> None:
    client = ClientRecorder()
    args = SimpleNamespace(max_results=250, jql="project = PROJ", fields=None)

    jira.handle_search(client, args)

    assert client.calls[0].path.startswith(
        "/search?jql=project%20%3D%20PROJ&maxResults=100"
    )


def test_request_redacts_error_details(
    configured_client: jira.JiraClient,
    mocker: MockerFixture,
) -> None:
    def fake_open(request: urllib.request.Request, timeout: int) -> object:
        raise urllib.error.HTTPError(
            url=request.full_url,
            code=400,
            msg="Bad Request",
            hdrs={"Content-Type": "application/json"},
            fp=io.BytesIO(
                b'{"errorMessages": ["Authorization: Bearer super-secret-token"]}'
            ),
        )

    mocker.patch("jira._OPENER.open", side_effect=fake_open)

    with pytest.raises(jira.ScriptError) as exc_info:
        configured_client.request("GET", REQUEST_PATH)

    message = str(exc_info.value)
    assert "super-secret-token" not in message
    assert "[REDACTED]" in message


def test_request_truncates_and_redacts_long_error_preview(
    configured_client: jira.JiraClient,
    mocker: MockerFixture,
) -> None:
    body = "Authorization: Bearer super-secret-token " + ("x" * 3000)

    def fake_open(request: urllib.request.Request, timeout: int) -> object:
        raise urllib.error.HTTPError(
            url=request.full_url,
            code=400,
            msg="Bad Request",
            hdrs={"Content-Type": "application/json"},
            fp=io.BytesIO(body.encode("utf-8")),
        )

    mocker.patch("jira._OPENER.open", side_effect=fake_open)

    with pytest.raises(jira.ScriptError) as exc_info:
        configured_client.request("GET", REQUEST_PATH)

    message = str(exc_info.value)
    assert "super-secret-token" not in message
    assert "[REDACTED]" in message
    assert "..." in message
