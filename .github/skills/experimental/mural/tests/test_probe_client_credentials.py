# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Tests for `_probe_client_credentials` (Phase C.3) and bootstrap probe gating."""

from __future__ import annotations

import argparse
import urllib.parse
from typing import Any

import pytest
from test_constants import TEST_CLIENT_ID, TEST_CLIENT_SECRET, TEST_TOKEN_URL

# ---------------------------------------------------------------------------
# Direct unit tests for _probe_client_credentials
# ---------------------------------------------------------------------------


def test_probe_returns_true_on_2xx(
    mural_module: Any, recorded_http: Any, response_factory: Any
) -> None:
    recorded_http.responses.append(
        response_factory(
            b"{}",
            status=200,
            headers={"Content-Type": "application/json"},
        )
    )
    ok, message = mural_module._probe_client_credentials(
        TEST_CLIENT_ID,
        TEST_CLIENT_SECRET,
        token_url=TEST_TOKEN_URL,
        _http=recorded_http,
    )
    assert ok is True
    assert message == "credentials accepted by Mural"


def test_probe_returns_true_on_204(
    mural_module: Any, recorded_http: Any, response_factory: Any
) -> None:
    recorded_http.responses.append(response_factory(b"", status=204, headers={}))
    ok, message = mural_module._probe_client_credentials(
        TEST_CLIENT_ID,
        TEST_CLIENT_SECRET,
        token_url=TEST_TOKEN_URL,
        _http=recorded_http,
    )
    assert ok is True
    assert message == "credentials accepted by Mural"


def test_probe_returns_false_on_401(
    mural_module: Any, recorded_http: Any, http_error_factory: Any
) -> None:
    recorded_http.responses.append(
        http_error_factory(b'{"error":"invalid_client"}', code=401)
    )
    ok, message = mural_module._probe_client_credentials(
        TEST_CLIENT_ID,
        TEST_CLIENT_SECRET,
        token_url=TEST_TOKEN_URL,
        _http=recorded_http,
    )
    assert ok is False
    assert message == "credentials rejected by Mural (HTTP 401)"


def test_probe_returns_false_on_400(
    mural_module: Any, recorded_http: Any, http_error_factory: Any
) -> None:
    recorded_http.responses.append(
        http_error_factory(b'{"error":"invalid_request"}', code=400)
    )
    ok, message = mural_module._probe_client_credentials(
        TEST_CLIENT_ID,
        TEST_CLIENT_SECRET,
        token_url=TEST_TOKEN_URL,
        _http=recorded_http,
    )
    assert ok is False
    assert "rejected" in message
    assert "HTTP 400" in message


def test_probe_returns_false_on_url_error(
    mural_module: Any, recorded_http: Any
) -> None:
    import urllib.error

    recorded_http.responses.append(urllib.error.URLError("dns failure"))
    ok, message = mural_module._probe_client_credentials(
        TEST_CLIENT_ID,
        TEST_CLIENT_SECRET,
        token_url=TEST_TOKEN_URL,
        _http=recorded_http,
    )
    assert ok is False
    assert message == "could not reach Mural; rerun with --no-test to skip probing"


def test_probe_returns_false_on_timeout(mural_module: Any, recorded_http: Any) -> None:
    recorded_http.responses.append(TimeoutError("read timed out"))
    ok, message = mural_module._probe_client_credentials(
        TEST_CLIENT_ID,
        TEST_CLIENT_SECRET,
        token_url=TEST_TOKEN_URL,
        _http=recorded_http,
    )
    assert ok is False
    assert message == "could not reach Mural; rerun with --no-test to skip probing"


def test_probe_returns_false_on_oserror(mural_module: Any, recorded_http: Any) -> None:
    recorded_http.responses.append(OSError("broken pipe"))
    ok, message = mural_module._probe_client_credentials(
        TEST_CLIENT_ID,
        TEST_CLIENT_SECRET,
        token_url=TEST_TOKEN_URL,
        _http=recorded_http,
    )
    assert ok is False
    assert message == "could not reach Mural; rerun with --no-test to skip probing"


def test_probe_request_body_uses_client_credentials_grant(
    mural_module: Any, recorded_http: Any, response_factory: Any
) -> None:
    recorded_http.responses.append(response_factory(b"{}", status=200, headers={}))
    mural_module._probe_client_credentials(
        TEST_CLIENT_ID,
        TEST_CLIENT_SECRET,
        token_url=TEST_TOKEN_URL,
        _http=recorded_http,
    )
    call = recorded_http.calls[0]
    assert call.method == "POST"
    body = dict(urllib.parse.parse_qsl(call.data.decode("ascii")))
    assert body["grant_type"] == "client_credentials"
    assert body["client_id"] == TEST_CLIENT_ID
    assert body["client_secret"] == TEST_CLIENT_SECRET
    assert body["scope"] == mural_module.DEFAULT_LOGIN_SCOPES


