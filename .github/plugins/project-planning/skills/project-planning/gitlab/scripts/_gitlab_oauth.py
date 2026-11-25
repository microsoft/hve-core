#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""OAuth 2.0 public-client flows for the GitLab skill CLI."""

from __future__ import annotations

import base64
import hashlib
import http.client
import http.server
import json
import secrets
import socket
import threading
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from dataclasses import dataclass
from typing import Any, Callable

from _gitlab_credentials import Profile

CALLBACK_URI = "http://127.0.0.1:8766/callback"
CALLBACK_HOST = "127.0.0.1"
CALLBACK_PORT = 8766
CALLBACK_PATH = "/callback"
DEFAULT_SCOPE = "api"
REFRESH_LEEWAY_SECONDS = 60
MAX_TOKEN_BODY_BYTES = 1_048_576
MAX_EXPIRES_IN_SECONDS = 86_400
MIN_DEVICE_POLL_SECONDS = 1
CALLBACK_REQUEST_TIMEOUT_SECONDS = 5.0

AuditAttempt = Callable[[str], None]
AuditOutcome = Callable[[str, str, int | None, str | None], None]


class OAuthError(RuntimeError):
    """Raised when a GitLab OAuth operation fails safely."""

    def __init__(
        self,
        message: str,
        *,
        code: str | None = None,
        retryable: bool = False,
        completion_uncertain: bool = False,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.retryable = retryable
        self.completion_uncertain = completion_uncertain


def generate_pkce_pair() -> tuple[str, str]:
    """Return an RFC 7636 verifier and S256 challenge."""
    verifier = secrets.token_urlsafe(64)[:96]
    digest = hashlib.sha256(verifier.encode("ascii")).digest()
    challenge = base64.urlsafe_b64encode(digest).rstrip(b"=").decode("ascii")
    return verifier, challenge


def build_authorize_url(
    issuer: str,
    client_id: str,
    state: str,
    challenge: str,
    scope: str = DEFAULT_SCOPE,
) -> str:
    """Build the GitLab public-client authorization URL.

    Args:
        issuer: Canonical GitLab origin.
        client_id: Public OAuth application identifier.
        state: Per-login anti-forgery state.
        challenge: PKCE S256 challenge.
        scope: Space-delimited OAuth scopes.

    Returns:
        Authorization URL containing the fixed loopback redirect URI.
    """
    query = urllib.parse.urlencode(
        {
            "client_id": client_id,
            "redirect_uri": CALLBACK_URI,
            "response_type": "code",
            "state": state,
            "scope": scope,
            "code_challenge": challenge,
            "code_challenge_method": "S256",
        }
    )
    return f"{issuer}/oauth/authorize?{query}"


def _parse_json_response(response: Any) -> dict[str, Any]:
    content_type = str(getattr(response, "headers", {}).get("Content-Type", ""))
    if not content_type.lower().startswith("application/json"):
        raise OAuthError("GitLab OAuth endpoint returned a non-JSON response")
    body = response.read(MAX_TOKEN_BODY_BYTES + 1)
    if len(body) > MAX_TOKEN_BODY_BYTES:
        raise OAuthError("GitLab OAuth response exceeds the size limit")
    try:
        payload = json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise OAuthError("GitLab OAuth endpoint returned invalid JSON") from exc
    if not isinstance(payload, dict):
        raise OAuthError("GitLab OAuth endpoint returned a non-object payload")
    return payload


def post_form(
    issuer: str,
    path: str,
    fields: dict[str, str],
    *,
    opener: Callable[..., Any],
    timeout: float,
    operation: str,
    audit_attempt: AuditAttempt | None = None,
    audit_outcome: AuditOutcome | None = None,
) -> dict[str, Any]:
    """POST an OAuth form through the caller's no-redirect transport.

    Args:
        issuer: Canonical GitLab origin.
        path: OAuth endpoint path.
        fields: Form fields to encode.
        opener: Caller-owned no-redirect transport.
        timeout: Request timeout in seconds.
        operation: Bounded OAuth lifecycle operation name.
        audit_attempt: Optional write-ahead audit callback.
        audit_outcome: Optional best-effort audit outcome callback.

    Returns:
        Parsed JSON object returned by GitLab.

    Raises:
        OAuthError: The provider, transport, protocol, or response fails safely.
    """
    request = urllib.request.Request(
        f"{issuer}{path}",
        data=urllib.parse.urlencode(fields).encode("ascii"),
        method="POST",
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/json",
        },
    )
    if audit_attempt is not None:
        audit_attempt(operation)
    try:
        with opener(request, timeout=timeout) as response:
            try:
                payload = _parse_json_response(response)
            except OAuthError as exc:
                if audit_outcome is not None:
                    audit_outcome(operation, "error", None, "protocol")
                raise OAuthError(
                    str(exc),
                    completion_uncertain=True,
                ) from exc
            if audit_outcome is not None:
                audit_outcome(operation, "success", None, None)
            return payload
    except urllib.error.HTTPError as exc:
        if audit_outcome is not None:
            audit_outcome(operation, "error", exc.code, "http")
        try:
            payload = _parse_json_response(exc)
        except OAuthError:
            payload = {}
        error = payload.get("error")
        if isinstance(error, str):
            raise OAuthError(
                f"GitLab OAuth request failed: {error}",
                code=error,
                retryable=exc.code == 429 or exc.code >= 500,
                completion_uncertain=exc.code == 429 or exc.code >= 500,
            ) from exc
        raise OAuthError(
            f"GitLab OAuth request failed with HTTP {exc.code}",
            retryable=exc.code == 429 or exc.code >= 500,
            completion_uncertain=exc.code == 429 or exc.code >= 500,
        ) from exc
    except urllib.error.URLError as exc:
        reason = exc.reason
        conclusively_pre_exchange = isinstance(
            reason,
            (ConnectionRefusedError, socket.gaierror),
        )
        if audit_outcome is not None:
            failure_kind = "timeout" if isinstance(reason, TimeoutError) else "network"
            audit_outcome(operation, "error", None, failure_kind)
        raise OAuthError(
            "GitLab OAuth network request failed",
            retryable=True,
            completion_uncertain=not conclusively_pre_exchange,
        ) from exc
    except (TimeoutError, ConnectionResetError, http.client.HTTPException) as exc:
        if audit_outcome is not None:
            failure_kind = "timeout" if isinstance(exc, TimeoutError) else "protocol"
            audit_outcome(operation, "error", None, failure_kind)
        raise OAuthError(
            "GitLab OAuth network request failed",
            retryable=True,
            completion_uncertain=True,
        ) from exc


