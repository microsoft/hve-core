# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Tests for GitLab public-client OAuth helpers."""

from __future__ import annotations

import http.client
import json
import socket
import threading
import urllib.error

import _gitlab_oauth as oauth
import pytest


class _Response:
    def __init__(self, payload: dict[str, object]) -> None:
        self.headers = {"Content-Type": "application/json"}
        self._body = json.dumps(payload).encode()

    def __enter__(self) -> "_Response":
        return self

    def __exit__(self, *_args: object) -> bool:
        return False

    def read(self, _amount: int = -1) -> bytes:
        return self._body


def test_pkce_pair_is_s256_and_has_no_secret() -> None:
    verifier, challenge = oauth.generate_pkce_pair()
    url = oauth.build_authorize_url(
        "https://gitlab.example.com", "client", "state", challenge
    )

    assert 43 <= len(verifier) <= 128
    assert "code_challenge_method=S256" in url
    assert "client_secret" not in url


def test_token_profile_requires_rotating_refresh_token() -> None:
    with pytest.raises(oauth.OAuthError, match="refresh_token"):
        oauth.token_profile(
            {"access_token": "access", "expires_in": 7200},
            issuer="https://gitlab.example.com",
            client_id="client",
            now=100.0,
        )


def test_token_profile_uses_provider_expiry() -> None:
    profile = oauth.token_profile(
        {
            "access_token": "access",
            "refresh_token": "refresh",
            "expires_in": 7200,
            "scope": "api",
        },
        issuer="https://gitlab.example.com",
        client_id="client",
        now=100.0,
    )

    assert profile["expires_at"] == 7300
    assert profile["scopes"] == ["api"]


@pytest.mark.parametrize(
    "payload",
    [
        {
            "access_token": "access",
            "refresh_token": "refresh",
            "expires_in": oauth.MAX_EXPIRES_IN_SECONDS + 1,
        },
        {
            "access_token": "access",
            "refresh_token": "refresh",
            "expires_in": 7200,
            "token_type": "MAC",
        },
    ],
)
def test_token_profile_rejects_unbounded_or_unsupported_tokens(
    payload: dict[str, object],
) -> None:
    with pytest.raises(oauth.OAuthError):
        oauth.token_profile(
            payload,
            issuer="https://gitlab.example.com",
            client_id="client",
            now=100.0,
        )


def test_device_login_honors_pending_and_slow_down() -> None:
    responses: list[object] = [
        _Response(
            {
                "device_code": "device-secret",
                "user_code": "ABCD-EFGH",
                "verification_uri": "https://gitlab.example.com/oauth/device",
                "expires_in": 300,
                "interval": 5,
            }
        ),
        oauth.OAuthError(
            "GitLab OAuth request failed: authorization_pending",
            code="authorization_pending",
        ),
        oauth.OAuthError(
            "GitLab OAuth request failed: slow_down",
            code="slow_down",
        ),
        _Response(
            {
                "access_token": "access",
                "expires_in": 7200,
                "scope": "api",
            }
        ),
    ]
    times = [0.0]
    sleeps: list[float] = []

    def opener(*_args: object, **_kwargs: object) -> object:
        response = responses.pop(0)
        if isinstance(response, Exception):
            raise response
        return response

    def sleep(seconds: float) -> None:
        sleeps.append(seconds)
        times[0] += seconds

    profile = oauth.device_login(
        "https://gitlab.example.com",
        "client",
        opener=opener,
        timeout=300,
        emit_instructions=lambda _uri, _code: None,
        now=lambda: times[0],
        monotonic=lambda: times[0],
        sleep=sleep,
    )

    assert profile["access_token"] == "access"
    assert profile["refresh_token"] == ""
    assert sleeps == [5, 5, 10]


def test_device_login_does_not_poll_past_deadline() -> None:
    responses: list[object] = [
        _Response(
            {
                "device_code": "device-secret",
                "user_code": "ABCD-EFGH",
                "verification_uri": "https://gitlab.example.com/oauth/device",
                "expires_in": 4,
                "interval": 10,
            }
        ),
        oauth.OAuthError("pending", code="authorization_pending"),
    ]
    times = [0.0]
    sleeps: list[float] = []

    def opener(*_args: object, **_kwargs: object) -> object:
        response = responses.pop(0)
        if isinstance(response, Exception):
            raise response
        return response

    def sleep(seconds: float) -> None:
        sleeps.append(seconds)
        times[0] += seconds

    with pytest.raises(oauth.OAuthError, match="timed out"):
        oauth.device_login(
            "https://gitlab.example.com",
            "client",
            opener=opener,
            timeout=300,
            emit_instructions=lambda _uri, _code: None,
            now=lambda: times[0],
            monotonic=lambda: times[0],
            sleep=sleep,
        )

    assert sleeps == [4]
    assert len(responses) == 1


