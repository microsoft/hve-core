# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Shared fixtures for GitLab skill tests."""

from __future__ import annotations

import io
import os
import pathlib
import urllib.error
from collections.abc import Callable
from contextlib import contextmanager
from copy import deepcopy
from dataclasses import dataclass, field
from email.message import Message
from types import ModuleType
from typing import Any, Iterator, Literal

import gitlab
import pytest
from coverage import Coverage
from pytest_cov.plugin import CovPlugin
from pytest_mock import MockerFixture
from test_constants import TEST_API_URL, TEST_GITLAB_TOKEN, TEST_GITLAB_URL


class FakeHttpResponse:
    """Minimal HTTP response stub for urllib tests."""

    def __init__(self, body: str) -> None:
        self._body = body.encode()

    def __enter__(self) -> "FakeHttpResponse":
        return self

    def __exit__(self, exc_type: object, exc: object, tb: object) -> Literal[False]:
        return False

    def read(self, amount: int | None = None) -> bytes:
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


_POSIX_STORE = r"^def (?:_validate_descriptor|load_store|save_store|store_lock)\("


@pytest.hookimpl(trylast=True)
def pytest_sessionstart(session: pytest.Session) -> None:
    """Exclude unsupported POSIX store functions from Windows coverage only."""
    if os.name != "nt" or session.config.getoption("no_cov"):
        return
    coverage = Coverage.current()
    if coverage is None:
        raise RuntimeError("Windows coverage requires an active pytest-cov session")
    coverage.exclude(_POSIX_STORE)
    plugin = session.config.pluginmanager.get_plugin("_cov")
    if not isinstance(plugin, CovPlugin) or plugin.cov_controller is None:
        raise RuntimeError("Windows coverage requires a pytest-cov report session")
    report_coverage = plugin.cov_controller.combining_cov
    if report_coverage is None:
        raise RuntimeError("Windows coverage requires a combined pytest-cov report")
    # pytest-cov reports from a separate combined Coverage instance.
    report_coverage.exclude(_POSIX_STORE)


@pytest.fixture(autouse=True)
def reset_gitlab_state(monkeypatch: pytest.MonkeyPatch) -> None:
    """Reset module globals and seed environment variables for each test."""
    gitlab.selected_fields = None
    gitlab.gitlab_url = ""
    gitlab.api_url = ""
    gitlab.auth_context = None

    monkeypatch.setenv("GITLAB_URL", TEST_GITLAB_URL)
    monkeypatch.setenv("GITLAB_TOKEN", TEST_GITLAB_TOKEN)
    monkeypatch.setenv("GITLAB_AUTH_MODE", "legacy-token")
    monkeypatch.delenv("GITLAB_PROJECT", raising=False)
    monkeypatch.delenv("GITLAB_OAUTH_CLIENT_ID", raising=False)
    monkeypatch.delenv("GITLAB_PROFILE", raising=False)
    monkeypatch.delenv("GITLAB_TOKEN_STORE", raising=False)


@pytest.fixture()
def memory_oauth_store(mocker: MockerFixture) -> None:
    """Keep OAuth behavior tests independent of protected file persistence."""
    stores: dict[pathlib.Path, dict[str, Any]] = {}

    def load(path: pathlib.Path) -> dict[str, Any]:
        return deepcopy(
            stores.get(
                path,
                {"schema_version": gitlab.credentials.SCHEMA_VERSION, "profiles": {}},
            )
        )

    def save(path: pathlib.Path, payload: dict[str, Any]) -> None:
        stores[path] = deepcopy(payload)

    @contextmanager
    def lock(_path: pathlib.Path) -> Iterator[None]:
        yield

    mocker.patch.object(gitlab.credentials, "load_store", side_effect=load)
    mocker.patch.object(gitlab.credentials, "save_store", side_effect=save)
    mocker.patch.object(gitlab.credentials, "store_lock", side_effect=lock)


@pytest.fixture
def configured_gitlab() -> ConfiguredGitLab:
    """Return the gitlab module with configured API globals."""
    gitlab.gitlab_url = TEST_GITLAB_URL
    gitlab.api_url = TEST_API_URL
    gitlab.auth_context = gitlab.AuthContext(
        mode="legacy-token",
        issuer=TEST_GITLAB_URL,
        token=TEST_GITLAB_TOKEN,
    )
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
