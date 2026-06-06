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
    recorded_http.responses.append(
        response_factory(
            _token_payload(),
            status=200,
            headers={"Content-Type": "application/json"},
        )
    )

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
    content_type = call.headers.get("Content-Type") or call.headers.get("Content-type")
    assert content_type == "application/x-www-form-urlencoded"


def test_exchange_authorization_code_omits_secret_when_absent(
    mural_module: Any, recorded_http: Any, response_factory: Any, fake_now: Any
) -> None:
    recorded_http.responses.append(
        response_factory(
            _token_payload(),
            status=200,
            headers={"Content-Type": "application/json"},
        )
    )

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


def test_exchange_authorization_code_omits_scope_from_record(
    mural_module: Any, recorded_http: Any, response_factory: Any, fake_now: Any
) -> None:
    """Mural ``/token`` does not return ``scope``; we must not forge or store it."""
    recorded_http.responses.append(
        response_factory(
            _token_payload(scope="murals:read murals:write"),
            status=200,
            headers={"Content-Type": "application/json"},
        )
    )

    record = mural_module._exchange_authorization_code(
        code=TEST_AUTH_CODE,
        code_verifier=TEST_CODE_VERIFIER,
        client_id=TEST_CLIENT_ID,
        client_secret=TEST_CLIENT_SECRET,
        redirect_uri=TEST_REDIRECT_URI,
        _http=recorded_http,
        _now=fake_now,
    )
    assert "scope" not in record
    assert set(record.keys()) == {
        "access_token",
        "refresh_token",
        "token_type",
        "expires_at",
        "obtained_at",
    }


def test_apply_refresh_does_not_persist_scope(
    mural_module: Any, recorded_http: Any, response_factory: Any, fake_now: Any
) -> None:
    """`_apply_refresh` must never write a ``scope`` field into a profile."""
    recorded_http.responses.append(
        response_factory(
            _token_payload(scope="murals:read murals:write"),
            status=200,
            headers={"Content-Type": "application/json"},
        )
    )
    store = {
        "schema_version": 2,
        "profiles": {
            mural_module.DEFAULT_PROFILE_NAME: {
                "client_id": TEST_CLIENT_ID,
                "access_token": "old",
                "refresh_token": TEST_REFRESH_TOKEN,
                "token_type": "Bearer",
                "obtained_at": 0,
                "granted_scopes": ["murals:read"],
                "expires_at": 0,
            }
        },
    }

    new_store = mural_module._apply_refresh(
        store,
        client_id=TEST_CLIENT_ID,
        client_secret=None,
        token_url="https://app.mural.co/api/public/v1/authorization/oauth2/token",
        _http=recorded_http,
        _now=fake_now,
    )
    new_profile = new_store["profiles"][mural_module.DEFAULT_PROFILE_NAME]
    assert "scope" not in new_profile


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
    recorded_http.responses.append(
        response_factory(
            b"not-json",
            status=200,
            headers={"Content-Type": "application/json"},
        )
    )
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
    assert excinfo.value.code == "TOKEN_INVALID_JSON"


def test_exchange_authorization_code_missing_access_token_raises(
    mural_module: Any, recorded_http: Any, response_factory: Any, fake_now: Any
) -> None:
    recorded_http.responses.append(
        response_factory(
            b'{"token_type":"Bearer"}',
            headers={"Content-Type": "application/json"},
        )
    )
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
# Phase 2: token endpoint redirect / Content-Type hardening
# ---------------------------------------------------------------------------


def test_exchange_authorization_code_rejects_redirect(
    mural_module: Any, recorded_http: Any, response_factory: Any, fake_now: Any
) -> None:
    def _redirect_http(req: Any) -> Any:
        return mural_module._NoRedirect()._block(
            req, None, 302, "Found", {"Location": "https://evil.example/steal"}
        )

    with pytest.raises(mural_module.MuralAPIError) as excinfo:
        mural_module._exchange_authorization_code(
            code=TEST_AUTH_CODE,
            code_verifier=TEST_CODE_VERIFIER,
            client_id=TEST_CLIENT_ID,
            client_secret=None,
            redirect_uri=TEST_REDIRECT_URI,
            _http=_redirect_http,
            _now=fake_now,
        )
    assert excinfo.value.code == "TOKEN_REDIRECT"
    assert "https://evil.example/steal" in excinfo.value.message


