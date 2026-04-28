# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""OAuth Authorization Code + PKCE loopback flow tests."""

from __future__ import annotations

import io
import json
import pathlib
import threading
import urllib.parse
from typing import Any

import pytest
from test_constants import (
    TEST_ACCESS_TOKEN,
    TEST_AUTH_CODE,
    TEST_CLIENT_ID,
    TEST_CLIENT_SECRET,
    TEST_CODE_VERIFIER,
    TEST_REDIRECT_URI,
    TEST_REFRESH_TOKEN,
    TEST_STATE,
)

# ---------------------------------------------------------------------------
# _build_authorize_url
# ---------------------------------------------------------------------------


def test_build_authorize_url_emits_pkce_s256_query(mural_module: Any) -> None:
    url = mural_module._build_authorize_url(
        client_id=TEST_CLIENT_ID,
        redirect_uri=TEST_REDIRECT_URI,
        state=TEST_STATE,
        code_challenge="challenge-value",
        scopes=mural_module.DEFAULT_SCOPES,
    )
    parsed = urllib.parse.urlsplit(url)
    params = dict(urllib.parse.parse_qsl(parsed.query))
    assert params["response_type"] == "code"
    assert params["client_id"] == TEST_CLIENT_ID
    assert params["redirect_uri"] == TEST_REDIRECT_URI
    assert params["state"] == TEST_STATE
    assert params["code_challenge"] == "challenge-value"
    assert params["code_challenge_method"] == "S256"
    assert params["scope"] == mural_module.DEFAULT_SCOPES


@pytest.mark.parametrize(
    "missing",
    ["client_id", "redirect_uri", "state", "code_challenge"],
)
def test_build_authorize_url_rejects_missing_required(
    mural_module: Any, missing: str
) -> None:
    kwargs = {
        "client_id": TEST_CLIENT_ID,
        "redirect_uri": TEST_REDIRECT_URI,
        "state": TEST_STATE,
        "code_challenge": "challenge-value",
        "scopes": mural_module.DEFAULT_SCOPES,
    }
    kwargs[missing] = ""
    with pytest.raises(mural_module.MuralError):
        mural_module._build_authorize_url(**kwargs)


# ---------------------------------------------------------------------------
# _exchange_authorization_code
# ---------------------------------------------------------------------------


def _token_payload(**overrides: Any) -> bytes:
    body = {
        "access_token": TEST_ACCESS_TOKEN,
        "refresh_token": TEST_REFRESH_TOKEN,
        "scope": "murals:read",
        "token_type": "Bearer",
        "expires_in": 3600,
    }
    body.update(overrides)
    return json.dumps(body).encode("utf-8")


def test_exchange_authorization_code_happy_path(
    mural_module: Any, recorded_http: Any, response_factory: Any, fake_now: Any
) -> None:
    recorded_http.responses.append(response_factory(_token_payload(), status=200))

    record = mural_module._exchange_authorization_code(
        code=TEST_AUTH_CODE,
        code_verifier=TEST_CODE_VERIFIER,
        client_id=TEST_CLIENT_ID,
        client_secret=TEST_CLIENT_SECRET,
        redirect_uri=TEST_REDIRECT_URI,
        _http=recorded_http,
        _now=fake_now,
    )

    assert record["access_token"] == TEST_ACCESS_TOKEN
    assert record["refresh_token"] == TEST_REFRESH_TOKEN
    assert record["expires_at"] == int(fake_now()) + 3600
    assert record["obtained_at"] == int(fake_now())

    call = recorded_http.calls[0]
    assert call.method == "POST"
    body_params = dict(urllib.parse.parse_qsl(call.data.decode("ascii")))
    assert body_params["grant_type"] == "authorization_code"
    assert body_params["code"] == TEST_AUTH_CODE
    assert body_params["code_verifier"] == TEST_CODE_VERIFIER
    assert body_params["client_id"] == TEST_CLIENT_ID
    assert body_params["client_secret"] == TEST_CLIENT_SECRET
    assert body_params["redirect_uri"] == TEST_REDIRECT_URI
    content_type = call.headers.get("Content-Type") or call.headers.get(
        "Content-type"
    )
    assert content_type == "application/x-www-form-urlencoded"


def test_exchange_authorization_code_omits_secret_when_absent(
    mural_module: Any, recorded_http: Any, response_factory: Any, fake_now: Any
) -> None:
    recorded_http.responses.append(response_factory(_token_payload(), status=200))

    mural_module._exchange_authorization_code(
        code=TEST_AUTH_CODE,
        code_verifier=TEST_CODE_VERIFIER,
        client_id=TEST_CLIENT_ID,
        client_secret=None,
        redirect_uri=TEST_REDIRECT_URI,
        _http=recorded_http,
        _now=fake_now,
    )
    body_params = dict(
        urllib.parse.parse_qsl(recorded_http.calls[0].data.decode("ascii"))
    )
    assert "client_secret" not in body_params


