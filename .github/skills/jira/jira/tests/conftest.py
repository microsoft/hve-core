"""Shared fixtures for Jira skill tests."""

from __future__ import annotations

import io
import urllib.error
from collections.abc import Callable
from dataclasses import dataclass, field
from email.message import Message
from typing import Literal, cast

import jira
import pytest
from test_constants import (
    TEST_API_TOKEN,
    TEST_BASE_URL,
    TEST_PAT,
    TEST_USER_EMAIL,
)


class FakeHttpResponse:
    """Minimal HTTP response stub for urllib tests."""

    def __init__(self, body: str) -> None:
        self._body = body.encode()

    def __enter__(self) -> "FakeHttpResponse":
        return self

    def __exit__(self, exc_type: object, exc: object, tb: object) -> Literal[False]:
        return False

    def read(self) -> bytes:
        return self._body


@dataclass
class RecordedCall:
    """Captured client request call."""

    method: str
    path: str
    data: object | None


@dataclass
class ClientRecorder:
    """Simple fake Jira client for handler tests."""

    use_legacy_search: bool = True
    responses: list[object | None] = field(default_factory=list)
    calls: list[RecordedCall] = field(default_factory=list)

    def request(
        self,
        method: str,
        path: str,
        data: object | None = None,
    ) -> object | None:
        self.calls.append(RecordedCall(method=method, path=path, data=data))
        if self.responses:
            return self.responses.pop(0)
        return None


ResponseFactory = Callable[[str], FakeHttpResponse]
StdinFactory = Callable[[str], None]
HttpErrorFactory = Callable[[str, int, str], urllib.error.HTTPError]


@pytest.fixture(autouse=True)
def reset_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    """Seed a stable environment for Jira tests."""
    monkeypatch.setenv("JIRA_BASE_URL", TEST_BASE_URL)
    monkeypatch.delenv("JIRA_PAT", raising=False)
    monkeypatch.delenv("JIRA_USER_EMAIL", raising=False)
    monkeypatch.delenv("JIRA_API_TOKEN", raising=False)


@pytest.fixture
def configured_server_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    """Configure PAT-based Jira authentication."""
    monkeypatch.setenv("JIRA_PAT", TEST_PAT)


@pytest.fixture
def configured_cloud_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    """Configure email-plus-token Jira authentication."""
    monkeypatch.setenv("JIRA_USER_EMAIL", TEST_USER_EMAIL)
    monkeypatch.setenv("JIRA_API_TOKEN", TEST_API_TOKEN)


@pytest.fixture
def response_factory() -> ResponseFactory:
    """Return a factory for minimal HTTP response stubs."""

    def _factory(body: str) -> FakeHttpResponse:
        return FakeHttpResponse(body)

    return _factory


@pytest.fixture
def http_error_factory() -> HttpErrorFactory:
    """Return a factory for HTTPError objects with readable bodies."""

    def _factory(
        body: str,
        code: int = 400,
        url: str = "https://jira.example.com/rest/api/2/test",
    ) -> urllib.error.HTTPError:
        return urllib.error.HTTPError(
            url=url,
            code=code,
            msg="error",
            hdrs=Message(),
            fp=io.BytesIO(body.encode()),
        )

    return _factory


@pytest.fixture
def stdin_factory(monkeypatch: pytest.MonkeyPatch) -> StdinFactory:
    """Return a helper that replaces stdin with text content."""

    def _factory(text: str) -> None:
        monkeypatch.setattr("sys.stdin", io.StringIO(text))

    return _factory


@pytest.fixture
def client_recorder() -> ClientRecorder:
    """Return a recording Jira client for handler tests."""
    return ClientRecorder()


@pytest.fixture
def handler_client(client_recorder: ClientRecorder) -> jira.JiraClient:
    """Return the recorder cast to the Jira client surface used by handlers."""
    return cast(jira.JiraClient, client_recorder)


@pytest.fixture
def configured_client(configured_server_environment: None) -> jira.JiraClient:
    """Return a server-auth Jira client from the environment."""
    return jira.JiraClient.from_environment()
