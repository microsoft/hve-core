# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Shared fixtures for Mural skill tests."""

from __future__ import annotations

import importlib
import io
import os
import pathlib
import urllib.error
from collections.abc import Callable
from dataclasses import dataclass, field
from email.message import Message
from typing import Any, Literal

import pytest
from test_constants import (
    ENV_BASE_URL,
    ENV_CLIENT_ID,
    ENV_CLIENT_SECRET,
    ENV_REDIRECT_URI,
    ENV_TOKEN_STORE,
    MURAL_ENV_VARS,
    TEST_BASE_URL,
    TEST_CLIENT_ID,
    TEST_CLIENT_SECRET,
    TEST_REDIRECT_URI,
)


class FakeHttpResponse:
    """Minimal HTTP response stub mirroring `urllib` context-manager semantics."""

    def __init__(
        self,
        body: bytes | str = b"",
        *,
        status: int = 200,
        headers: dict[str, str] | None = None,
    ) -> None:
        if isinstance(body, str):
            body = body.encode("utf-8")
        self._body = body
        self.status = status
        msg = Message()
        for key, value in (headers or {}).items():
            msg[key] = value
        self.headers = msg

    def __enter__(self) -> "FakeHttpResponse":
        return self

    def __exit__(self, exc_type: object, exc: object, tb: object) -> Literal[False]:
        return False

    def read(self) -> bytes:
        return self._body


@dataclass
class RecordedHttpCall:
    """Captured HTTP request issued through the `_http` seam."""

    method: str
    url: str
    headers: dict[str, str]
    data: bytes | None


@dataclass
class HttpRecorder:
    """Callable seam that records requests and returns queued responses."""

    responses: list[Any] = field(default_factory=list)
    calls: list[RecordedHttpCall] = field(default_factory=list)

    def __call__(self, request: Any, *args: Any, **kwargs: Any) -> Any:
        method = getattr(request, "get_method", lambda: "GET")()
        url = getattr(request, "full_url", getattr(request, "url", ""))
        raw_headers = getattr(request, "headers", {}) or {}
        headers = {str(k): str(v) for k, v in dict(raw_headers).items()}
        data = getattr(request, "data", None)
        self.calls.append(
            RecordedHttpCall(method=method, url=url, headers=headers, data=data)
        )
        if not self.responses:
            raise AssertionError(f"no queued response for {method} {url}")
        outcome = self.responses.pop(0)
        if isinstance(outcome, BaseException):
            raise outcome
        return outcome


ResponseFactory = Callable[..., FakeHttpResponse]
HttpErrorFactory = Callable[..., urllib.error.HTTPError]
StdinFactory = Callable[[str], None]


@pytest.fixture(autouse=True)
def reset_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    """Strip Mural env vars and seed deterministic defaults."""
    for var in MURAL_ENV_VARS:
        monkeypatch.delenv(var, raising=False)
    monkeypatch.setenv(ENV_BASE_URL, TEST_BASE_URL)
    monkeypatch.setenv(ENV_CLIENT_ID, TEST_CLIENT_ID)
    monkeypatch.setenv(ENV_CLIENT_SECRET, TEST_CLIENT_SECRET)
    monkeypatch.setenv(ENV_REDIRECT_URI, TEST_REDIRECT_URI)


@pytest.fixture
def mural_module() -> Any:
    """Import the `mural` script module fresh for each test."""
    import mural

    return importlib.reload(mural)


@pytest.fixture
def fake_token_store(
    tmp_path: pathlib.Path, monkeypatch: pytest.MonkeyPatch
) -> pathlib.Path:
    """Provide a temp token-store path with mode 0600 and wire `MURAL_TOKEN_STORE`."""
    store_path = tmp_path / "mural-token.json"
    fd = os.open(str(store_path), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    try:
        os.write(fd, b"{}")
    finally:
        os.close(fd)
    os.chmod(store_path, 0o600)
    monkeypatch.setenv(ENV_TOKEN_STORE, str(store_path))
    return store_path


@pytest.fixture
def fake_now() -> Callable[[], float]:
    """Return a deterministic `time.time()` replacement."""
    state = {"value": 1_700_000_000.0}

    def _now() -> float:
        return state["value"]

    _now.advance = lambda delta: state.update(value=state["value"] + float(delta))  # type: ignore[attr-defined]
    _now.set = lambda value: state.update(value=float(value))  # type: ignore[attr-defined]
    return _now


@pytest.fixture
def response_factory() -> ResponseFactory:
    """Return a factory for `FakeHttpResponse` objects."""

    def _factory(
        body: bytes | str = b"",
        *,
        status: int = 200,
        headers: dict[str, str] | None = None,
    ) -> FakeHttpResponse:
        return FakeHttpResponse(body, status=status, headers=headers)

    return _factory


@pytest.fixture
def http_error_factory() -> HttpErrorFactory:
    """Return a factory for `urllib.error.HTTPError` instances."""

    def _factory(
        body: bytes | str = b"",
        *,
        code: int = 400,
        url: str = f"{TEST_BASE_URL}/test",
        headers: dict[str, str] | None = None,
    ) -> urllib.error.HTTPError:
        if isinstance(body, str):
            body = body.encode("utf-8")
        msg = Message()
        for key, value in (headers or {}).items():
            msg[key] = value
        return urllib.error.HTTPError(
            url=url,
            code=code,
            msg="error",
            hdrs=msg,
            fp=io.BytesIO(body),
        )

    return _factory


@pytest.fixture
def recorded_http() -> HttpRecorder:
    """Return a recording HTTP seam that can be injected via `_http=...`."""
    return HttpRecorder()


@pytest.fixture
def stdin_factory(monkeypatch: pytest.MonkeyPatch) -> StdinFactory:
    """Return a helper that replaces `sys.stdin` with text content."""

    def _factory(text: str) -> None:
        monkeypatch.setattr("sys.stdin", io.StringIO(text))

    return _factory