def test_refresh_access_token_rejects_redirect(
    mural_module: Any, recorded_http: Any, fake_now: Any
) -> None:
    def _redirect_http(req: Any) -> Any:
        return mural_module._NoRedirect()._block(
            req, None, 301, "Moved", {"Location": "https://evil.example/steal"}
        )

    with pytest.raises(mural_module.MuralAPIError) as excinfo:
        mural_module._refresh_access_token(
            TEST_REFRESH_TOKEN,
            client_id=TEST_CLIENT_ID,
            client_secret=TEST_CLIENT_SECRET,
            _http=_redirect_http,
        )
    assert excinfo.value.code == "TOKEN_REDIRECT"
    assert "https://evil.example/steal" in excinfo.value.message


def test_exchange_authorization_code_rejects_non_json_content_type(
    mural_module: Any, recorded_http: Any, response_factory: Any, fake_now: Any
) -> None:
    recorded_http.responses.append(
        response_factory(
            b"<html>oops</html>",
            status=200,
            headers={"Content-Type": "text/html"},
        )
    )
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
    assert excinfo.value.code == "TOKEN_BAD_CONTENT_TYPE"
    assert "text/html" in excinfo.value.message


def test_refresh_access_token_rejects_non_json_content_type(
    mural_module: Any, recorded_http: Any, response_factory: Any
) -> None:
    recorded_http.responses.append(
        response_factory(
            b"<html>oops</html>",
            status=200,
            headers={"Content-Type": "text/html"},
        )
    )
    with pytest.raises(mural_module.MuralAPIError) as excinfo:
        mural_module._refresh_access_token(
            TEST_REFRESH_TOKEN,
            client_id=TEST_CLIENT_ID,
            client_secret=TEST_CLIENT_SECRET,
            _http=recorded_http,
        )
    assert excinfo.value.code == "TOKEN_BAD_CONTENT_TYPE"
    assert "text/html" in excinfo.value.message


def test_exchange_authorization_code_accepts_json_with_charset(
    mural_module: Any, recorded_http: Any, response_factory: Any, fake_now: Any
) -> None:
    recorded_http.responses.append(
        response_factory(
            _token_payload(),
            status=200,
            headers={"Content-Type": "application/json; charset=utf-8"},
        )
    )
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


def test_refresh_access_token_accepts_json_with_charset(
    mural_module: Any, recorded_http: Any, response_factory: Any
) -> None:
    recorded_http.responses.append(
        response_factory(
            _token_payload(),
            status=200,
            headers={"Content-Type": "Application/JSON; charset=UTF-8"},
        )
    )
    data = mural_module._refresh_access_token(
        TEST_REFRESH_TOKEN,
        client_id=TEST_CLIENT_ID,
        client_secret=TEST_CLIENT_SECRET,
        _http=recorded_http,
    )
    assert data["access_token"] == TEST_ACCESS_TOKEN


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
    recorded_http.responses.append(
        response_factory(
            _token_payload(),
            status=200,
            headers={"Content-Type": "application/json"},
        )
    )

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


def test_run_login_default_http_rejects_token_endpoint_redirect(
    mural_module: Any,
) -> None:
    # The _http default for _run_login must flow through the redirect-blocking
    # opener so an attacker-controlled 30x from the token endpoint cannot
    # exfiltrate the authorization code + client secret to a different host.
    import inspect

    sig = inspect.signature(mural_module._run_login)
    assert sig.parameters["_http"].default == mural_module._TOKEN_OPENER.open

    with pytest.raises(mural_module.MuralAPIError) as excinfo:
        mural_module._NoRedirect().http_error_307(
            req=None,
            fp=None,
            code=307,
            msg="",
            headers={"Location": "https://attacker.example/steal"},
        )
    assert excinfo.value.code == "TOKEN_REDIRECT"