def test_post_form_preserves_provider_error_code_and_retryability() -> None:
    error = urllib.error.HTTPError(
        url="https://gitlab.example.com/oauth/token",
        code=503,
        msg="unavailable",
        hdrs={"Content-Type": "application/json"},
        fp=None,
    )
    error.read = lambda _amount=-1: b'{"error":"temporarily_unavailable"}'  # type: ignore[method-assign]

    with pytest.raises(oauth.OAuthError) as exc_info:
        oauth.post_form(
            "https://gitlab.example.com",
            "/oauth/token",
            {"grant_type": "refresh_token"},
            opener=lambda *_args, **_kwargs: (_ for _ in ()).throw(error),
            timeout=30,
            operation="oauth.refresh",
        )

    assert exc_info.value.code == "temporarily_unavailable"
    assert exc_info.value.retryable is True
    assert exc_info.value.completion_uncertain is True


@pytest.mark.parametrize(
    ("error", "completion_uncertain"),
    [
        (TimeoutError("timed out"), True),
        (ConnectionResetError("reset"), True),
        (http.client.IncompleteRead(b"partial"), True),
        (http.client.BadStatusLine("bad"), True),
        (urllib.error.URLError(socket.gaierror("dns")), False),
        (urllib.error.URLError(ConnectionRefusedError("refused")), False),
    ],
)
def test_post_form_classifies_transport_failures(
    error: Exception,
    completion_uncertain: bool,
) -> None:
    with pytest.raises(oauth.OAuthError) as exc_info:
        oauth.post_form(
            "https://gitlab.example.com",
            "/oauth/token",
            {"grant_type": "refresh_token"},
            opener=lambda *_args, **_kwargs: (_ for _ in ()).throw(error),
            timeout=30,
            operation="oauth.refresh",
        )

    assert exc_info.value.retryable is True
    assert exc_info.value.completion_uncertain is completion_uncertain
    assert exc_info.value.__cause__ is error


def test_refresh_profile_rejects_binding_mismatch_before_network() -> None:
    profile = oauth.token_profile(
        {
            "access_token": "access",
            "refresh_token": "refresh",
            "expires_in": 7200,
        },
        issuer="https://gitlab.example.com",
        client_id="client",
        now=100.0,
    )

    with pytest.raises(oauth.OAuthError, match="not bound"):
        oauth.refresh_profile(
            profile,
            expected_issuer="https://other.example.com",
            expected_client_id="client",
            opener=lambda *_args, **_kwargs: (_ for _ in ()).throw(
                AssertionError("network must not run")
            ),
            timeout=30,
        )


def test_refresh_profile_marks_malformed_success_as_uncertain() -> None:
    profile = oauth.token_profile(
        {
            "access_token": "access",
            "refresh_token": "refresh",
            "expires_in": 7200,
        },
        issuer="https://gitlab.example.com",
        client_id="client",
        now=100.0,
    )

    with pytest.raises(oauth.OAuthError) as exc_info:
        oauth.refresh_profile(
            profile,
            expected_issuer="https://gitlab.example.com",
            expected_client_id="client",
            opener=lambda *_args, **_kwargs: _Response(
                {"access_token": "replacement", "expires_in": 7200}
            ),
            timeout=30,
        )

    assert exc_info.value.completion_uncertain is True


def test_authorization_login_converts_callback_bind_failure(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        oauth,
        "_CallbackServer",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(OSError("in use")),
    )

    with pytest.raises(oauth.OAuthError, match="device-login"):
        oauth.authorization_code_login(
            "https://gitlab.example.com",
            "client",
            opener=lambda *_args, **_kwargs: None,
            timeout=1,
        )


