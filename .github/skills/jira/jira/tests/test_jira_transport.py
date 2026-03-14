"""Transport and environment tests for jira.py."""

from __future__ import annotations

import base64
import json
import urllib.error
import urllib.request
from typing import cast
from unittest.mock import patch

import jira
import pytest
from conftest import HttpErrorFactory, ResponseFactory
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
    encoded = base64.b64encode(
        f"{TEST_USER_EMAIL}:{TEST_API_TOKEN}".encode()).decode()

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


def test_request_returns_parsed_json(
    configured_client: jira.JiraClient,
    response_factory: ResponseFactory,
) -> None:
    captured_request: dict[str, urllib.request.Request] = {}

    def fake_urlopen(request: urllib.request.Request) -> object:
        captured_request["request"] = request
        return response_factory('{"key": "PROJ-123"}')

    with patch("urllib.request.urlopen", side_effect=fake_urlopen):
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
) -> None:
    with patch("urllib.request.urlopen", return_value=response_factory("   ")):
        assert configured_client.request("GET", REQUEST_PATH) is None


def test_request_returns_plain_text_for_non_json_response(
    configured_client: jira.JiraClient,
    response_factory: ResponseFactory,
) -> None:
    with patch("urllib.request.urlopen", return_value=response_factory("plain text")):
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
    body: str,
    expected_detail: str,
) -> None:
    error = http_error_factory(body, code=403, url=REQUEST_URL)

    with patch("urllib.request.urlopen", side_effect=error):
        with pytest.raises(jira.ScriptError) as exc_info:
            configured_client.request("GET", REQUEST_PATH)

    assert str(
        exc_info.value) == f"HTTP 403 from GET {REQUEST_URL}: {expected_detail}"


def test_request_translates_url_error(configured_client: jira.JiraClient) -> None:
    with patch(
        "urllib.request.urlopen",
        side_effect=urllib.error.URLError("network down"),
    ):
        with pytest.raises(jira.ScriptError) as exc_info:
            configured_client.request("GET", REQUEST_PATH)

    assert str(exc_info.value) == (
        f"Could not reach Jira API at {REQUEST_URL}: network down"
    )