def test_run_login_defaults_to_hardened_loopback_server(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    # The production path (no injected server_factory) must bind the hardened
    # _LoopbackServer, not the bare http.server.HTTPServer. Capture the factory
    # passed to _start_loopback_server and abort before any socket is bound.
    captured: dict[str, Any] = {}

    class _Stop(Exception):
        pass

    def _capture_start(*, server_factory: Any, bind_host: str, port: int) -> Any:
        captured["server_factory"] = server_factory
        raise _Stop

    monkeypatch.setattr(mural_module._oauth, "_start_loopback_server", _capture_start)

    with pytest.raises(_Stop):
        mural_module._run_login(
            env={
                "MURAL_CLIENT_ID": TEST_CLIENT_ID,
                "MURAL_REDIRECT_URI": TEST_REDIRECT_URI,
            },
            scopes=mural_module.DEFAULT_SCOPES,
            timeout_seconds=1,
            open_browser=lambda _url: True,
        )

    assert captured["server_factory"] is mural_module._LoopbackServer


# ---------------------------------------------------------------------------
# _LoopbackHandler — direct request/response semantics
# ---------------------------------------------------------------------------


def test_loopback_handler_success_returns_200(mural_module: Any) -> None:
    captured = mural_module._CallbackResult()
    received = threading.Event()

    class _ServerStub:
        callback_result = captured
        callback_received = received
        server_port = 53682

    handler = mural_module._LoopbackHandler.__new__(mural_module._LoopbackHandler)
    handler.server = _ServerStub()  # type: ignore[attr-defined]
    handler.path = f"/callback?code={TEST_AUTH_CODE}&state={TEST_STATE}"
    handler.headers = {"Host": "127.0.0.1:53682"}  # type: ignore[attr-defined]
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
        server_port = 53682

    handler = mural_module._LoopbackHandler.__new__(mural_module._LoopbackHandler)
    handler.server = _ServerStub()  # type: ignore[attr-defined]
    handler.path = "/callback?error=access_denied&error_description=denied"
    handler.headers = {"Host": "127.0.0.1:53682"}  # type: ignore[attr-defined]
    handler.wfile = io.BytesIO()

    sent: dict[str, Any] = {"status": None}
    handler.send_response = lambda code: sent.update(status=code)  # type: ignore[assignment]
    handler.send_header = lambda *_a, **_k: None  # type: ignore[assignment]
    handler.end_headers = lambda: None  # type: ignore[assignment]

    handler.do_GET()
    assert sent["status"] == 400
    assert captured.error == "access_denied"
    assert captured.error_description == "denied"


# ---------------------------------------------------------------------------
# Phase 4: Host-header guard and redirect-uri allowlist
# ---------------------------------------------------------------------------


def test_loopback_handler_rejects_mismatched_host(mural_module: Any) -> None:
    """Step 4.10: callers presenting a non-loopback Host header receive 421."""
    captured = mural_module._CallbackResult()
    received = threading.Event()

    class _ServerStub:
        callback_result = captured
        callback_received = received
        server_port = 53682
        server_address = ("127.0.0.1", 53682)

    handler = mural_module._LoopbackHandler.__new__(mural_module._LoopbackHandler)
    handler.server = _ServerStub()  # type: ignore[attr-defined]
    handler.path = f"/callback?code={TEST_AUTH_CODE}&state={TEST_STATE}"
    handler.headers = {"Host": "evil.example.com"}  # type: ignore[attr-defined]
    handler.wfile = io.BytesIO()

    sent: dict[str, Any] = {"status": None}
    handler.send_response = lambda code: sent.update(status=code)  # type: ignore[assignment]
    handler.send_header = lambda *_a, **_k: None  # type: ignore[assignment]
    handler.end_headers = lambda: None  # type: ignore[assignment]

    handler.do_GET()

    assert sent["status"] == 421
    assert captured.code is None
    assert not received.is_set()


@pytest.mark.parametrize(
    "bad_uri",
    [
        pytest.param("https://127.0.0.1:50000/callback", id="https-scheme"),
        pytest.param("http://example.com:50000/callback", id="public-host"),
        pytest.param("http://127.0.0.1:80/callback", id="privileged-port"),
        pytest.param("http://127.0.0.1:50000/evil", id="non-allowlisted-path"),
    ],
)
def test_validate_redirect_uri_rejects_unsafe_values(
    mural_module: Any, bad_uri: str
) -> None:
    """Step 4.10: redirect_uri allowlist rejects scheme/host/port/path violations."""
    with pytest.raises(mural_module.MuralSecurityError):
        mural_module._validate_redirect_uri(bad_uri)


def test_validate_redirect_uri_accepts_loopback_callback(mural_module: Any) -> None:
    """Step 4.10: a well-formed loopback redirect_uri passes validation."""
    mural_module._validate_redirect_uri("http://127.0.0.1:50000/callback")


# ---------------------------------------------------------------------------
# Phase 1: Loopback redirect URI defaults and helper contract
# ---------------------------------------------------------------------------


def test_default_redirect_uri_constant(mural_module: Any) -> None:
    """Step 1.1 (DR-10): the module exposes the canonical localhost default."""
    assert mural_module.DEFAULT_REDIRECT_URI == "http://localhost:8765/callback"


def test_resolve_redirect_uri_defaults_when_unset(mural_module: Any) -> None:
    """Step 1.1 (DR-10): no override returns the canonical default triple."""
    uri, host, port = mural_module._resolve_redirect_uri({})
    assert uri == "http://localhost:8765/callback"
    assert host == "127.0.0.1"
    assert port == 8765


def test_resolve_redirect_uri_parses_override(mural_module: Any) -> None:
    """Step 1.1: an env override is validated and parsed into (uri, host, port)."""
    uri, host, port = mural_module._resolve_redirect_uri(
        {"MURAL_REDIRECT_URI": "http://127.0.0.1:9000/callback"}
    )
    assert uri == "http://127.0.0.1:9000/callback"
    assert host == "127.0.0.1"
    assert port == 9000


def test_resolve_redirect_uri_rejects_invalid_override(mural_module: Any) -> None:
    """Step 1.1: invalid overrides surface ``MuralSecurityError``."""
    with pytest.raises(mural_module.MuralSecurityError):
        mural_module._resolve_redirect_uri(
            {"MURAL_REDIRECT_URI": "https://evil.example.com/callback"}
        )


def test_validate_redirect_uri_accepts_localhost(mural_module: Any) -> None:
    """Step 1.4 (DR-10): ``localhost`` is in the host allowlist (canonicalization)."""
    mural_module._validate_redirect_uri("http://localhost:8765/callback")


def test_validate_redirect_uri_rejects_ipv6_loopback(mural_module: Any) -> None:
    """Step 1.4: IPv6 loopback (``[::1]``) is rejected; loopback is IPv4-only."""
    with pytest.raises(mural_module.MuralSecurityError):
        mural_module._validate_redirect_uri("http://[::1]:8765/callback")


def test_validate_redirect_uri_rejects_malformed_ipv6_host(mural_module: Any) -> None:
    """Malformed IPv6 hosts are invalid overrides, not parser crashes."""
    with pytest.raises(mural_module.MuralSecurityError):
        mural_module._validate_redirect_uri("http://[::1:8765/callback")


def test_start_loopback_server_eaddrinuse_raises_mural_error(
    mural_module: Any,
) -> None:
    """Step 1.2: bind failure surfaces an actionable ``MuralError``."""
    import errno as errno_module

    def _factory(_address: tuple[str, int], _handler: Any) -> Any:
        raise OSError(errno_module.EADDRINUSE, "address already in use")

    with pytest.raises(mural_module.MuralError) as excinfo:
        mural_module._start_loopback_server(
            server_factory=_factory, bind_host="127.0.0.1", port=8765
        )
    message = str(excinfo.value)
    assert "8765" in message
    assert "MURAL_REDIRECT_URI" in message


def test_run_login_emits_authorize_url_to_stderr_before_browser(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """Step 1.5: the authorize URL is printed to stderr even when the
    browser launcher raises (covers headless / no-DISPLAY callers)."""
    monkeypatch.setattr(
        mural_module.secrets, "token_urlsafe", lambda _n=32: "the-state"
    )
    monkeypatch.setattr(
        mural_module, "_generate_pkce_pair", lambda: (TEST_CODE_VERIFIER, "chal")
    )
    factory = _server_factory_for(
        {"code": None, "state": None, "error": "access_denied"}
    )

    def _broken_browser(_url: str) -> bool:
        raise RuntimeError("no display")

    with pytest.raises(mural_module.MuralError):
        mural_module._run_login(
            env={
                "MURAL_CLIENT_ID": TEST_CLIENT_ID,
                "MURAL_REDIRECT_URI": TEST_REDIRECT_URI,
            },
            scopes=mural_module.DEFAULT_SCOPES,
            timeout_seconds=1,
            open_browser=_broken_browser,
            server_factory=factory,
            _http=lambda *_a, **_k: pytest.fail("token endpoint must not be called"),
        )
    err = capsys.readouterr().err
    assert "open this URL to authorize:" in err
    assert "response_type=code" in err