def token_profile(
    payload: dict[str, Any],
    *,
    issuer: str,
    client_id: str,
    now: float,
    require_refresh_token: bool = True,
) -> Profile:
    """Convert a token response into one validated profile record."""
    access_token = payload.get("access_token")
    refresh_token = payload.get("refresh_token")
    expires_in = payload.get("expires_in")
    if not isinstance(access_token, str) or not access_token:
        raise OAuthError("GitLab OAuth response is missing access_token")
    if require_refresh_token and (
        not isinstance(refresh_token, str) or not refresh_token
    ):
        raise OAuthError("GitLab OAuth response is missing replacement refresh_token")
    if (
        not isinstance(expires_in, int)
        or isinstance(expires_in, bool)
        or expires_in <= 0
        or expires_in > MAX_EXPIRES_IN_SECONDS
    ):
        raise OAuthError("GitLab OAuth response has invalid expires_in")
    token_type = str(payload.get("token_type") or "Bearer")
    if token_type.lower() != "bearer":
        raise OAuthError("GitLab OAuth response declares unsupported token_type")
    scope = payload.get("scope", DEFAULT_SCOPE)
    scopes = scope.split() if isinstance(scope, str) and scope else [DEFAULT_SCOPE]
    return {
        "issuer": issuer,
        "client_id": client_id,
        "access_token": access_token,
        "refresh_token": refresh_token if isinstance(refresh_token, str) else "",
        "token_type": token_type,
        "obtained_at": int(now),
        "expires_at": int(now) + expires_in,
        "scopes": scopes,
        "usable": True,
    }


@dataclass
class _CallbackResult:
    code: str | None = None
    state: str | None = None
    error: str | None = None


class _CallbackServer(http.server.HTTPServer):
    allow_reuse_address = False
    callback_result: _CallbackResult
    callback_received: threading.Event
    stop_requested: threading.Event
    expected_state: str

    def get_request(self) -> tuple[socket.socket, Any]:
        """Accept one callback peer and bound its request-read lifetime."""
        request, address = super().get_request()
        request.settimeout(CALLBACK_REQUEST_TIMEOUT_SECONDS)
        return request, address