def test_exchange_authorization_code_http_error_raises_api_error(
    mural_module: Any, recorded_http: Any, http_error_factory: Any, fake_now: Any
) -> None:
    recorded_http.responses.append(
        http_error_factory(b'{"error":"invalid_grant"}', code=400)
    )

    with pytest.raises(mural_module.MuralAPIError) as excinfo:
        mural_module._exchange_authorization_code(
            code="bad",
            code_verifier=TEST_CODE_VERIFIER,
            client_id=TEST_CLIENT_ID,
            client_secret=None,
            redirect_uri=TEST_REDIRECT_URI,
            _http=recorded_http,
            _now=fake_now,
        )
    assert excinfo.value.status == 400
    assert excinfo.value.code == "TOKEN_EXCHANGE_FAILED"


def test_exchange_authorization_code_invalid_json_raises(
    mural_module: Any, recorded_http: Any, response_factory: Any, fake_now: Any
) -> None:
    recorded_http.responses.append(response_factory(b"not-json", status=200))
    with pytest.raises(mural_module.MuralAPIError) as excinfo:
        mural_module._exchange_authorization_code(
            code=TEST_AUTH_CODE,
            code_verifier=TEST_CODE_VERIFIER,
            client_id=TEST_CLIENT_ID,
            client_secret=None,
            redirect_uri=TEST_REDIRECT_URI,
            _http=recorded_http,
            _now=fake_now,
        )
    assert excinfo.value.code == "TOKEN_EXCHANGE_INVALID_JSON"


def test_exchange_authorization_code_missing_access_token_raises(
    mural_module: Any, recorded_http: Any, response_factory: Any, fake_now: Any
) -> None:
    recorded_http.responses.append(response_factory(b'{"token_type":"Bearer"}'))
    with pytest.raises(mural_module.MuralAPIError) as excinfo:
        mural_module._exchange_authorization_code(
            code=TEST_AUTH_CODE,
            code_verifier=TEST_CODE_VERIFIER,
            client_id=TEST_CLIENT_ID,
            client_secret=None,
            redirect_uri=TEST_REDIRECT_URI,
            _http=recorded_http,
            _now=fake_now,
        )
    assert excinfo.value.code == "TOKEN_EXCHANGE_INVALID_PAYLOAD"


# ---------------------------------------------------------------------------
# _LoopbackHandler — exercised via a fake server_factory through _run_login
# ---------------------------------------------------------------------------


class _FakeServer:
    """Minimal stand-in for `http.server.HTTPServer` used by `_run_login`."""

    server_address = ("127.0.0.1", 53682)

    def __init__(self, callback_payload: dict[str, str | None]) -> None:
        self._payload = callback_payload
        self.callback_result = None
        self.callback_received = threading.Event()
        self._closed = False

    def serve_forever(self) -> None:
        # Populate the callback result then signal completion.
        result = self.callback_result
        result.code = self._payload.get("code")
        result.state = self._payload.get("state")
        result.error = self._payload.get("error")
        result.error_description = self._payload.get("error_description")
        self.callback_received.set()

    def shutdown(self) -> None:
        self._closed = True

    def server_close(self) -> None:
        self._closed = True


def _server_factory_for(payload: dict[str, str | None]) -> Any:
    holder: dict[str, _FakeServer] = {}

    def _factory(_address: tuple[str, int], _handler: Any) -> _FakeServer:
        server = _FakeServer(payload)
        holder["server"] = server
        return server

    _factory.holder = holder  # type: ignore[attr-defined]
    return _factory


def test_run_login_state_mismatch_raises_security_error(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        mural_module.secrets, "token_urlsafe", lambda _n=32: "expected-state"
    )
    factory = _server_factory_for(
        {"code": "abc", "state": "wrong-state", "error": None}
    )

    with pytest.raises(mural_module.MuralSecurityError):
        mural_module._run_login(
            env={
                "MURAL_CLIENT_ID": TEST_CLIENT_ID,
                "MURAL_REDIRECT_URI": TEST_REDIRECT_URI,
            },
            scopes=mural_module.DEFAULT_SCOPES,
            timeout_seconds=1,
            open_browser=lambda _url: True,
            server_factory=factory,
            _http=lambda *_a, **_k: pytest.fail("token endpoint must not be called"),
        )