def test_callback_ignores_wrong_path_then_accepts_valid_state(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    server = oauth._CallbackServer(
        (oauth.CALLBACK_HOST, 0),
        oauth._CallbackHandler,
    )
    server.callback_result = oauth._CallbackResult()
    server.callback_received = threading.Event()
    server.stop_requested = threading.Event()
    server.expected_state = "expected-state"
    port = server.server_address[1]
    monkeypatch.setattr(oauth, "CALLBACK_PORT", port)

    def serve_two_requests() -> None:
        for _ in range(2):
            server.handle_request()

    thread = threading.Thread(target=serve_two_requests)
    thread.start()
    try:
        wrong = http.client.HTTPConnection(oauth.CALLBACK_HOST, port, timeout=1)
        wrong.request("GET", "/wrong", headers={"Host": f"127.0.0.1:{port}"})
        assert wrong.getresponse().status == 404
        wrong.close()
        assert server.callback_received.is_set() is False

        valid = http.client.HTTPConnection(oauth.CALLBACK_HOST, port, timeout=1)
        valid.request(
            "GET",
            "/callback?code=authorization-code&state=expected-state",
            headers={"Host": f"127.0.0.1:{port}"},
        )
        assert valid.getresponse().status == 200
        valid.close()
        thread.join(timeout=1)
    finally:
        server.server_close()

    assert server.callback_received.is_set() is True
    assert server.callback_result.code == "authorization-code"


def test_callback_socket_has_bounded_read_timeout(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(oauth, "CALLBACK_REQUEST_TIMEOUT_SECONDS", 0.05)
    server = oauth._CallbackServer((oauth.CALLBACK_HOST, 0), oauth._CallbackHandler)
    port = server.server_address[1]
    peer = socket.create_connection((oauth.CALLBACK_HOST, port), timeout=1)

    thread = threading.Thread(target=server.handle_request)
    thread.start()
    thread.join(timeout=0.5)
    peer.close()
    server.server_close()

    assert thread.is_alive() is False


def test_device_login_uses_injected_monotonic_clock() -> None:
    responses: list[object] = [
        _Response(
            {
                "device_code": "device-secret",
                "user_code": "ABCD-EFGH",
                "verification_uri": "https://gitlab.example.com/oauth/device",
                "expires_in": 4,
                "interval": 10,
            }
        )
    ]
    elapsed = [0.0]

    def opener(*_args: object, **_kwargs: object) -> object:
        return responses.pop(0)

    def sleep(seconds: float) -> None:
        elapsed[0] += seconds

    with pytest.raises(oauth.OAuthError, match="timed out"):
        oauth.device_login(
            "https://gitlab.example.com",
            "client",
            opener=opener,
            timeout=300,
            emit_instructions=lambda _uri, _code: None,
            monotonic=lambda: elapsed[0],
            sleep=sleep,
        )

    assert elapsed == [4.0]


class _ImmediateCallbackServer:
    """Stand in for the loopback listener with an already-received callback."""

    def __init__(self, *_args: object, **_kwargs: object) -> None:
        self.callback_result = oauth._CallbackResult()
        self.callback_received = threading.Event()
        self.stop_requested = threading.Event()
        self.expected_state = ""
        self.timeout = 0.0

    def handle_request(self) -> None:  # pragma: no cover - never serves
        return

    def server_close(self) -> None:
        return


@pytest.fixture()
def immediate_callback(monkeypatch: pytest.MonkeyPatch) -> list[dict[str, object]]:
    """Replace the listener so authorization-code tests stay deterministic."""
    servers: list[_ImmediateCallbackServer] = []

    def build_server(*args: object, **kwargs: object) -> _ImmediateCallbackServer:
        server = _ImmediateCallbackServer(*args, **kwargs)
        servers.append(server)
        return server

    def start_thread(self: threading.Thread) -> None:
        for server in servers:
            server.callback_result = oauth._CallbackResult(
                code="authorization-code",
                state=server.expected_state,
            )
            server.callback_received.set()

    monkeypatch.setattr(oauth, "_CallbackServer", build_server)
    monkeypatch.setattr(threading.Thread, "start", start_thread)
    monkeypatch.setattr(threading.Thread, "join", lambda self, timeout=None: None)
    return servers


def test_authorization_login_passes_remaining_budget_to_exchange(
    immediate_callback: list[object],
) -> None:
    calls: list[float] = []
    clock = [0.0]

    def opener(*_args: object, **kwargs: object) -> object:
        calls.append(float(kwargs["timeout"]))
        clock[0] += 0.0
        return _Response(
            {
                "access_token": "access",
                "refresh_token": "refresh",
                "expires_in": 7200,
            }
        )

    def monotonic() -> float:
        value = clock[0]
        clock[0] += 2.0
        return value

    profile = oauth.authorization_code_login(
        "https://gitlab.example.com",
        "client",
        opener=opener,
        timeout=10,
        open_browser=lambda _url: True,
        now=lambda: 100.0,
        monotonic=monotonic,
    )

    assert profile["access_token"] == "access"
    assert calls == [pytest.approx(6.0)]


def test_authorization_login_refuses_exchange_without_remaining_budget(
    immediate_callback: list[object],
) -> None:
    clock = [0.0]

    def monotonic() -> float:
        value = clock[0]
        clock[0] += 10.0
        return value

    with pytest.raises(oauth.OAuthError, match="deadline expired"):
        oauth.authorization_code_login(
            "https://gitlab.example.com",
            "client",
            opener=lambda *_args, **_kwargs: (_ for _ in ()).throw(
                AssertionError("exchange must not run")
            ),
            timeout=10,
            open_browser=lambda _url: True,
            now=lambda: 100.0,
            monotonic=monotonic,
        )


def _device_response(verification_uri: str, user_code: str) -> "_Response":
    return _Response(
        {
            "device_code": "device-secret",
            "user_code": user_code,
            "verification_uri": verification_uri,
            "expires_in": 300,
            "interval": 5,
        }
    )


def _run_device_login(
    verification_uri: str,
    user_code: str,
    issuer: str = "https://gitlab.example.com",
) -> list[tuple[str, str]]:
    emitted: list[tuple[str, str]] = []
    responses: list[object] = [_device_response(verification_uri, user_code)]
    times = [0.0]

    def opener(*_args: object, **_kwargs: object) -> object:
        if responses:
            return responses.pop(0)
        raise oauth.OAuthError("pending", code="authorization_pending")

    def sleep(seconds: float) -> None:
        times[0] += seconds

    with pytest.raises(oauth.OAuthError):
        oauth.device_login(
            issuer,
            "client",
            opener=opener,
            timeout=6,
            emit_instructions=lambda uri, code: emitted.append((uri, code)),
            now=lambda: times[0],
            monotonic=lambda: times[0],
            sleep=sleep,
        )
    return emitted


@pytest.mark.parametrize(
    "user_code",
    ["ABCD\nEFGH", "ABCD\x1b[2JEFGH", "ABCD\x7fEFGH"],
)
def test_device_login_rejects_control_characters_in_user_code(user_code: str) -> None:
    emitted = _run_device_login(
        "https://gitlab.example.com/oauth/device",
        user_code,
    )

    assert emitted == []


@pytest.mark.parametrize(
    "verification_uri",
    [
        "https://gitlab.example.com/oauth/de vice",
        "https://gitlab.example.com\\oauth",
        "https://user:pass@gitlab.example.com/oauth/device",
        "http://gitlab.example.com/oauth/device",
        "https://attacker.example.com/oauth/device",
        "https://gitlab.example.com:0/oauth/device",
        "https://gitlab.example.com:99999/oauth/device",
    ],
)
def test_device_login_rejects_unsafe_verification_uri(verification_uri: str) -> None:
    emitted = _run_device_login(verification_uri, "ABCD-EFGH")

    assert emitted == []


@pytest.mark.parametrize(
    ("verification_uri", "user_code"),
    [
        ("https://gitlab.example.com/oauth/device", "ABCD-EFGH"),
        ("https://gitlab.example.com/oauth/device?user_code=ABCD", "ABCD-EFGH"),
        ("https://gitlab.example.com/oauth/device#frag", "ABCD EFGH"),
        ("https://GitLab.Example.com/oauth/device", "ABCD.EFGH!"),
        ("https://gitlab.example.com:443/oauth/device", "\u00c5\u00c4\u00d6-1234"),
    ],
)
def test_device_login_preserves_compatible_instructions(
    verification_uri: str,
    user_code: str,
) -> None:
    emitted = _run_device_login(verification_uri, user_code)

    assert emitted == [(verification_uri, user_code)]


def test_device_login_accepts_loopback_development_issuer() -> None:
    emitted = _run_device_login(
        "http://127.0.0.1:8080/oauth/device",
        "ABCD-EFGH",
        issuer="http://127.0.0.1:8080",
    )

    assert emitted == [("http://127.0.0.1:8080/oauth/device", "ABCD-EFGH")]
