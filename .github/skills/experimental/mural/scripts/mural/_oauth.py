#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Loopback OAuth 2.0 + PKCE login flow for the Mural CLI.

Carved from ``mural/__init__.py`` (Step 5.2 of the modularization plan).
Contains the authorize-URL builder, single-shot loopback HTTP handler/server,
authorization-code exchange, redirect-URI validation, the bootstrap
client-credentials probe, and the orchestrating ``_run_login`` entry point.

PKCE primitives (``_b64url_nopad``, ``_generate_pkce_pair``, ``_verify_pkce``)
and the scope helpers (``_token_granted_scopes``, ``_require_scope``) now live
in this module and are re-exported from the package ``__init__`` to preserve
``mural.<symbol>`` access.  Transport and credential helpers (``_TOKEN_OPENER``,
``_read_capped``, ``_parse_token_response``, ``_read_response_body``, ``_emit``,
``_select_profile``, ``_load_token_store``, ``_resolve_token_store_path``) come
from the package and are bound when this submodule is first imported by
``__init__.py`` (which happens after those helpers are defined).
"""

from __future__ import annotations

import base64
import contextlib
import errno
import hashlib
import http.server
import json
import logging
import os
import pathlib
import secrets
import socket
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from dataclasses import dataclass
from typing import Any, Callable, Sequence

from . import (  # noqa: E402 - package siblings defined before this import runs
    _TOKEN_OPENER,
    _compute_expires_at,
    _emit,
    _load_token_store,
    _parse_token_response,
    _read_capped,
    _read_response_body,
    _refresh_access_token,
    _resolve_token_store_path,
    _select_profile,
)
from ._constants import (
    _REFRESH_LOCK,
    DEFAULT_LOGIN_SCOPES,
    DEFAULT_PROFILE_NAME,
    DEFAULT_REDIRECT_URI,
    DEFAULT_SCOPES,
    ENV_CLIENT_ID,
    ENV_CLIENT_SECRET,
    ENV_REDIRECT_URI,
    MURAL_AUTHORIZE_URL,
    MURAL_MAX_BODY_BYTES,
    MURAL_TOKEN_URL,
    USER_AGENT,
)
from ._credentials import _token_store_session
from ._exceptions import (
    MuralAPIError,
    MuralAuthScopeError,
    MuralError,
    MuralSecurityError,
)


def _pkg() -> Any:
    """Return the package module for monkeypatch-aware call-time routing.

    Refresh helpers reach package-level siblings (e.g. ``_apply_refresh``)
    through this accessor so tests can patch ``mural.<symbol>`` and have the
    override honored at call time rather than binding at import time.
    """
    return sys.modules[__package__]


def _apply_refresh(
    store: dict[str, Any],
    *,
    client_id: str,
    client_secret: str | None,
    token_url: str,
    _http: Callable[..., Any],
    _now: Callable[[], float],
    profile_name: str = DEFAULT_PROFILE_NAME,
) -> dict[str, Any]:
    """Refresh ``profile_name`` inside a v2 envelope and return a new envelope."""
    profile = _select_profile(store, profile_name)
    refresh_token = profile.get("refresh_token")
    if not refresh_token:
        raise MuralError(
            "token store has no refresh_token; run `python -m mural auth login`"
        )
    fresh = _refresh_access_token(
        refresh_token,
        client_id=client_id,
        client_secret=client_secret,
        token_url=token_url,
        _http=_http,
    )
    expires_in = int(fresh.get("expires_in", 0) or 0)
    new_profile = dict(profile)
    new_profile["access_token"] = fresh["access_token"]
    if "refresh_token" in fresh and fresh["refresh_token"]:
        new_profile["refresh_token"] = fresh["refresh_token"]
    new_profile["expires_at"] = _compute_expires_at(_now(), expires_in)
    new_store = dict(store)
    new_profiles = dict(store.get("profiles") or {})
    new_profiles[profile_name] = new_profile
    new_store["profiles"] = new_profiles
    return new_store


def _coalesced_refresh(
    store_path: pathlib.Path,
    observed_access_token: str,
    *,
    client_id: str,
    client_secret: str | None,
    token_url: str,
    _http: Callable[..., Any],
    _now: Callable[[], float],
    profile_name: str,
) -> dict[str, Any]:
    """Run a token refresh under both in-process and cross-process locks.

    Holds :data:`_REFRESH_LOCK` to coalesce threads, and ``_token_store_session``
    to coalesce peer processes. Re-reads the token store inside the locks; if a
    peer (thread or process) already rotated the access token, returns the
    peer's store without contacting the token endpoint. Otherwise calls
    :func:`_apply_refresh`, persists, and returns the new store.
    """
    with _REFRESH_LOCK:
        with _token_store_session(store_path) as (envelope, commit):
            store = envelope or {}
            profile = _select_profile(store, profile_name)
            if profile.get("access_token") != observed_access_token:
                return store
            store = _pkg()._apply_refresh(
                store,
                client_id=client_id,
                client_secret=client_secret,
                token_url=token_url,
                _http=_http,
                _now=_now,
                profile_name=profile_name,
            )
            commit(store)
            return store


def _b64url_nopad(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def _token_granted_scopes(
    store: dict[str, Any] | None,
    profile_name: str = DEFAULT_PROFILE_NAME,
) -> tuple[str, ...]:
    """Return the scopes granted to the named profile in a v2 envelope.

    Returns an empty tuple when ``store`` is empty, the profile is missing,
    or ``granted_scopes`` is absent or malformed. Mural's ``/token`` endpoint
    does not return ``scope`` (RFC 6749 §5.1 permits this; per §3.3 the
    granted scope equals the requested scope when omitted), so the canonical
    record is the ``granted_scopes`` list captured at authorization time.
    """
    if not store:
        return ()
    try:
        profile = _select_profile(store, profile_name)
    except MuralError:
        return ()
    granted = profile.get("granted_scopes")
    if isinstance(granted, list) and all(isinstance(s, str) for s in granted):
        return tuple(granted)
    return ()


def _require_scope(
    scope: "str | Sequence[str]",
    *,
    store: dict[str, Any] | None = None,
    profile_name: str = DEFAULT_PROFILE_NAME,
) -> None:
    """Raise :class:`MuralAuthScopeError` when ``scope`` is not in the granted
    set of the named profile.

    ``scope`` may be a single string or a sequence of strings; in the
    sequence form every entry must be granted (logical AND). Templates and
    composite tools pass their required scopes directly.
    """
    if store is None:
        store = _load_token_store(_resolve_token_store_path())
    granted = _token_granted_scopes(store, profile_name)
    needed = (scope,) if isinstance(scope, str) else tuple(scope)
    for s in needed:
        if s not in granted:
            raise MuralAuthScopeError(s, granted)


def _generate_pkce_pair() -> tuple[str, str]:
    """Return ``(verifier, challenge)`` for the PKCE S256 method."""
    verifier = secrets.token_urlsafe(64)
    challenge = _b64url_nopad(hashlib.sha256(verifier.encode("ascii")).digest())
    return verifier, challenge


def _verify_pkce(verifier: str, challenge: str) -> bool:
    """Return ``True`` when ``challenge`` is the S256 digest of ``verifier``."""
    try:
        verifier_bytes = verifier.encode("ascii")
        challenge_bytes = challenge.encode("ascii")
    except UnicodeEncodeError:
        # PKCE values are ASCII per RFC 7636; non-ASCII input cannot match.
        return False
    expected = _b64url_nopad(hashlib.sha256(verifier_bytes).digest()).encode("ascii")
    # Constant-time comparison to mirror what the auth server does.
    return secrets.compare_digest(expected, challenge_bytes)


def _build_authorize_url(
    client_id: str,
    redirect_uri: str,
    state: str,
    code_challenge: str,
    scopes: str,
    *,
    authorize_url: str = MURAL_AUTHORIZE_URL,
) -> str:
    """Construct the OAuth 2.0 authorize URL with PKCE S256 parameters."""
    if not client_id:
        raise MuralError("client_id is required to build authorize URL")
    if not redirect_uri:
        raise MuralError("redirect_uri is required to build authorize URL")
    if not state:
        raise MuralError("state is required to build authorize URL")
    if not code_challenge:
        raise MuralError("code_challenge is required to build authorize URL")
    query = {
        "response_type": "code",
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "state": state,
        "code_challenge": code_challenge,
        "code_challenge_method": "S256",
        "scope": scopes,
    }
    return f"{authorize_url}?{urllib.parse.urlencode(query)}"


@dataclass
class _CallbackResult:
    code: str | None = None
    state: str | None = None
    error: str | None = None
    error_description: str | None = None


class _LoopbackHandler(http.server.BaseHTTPRequestHandler):
    """Single-shot HTTP handler that captures the OAuth callback query.

    Hardened against drive-by callers: only ``GET /callback`` is accepted,
    and the ``Host`` header must match the loopback bind address. Other
    methods receive ``405`` and other paths receive ``404``. A mismatched
    ``Host`` returns ``421`` so external scanners cannot smuggle a callback
    via DNS rebinding or virtual-host shenanigans. Default access logging
    is suppressed so token-bearing query strings never reach stderr.
    """

    server_version = "MuralLoopback/1.0"
    sys_version = ""

    def _reject(self, code: int, body: bytes = b"") -> None:
        self.send_response(code)
        if body:
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
        else:
            self.send_header("Content-Length", "0")
        self.end_headers()
        if body:
            self.wfile.write(body)

    def _expected_hosts(self) -> set[str]:
        port = getattr(self.server, "server_port", None)
        if port is None:
            address = getattr(self.server, "server_address", ("", 0))
            port = address[1] if isinstance(address, tuple) and len(address) > 1 else 0
        return {
            f"127.0.0.1:{port}",
            f"localhost:{port}",
            f"[::1]:{port}",
        }

    def _host_ok(self) -> bool:
        host = self.headers.get("Host") if getattr(self, "headers", None) else None
        if not host:
            return False
        return host in self._expected_hosts()

    def do_GET(self) -> None:  # noqa: N802 - http.server contract
        if not self._host_ok():
            self._reject(421, b"misdirected request")
            return
        parsed = urllib.parse.urlsplit(self.path)
        if parsed.path != "/callback":
            self._reject(404, b"not found")
            return
        params = urllib.parse.parse_qs(parsed.query)
        result: _CallbackResult = self.server.callback_result  # type: ignore[attr-defined]
        result.code = (params.get("code") or [None])[0]
        result.state = (params.get("state") or [None])[0]
        result.error = (params.get("error") or [None])[0]
        result.error_description = (params.get("error_description") or [None])[0]

        body = (
            "<html><body><h1>Mural authentication complete</h1>"
            "<p>You may close this window and return to the terminal.</p>"
            "</body></html>"
        ).encode("utf-8")
        if result.error:
            self.send_response(400)
        else:
            self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
        # Signal the main thread that the callback has been received.
        self.server.callback_received.set()  # type: ignore[attr-defined]

    def do_POST(self) -> None:  # noqa: N802 - http.server contract
        self._reject(405, b"method not allowed")

    do_PUT = do_POST  # noqa: N815 - http.server contract
    do_DELETE = do_POST  # noqa: N815 - http.server contract
    do_PATCH = do_POST  # noqa: N815 - http.server contract
    do_HEAD = do_POST  # noqa: N815 - http.server contract
    do_OPTIONS = do_POST  # noqa: N815 - http.server contract

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
        # Suppress default stderr access logging entirely; OAuth callbacks
        # carry secrets in the query string and must never reach stderr.
        return


class _LoopbackServer(http.server.HTTPServer):
    """HTTPServer tuned for the single-shot OAuth callback flow."""

    timeout = 30
    request_queue_size = 4

    def server_bind(self) -> None:  # type: ignore[override]
        # On Windows, request exclusive port ownership so concurrent CLI
        # invocations cannot race onto the same loopback port.
        if sys.platform == "win32":
            SO_EXCLUSIVEADDRUSE = 0x4  # noqa: N806
            with contextlib.suppress(OSError, AttributeError):
                self.socket.setsockopt(socket.SOL_SOCKET, SO_EXCLUSIVEADDRUSE, 1)
        super().server_bind()


def _probe_client_credentials(
    client_id: str,
    client_secret: str,
    *,
    token_url: str = MURAL_TOKEN_URL,
    _http: Callable[..., Any] = _TOKEN_OPENER.open,
) -> tuple[bool, str]:
    """Best-effort credential probe used by ``auth bootstrap`` Stage 8.

    Posts a ``client_credentials`` grant to Mural's token endpoint to verify
    the just-saved client_id/client_secret pair. Returns ``(ok, message)``;
    ``message`` is safe to display to the user (no raw bodies, no header
    echoes, no secrets). Network failures and 4xx responses both produce
    ``ok=False`` with a remediation hint; only 2xx returns ``ok=True``.
    """
    body = urllib.parse.urlencode(
        {
            "grant_type": "client_credentials",
            "client_id": client_id,
            "client_secret": client_secret,
            "scope": DEFAULT_LOGIN_SCOPES,
        }
    ).encode("ascii")
    request = urllib.request.Request(
        token_url,
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/json",
            "User-Agent": USER_AGENT,
        },
    )
    try:
        with _http(request, timeout=10) as resp:  # type: ignore[arg-type]
            status = getattr(resp, "status", 200)
            # Drain the body so the connection is reusable; we deliberately
            # do not parse, log, or surface the token payload here.
            _read_capped(resp, MURAL_MAX_BODY_BYTES)
    except urllib.error.HTTPError as exc:
        return (
            False,
            f"credentials rejected by Mural (HTTP {exc.code})",
        )
    except (urllib.error.URLError, TimeoutError, OSError):
        return (
            False,
            "could not reach Mural; rerun with --no-test to skip probing",
        )
    if 200 <= status < 300:
        return (True, "credentials accepted by Mural")
    return (False, f"credentials rejected by Mural (HTTP {status})")


def _exchange_authorization_code(
    *,
    code: str,
    code_verifier: str,
    client_id: str,
    client_secret: str | None,
    redirect_uri: str,
    token_url: str = MURAL_TOKEN_URL,
    _http: Callable[..., Any] = _TOKEN_OPENER.open,
    _now: Callable[[], float] = time.time,
) -> dict[str, Any]:
    body: dict[str, str] = {
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": redirect_uri,
        "code_verifier": code_verifier,
        "client_id": client_id,
    }
    if client_secret:
        body["client_secret"] = client_secret
    encoded = urllib.parse.urlencode(body).encode("ascii")
    request = urllib.request.Request(
        token_url,
        data=encoded,
        method="POST",
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/json",
            "User-Agent": USER_AGENT,
        },
    )
    try:
        with _http(request) as resp:  # type: ignore[arg-type]
            data = _parse_token_response(resp)
            status = getattr(resp, "status", 200)
    except urllib.error.HTTPError as exc:
        text = _read_response_body(exc).decode("utf-8", errors="replace")
        raise MuralAPIError(
            exc.code, "TOKEN_EXCHANGE_FAILED", text or "exchange failed"
        ) from exc
    if status >= 400:
        raise MuralAPIError(status, "TOKEN_EXCHANGE_FAILED", json.dumps(data))
    if "access_token" not in data:
        raise MuralAPIError(
            status, "TOKEN_EXCHANGE_INVALID_PAYLOAD", "missing access_token"
        )
    expires_in = int(data.get("expires_in", 0) or 0)
    record = {
        "access_token": data["access_token"],
        "refresh_token": data.get("refresh_token"),
        "token_type": data.get("token_type", "Bearer"),
        "expires_at": _compute_expires_at(_now(), expires_in),
        "obtained_at": int(_now()),
    }
    return record


def _start_loopback_server(
    *,
    port: int,
    server_factory: Callable[..., http.server.HTTPServer] = _LoopbackServer,
    bind_host: str = "127.0.0.1",
) -> tuple[http.server.HTTPServer, _CallbackResult, threading.Event, int]:
    try:
        server = server_factory((bind_host, port), _LoopbackHandler)
    except OSError as exc:
        if exc.errno == errno.EADDRINUSE:
            raise MuralError(
                f"port {port} already in use on {bind_host}; set "
                "MURAL_REDIRECT_URI to a free loopback port and re-register "
                "it in your Mural OAuth app"
            ) from exc
        raise
    # Attach state holders the handler reads from.
    server.callback_result = _CallbackResult()  # type: ignore[attr-defined]
    server.callback_received = threading.Event()  # type: ignore[attr-defined]
    bound_port = server.server_address[1]
    return server, server.callback_result, server.callback_received, bound_port  # type: ignore[attr-defined]


def _validate_redirect_uri(uri: str) -> str:
    """Reject any ``MURAL_REDIRECT_URI`` override outside the loopback allowlist.

    The OAuth Authorization Code + PKCE flow only ever needs to redirect back
    to a loopback port on this host. Anything else is treated as a security
    violation: an attacker-controlled override could redirect the
    authorization code to a remote host, defeating PKCE's intent. Both
    ``localhost`` and ``127.0.0.1`` are accepted (per RFC 8252 §7.3); IPv6
    ``[::1]`` and any other host are rejected.
    """
    if not isinstance(uri, str) or not uri:
        raise MuralSecurityError("redirect_uri override is empty")
    try:
        parsed = urllib.parse.urlsplit(uri)
    except ValueError as exc:
        raise MuralSecurityError(f"redirect_uri is invalid: {exc}") from exc
    if parsed.scheme != "http":
        raise MuralSecurityError(
            f"redirect_uri scheme must be http (got {parsed.scheme!r})"
        )
    host = (parsed.hostname or "").lower()
    if host not in {"localhost", "127.0.0.1"}:
        raise MuralSecurityError(
            f"redirect_uri host must be 'localhost' or '127.0.0.1' "
            f"(got {host!r}); IPv6 loopback ('[::1]') is not accepted"
        )
    port = parsed.port
    if port is None or not (1024 <= port <= 65535):
        raise MuralSecurityError(
            "redirect_uri must specify a port in the range 1024-65535"
        )
    if parsed.path != "/callback":
        raise MuralSecurityError(
            f"redirect_uri path must be /callback exactly (got {parsed.path!r})"
        )
    if parsed.query:
        raise MuralSecurityError("redirect_uri must not include a query string")
    if parsed.fragment:
        raise MuralSecurityError("redirect_uri must not include a fragment")
    return uri


def _resolve_redirect_uri(
    env: dict[str, str] | None = None,
) -> tuple[str, str, int]:
    """Return ``(redirect_uri, bind_host, port)`` for the OAuth loopback flow.

    Reads ``MURAL_REDIRECT_URI`` from ``env`` (defaulting to ``os.environ``).
    When unset, returns ``DEFAULT_REDIRECT_URI`` (URI uses ``localhost`` so
    the Mural portal accepts it) paired with bind host ``127.0.0.1`` per
    RFC 8252 §7.3. When set, validates via ``_validate_redirect_uri`` and
    parses out the host and port; an override using ``localhost`` is
    normalised to bind host ``127.0.0.1`` to avoid IPv6 ambiguity.
    """
    src = env if env is not None else os.environ
    override = src.get(ENV_REDIRECT_URI)
    if not override:
        return DEFAULT_REDIRECT_URI, "127.0.0.1", 8765
    uri = _validate_redirect_uri(override)
    parsed = urllib.parse.urlsplit(uri)
    host = (parsed.hostname or "").lower()
    if host == "localhost":
        host = "127.0.0.1"
    port = parsed.port
    if port is None:
        # ``_validate_redirect_uri`` enforces a port, but guard defensively
        # so the type checker sees a concrete int.
        raise MuralSecurityError("redirect_uri must specify a port")
    return uri, host, port


def _run_login(
    *,
    env: dict[str, str] | None = None,
    scopes: str | None = None,
    timeout_seconds: int = 300,
    open_browser: Callable[[str], bool] = webbrowser.open,
    server_factory: Callable[..., http.server.HTTPServer] = _LoopbackServer,
    _http: Callable[..., Any] = _TOKEN_OPENER.open,
    _now: Callable[[], float] = time.time,
) -> dict[str, Any]:
    src = env if env is not None else os.environ
    client_id = src.get(ENV_CLIENT_ID)
    if not client_id:
        raise MuralError(f"{ENV_CLIENT_ID} is not set")
    client_secret = src.get(ENV_CLIENT_SECRET) or None

    redirect_uri, bind_host, port = _resolve_redirect_uri(src)
    server, result, received, _bound_port = _start_loopback_server(
        server_factory=server_factory, bind_host=bind_host, port=port
    )

    verifier, challenge = _generate_pkce_pair()
    state = secrets.token_urlsafe(32)
    authorize_url = _build_authorize_url(
        client_id=client_id,
        redirect_uri=redirect_uri,
        state=state,
        code_challenge=challenge,
        scopes=scopes or DEFAULT_SCOPES,
    )

    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        _emit(f"listening on {redirect_uri}", level=logging.INFO)
        # Emit the authorize URL to stderr before opening the browser so
        # headless / no-DISPLAY callers (SSH, remote terminals) can still
        # complete the flow. ``code_challenge`` is public by PKCE design and is not
        # in ``_REDACT_KEYS``; ``code_verifier`` is and would mangle this
        # URL if it ever appeared here, but PKCE keeps the verifier client-
        # side only.
        _emit(
            f"open this URL to authorize: {authorize_url}",
            level=logging.INFO,
        )
        opened = False
        try:
            opened = bool(open_browser(authorize_url))
        except Exception:  # noqa: BLE001
            opened = False
        if not opened:
            print(f"open this URL manually: {authorize_url}", file=sys.stderr)

        if not received.wait(timeout=timeout_seconds):
            raise MuralError("timed out waiting for OAuth callback")
    finally:
        server.shutdown()
        with contextlib.suppress(Exception):
            server.server_close()

    if result.error:
        raise MuralError(
            f"authorization failed: {result.error}: {result.error_description or ''}"
        )
    if not result.code:
        raise MuralError("authorization callback returned no code")
    if not result.state or not secrets.compare_digest(result.state, state):
        raise MuralSecurityError("state parameter mismatch on OAuth callback")

    record = _exchange_authorization_code(
        code=result.code,
        code_verifier=verifier,
        client_id=client_id,
        client_secret=client_secret,
        redirect_uri=redirect_uri,
        _http=_http,
        _now=_now,
    )
    return record