class _CallbackHandler(http.server.BaseHTTPRequestHandler):
    """Single-purpose loopback OAuth callback handler."""

    server: _CallbackServer

    def handle_one_request(self) -> None:
        """Close an idle or partial callback peer after its socket timeout."""
        try:
            super().handle_one_request()
        except (TimeoutError, OSError):
            self.close_connection = True

    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler contract
        expected_host = f"{CALLBACK_HOST}:{CALLBACK_PORT}"
        if self.headers.get("Host") != expected_host:
            self.send_error(421)
            return
        parsed = urllib.parse.urlsplit(self.path)
        if parsed.path != CALLBACK_PATH:
            self.send_error(404)
            return
        values = urllib.parse.parse_qs(parsed.query)
        code = (values.get("code") or [None])[0]
        state = (values.get("state") or [None])[0]
        error = (values.get("error") or [None])[0]
        if (
            state is None
            or not secrets.compare_digest(
                state.encode("utf-8"),
                self.server.expected_state.encode("utf-8"),
            )
            or (code is None and error is None)
        ):
            self.send_error(400)
            return
        self.server.callback_result = _CallbackResult(
            code=code,
            state=state,
            error=error,
        )
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.end_headers()
        self.wfile.write(b"GitLab authorization received. Return to the terminal.")
        self.wfile.flush()
        self.server.callback_received.set()

    def log_message(self, _format: str, *_args: object) -> None:
        return


def authorization_code_login(
    issuer: str,
    client_id: str,
    *,
    opener: Callable[..., Any],
    timeout: float,
    open_browser: Callable[[str], bool] = webbrowser.open,
    emit_authorize_url: Callable[[str], None] | None = None,
    now: Callable[[], float] = time.time,
    monotonic: Callable[[], float] = time.monotonic,
    audit_attempt: AuditAttempt | None = None,
    audit_outcome: AuditOutcome | None = None,
) -> Profile:
    """Run Authorization Code with PKCE over a fixed loopback callback.

    Args:
        issuer: Canonical GitLab origin.
        client_id: Public OAuth application identifier.
        opener: Caller-owned no-redirect transport.
        timeout: Local budget shared by the callback wait and the decision to
            start token exchange. The unconsumed remainder becomes the exchange
            transport timeout, which bounds blocking operations rather than
            guaranteeing that the exchange completes before the deadline.
        open_browser: Browser launcher.
        emit_authorize_url: Optional safe authorization-URL sink.
        now: Wall clock used for token timestamps.
        monotonic: Monotonic clock used for elapsed callback time.
        audit_attempt: Optional write-ahead audit callback.
        audit_outcome: Optional best-effort audit outcome callback.

    Returns:
        Validated rotating-token profile.

    Raises:
        OAuthError: Listener, callback, provider, or transport processing fails.
    """
    verifier, challenge = generate_pkce_pair()
    expected_state = secrets.token_urlsafe(32)
    authorize_url = build_authorize_url(issuer, client_id, expected_state, challenge)
    try:
        server = _CallbackServer((CALLBACK_HOST, CALLBACK_PORT), _CallbackHandler)
    except OSError as exc:
        raise OAuthError(
            "cannot bind the GitLab OAuth callback listener; "
            "use auth device-login if this port is unavailable"
        ) from exc
    server.callback_result = _CallbackResult()
    server.callback_received = threading.Event()
    server.stop_requested = threading.Event()
    server.expected_state = expected_state
    deadline = monotonic() + timeout

    def serve_until_callback() -> None:
        server.timeout = 0.25
        while (
            not server.callback_received.is_set()
            and not server.stop_requested.is_set()
            and monotonic() < deadline
        ):
            server.handle_request()

    thread = threading.Thread(target=serve_until_callback, daemon=True)
    thread.start()
    try:
        if emit_authorize_url is not None:
            emit_authorize_url(authorize_url)
        try:
            opened = bool(open_browser(authorize_url))
        except Exception:  # pragma: no cover - platform browser integration
            opened = False
        if not opened and emit_authorize_url is None:
            raise OAuthError(
                "could not open a browser; use auth device-login on a "
                "browserless or remote system"
            )
        remaining = max(0.0, deadline - monotonic())
        if not server.callback_received.wait(remaining):
            raise OAuthError(
                "timed out waiting for GitLab OAuth callback; "
                "use auth device-login on a browserless or remote system"
            )
        result = server.callback_result
    finally:
        server.stop_requested.set()
        thread.join(timeout=1)
        server.server_close()
    if result.error:
        raise OAuthError(f"GitLab authorization failed: {result.error}")
    if not result.code or not result.state:
        raise OAuthError("GitLab OAuth callback is incomplete")
    if not secrets.compare_digest(
        result.state.encode("utf-8"),
        expected_state.encode("utf-8"),
    ):
        raise OAuthError("GitLab OAuth callback state mismatch")
    remaining = deadline - monotonic()
    if remaining <= 0:
        raise OAuthError(
            "GitLab OAuth deadline expired before the token exchange could start; "
            "retry auth login"
        )
    payload = post_form(
        issuer,
        "/oauth/token",
        {
            "client_id": client_id,
            "code": result.code,
            "grant_type": "authorization_code",
            "redirect_uri": CALLBACK_URI,
            "code_verifier": verifier,
        },
        opener=opener,
        timeout=remaining,
        operation="oauth.authorization_code.exchange",
        audit_attempt=audit_attempt,
        audit_outcome=audit_outcome,
    )
    return token_profile(payload, issuer=issuer, client_id=client_id, now=now())