def test_probe_request_headers_set_form_and_user_agent(
    mural_module: Any, recorded_http: Any, response_factory: Any
) -> None:
    recorded_http.responses.append(response_factory(b"{}", status=200, headers={}))
    mural_module._probe_client_credentials(
        TEST_CLIENT_ID,
        TEST_CLIENT_SECRET,
        token_url=TEST_TOKEN_URL,
        _http=recorded_http,
    )
    headers = recorded_http.calls[0].headers
    content_type = headers.get("Content-Type") or headers.get("Content-type")
    accept = headers.get("Accept")
    user_agent = headers.get("User-Agent") or headers.get("User-agent")
    assert content_type == "application/x-www-form-urlencoded"
    assert accept == "application/json"
    assert user_agent == mural_module.USER_AGENT


def test_probe_messages_never_leak_secret_or_url(
    mural_module: Any, recorded_http: Any, http_error_factory: Any
) -> None:
    recorded_http.responses.append(
        http_error_factory(b'{"error":"invalid_client"}', code=401)
    )
    ok, message = mural_module._probe_client_credentials(
        TEST_CLIENT_ID,
        TEST_CLIENT_SECRET,
        token_url=TEST_TOKEN_URL,
        _http=recorded_http,
    )
    assert ok is False
    assert TEST_CLIENT_SECRET not in message
    assert TEST_CLIENT_ID not in message
    assert TEST_TOKEN_URL not in message
    assert "Authorization" not in message
    assert "invalid_client" not in message  # no upstream body leakage


# ---------------------------------------------------------------------------
# Bootstrap Stage 7 integration: --no-test gating + failure path
# ---------------------------------------------------------------------------


class _RecordingProbe:
    def __init__(self, result: tuple[bool, str]) -> None:
        self.result = result
        self.calls: list[tuple[str, str]] = []

    def __call__(self, client_id: str, client_secret: str) -> tuple[bool, str]:
        self.calls.append((client_id, client_secret))
        return self.result


@pytest.fixture
def _interactive_bootstrap(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    fake_token_store: Any,
    tmp_path: Any,
) -> Any:
    """Configure environment so `_cmd_auth_bootstrap` reaches Stage 7."""
    monkeypatch.setattr(mural_module, "_bootstrap_is_interactive", lambda: True)
    # Use file backend (no keyring) and isolate the credential file per test.
    monkeypatch.setenv("MURAL_CREDENTIAL_BACKEND", "file")
    monkeypatch.setenv("MURAL_ENV_FILE", str(tmp_path / "mural.default.env"))
    monkeypatch.setattr("builtins.input", lambda prompt="": TEST_CLIENT_ID)
    monkeypatch.setattr(
        mural_module.getpass,
        "getpass",
        lambda prompt="": TEST_CLIENT_SECRET,
    )
    # No-op browser open so suite is hermetic.
    monkeypatch.setattr(
        mural_module.webbrowser, "open", lambda url, *args, **kwargs: True
    )
    return mural_module


def test_bootstrap_no_test_flag_skips_probe(
    _interactive_bootstrap: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    probe = _RecordingProbe((True, "credentials accepted by Mural"))
    monkeypatch.setattr(_interactive_bootstrap, "_probe_client_credentials", probe)
    args = argparse.Namespace(profile=None, force=False, no_test=True)
    rc = _interactive_bootstrap._cmd_auth_bootstrap(args)
    assert rc == _interactive_bootstrap.EXIT_SUCCESS
    assert probe.calls == []


def test_bootstrap_runs_probe_by_default(
    _interactive_bootstrap: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    probe = _RecordingProbe((True, "credentials accepted by Mural"))
    monkeypatch.setattr(_interactive_bootstrap, "_probe_client_credentials", probe)
    args = argparse.Namespace(profile=None, force=False, no_test=False)
    rc = _interactive_bootstrap._cmd_auth_bootstrap(args)
    assert rc == _interactive_bootstrap.EXIT_SUCCESS
    assert probe.calls == [(TEST_CLIENT_ID, TEST_CLIENT_SECRET)]


def test_bootstrap_failed_probe_returns_failure_with_hint(
    _interactive_bootstrap: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    probe = _RecordingProbe((False, "credentials rejected by Mural (HTTP 401)"))
    monkeypatch.setattr(_interactive_bootstrap, "_probe_client_credentials", probe)
    args = argparse.Namespace(profile=None, force=False, no_test=False)
    rc = _interactive_bootstrap._cmd_auth_bootstrap(args)
    assert rc == _interactive_bootstrap.EXIT_FAILURE
    captured = capsys.readouterr()
    combined = captured.out + captured.err
    assert "credentials rejected by Mural (HTTP 401)" in combined
    assert "mural auth bootstrap --no-test" in combined