def test_run_login_propagates_authorization_error(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        mural_module.secrets, "token_urlsafe", lambda _n=32: "the-state"
    )
    factory = _server_factory_for(
        {"code": None, "state": None, "error": "access_denied"}
    )

    with pytest.raises(mural_module.MuralError) as excinfo:
        mural_module._run_login(
            env={
                "MURAL_CLIENT_ID": TEST_CLIENT_ID,
                "MURAL_REDIRECT_URI": TEST_REDIRECT_URI,
            },
            scopes=mural_module.DEFAULT_SCOPES,
            timeout_seconds=1,
            open_browser=lambda _url: True,
            server_factory=factory,
            _http=lambda *_a, **_k: pytest.fail("token endpoint must not be called"),
        )
    assert "access_denied" in str(excinfo.value)


def test_run_login_happy_path_persists_record(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    recorded_http: Any,
    response_factory: Any,
    fake_now: Any,
    fake_token_store: pathlib.Path,
) -> None:
    monkeypatch.setattr(
        mural_module.secrets, "token_urlsafe", lambda _n=32: "the-state"
    )
    monkeypatch.setattr(
        mural_module, "_generate_pkce_pair", lambda: (TEST_CODE_VERIFIER, "challenge")
    )
    factory = _server_factory_for(
        {"code": TEST_AUTH_CODE, "state": "the-state", "error": None}
    )
    recorded_http.responses.append(response_factory(_token_payload(), status=200))

    record = mural_module._run_login(
        env={
            "MURAL_CLIENT_ID": TEST_CLIENT_ID,
            "MURAL_CLIENT_SECRET": TEST_CLIENT_SECRET,
            "MURAL_REDIRECT_URI": TEST_REDIRECT_URI,
        },
        scopes=mural_module.DEFAULT_SCOPES,
        timeout_seconds=2,
        open_browser=lambda _url: True,
        server_factory=factory,
        _http=recorded_http,
        _now=fake_now,
    )
    assert record["access_token"] == TEST_ACCESS_TOKEN
    assert record["refresh_token"] == TEST_REFRESH_TOKEN

    # Persist via the public save path and confirm 0600.
    target = fake_token_store
    mural_module._save_token_store(target, record)
    import os
    assert oct(os.stat(target).st_mode & 0o777) == "0o600"


# ---------------------------------------------------------------------------
# _LoopbackHandler — direct request/response semantics
# ---------------------------------------------------------------------------


def test_loopback_handler_success_returns_200(mural_module: Any) -> None:
    captured = mural_module._CallbackResult()
    received = threading.Event()

    class _ServerStub:
        callback_result = captured
        callback_received = received

    handler = mural_module._LoopbackHandler.__new__(mural_module._LoopbackHandler)
    handler.server = _ServerStub()  # type: ignore[attr-defined]
    handler.path = (
        f"/callback?code={TEST_AUTH_CODE}&state={TEST_STATE}"
    )
    handler.wfile = io.BytesIO()
    handler.rfile = io.BytesIO()

    sent: dict[str, Any] = {"status": None, "headers": []}

    def _send_response(code: int) -> None:
        sent["status"] = code

    def _send_header(name: str, value: str) -> None:
        sent["headers"].append((name, value))

    def _end_headers() -> None:
        sent["ended"] = True

    handler.send_response = _send_response  # type: ignore[assignment]
    handler.send_header = _send_header  # type: ignore[assignment]
    handler.end_headers = _end_headers  # type: ignore[assignment]

    handler.do_GET()
    assert sent["status"] == 200
    assert captured.code == TEST_AUTH_CODE
    assert captured.state == TEST_STATE
    assert received.is_set()


def test_loopback_handler_error_returns_400(mural_module: Any) -> None:
    captured = mural_module._CallbackResult()
    received = threading.Event()

    class _ServerStub:
        callback_result = captured
        callback_received = received

    handler = mural_module._LoopbackHandler.__new__(mural_module._LoopbackHandler)
    handler.server = _ServerStub()  # type: ignore[attr-defined]
    handler.path = "/callback?error=access_denied&error_description=denied"
    handler.wfile = io.BytesIO()

    sent: dict[str, Any] = {"status": None}
    handler.send_response = lambda code: sent.update(status=code)  # type: ignore[assignment]
    handler.send_header = lambda *_a, **_k: None  # type: ignore[assignment]
    handler.end_headers = lambda: None  # type: ignore[assignment]

    handler.do_GET()
    assert sent["status"] == 400
    assert captured.error == "access_denied"
    assert captured.error_description == "denied"