def _has_control_characters(value: str) -> bool:
    """Return True when a value carries Unicode control characters."""
    return any(unicodedata.category(character) == "Cc" for character in value)


def _validate_device_instructions(
    verification_uri: str,
    user_code: str,
    issuer: str,
) -> None:
    """Reject device instructions that are unsafe to display or misdirect the user.

    Terminal safety and issuer binding are repository defense-in-depth policy.
    RFC 8628 leaves the user-code format to the authorization server, so any
    non-control code is preserved unchanged. Binding the verification URI to
    the configured issuer origin deliberately narrows support for deployments
    that publish device verification on a different host.

    Raises:
        OAuthError: The provider response cannot be displayed or trusted.
    """
    if _has_control_characters(user_code):
        raise OAuthError("GitLab device response has invalid user_code")
    if _has_control_characters(verification_uri) or any(
        character in verification_uri for character in (" ", "\\")
    ):
        raise OAuthError("GitLab device response has invalid verification_uri")
    try:
        parsed = urllib.parse.urlsplit(verification_uri)
        parsed_issuer = urllib.parse.urlsplit(issuer)
        verification_port = parsed.port
        issuer_port = parsed_issuer.port
    except ValueError as exc:
        raise OAuthError("GitLab device response has invalid verification_uri") from exc
    if (
        parsed.scheme != parsed_issuer.scheme
        or not parsed.hostname
        or parsed.username is not None
        or parsed.password is not None
        or parsed.hostname != parsed_issuer.hostname
    ):
        raise OAuthError("GitLab device response has invalid verification_uri")
    default_ports = {"https": 443, "http": 80}
    default_port = default_ports.get(parsed.scheme)
    verification_effective_port = (
        verification_port if verification_port is not None else default_port
    )
    issuer_effective_port = issuer_port if issuer_port is not None else default_port
    if verification_effective_port != issuer_effective_port:
        raise OAuthError("GitLab device response has invalid verification_uri")


