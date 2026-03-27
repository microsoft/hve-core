# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Shared fixtures for GitLab skill tests."""

from __future__ import annotations

import io
import urllib.error
from collections.abc import Callable
from dataclasses import dataclass, field
from email.message import Message
from types import ModuleType
from typing import Literal

import pytest
from test_constants import TEST_API_URL, TEST_GITLAB_TOKEN, TEST_GITLAB_URL

import gitlab


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
    """Captured invocation of gitlab.request."""

    method: str
    url: str
    data: object | None
    quiet: bool


@dataclass
class RequestRecorder:
    """Callable test double that records request calls."""

    response: object | None = None
    calls: list[RecordedCall] = field(default_factory=list)

    def __call__(
        self,
        method: str,
        url: str,
        data: object | None = None,
        quiet: bool = False,
    ) -> object | None:
        self.calls.append(RecordedCall(method=method, url=url, data=data, quiet=quiet))
        return self.response


ConfiguredGitLab = ModuleType
ResponseFactory = Callable[[str], FakeHttpResponse]
StdinFactory = Callable[[str], None]
HttpErrorFactory = Callable[[str, int, str], urllib.error.HTTPError]


@pytest.fixture(autouse=True)
def reset_gitlab_state(monkeypatch: pytest.MonkeyPatch) -> None:
    """Reset module globals and seed environment variables for each test."""
    gitlab.selected_fields = None
    gitlab.gitlab_url = ""
    gitlab.gitlab_token = ""
    gitlab.api_url = ""

    monkeypatch.setenv("GITLAB_URL", TEST_GITLAB_URL)
    monkeypatch.setenv("GITLAB_TOKEN", TEST_GITLAB_TOKEN)
    monkeypatch.delenv("GITLAB_PROJECT", raising=False)


@pytest.fixture
def configured_gitlab() -> ConfiguredGitLab:
    """Return the gitlab module with configured API globals."""
    gitlab.gitlab_url = TEST_GITLAB_URL
    gitlab.gitlab_token = TEST_GITLAB_TOKEN
    gitlab.api_url = TEST_API_URL
    return gitlab


@pytest.fixture
def http_error_factory() -> HttpErrorFactory:
    """Return a factory for urllib HTTPError objects with readable bodies."""

    def _factory(
        body: str, code: int = 400, url: str = TEST_API_URL
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
def response_factory() -> ResponseFactory:
    """Return a factory for minimal HTTP response stubs."""

    def _factory(body: str) -> FakeHttpResponse:
        return FakeHttpResponse(body)

    return _factory


@pytest.fixture
def request_recorder() -> RequestRecorder:
    """Return a recording request double for command tests."""
    return RequestRecorder()


@pytest.fixture
def stdin_factory(monkeypatch: pytest.MonkeyPatch) -> StdinFactory:
    """Return a helper that replaces stdin with text content."""

    def _factory(text: str) -> None:
        monkeypatch.setattr("sys.stdin", io.StringIO(text))

    return _factory