def device_login(
    issuer: str,
    client_id: str,
    *,
    opener: Callable[..., Any],
    timeout: float,
    emit_instructions: Callable[[str, str], None],
    now: Callable[[], float] = time.time,
    monotonic: Callable[[], float] = time.monotonic,
    sleep: Callable[[float], None] = time.sleep,
    audit_attempt: AuditAttempt | None = None,
    audit_outcome: AuditOutcome | None = None,
) -> Profile:
    """Run GitLab Device Authorization Grant with bounded polling.

    Args:
        issuer: Canonical GitLab origin.
        client_id: Public OAuth application identifier.
        opener: Caller-owned no-redirect transport.
        timeout: Maximum authorization duration in seconds.
        emit_instructions: Safe verification URI and user-code sink.
        now: Wall clock used for token timestamps.
        monotonic: Monotonic clock used for elapsed authorization time.
        sleep: Poll delay function.
        audit_attempt: Optional write-ahead audit callback.
        audit_outcome: Optional best-effort audit outcome callback.

    Returns:
        Validated access-token profile.

    Raises:
        OAuthError: Device authorization or token processing fails.
    """
    device = post_form(
        issuer,
        "/oauth/authorize_device",
        {"client_id": client_id, "scope": DEFAULT_SCOPE},
        opener=opener,
        timeout=timeout,
        operation="oauth.device.authorize",
        audit_attempt=audit_attempt,
        audit_outcome=audit_outcome,
    )
    device_code = device.get("device_code")
    user_code = device.get("user_code")
    verification_uri = device.get("verification_uri")
    expires_in = device.get("expires_in")
    interval = device.get("interval", 5)
    if not isinstance(device_code, str) or not device_code:
        raise OAuthError("GitLab device response is missing device_code")
    if not isinstance(user_code, str) or not user_code:
        raise OAuthError("GitLab device response is missing user_code")
    if not isinstance(verification_uri, str) or not verification_uri:
        raise OAuthError("GitLab device response has invalid verification_uri")
    _validate_device_instructions(verification_uri, user_code, issuer)
    if (
        not isinstance(expires_in, int)
        or isinstance(expires_in, bool)
        or expires_in <= 0
    ):
        raise OAuthError("GitLab device response has invalid expires_in")
    if not isinstance(interval, int) or isinstance(interval, bool) or interval <= 0:
        raise OAuthError("GitLab device response has invalid interval")
    emit_instructions(verification_uri, user_code)
    started = monotonic()
    deadline = min(started + expires_in, started + timeout)
    while monotonic() < deadline:
        remaining = deadline - monotonic()
        if remaining <= 0:
            break
        sleep(min(max(MIN_DEVICE_POLL_SECONDS, interval), remaining))
        if monotonic() >= deadline:
            break
        try:
            payload = post_form(
                issuer,
                "/oauth/token",
                {
                    "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                    "device_code": device_code,
                    "client_id": client_id,
                },
                opener=opener,
                timeout=max(0.001, min(timeout, deadline - monotonic())),
                operation="oauth.device.poll",
                audit_attempt=audit_attempt,
                audit_outcome=audit_outcome,
            )
        except OAuthError as exc:
            if exc.code == "authorization_pending":
                continue
            if exc.code == "slow_down":
                interval += 5
                continue
            if exc.retryable:
                interval = max(interval, MIN_DEVICE_POLL_SECONDS)
                continue
            raise
        return token_profile(
            payload,
            issuer=issuer,
            client_id=client_id,
            now=now(),
            require_refresh_token=False,
        )
    raise OAuthError("GitLab device authorization timed out")


def refresh_profile(
    profile: dict[str, Any],
    *,
    expected_issuer: str,
    expected_client_id: str,
    opener: Callable[..., Any],
    timeout: float,
    now: Callable[[], float] = time.time,
    audit_attempt: AuditAttempt | None = None,
    audit_outcome: AuditOutcome | None = None,
) -> Profile:
    """Rotate an OAuth refresh token and return the replacement profile.

    Args:
        profile: Tombstoned persisted profile containing the refresh token.
        expected_issuer: Trusted GitLab origin.
        expected_client_id: Trusted public client identifier.
        opener: Caller-owned no-redirect transport.
        timeout: Request timeout in seconds.
        now: Wall clock used for replacement token timestamps.
        audit_attempt: Optional write-ahead audit callback.
        audit_outcome: Optional best-effort audit outcome callback.

    Returns:
        Validated replacement profile.

    Raises:
        OAuthError: Binding, exchange, or replacement validation fails. A
            completion-uncertain error requires the stored profile to remain
            unusable until the operator logs in again.
    """
    issuer = str(profile["issuer"])
    client_id = str(profile["client_id"])
    if not secrets.compare_digest(
        issuer.encode("utf-8"),
        expected_issuer.encode("utf-8"),
    ) or not secrets.compare_digest(
        client_id.encode("utf-8"),
        expected_client_id.encode("utf-8"),
    ):
        raise OAuthError(
            "stored GitLab OAuth profile is not bound to this instance and client"
        )
    payload = post_form(
        expected_issuer,
        "/oauth/token",
        {
            "client_id": expected_client_id,
            "refresh_token": str(profile["refresh_token"]),
            "grant_type": "refresh_token",
            "redirect_uri": CALLBACK_URI,
        },
        opener=opener,
        timeout=timeout,
        operation="oauth.refresh",
        audit_attempt=audit_attempt,
        audit_outcome=audit_outcome,
    )
    try:
        return token_profile(
            payload,
            issuer=expected_issuer,
            client_id=expected_client_id,
            now=now(),
        )
    except OAuthError as exc:
        raise OAuthError(
            "GitLab OAuth refresh completed without a usable replacement token",
            completion_uncertain=True,
        ) from exc
